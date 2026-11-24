#!/bin/bash
set -e

dnf install -y python3

useradd --system --create-home \
  --home-dir /var/lib/infrawatch-agent \
  --shell /sbin/nologin \
  infrawatch-agent

mkdir -p /opt/infrawatch-agent

echo '${agent_code}' | base64 --decode > /opt/infrawatch-agent/agent.py
echo '${agent_version}' | base64 --decode > /opt/infrawatch-agent/version.json

cat > /etc/systemd/system/infrawatch-agent.service <<'EOF'
[Unit]
Description=InfraWatch monitoring agent
Wants=network-online.target
After=network-online.target

[Service]
User=infrawatch-agent
WorkingDirectory=/opt/infrawatch-agent
ExecStart=/usr/bin/python3 -u /opt/infrawatch-agent/agent.py --server http://127.0.0.1:9000 --state-dir /var/lib/infrawatch-agent
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now infrawatch-agent