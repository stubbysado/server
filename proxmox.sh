#!/bin/bash -x

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

# ZRAM
 apt update
 apt install systemd-zram-generator -y

echo "[zram0]
zram-size = min(ram, 8192)
compression-algorithm = zstd" | tee /etc/systemd/zram-generator.conf

echo "vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0" | tee /etc/sysctl.d/99-zram.conf

# FIX E1000E NIC
apt update
apt install ethtool -y

NIC="nic0"
CONFIG="/etc/network/interfaces"

/usr/sbin/ethtool -K $NIC tso off gso off gro off

if grep -q "ethtool -K $NIC" "$CONFIG"; then
    :
else
    sed -i "/iface $NIC/a \      post-up /usr/sbin/ethtool -K $NIC tso off gso off gro off" "$CONFIG"
fi

ethtool -k $NIC | grep -E 'tcp-segmentation-offload|generic-segmentation-offload|generic-receive-offload'
