# InfraWatch standalone

## Dashboard access

The original dashboard is at http://localhost:3000/ with its existing Admin login/logout controls. The separate public status page and publication feature were removed at the user's request. Devices, history, agent pairing and settings were preserved. Internal data currently loads after login; API authentication remains enabled.

## Device controls and agent updates

Device Settings lets an administrator rename a device, pause monitoring and choose separate CPU/RAM/GPU/storage thresholds (10–100%). Recovery occurs five points below each threshold. Device details includes live interactive percentage graphs, period selection, peaks and the reported agent version. The administrator notification center retains triggered/recovered resource and connectivity events, with browser-local read state.

The app and agent development baseline is v0.9.0; earlier arbitrary 4.x agent labels are retired. The agent checks update availability on connection and every 30 minutes, with installation after clicking Update and confirming. Update packages come from the configured InfraWatch server and are SHA-256 checked for download integrity. The updater keeps config.json and connection.json, backs up replaced agent files, and resumes monitoring when it was running. Use a trusted network/server; these packages are not digitally signed. Agents with retired 4.x labels need one manual update including Update-Agent.ps1 and version.json before the normal version comparison can resume.

Every agent release increments agent/version.json. The UI, Windows agent title and ZIP filename use this shared version. Downloads contain a top-level InfraWatch-Agent folder; open that folder after extraction to find Start Agent.cmd. Preserve config.json and connection.json when updating an existing device.

Device telemetry targets one update per second with the latest Windows agent. Hardware inventory is read at connection and then hourly; CPU/memory counters and system-drive free space are sampled independently. Website intervals are unchanged. Storage percentages describe capacity used, not Task Manager disk activity; cards show system-drive GB free / total as well.

## Device alerts

Paired computers appear in Overview with CPU, RAM, GPU and disk readings. CPU/RAM/GPU/disk alerts trigger at 90% usage and clear below 85% to avoid repeated alerts around the limit. Missing GPU telemetry is shown as unavailable rather than zero. The Windows agent reports the busiest GPU 3D engines where driver performance counters are available; download the updated agent to enable this reading.

After 30–35 seconds without metrics, a connected device is marked offline and a connection alert opens. Active alerts and resolved incidents appear in Alerts. Administrators receive silent in-app notifications once per new alert; viewers see status but receive no notifications. Optional silent desktop notifications can be enabled from Alerts and require browser permission on localhost or HTTPS. The web app must remain open and signed in as admin for notifications.

## Add a device

Sign in as administrator, open Devices, then Add device.

- Website / API: enter a name and website address. HTTP(S) is detected automatically.
- Computer / Server: download the agent from the separate Download agent page. Extract all files on the Windows device, open Start Agent.cmd and click Start. In InfraWatch choose Add device > Computer / Server and enter the temporary six-character code. The real hostname and hardware are detected automatically; a display name is optional.

The connection address is included automatically in the download. If the PC has several network adapters, check the address in the agent. The device must reach that address; localhost on the laptop points to the laptop, not the monitoring PC. Existing agents continue working with their original IDs and tokens.

Pairing codes expire after five minutes and require administrator approval. They cannot be approved twice. The paired connection is saved on the Windows device using user-scoped Windows encryption. On future launches, click Start to reconnect. Stop or close the agent to stop collecting and transmitting metrics.

Device details shows the actual hostname, Windows edition/version, CPU model/cores/threads, installed RAM, GPU names, and disk capacity/free space. Inventory refreshes hourly; usage metrics target a one-second interval. System-drive free/total GB update with live samples. Old agents need the new Agent.ps1 for these changes. The Download agent tutorial explains how to upgrade while retaining the original device.

Requires Node.js 24 or newer.

```powershell
git clone https://github.com/barbuaalex-ctrl/InfraWatch.git
cd InfraWatch
npm ci
npm start
```

Open http://localhost:3000. Stop with Ctrl+C in the terminal running the application.

The frontend and API run together. Website monitors, history, incidents and the changed administrator password are stored in backend/data. Keep this folder to preserve your records.

For the first login, the default administrator password is `infrawatch-admin`. You can change it using Security after logging in. Sessions expire after one hour.

Optional settings: PORT, DATA_DIR, ADMIN_PASSWORD (initial password only) and SESSION_TTL_MS. No Docker, cloud account or infrastructure services are needed.

The previous project remains in H:\PROIECT FINAL. This folder is the standalone application to edit going forward.
