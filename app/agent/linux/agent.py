#!/usr/bin/env python3
"""InfraWatch Linux agent: pair once, then send real metrics every second."""

import argparse
import json
import os
import platform
import shutil
import socket
import tempfile
import time
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

PROC_DIR = Path('/proc')
DMI_DIR = Path('/sys/class/dmi/id')
OS_RELEASE_FILE = Path('/etc/os-release')


def read_text(path):
    try:
        return path.read_text().strip()
    except (OSError, UnicodeError):
        return ''


def read_version():
    folder = Path(__file__).resolve().parent
    for file in [folder / 'version.json', folder.parent / 'version.json']:
        if file.exists():
            return json.loads(file.read_text())['version']
    raise RuntimeError('version.json is missing. Extract the entire agent ZIP.')


def memory_info():
    values = {}
    for line in (PROC_DIR / 'meminfo').read_text().splitlines():
        key, value = line.split(':', 1)
        values[key] = int(value.split()[0]) * 1024
    total = values['MemTotal']
    available = values.get('MemAvailable', values.get('MemFree', 0))
    return total, round(max(0, min(100, 100 * (1 - available / total))), 1)


def cpu_times():
    # Guest times are already included in user/nice; count them only once.
    values = [int(value) for value in (PROC_DIR / 'stat').read_text().splitlines()[0].split()[1:9]]
    return sum(values), values[3] + values[4]


def inventory():
    processors = []
    for block in read_text(PROC_DIR / 'cpuinfo').split('\n\n'):
        fields = dict(line.split(':', 1) for line in block.splitlines() if ':' in line)
        fields = {key.strip(): value.strip() for key, value in fields.items()}
        if fields:
            processors.append(fields)
    cores = {(p['physical id'], p['core id']) for p in processors if 'physical id' in p and 'core id' in p}
    try:
        release = platform.freedesktop_os_release()
    except (OSError, AttributeError):
        release = {}
        for line in read_text(OS_RELEASE_FILE).splitlines():
            key, separator, value = line.partition('=')
            if separator and not key.startswith('#'):
                release[key] = value.strip().strip(chr(34)).strip(chr(39))
    disk = shutil.disk_usage('/')
    total_ram, _ = memory_info()
    first = processors[0] if processors else {}
    return {
        'hostname': socket.gethostname(),
        'osName': release.get('PRETTY_NAME', 'Linux'),
        'osVersion': platform.release(),
        'architecture': platform.machine(),
        'manufacturer': read_text(DMI_DIR / 'sys_vendor'),
        'model': read_text(DMI_DIR / 'product_name'),
        'cpuName': first.get('model name') or first.get('Processor') or platform.machine(),
        'cores': len(cores) if cores else None,
        'threads': os.cpu_count(),
        'ramGB': round(total_ram / 1024 ** 3, 2),
        'gpu': [],
        'disks': [{'name': '/', 'sizeGB': round(disk.total / 1024 ** 3, 2), 'freeGB': round(disk.free / 1024 ** 3, 2)}]
    }


def metrics(previous_cpu, version):
    current_cpu = cpu_times()
    total = current_cpu[0] - previous_cpu[0]
    idle = current_cpu[1] - previous_cpu[1]
    cpu = max(0, min(100, 100 * (total - idle) / total)) if total > 0 else 0
    _, ram = memory_info()
    disk = shutil.disk_usage('/')
    payload = {
        'cpu': round(cpu, 1), 'ram': ram,
        'disk': round(100 * disk.used / disk.total, 1),
        'diskFreeGB': round(disk.free / 1024 ** 3, 2),
        'diskTotalGB': round(disk.total / 1024 ** 3, 2),
        'systemDrive': '/', 'gpu': None,
        'uptimeSeconds': float((PROC_DIR / 'uptime').read_text().split()[0]),
        'hostname': socket.gethostname(), 'agentVersion': version
    }
    return payload, current_cpu


def server_address(value):
    parsed = urlsplit(value)
    if (parsed.scheme not in ('http', 'https') or not parsed.hostname
            or parsed.username or parsed.password or parsed.query or parsed.fragment
            or parsed.path not in ('', '/')):
        raise ValueError('Use the InfraWatch base address, for example http://192.168.0.107:8080')
    return value.rstrip('/')


def api(server, route, body=None, headers=None):
    request = Request(server + route, headers={'Content-Type': 'application/json', **(headers or {})})
    if body is not None:
        request.data = json.dumps(body).encode('utf-8')
    with urlopen(request, timeout=10) as response:
        return json.load(response)


