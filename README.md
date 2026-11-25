# InfraWatch

## Dashboard access

InfraWatch monitors websites, APIs and paired Windows/Linux devices. The Node.js backend serves the dashboard and API together. Administrators manage resources, approve devices and receive alerts.

The repository separates application code (`app/`), infrastructure and deployment (`devops/`), and GitHub Actions workflows (`.github/workflows/`). See the [DevOps guide](devops/README.md) for installation and deployment, and the [demo guide](devops/DEMO.md) for presentation commands.

## Device controls and agent updates

Device Settings lets an administrator rename a device, pause monitoring and choose separate CPU/RAM/GPU/storage thresholds (10–100%). Recovery occurs five points below each threshold. Device details includes live interactive percentage graphs, period selection, peaks and the reported agent version. The administrator notification center retains triggered/recovered resource and connectivity events, with browser-local read state.

The application and shared agent release are v0.10.0. The Windows agent checks update availability on connection and every 30 minutes, with installation after clicking Update and confirming. Update packages come from the configured InfraWatch server and are SHA-256 checked for download integrity. The updater keeps config.json and connection.json, backs up replaced agent files, and resumes monitoring when it was running. Use a trusted network/server; these packages are not digitally signed. Agents with retired 4.x labels need one manual update including Update-Agent.ps1 and version.json before the normal version comparison can resume.

Every agent release increments `app/agent/version.json`. The UI, Windows agent title and ZIP filename use this shared version. Downloads contain a top-level InfraWatch-Agent folder; open that folder after extraction to find Start Agent.cmd. Preserve config.json and connection.json when updating an existing device.

Windows and Linux device telemetry target one update per second. Hardware inventory is read at connection and then hourly; CPU/memory counters and system-drive free space are sampled independently. Website intervals are unchanged. Storage percentages describe capacity used, not Task Manager disk activity; cards show system-drive GB free / total as well.

## Device alerts

Paired computers appear in Overview with CPU, RAM, GPU and disk readings. CPU/RAM/GPU/disk alerts trigger at 90% usage and clear below 85% to avoid repeated alerts around the limit. Missing GPU telemetry is shown as unavailable rather than zero. The Windows agent reports the busiest GPU 3D engines where driver performance counters are available; download the updated agent to enable this reading.

After 30–35 seconds without metrics, a connected device is marked offline and a connection alert opens. Active alerts and resolved incidents appear in Alerts. Administrators receive silent in-app notifications once per new alert; viewers see status but receive no notifications. Optional silent desktop notifications can be enabled from Alerts and require browser permission on localhost or HTTPS. The web app must remain open and signed in as admin for notifications.

## Agent tutorials

- [Windows agent tutorial](docs/agent-windows.md)
- [Linux agent tutorial](docs/agent-linux.md)

## Run standalone

The application source and npm workspace are under `app/`. Docker configuration is under `devops/`. Standalone operation requires Node.js 24 or newer.

```powershell
git clone https://github.com/barbuaalex-ctrl/InfraWatch.git
cd InfraWatch/app
npm ci
npm start
```

Open http://localhost:3000. Stop with Ctrl+C in the terminal running the application.

The frontend and API run together. Website monitors, history, incidents and the changed administrator password are stored in `app/backend/data/` relative to the repository root. Keep this folder to preserve your records. Run `npm test` from `app/` to check the application.

For the first login, the default administrator password is `infrawatch-admin`. You can change it using Security after logging in. Sessions expire after one hour.

Optional settings: PORT, DATA_DIR, ADMIN_PASSWORD (initial password only) and SESSION_TTL_MS. No Docker, cloud account or infrastructure services are needed.

## Run with Docker Compose

The current deployment uses published images from `ghcr.io/barbuaalex-ctrl/infrawatch`. Follow the [first installation steps](devops/README.md#prima-pornire-cu-docker-compose) to create the external volume, runtime environment file and Nginx routing file, then start one application instance and Nginx.

Open http://localhost:8080 on the Docker host, or `http://VM_IP:8080` from another computer. Only one application instance may run against the shared JSON data volume at a time.

GitHub Actions tests and publishes images tagged `ci-N`. A separate, manually triggered deployment workflow automates activation and rollback on the configured Debian runner. Terraform creates an EC2 device to monitor; it does not host the dashboard in this setup.

To build an image locally from the repository root:

```sh
docker build -f devops/Dockerfile -t infrawatch:local .
```
