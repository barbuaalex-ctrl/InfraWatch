# Windows agent tutorial

The agent runs on the Windows computer you want to monitor. The InfraWatch dashboard can run on another computer or a VM. Pairing uses a temporary code; you do not need to copy a token or server ID manually.

## 1. Choose the correct dashboard address

| Agent location | InfraWatch address |
| --- | --- |
| Windows PC on the same network as the Debian VM | http://VM_IP:8080 |
| The same Windows PC that runs the application with npm start | http://127.0.0.1:3000 |
| Another PC, with the application running through npm start | http://APPLICATION_PC_IP:3000 |

Replace the placeholders with actual IP addresses. This project's Docker/Nginx entry point uses port **8080**.

On Debian, hostname -I lists the VM's addresses. Choose the LAN address reachable from Windows, rather than an internal container address.

First, open the dashboard address in a browser on the Windows device. If it does not load, resolve connectivity before starting the agent.

localhost and 127.0.0.1 refer to the computer running the agent. On a laptop, they do not refer to another PC or VM.

## 2. Download and extract

1. Open InfraWatch and sign in as an administrator.
2. Open **Download agent**.
3. Download the **Windows** archive with the displayed version.
4. Transfer the archive to the monitored device if necessary.
5. Extract all files into a writable folder, such as Documents.
6. Open the **InfraWatch-Agent** directory inside the extracted archive.

Do not run the agent from inside the ZIP. Keep all extracted files together, including the scripts and version.json.

## 3. Start and pair the device

1. Double-click **Start Agent.cmd**.
2. Check **InfraWatch address** in the agent window. The download normally includes this address; correct it if the Windows PC cannot reach it.
3. Click **Start**.
4. A temporary code appears, for example ABC-234.
5. Click **Copy code**, or select the code and press Ctrl+C.
6. In the dashboard, open **Devices > Add device > Computer / Server**.
7. Enter the code, click **Paste code**, or press Ctrl+V in the code field. The separator is inserted automatically when typing.
8. Optionally enter a display name. Otherwise, InfraWatch uses the detected device name.
9. Click **Connect device**.

Codes expire after five minutes and can be approved only once. The agent does not need the administrator password; approval happens in the dashboard.

After approval, the agent displays CONNECTED and the first metrics appear in InfraWatch.

## 4. View metrics and hardware

Paired devices appear in Overview. Open Devices > Device details for charts and detected hardware.

- CPU and RAM show current usage.
- GPU shows 3D engine usage where compatible Windows driver counters are available.
- Disk shows system-drive capacity used and free/total GB.
- Uptime shows time since system startup.
- Inventory includes hostname, Windows version, processor, memory, graphics adapters, and drives.

**Disk at 98% means 98% of capacity is occupied. It does not mean 98% disk activity in Task Manager.**

Metrics target a one-second interval. Network latency and counter collection can delay updates. Hardware inventory refreshes approximately hourly.

Device Settings allows an administrator to change thresholds and pause monitoring. Administrators receive alert notifications while signed in to the dashboard.

## 5. Stop and reconnect

- Click **Stop** to stop transmitting metrics.
- Closing the agent window also stops it.
- To reconnect, open Start Agent.cmd from the same folder and click Start.
- A new pairing code is unnecessary while the saved connection remains valid.

The connection is saved in connection.json using Windows user-scoped protection. Keep it on the device and under the Windows account that performed the pairing. Do not share connection files.

This agent does not install a Windows service or add itself to system startup. Keep its window open while monitoring.

InfraWatch marks the device offline after approximately 30-35 seconds without metrics.

## 6. Update the agent

The Windows agent checks for updates on connection and approximately every 30 minutes.

1. When an update is available, click the update button.
2. Confirm installation.
3. The updater replaces application files while retaining the saved device connection. If monitoring was running, it attempts to resume it.

Update checking is automatic; installation requires a click and confirmation.

For an older version without the updater, stop the agent and copy the program files from the new Windows archive into the existing folder. Keep config.json and connection.json. Do not reuse another device's connection files.

## 7. Troubleshooting

| Symptom | What to check |
| --- | --- |
| No code appears | Confirm the agent address opens the dashboard in a browser on the same PC and that InfraWatch is running. |
| Code expired | Click Stop, then Start, and approve the new code within five minutes. |
| PAIR AGAIN | The device may have been removed from InfraWatch. Click Start and approve a new code. |
| PAUSED | Resume monitoring from Device Settings in the dashboard. |
| Pairing is not remembered | Extract the agent into a folder writable by the current Windows user. |
| GPU unavailable | The driver may not provide compatible counters; CPU/RAM monitoring can still work. |
| Agent window does not open | Check that the ZIP was fully extracted and includes Start Agent.cmd, Agent.ps1, Pairing-Agent.ps1, and version.json. Retain the exact error if system policy blocks the scripts. |
| Another PC cannot reach the VM | Check the VM address, network configuration, and firewall rules for the dashboard port. |

Older bundled instructions may describe manual tokens or five-second reporting. This tutorial describes the current temporary-code pairing flow and one-second target interval.
