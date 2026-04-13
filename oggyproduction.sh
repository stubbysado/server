#!/bin/bash -x

# REMOVE SOURCES.LIST
sudo rm -f /etc/apt/sources.list

# SOURCES.LIST
sudo tee /etc/apt/sources.list.d/debian.sources <<'EOF'
Types: deb deb-src
URIs: http://10.0.0.41/debian
Suites: trixie trixie-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: http://10.0.0.41/debian-security
Suites: trixie-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

# PACKAGES
sudo apt update
sudo apt upgrade -y
sudo apt clean
sudo apt autoremove -y
sudo apt install curl nginx -y

# NFS
sudo apt update
sudo apt install nfs-common -y
sudo mkdir -p /mnt/server
sudo chown oggy:oggy /mnt/server
echo "10.0.0.21:/mnt/server /mnt/server nfs rw,async,nconnect=8,rsize=1048576,wsize=1048576,noatime,nofail,noauto 0 0" | sudo tee -a /etc/fstab
sudo mount /mnt/server

sudo tee /etc/systemd/system/nfs-mount.service <<'EOF'
[Unit]
Description=NFS Mount 10.0.0.21:/mnt/server
After=network-online.target nfs-client.target
Wants=network-online.target
Before=remote-fs.target shutdown.target
StartLimitBurst=10
StartLimitIntervalSec=90

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/mount /mnt/server
ExecStop=/bin/umount -l -f /mnt/server
Restart=on-failure
RestartSec=6
TimeoutStartSec=15
TimeoutStopSec=15

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable nfs-mount.service

# FILEBROWSER QUANTUM
FILEBROWSERQUANTUMLINK="https://github.com/gtsteffaniak/filebrowser/releases/download/v1.2.4-stable/linux-amd64-filebrowser"
FILEBROWSERQUANTUMBIN="/home/oggy/filebrowser"

wget -O "$FILEBROWSERQUANTUMBIN" "$FILEBROWSERQUANTUMLINK"
sudo chmod 755 "$FILEBROWSERQUANTUMBIN"
sudo mv "$FILEBROWSERQUANTUMBIN" /usr/local/bin/filebrowser
sudo mkdir -p /opt/filebrowser
sudo chown oggy:oggy /opt/filebrowser
sudo tee /opt/filebrowser/config.yaml <<'EOF'
server:
  port: 55555
  database: /opt/filebrowser/database.db
  sources:
  - name: Oggy Production
    path: /mnt/server/09-Work/RAW/
  logging:
  - levels: info|warning|error
    apiLevels: info|warning|error
    output: stdout
    noColors: false
    utc: false
frontend:
  name: Oggy Production
auth:
  adminUsername: admin
  adminPassword: fWEHt"Pg]N4G$w76
userDefaults:
  permissions:
    api: false
    admin: false
    modify: false
    share: false
    realtime: false
    delete: false
    create: false
    download: false
EOF
sudo tee /etc/systemd/system/filebrowser.service <<'EOF'
[Unit]
Description=FileBrowser Quantum
After=network.target

[Service]
Type=simple
User=oggy
WorkingDirectory=/opt/filebrowser
ExecStart=/usr/local/bin/filebrowser -c /opt/filebrowser/config.yaml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable filebrowser
sudo systemctl start filebrowser

# CRONTAB
sudo bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 30 && systemctl restart filebrowser.service") | crontab -'

# ZRAM
sudo apt update
sudo apt install systemd-zram-generator -y

echo "[zram0]
zram-size = ram" | sudo tee /etc/systemd/zram-generator.conf

echo "vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0" | sudo tee /etc/sysctl.d/99-zram.conf

# UPDATE.SH
tee /home/oggy/update.sh <<'EOF'
#!/bin/bash

# UPDATE
apt update
apt upgrade -y
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

# 2. CHECK CORE LIBRARY
GLIBC_UPGRADE=$(lsof -n -p 1 | grep -E 'libc.*\.so' | grep 'DEL')
if [ -n "$GLIBC_UPGRADE" ]; then
    echo "[!] CORE LIBRARY UPDATED."
    REBOOT_NEEDED=1
fi

# 3. CHECK CPU MICROCODE
BOOT_MICROCODE=$(journalctl -b -k | grep -i "microcode updated early" | awk -F'revision=' '{print $2}' | awk '{print $1}' | head -1)
CURRENT_MICROCODE=$(grep -m1 "microcode" /proc/cpuinfo | awk '{print $3}')

if [ -n "$BOOT_MICROCODE" ] && [ "$BOOT_MICROCODE" != "$CURRENT_MICROCODE" ]; then
    echo "[!] MICROCODE UPDATED."
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
chmod 755 -v /home/oggy/update.sh
sudo bash -c "(crontab -l 2>/dev/null; echo '30 6 * * 1 /home/oggy/update.sh > /home/oggy/update.log 2>&1') | crontab -"
