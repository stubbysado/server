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
sudo apt install curl nginx -y

# RE-CHECK UPDATE
sudo apt update
sudo apt upgrade -y
sudo apt clean
sudo apt autoremove -y

# NFS
sudo apt update
sudo apt install nfs-common -y
sudo mkdir -p /mnt/server
sudo chown oggy:oggy /mnt/server
echo "10.0.0.21:/mnt/server /mnt/server nfs rw,async,nconnect=8,rsize=1048576,wsize=1048576,noatime,nofail 0 0" | sudo tee -a /etc/fstab
sudo mount -a

# LINK
check_link() {
    if ! curl --output /dev/null --silent --head --fail "$1"; then
        return 1
    fi
}

while true; do
    echo "--- INVALID LINK (Ctrl+C to exit) ---"
    
    read -p "FILEBROWSER QUANTUM link: " FILEBROWSER
    
    if [ -z "$FILEBROWSER" ] ; then
        echo "ERROR: Link required"
        continue
    fi

    echo "Checking link"
    if  check_link "$FILEBROWSER" ; then
        echo "Link verified"
        break
    else
        echo "ERROR: One or more links are unreachable. Please re-enter all links."
    fi
done

# FILEBROWSER QUANTUM
wget "$FILEBROWSER"
chmod 755 ./linux-amd64-filebrowser
sudo mv ./linux-amd64-filebrowser /usr/local/bin/filebrowser
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
sudo bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 30 && /usr/bin/mount -a") | crontab -'
sudo bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 60 && systemctl restart filebrowser.service") | crontab -'

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
tee ./update.sh <<'EOF'
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
chmod 755 -v ./update.sh
sudo bash -c "(crontab -l 2>/dev/null; echo '0 5 1-7 * * [ \"\$(date \"+\%a\")\" = \"Wed\" ] && /bin/bash /home/oggy/update.sh') | crontab -"
