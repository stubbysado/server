#!/bin/bash -x

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

# SSH
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && systemctl restart ssh.service

# INSTALL DOCKER
apt update
apt install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# CHECK DOCKER STATUS
systemctl status docker --no-pager

# IF NOT RUNNING
systemctl enable docker
systemctl start docker

# INSTALL VAULTWARDEN
docker pull vaultwarden/server:latest
docker rm -f vaultwarden 2>/dev/null
docker run -d --name vaultwarden -v /vw-data/:/data/ -p 80:80 vaultwarden/server:latest

# FIX HTTPS
mkdir -p /vw-data/ssl
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout /vw-data/ssl/key.pem \
  -out /vw-data/ssl/cert.pem \
  -subj "/CN=10.0.0.46"

docker stop vaultwarden 2>/dev/null
docker rm -f vaultwarden 2>/dev/null
docker run -d --name vaultwarden \
  --restart unless-stopped \
  -e ROCKET_TLS='{certs="/data/ssl/cert.pem",key="/data/ssl/key.pem"}' \
  -e ROCKET_PORT=443 \
  -v /vw-data/:/data/ \
  -p 443:443 \
  vaultwarden/server:latest

# VERIFY
docker logs vaultwarden