def save_connection(file, connection):
    # Private Linux file, atomically replaced; never print its token.
    file.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(file.parent, 0o700)
    descriptor, temporary = tempfile.mkstemp(prefix='.connection-', dir=file.parent)
    try:
        with os.fdopen(descriptor, 'w') as output:
            json.dump(connection, output)
        os.chmod(temporary, 0o600)
        os.replace(temporary, file)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def load_connection(file):
    if not file.exists():
        return None
    connection = json.loads(file.read_text())
    if not all(isinstance(connection.get(key), str) and connection[key] for key in ('serverUrl', 'serverId', 'token')):
        raise ValueError('Invalid connection file. Restore it or choose a new --state-dir to pair again.')
    server_address(connection['serverUrl'])
    os.chmod(file, 0o600)
    return connection


def pair(server):
    while True:
        try:
            pending = api(server, '/api/pairing/request', {'platform': 'linux', 'inventory': inventory()})
            print('Pairing code:', pending['code'], flush=True)
            print('InfraWatch: Devices > Add device > Computer / Server. Approve this code within 5 minutes.', flush=True)
            while True:
                time.sleep(2)
                approval = api(server, '/api/pairing/' + pending['requestId'],
                               headers={'x-pairing-secret': pending['requestSecret']})
                if approval['status'] == 'approved':
                    return {'serverUrl': server, 'serverId': approval['serverId'], 'token': approval['token']}
        except HTTPError as error:
            error.close()
            if error.code == 410:
                print('Code expired. Requesting a new code.', flush=True)
                continue
            if error.code in (401, 403, 404):
                raise RuntimeError('Pairing unavailable. Check the server address and update InfraWatch for Linux support.') from None
            print('Pairing unavailable; retrying in 5 seconds. HTTP', error.code, flush=True)
        except OSError:
            print('Cannot reach InfraWatch; retrying in 5 seconds.', flush=True)
        time.sleep(5)


def run(connection, version, once=False):
    previous_cpu = cpu_times()
    next_inventory = 0
    print('Connected. Sending metrics every second. Press Ctrl+C to stop.', flush=True)
    time.sleep(1)
    while True:
        started = time.monotonic()
        payload, previous_cpu = metrics(previous_cpu, version)
        include_inventory = started >= next_inventory
        if include_inventory:
            payload['inventory'] = inventory()
        try:
            api(connection['serverUrl'], '/api/agents/' + connection['serverId'] + '/metrics',
                payload, {'x-agent-token': connection['token']})
            if include_inventory:
                next_inventory = time.monotonic() + 3600
            if once:
                return
        except HTTPError as error:
            error.close()
            if error.code in (401, 403):
                raise RuntimeError('Device connection rejected. Check the server or pair again using a new --state-dir.') from None
            if once:
                raise RuntimeError('Metric delivery failed. HTTP ' + str(error.code)) from None
            print('Monitoring paused.' if error.code == 409 else 'Server error; retrying in 5 seconds.', flush=True)
            time.sleep(5)
        except OSError:
            if once:
                raise RuntimeError('Cannot reach InfraWatch.') from None
            print('Connection lost; retrying in 5 seconds.', flush=True)
            time.sleep(5)
        time.sleep(max(0, 1 - (time.monotonic() - started)))


def main():
    parser = argparse.ArgumentParser(description='InfraWatch Linux agent')
    parser.add_argument('--server', help='Reachable InfraWatch address, including its port')
    parser.add_argument('--state-dir', type=Path, default=Path.home() / '.config' / 'infrawatch-agent')
    parser.add_argument('--once', action='store_true', help='Send one metric sample after pairing, then exit')
    parser.add_argument('--version', action='version', version='InfraWatch Linux agent v' + read_version())
    args = parser.parse_args()
    if platform.system() != 'Linux':
        parser.error('This agent runs on Linux. Use the Windows agent on Windows.')
    try:
        connection_file = args.state_dir.expanduser().resolve() / 'connection.json'
        connection = load_connection(connection_file)
        server = args.server
        config = Path(__file__).resolve().parent / 'config.json'
        if not server and not connection and config.exists():
            server = json.loads(config.read_text()).get('serverUrl')
        if connection:
            if server and server_address(server) != connection['serverUrl']:
                raise ValueError('This state directory belongs to another InfraWatch server. Use a different --state-dir.')
        else:
            if not server:
                raise ValueError('Provide --server with the reachable InfraWatch address.')
            connection = pair(server_address(server))
            save_connection(connection_file, connection)
        run(connection, read_version(), args.once)
    except KeyboardInterrupt:
        print('\nAgent stopped. Your saved connection is retained.', flush=True)
    except (OSError, ValueError, RuntimeError) as error:
        # Report safe messages only; never print HTTP headers or connection files.
        parser.exit(1, 'Agent error: ' + str(error) + '\n')


if __name__ == '__main__':
    main()
