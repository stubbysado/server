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
sudo apt install curl nginx transmission-daemon -y

# NFS
sudo apt update
sudo apt install nfs-common -y
sudo mkdir -p /mnt/server
sudo chown oggy:oggy /mnt/server
echo "10.0.0.21:/mnt/server /mnt/server nfs rw,async,nconnect=8,rsize=1048576,wsize=1048576,noatime,nofail,noauto 0 0" | sudo tee -a /etc/fstab
sudo mount -a

sudo tee /etc/systemd/system/nfs-mount.service <<'EOF'
[Unit]
Description=NFS Mount 10.0.0.21:/mnt/server
After=network-online.target nfs-client.target
Wants=network-online.target
Before=remote-fs.target
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

# TRANSMISSION
sudo systemctl stop transmission-daemon.service
sudo systemctl start transmission-daemon.service
sudo systemctl stop transmission-daemon.service
sleep 3
sudo cp /lib/systemd/system/transmission-daemon.service /lib/systemd/system/transmission-daemon.service.bak
sudo sed -i 's|User=debian-transmission|User=oggy|g' /lib/systemd/system/transmission-daemon.service
sudo sed -i 's|Type=notify|Type=simple|g' /lib/systemd/system/transmission-daemon.service
sudo systemctl daemon-reload
sudo systemctl start transmission-daemon.service
sleep 3
sudo systemctl stop transmission-daemon.service
sudo systemctl start transmission-daemon.service
sudo systemctl stop transmission-daemon.service
sleep 3
sudo cp /home/oggy/.config/transmission-daemon/settings.json /home/oggy/.config/transmission-daemon/settings.json.bak
sudo sed -i 's|"cache-size-mb": 4,|"cache-size-mb": 256,|g' /home/oggy/.config/transmission-daemon/settings.json
sudo sed -i 's|"download-dir": "/home/oggy/Downloads",|"download-dir": "/mnt/server/02-Downloads/transmission/downloads/",|g' /home/oggy/.config/transmission-daemon/settings.json
sudo sed -i 's|"encryption": 1,|"encryption": 2,|g' /home/oggy/.config/transmission-daemon/settings.json
sudo sed -i 's|"incomplete-dir": .*|"incomplete-dir": "/mnt/server/02-Downloads/transmission/incomplete-dir/",|' /home/oggy/.config/transmission-daemon/settings.json
sudo sed -i 's|"incomplete-dir-enabled": false,|"incomplete-dir-enabled": true,|' /home/oggy/.config/transmission-daemon/settings.json
sudo sed -i 's|"rpc-authentication-required": false,|"rpc-authentication-required": true,|g' /home/oggy/.config/transmission-daemon/settings.json
sudo sed -i 's|"rpc-username": "",|"rpc-username": "oggy",|g' /home/oggy/.config/transmission-daemon/settings.json
sudo sed -i 's|"rpc-password": .*|"rpc-password": "sudo",|' /home/oggy/.config/transmission-daemon/settings.json
sudo sed -i 's|"rpc-whitelist": "127.0.0.1,::1",|"rpc-whitelist": "127.0.0.1,10.0.0.*",|g' /home/oggy/.config/transmission-daemon/settings.json
sudo systemctl daemon-reload
sudo systemctl start transmission-daemon.service

# PROWLARR
sudo apt update
sudo apt install curl sqlite3 libicu-dev -y
wget --content-disposition 'http://prowlarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=x64'
tar -xvzf ./Prowlarr*.linux*.tar.gz
sudo mv ./Prowlarr/ /opt
sudo chown oggy:oggy -Rv /opt/Prowlarr
sudo mkdir -p /var/lib/prowlarr
sudo chown -R oggy:oggy /var/lib/prowlarr
sudo tee /etc/systemd/system/prowlarr.service <<'EOF'
[Unit]
Description=Prowlarr Daemon
After=syslog.target network.target
[Service]
User=oggy
Group=oggy
Type=simple

ExecStart=/opt/Prowlarr/Prowlarr -nobrowser -data=/var/lib/prowlarr/
TimeoutStopSec=20
KillMode=process
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now prowlarr
rm ./Prowlarr*.linux*.tar.gz

# RADARR
sudo apt install curl sqlite3 -y

sudo mkdir -p /var/lib/radarr
sudo chown "$USER":"$USER" /var/lib/radarr

wget --content-disposition 'http://radarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=x64'

tar -xvzf Radarr*.linux*.tar.gz
sudo mv Radarr /opt/
sudo chown "$USER":"$USER" -R /opt/Radarr

sudo tee /etc/systemd/system/radarr.service <<EOF
[Unit]
Description=Radarr Daemon
After=syslog.target network.target
[Service]
User=$USER
Group=$USER
Type=simple
ExecStart=/opt/Radarr/Radarr -nobrowser -data=/var/lib/radarr/
TimeoutStopSec=20
KillMode=process
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl -q daemon-reload
sudo systemctl enable --now -q radarr
rm Radarr*.linux*.tar.gz

# SONARR
curl -o install-sonarr.sh https://raw.githubusercontent.com/Sonarr/Sonarr/develop/distribution/debian/install.sh
sudo bash install-sonarr.sh

