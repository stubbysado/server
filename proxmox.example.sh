#!/bin/bash -x

# CRONTAB
LINE="@reboot echo 0 | tee /sys/class/backlight/intel_backlight/brightness"

(crontab -l 2>/dev/null | grep -Fq "$LINE") || (crontab -l 2>/dev/null; echo "$LINE") | crontab -

# SOURCE.LIST.D
sed -i 's|https://enterprise.proxmox.com|http://download.proxmox.com|g' /etc/apt/sources.list.d/ceph.sources
sed -i 's|enterprise|no-subscription|g' /etc/apt/sources.list.d/ceph.sources

sed -i 's|https://enterprise.proxmox.com|http://download.proxmox.com|g' /etc/apt/sources.list.d/pve-enterprise.sources
sed -i 's|pve-enterprise|pve-no-subscription|g' /etc/apt/sources.list.d/pve-enterprise.sources

sed -i 's|http://deb.debian.org|https://mirror.sg.gs|g' /etc/apt/sources.list.d/debian.sources
sed -i 's|http://security.debian.org|https://mirror.sg.gs|g' /etc/apt/sources.list.d/debian.sources

apt update
apt dist-upgrade -y
apt clean -y
apt autoremove -y
