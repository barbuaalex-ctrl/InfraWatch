import importlib.util
import json
import os
import stat
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('linux_agent', Path(__file__).with_name('agent.py'))
agent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(agent)


class LinuxAgentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.proc = self.folder / 'proc'
        self.proc.mkdir()
        (self.proc / 'stat').write_text('cpu  150 0 50 700 100 0 0 0 30 0\n')
        (self.proc / 'meminfo').write_text('MemTotal: 8388608 kB\nMemAvailable: 2097152 kB\n')
        (self.proc / 'uptime').write_text('1234.5 900.0\n')
        (self.proc / 'cpuinfo').write_text('processor : 0\nmodel name : Test Linux CPU\nphysical id : 0\ncore id : 0\n\nprocessor : 1\nmodel name : Test Linux CPU\nphysical id : 0\ncore id : 0\n')
        self.disk = SimpleNamespace(total=100 * 1024**3, used=60 * 1024**3, free=40 * 1024**3)
        for item in [patch.object(agent, 'PROC_DIR', self.proc),
                     patch.object(agent, 'DMI_DIR', self.folder / 'missing-dmi'),
                     patch.object(agent.shutil, 'disk_usage', return_value=self.disk),
                     patch.object(agent.platform, 'freedesktop_os_release', return_value={'PRETTY_NAME': 'Debian GNU/Linux 13'})]:
            item.start()
            self.addCleanup(item.stop)

    def test_real_metric_calculations_and_no_fake_gpu(self):
        self.assertEqual(agent.cpu_times(), (1000, 800))
        payload, previous = agent.metrics((800, 700), '0.10.0')
        self.assertEqual(payload['cpu'], 50)
        self.assertEqual(payload['ram'], 75)
        self.assertEqual(payload['disk'], 60)
        self.assertEqual(payload['diskFreeGB'], 40)
        self.assertEqual(payload['diskTotalGB'], 100)
        self.assertEqual(payload['systemDrive'], '/')
        self.assertEqual(payload['uptimeSeconds'], 1234.5)
        self.assertIsNone(payload['gpu'])
        self.assertEqual(previous, (1000, 800))

    def test_inventory_linux_identity_and_physical_cores(self):
        data = agent.inventory()
        self.assertEqual(data['osName'], 'Debian GNU/Linux 13')
        self.assertEqual(data['cpuName'], 'Test Linux CPU')
        self.assertEqual(data['cores'], 1)
        self.assertEqual(data['ramGB'], 8)
        self.assertEqual(data['gpu'], [])
        self.assertEqual(data['disks'][0]['name'], '/')

    def test_older_python_reads_distribution_from_os_release(self):
        release = self.folder / 'os-release'
        release.write_text('PRETTY_NAME="Amazon Linux 2023"\n')
        with patch.object(agent.platform, 'freedesktop_os_release', side_effect=AttributeError), patch.object(agent, 'OS_RELEASE_FILE', release):
            self.assertEqual(agent.inventory()['osName'], 'Amazon Linux 2023')

    def test_credentials_survive_restarts_and_use_private_linux_permissions(self):
        file = self.folder / 'state' / 'connection.json'
        data = {'serverUrl': 'https://monitor.example', 'serverId': 'device', 'token': 'private-token'}
        agent.save_connection(file, data)
        self.assertEqual(agent.load_connection(file), data)
        if os.name == 'posix':
            self.assertEqual(stat.S_IMODE(file.stat().st_mode), 0o600)
            self.assertEqual(stat.S_IMODE(file.parent.stat().st_mode), 0o700)
        self.assertFalse(list(file.parent.glob('.connection-*')))

    def test_invalid_or_unrelated_addresses_are_rejected(self):
        for value in ['ftp://example.com', 'http://user:pass@example.com', 'http://example.com/api', 'http://example.com/?token=secret']:
            with self.assertRaises(ValueError):
                agent.server_address(value)
        self.assertEqual(agent.server_address('https://example.com:8443/'), 'https://example.com:8443')

    def test_inventory_refresh_is_hourly_not_every_metric(self):
        connection = {'serverUrl': 'http://example.com', 'serverId': 'test', 'token': 'secret'}
        sent = []
        def capture(server, route, payload, headers):
            sent.append(payload)
            if len(sent) == 2:
                raise KeyboardInterrupt
        with patch.object(agent, 'api', side_effect=capture), patch.object(agent.time, 'sleep'), patch.object(agent, 'inventory', wraps=agent.inventory) as inventory:
            with self.assertRaises(KeyboardInterrupt):
                agent.run(connection, '0.10.0')
            self.assertEqual(inventory.call_count, 1)
        self.assertIn('inventory', sent[0])
        self.assertNotIn('inventory', sent[1])

    def test_expired_pairing_requests_a_new_code_without_exposing_secrets(self):
        from urllib.error import HTTPError
        pending = {'code': 'ABC-234', 'requestId': 'request', 'requestSecret': 'hidden'}
        approved = {'status': 'approved', 'serverId': 'device', 'token': 'private'}
        expired = HTTPError('http://example.com', 410, 'Expired', {}, None)
        with patch.object(agent, 'api', side_effect=[pending, expired, pending, approved]), patch.object(agent.time, 'sleep'), patch('builtins.print') as output:
            connection = agent.pair('http://example.com')
        self.assertEqual(connection['serverId'], 'device')
        self.assertNotIn('private', str(output.call_args_list))
        self.assertNotIn('hidden', str(output.call_args_list))

    def test_paused_monitoring_keeps_the_connection(self):
        from urllib.error import HTTPError
        connection = {'serverUrl': 'http://example.com', 'serverId': 'test', 'token': 'secret'}
        paused = HTTPError('http://example.com', 409, 'Paused', {}, None)
        with patch.object(agent, 'api', side_effect=[paused, KeyboardInterrupt]), patch.object(agent.time, 'sleep'):
            with self.assertRaises(KeyboardInterrupt):
                agent.run(connection, '0.10.0')
        self.assertEqual(connection['token'], 'secret')


if __name__ == '__main__':
    unittest.main()