# REAL DEBRID (RDT-CLIENT)
REALDEBRIDMICROSOFTLINK="https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb"
REALDEBRIDMICROSOFTDEB="/home/oggy/microsoft.deb"
REALDEBRIDCLIENTLINK="https://github.com/rogerfar/rdt-client/releases/download/v2.0.129/RealDebridClient.zip"

sudo apt update
sudo apt install unzip -y
wget -O "$REALDEBRIDMICROSOFTDEB" "$REALDEBRIDMICROSOFTLINK"
sudo dpkg -i "$REALDEBRIDMICROSOFTDEB"
sudo apt update
sudo apt install dotnet-sdk-10.0 -y
wget "$REALDEBRIDCLIENTLINK"
mkdir -p ./rdtc
unzip ./RealDebridClient.zip -d ./rdtc
sed -i 's@/data/db/@@g' ./rdtc/appsettings.json
sudo tee /etc/systemd/system/rdtc.service <<'EOF'
[Unit]
Description=RdtClient Service

[Service]
WorkingDirectory=/home/oggy/rdtc
ExecStart=/usr/bin/dotnet RdtClient.Web.dll
SyslogIdentifier=RdtClient
User=oggy

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable rdtc
sudo systemctl start rdtc

#RDTC UPDATE SCRIPT
tee /home/$USER/update_rdtc.sh <<'EOF'
#!/bin/bash -x

APP_DIR="/home/$USER/rdtc"
BACKUP_DIR="/home/$USER/rdtc_backup"
ZIP_FILE="/home/$USER/RealDebridClient.zip"

if [ ! -f "$ZIP_FILE" ]; then
    echo "ERROR: NO $ZIP_FILE"
    exit 1
fi

sudo systemctl stop rdtc.service
mkdir -p "$BACKUP_DIR"
cp "$APP_DIR/appsettings.json" "$BACKUP_DIR/"
cp "$APP_DIR/rdtclient.db"* "$BACKUP_DIR/"
unzip -o "$ZIP_FILE" -d "$APP_DIR/"
mv "$BACKUP_DIR/appsettings.json" "$APP_DIR/"
mv "$BACKUP_DIR/rdtclient.db"* "$APP_DIR/"
rm -rfv "$BACKUP_DIR"
rm "$ZIP_FILE"
sudo systemctl start rdtc.service
EOF

sudo chmod 755 -v /home/$USER/update_rdtc.sh

# ARIA2
ARIA2RPCSECRET="sudo"
ARIA2USERNAME=$(whoami)
ARIA2CONFIGDIR="$HOME/.config/aria2"
ARIA2CONFIGFILE="$ARIA2CONFIGDIR/aria2.conf"

sudo apt update && sudo apt install aria2 -y

mkdir -p "$ARIA2CONFIGDIR"
tee "$ARIA2CONFIGFILE" <<EOF
max-connection-per-server=16
split=16
min-split-size=1M

disk-cache=256M
file-allocation=none
no-file-allocation-limit=0

enable-rpc=true
rpc-listen-all=false
rpc-listen-port=6800
rpc-secret=$ARIA2RPCSECRET
EOF

sudo tee /etc/systemd/system/aria2c.service <<EOF
[Unit]
Description=Aria2c RPC Service
After=network.target nfs-client.target

[Service]
User=$ARIA2USERNAME
ExecStart=/usr/bin/aria2c --conf-path=$ARIA2CONFIGFILE

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable aria2c
sudo systemctl start aria2c

# NAVIDROME
NAVIDROMELINK="https://github.com/navidrome/navidrome/releases/download/v0.61.1/navidrome_0.61.1_linux_amd64.deb"
NAVIDROMEDEB="/home/oggy/navidrome.deb"

wget -O "$NAVIDROMEDEB" "$NAVIDROMELINK"
sudo apt install "$NAVIDROMEDEB" -y
sudo sed -i 's|MusicFolder = "/opt/navidrome/music"|MusicFolder = "/mnt/server/03-Music/Music/"|' /etc/navidrome/navidrome.toml
sudo systemctl enable --now navidrome

# CRONTAB
sudo bash -c '(crontab -l 2>/dev/null; echo "0 0 * * * systemctl restart transmission-daemon.service") | crontab -'
sudo bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 30 && systemctl restart rdtc.service") | crontab -'
sudo bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 30 && systemctl restart aria2c.service") | crontab -'
sudo bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 30 && systemctl restart prowlarr.service") | crontab -'
sudo bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 30 && systemctl restart radarr.service") | crontab -'
sudo bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 30 && systemctl restart sonarr.service") | crontab -'
sudo bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 30 && systemctl restart jellyfin.service") | crontab -'
sudo bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 30 && systemctl restart navidrome.service") | crontab -'
sudo bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 30 && systemctl restart transmission-daemon.service") | crontab -'

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
tee /home/$USER/update.sh <<'EOF'
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
chmod 755 -v /home/$USER/update.sh
sudo bash -c "(crontab -l 2>/dev/null; echo '30 6 * * 1 /home/oggy/update.sh > /home/oggy/update.log 2>&1') | crontab -"
