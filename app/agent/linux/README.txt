InfraWatch Linux agent

Requires Linux and Python 3.9 or newer. Uses only the Python standard library.
No pip packages, root privileges or Windows software are required.

1. Download and extract the ZIP. Open the InfraWatch-Agent directory.
2. Run: python3 agent.py --server http://INFRAWATCH_IP:PORT
3. In InfraWatch sign in as admin, then Devices > Add device > Computer / Server.
4. Enter the six-character code shown in the terminal. It expires in five minutes.
5. Keep the terminal open. Press Ctrl+C to stop. Run the same command to reconnect.

The server address must be reachable FROM this Linux device. localhost means this
Linux device, not your main PC. An EC2 server cannot reach a home 192.168.x.x
address directly. Networking and cloud provisioning are configured separately.
Use HTTPS when sending metrics across untrusted networks.

Pairing is approved once; the admin password is never needed by this agent.
The private connection is saved in ~/.config/infrawatch-agent/connection.json
(mode 0600; directory 0700). Treat it like a password. Linux file permissions are
used, not Windows DPAPI encryption. Do not commit or share this file.
Use --state-dir PATH for another user-specific state directory. Preserve that
same directory on update. Do not copy a paired state directory to another device.
To update: stop, replace agent.py and version.json from a new ZIP, then restart.
The Linux agent does not install automatic updates in this release.

CPU, RAM, root filesystem capacity and uptime target one sample per second.
Network delays can reduce the effective rate. Hardware inventory refreshes hourly.
Hostname, Linux distribution/kernel, architecture, CPU, RAM and root storage are
collected. GPU metrics are not collected and are reported as unavailable.
No personal files are collected. Infrastructure setup, systemd and Terraform are
outside this agent: it stays in the foreground so a service manager can supervise it.

Troubleshooting: --version prints the packaged version; --once sends one sample
and exits after pairing. Removing a device invalidates its token: pair again using
a new --state-dir, or move the old connection file aside yourself.
