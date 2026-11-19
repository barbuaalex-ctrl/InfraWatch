InfraWatch Windows Agent

1. Run InfraWatch on the main PC using npm start.
2. In Servers, sign in and choose Add Windows laptop.
3. Copy this agent folder to the laptop and double-click Start Agent.cmd.
4. Enter the main PC address (http://PC-LAN-IP:3000), server ID and token.
5. Click Start. Metrics are sent every 5 seconds. Stop or close to stop sending.

Both machines must be on the same trusted local network. Use the main PC's
IPv4 address from ipconfig, not localhost. First test this address in the
laptop browser. If Windows Firewall blocks it, allow Node.js on Private
networks or allow inbound TCP port 3000 restricted to your local subnet.
No firewall rules are changed by this agent. Avoid public Wi-Fi.

The app shows the laptop offline after about 30-35 seconds without data.
Disk reports usage of the Windows system drive. The agent sends only CPU,
RAM, disk percentage, hostname and uptime. It does not read personal files.
No installation, startup entry or background service is created. The token
is kept in memory only; re-enter it when restarting the agent.
