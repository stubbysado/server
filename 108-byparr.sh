#!/bin/bash

# REMOVE SOURCES.LIST
rm -f /etc/apt/sources.list

# SOURCES.LIST
tee /etc/apt/sources.list.d/debian.sources <<'EOF'
Types: deb deb-src
URIs: http://10.0.0.40/debian
Suites: trixie trixie-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: http://10.0.0.40/debian-security
Suites: trixie-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

# PACKAGES
apt update
apt upgrade -y
apt clean
apt autoremove -y

# BYPARR
apt install git -y
git clone https://github.com/ThePhaseless/Byparr
mv /root/Byparr/ /opt/byparr/

tee /etc/systemd/system/byparr.service <<'EOF'

[Unit]
Description=Byparr Minimal Service
After=network.target

[Service]
User=root
WorkingDirectory=/opt/byparr
ExecStart=/root/.local/bin/uv run /opt/byparr/main.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

wget -qO- https://astral.sh/uv/install.sh | sh
sleep 30
source $HOME/.local/bin/env
/opt/byparr/.venv/bin/playwright install-deps
systemctl daemon-reload
systemctl enable byparr.service
systemctl start byparr.service
