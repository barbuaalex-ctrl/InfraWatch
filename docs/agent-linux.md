# Linux agent tutorial

The agent monitors the Linux machine where you run it: a VM, physical server, or EC2 instance. It needs no graphical interface or attached monitor; a remote VS Code SSH terminal is enough.

Requirements: **Linux and Python 3.9 or newer**. The agent uses the Python standard library. No pip packages or sudo privileges are required for manual operation.

## 1. Choose the dashboard address

| Agent location | Address in this project |
| --- | --- |
| The same Debian host as the Docker/Nginx application | http://127.0.0.1:8080 |
| Another Linux device on the same LAN | http://VM_IP:8080 |
| EC2 using the SSH tunnel below | http://127.0.0.1:9000 |

127.0.0.1 always refers to the machine running the command. EC2 cannot directly reach a private home address such as 192.168.x.x.

The examples use port 8080 because Nginx fronts this deployment. For a standalone application started with npm start, the default port is 3000.

## 2. Download and extract on Linux

1. Sign in to InfraWatch as an administrator.
2. Open **Download agent** and download the **Linux** archive.
3. Transfer the ZIP to the monitored Linux machine if necessary.
4. Extract the archive.
5. Open its **InfraWatch-Agent** directory in a terminal.

For the v0.10.0 archive in the current directory:

```bash
unzip infrawatch-agent-linux-v0.10.0.zip
cd InfraWatch-Agent
python3 --version
python3 agent.py --version
```

Use the actual ZIP filename for other versions. If unzip is unavailable, use a graphical archive tool or install it on Debian/Ubuntu with sudo apt install unzip.

Keep agent.py and version.json together. The script does not need executable permissions when invoked with python3.

## 3. Start and approve the device

For a local test on the Debian host running the application:

```bash
python3 agent.py --server http://127.0.0.1:8080
```

For another Linux machine on the same LAN:

```bash
python3 agent.py --server http://VM_IP:8080
```

Replace VM_IP with the reachable address of the dashboard VM.

1. The terminal displays Pairing code: ABC-234.
2. Copy the code. In the VS Code terminal on Linux, Ctrl+Shift+C can copy selected text.
3. In the dashboard, open **Devices > Add device > Computer / Server**.
4. Enter or paste the code. A display name is optional.
5. Click **Connect device** within five minutes.
6. Wait for metrics to appear.

The agent receives its connection credentials after administrator approval; you do not enter a token or server ID manually.

The message Connected. Sending metrics every second. means a connection has been loaded. Confirm delivery by checking live updates in the dashboard. If an error immediately follows that message, follow the error instead.

## 4. Reported information

- CPU: usage calculated between samples.
- RAM: memory usage percentage.
- Disk: capacity used and free/total GB for the root filesystem, /.
- Uptime: time since Linux started.
- Inventory: hostname, distribution, kernel, architecture, CPU, memory, and root storage.

GPU telemetry is **unavailable** in the current Linux agent; it does not send a synthetic zero.

Metrics target one sample per second. Network delays and retries can lower the effective frequency. Hardware inventory refreshes approximately hourly.

Root filesystem capacity does not necessarily cover every mounted disk, and it does not measure disk I/O activity.

## 5. Stop and reconnect

For a manually started agent:

- Keep the terminal open while monitoring.
- Press **Ctrl+C** to stop.
- Run the same command to reconnect.

The default connection file is:

```text
~/.config/infrawatch-agent/connection.json
```

A valid saved connection does not need repeated approval. Use the same Linux account and state directory. Running with sudo changes the user context and may create a separate pairing.

The connection file is private. Do not share it or copy it to another device.

## 6. Separate tests and new pairings

To keep a local test separate from an existing connection:

```bash
python3 agent.py --server http://127.0.0.1:8080 --state-dir ~/.config/infrawatch-local-test
```

The --state-dir option selects where the agent saves its connection. Reuse that directory on subsequent launches.

If Device connection rejected appears after deleting the device in the dashboard, first confirm that the server address is correct. To create a new pairing, select an unused state directory:

```bash
python3 agent.py --server http://127.0.0.1:8080 --state-dir ~/.config/infrawatch-local-test-2
```

Approve the new code. This creates a new pairing; it does not repair or remove the old dashboard entry automatically.

If the agent reports that the state directory belongs to another InfraWatch server, use the saved address or a new state directory. Even two addresses pointing to the same backend are treated as different server addresses by this check.

## 7. Update the Linux agent

Linux updates are manual in this release:

1. Stop the agent with Ctrl+C.
2. Download and extract the new Linux archive.
3. Replace agent.py and version.json.
4. Preserve the state directory containing connection.json.
5. Restart with the same server address and --state-dir, if used.

Do not copy credentials from another device. The Windows agent's update button does not apply to Linux.

## 8. EC2 provisioned by this project's Terraform configuration

Terraform already installs the agent and its systemd service on EC2. **Do not run an additional manual copy of the agent alongside that service.**

From Debian, open the tunnel to the current EC2 public IP:

```bash
ssh -i ~/.ssh/infrawatch-ec2 -o ExitOnForwardFailure=yes -R 127.0.0.1:9000:127.0.0.1:8080 ec2-user@EC2_PUBLIC_IP
```

Replace EC2_PUBLIC_IP and keep the session open. EC2 loopback port 9000 now forwards to the dashboard on Debian.

In the EC2 terminal:

```bash
sudo cloud-init status --wait
sudo journalctl -u infrawatch-agent -n 20 --no-pager
```

Copy the pairing code from the log and approve it in the dashboard. An already paired service with valid saved credentials will not request a new code.

Useful commands, **run on EC2**:

```bash
sudo systemctl status infrawatch-agent --no-pager
sudo systemctl stop infrawatch-agent
sudo systemctl start infrawatch-agent
sudo systemctl restart infrawatch-agent
```

Stopping the service does not disable it for the next boot. The Terraform-created service stores its connection under /var/lib/infrawatch-agent, separately from a manually started user's agent.

systemd starts the enabled service at boot. Metric delivery still requires the dashboard and SSH tunnel. Closing the SSH session closes the tunnel; the device will eventually appear offline.

See the [demo guide](../devops/DEMO.md) for Terraform and resource cleanup.

## 9. Troubleshooting

| Message or symptom | Resolution |
| --- | --- |
| Cannot reach InfraWatch | Check the address and port from the agent machine. On EC2, check the SSH tunnel. |
| version.json is missing | Extract the whole archive and keep version.json beside agent.py. |
| Code expired | The Linux agent automatically requests a new code; use the latest one in its terminal or logs. |
| Monitoring paused | Resume monitoring in Device Settings. |
| Device connection rejected | Check the target backend. If the device was removed, pair again using a new state directory. |
| Duplicate device | Another user account or state directory may have created a second pairing. Stop the extra copy and use the intended connection. |
| Offline after closing the terminal | A manual agent needs its process to remain running. On the provisioned EC2, use the existing service. |
| EC2 cannot reach the VM's private IP | Use the reverse SSH tunnel; the home LAN address is not directly reachable from AWS. |
