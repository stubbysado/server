#!/bin/bash -x

# BACKUP SOURCES.LIST
mkdir -p /root/sources_list_bak/
mv /etc/apt/sources.list.d/* /root/sources_list_bak/
mv /etc/apt/sources.list /root/sources_list_bak/sources.list.bak

# SOURCES.LIST.D
tee /etc/apt/sources.list.d/debian.sources <<'EOF'
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

tee /etc/apt/sources.list.d/proxmox.sources <<'EOF'
Types: deb
URIs: http://mirror.sg.gs/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF

# UPDATE
apt update
apt full-upgrade -y
apt clean
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
NIC=$(basename $(ls -l /sys/class/net/*/device/driver 2>/dev/null | grep e1000e | awk '{print $9}' | cut -d/ -f5) 2>/dev/null | head -n 1)

if [ -n "$NIC" ]; then
    apt update && apt install ethtool -y
	
    tee /etc/systemd/system/e1000e-fix.service <<'EOF'
[Unit]
Description=Disable NIC offloading for Intel E1000E interface $NIC
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/ethtool -K $NIC gso off gro off tso off tx off rx off rxvlan off txvlan off sg off
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now e1000e-fix.service
    ethtool -k "$NIC"
else
    echo "E1000E not found"
fi

#UPDATE.SH
tee ./update.sh <<'EOF'
#!/bin/bash -x

apt update
apt full-upgrade -y
apt clean
apt autoremove -y
EOF
chmod 755 -v ./update.sh

# GUEST.SH
tee ./lxc-update.sh <<'EOF'
#!/bin/bash

for container in $(pct list | tail -n +2 | awk '{print $1}'); do
    if [ "$(pct status $container)" == "status: running" ]; then
        echo "--- LXC $container ---"
        pct exec $container -- bash -c "apt-get update && apt-get upgrade -y && apt-get clean && apt-get autoremove -y"
    else
        echo "--- LXC $container: SKIPPED ---"
    fi
done
EOF
chmod 755 -v ./lxc-update.sh
