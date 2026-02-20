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
	
    tee /etc/systemd/system/e1000e-fix.service <<EOF
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

tee ./update.sh <<'EOF'
#!/bin/bash

# UPDATE
apt update
apt full-upgrade -y
apt clean
apt autoremove -y

REBOOT_NEEDED=0

# 1. CHECK KERNEL
RUNNING_KERNEL=$(uname -r)
LATEST_KERNEL=$(ls -v /boot/vmlinuz-* | grep -v 'debug' | tail -1 | sed 's|/boot/vmlinuz-||')

if [ "$RUNNING_KERNEL" != "$LATEST_KERNEL" ]; then
    echo "[!] KERNEL UPDATED. Running: $RUNNING_KERNEL, Latest: $LATEST_KERNEL."
    REBOOT_NEEDED=1
fi

# 2. CHECK CORE LIBRARY (GLIBC)
GLIBC_UPGRADE=$(lsof -n -p 1 | grep 'libc-.*\.so' | grep 'DEL')
if [ -n "$GLIBC_UPGRADE" ]; then
    echo "[!] CORE LIBRARY UPDATED."
    REBOOT_NEEDED=1
fi

# 3. CHECK CPU MICROCODE
BOOT_MICROCODE=$(journalctl -b -k | grep -i "microcode updated early" | awk -F'revision=' '{print $2}' | awk '{print $1}' | head -1)
CURRENT_MICROCODE=$(grep -m1 "microcode" /proc/cpuinfo | awk '{print $3}')

if [ -n "$BOOT_MICROCODE" ] && [ "$BOOT_MICROCODE" != "$CURRENT_MICROCODE" ]; then
    echo "[!] MICROCODE MISMATCHED DETECTED."
    REBOOT_NEEDED=1
fi

if [ "$REBOOT_NEEDED" -eq 1 ]; then
    echo "[!] REBOOT REQUIRED"
    sleep 3
    reboot
else
    echo "No reboot required."
    exit 0
fi
EOF
chmod 755 -v ./update.sh
(crontab -l 2>/dev/null; echo '0 4 1-7 * * [ "$(date "+\%a")" = "Tue" ] && /bin/bash /root/update.sh') | crontab -
