#!/bin/bash -x

# CRONTAB
LINE="@reboot echo 0 | tee /sys/class/backlight/intel_backlight/brightness"

(crontab -l 2>/dev/null | grep -Fq "$LINE") || (crontab -l 2>/dev/null; echo "$LINE") | crontab -

# BACKUP REPO
mkdir -p /root/sources_list_bak/
mv /etc/apt/sources.list.d/* /root/sources_list_bak/
mv /etc/apt/sources.list /root/sources_list_bak/sources.list.bak

# CREATE REPO
tee /etc/apt/sources.list.d/debian.sources <<EOF
Types: deb deb-src
URIs: https://mirror.sg.gs/debian
Suites: trixie trixie-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: https://mirror.sg.gs/debian-security
Suites: trixie-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

tee /etc/apt/sources.list.d/proxmox.sources <<EOF
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF

# UPDATE
apt update
apt dist-upgrade -y
apt clean -y
apt autoremove -y
