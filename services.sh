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
    
    read -p "MICROSOFT link (Default: https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb): " MICROSOFT
    MICROSOFT=${MICROSOFT:-https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb}

    read -p "REAL DEBRID link: " REALDEBRID
    read -p "NAVIDROME link: " NAVIDROME

    if [ -z "$REALDEBRID" ] || [ -z "$NAVIDROME" ]; then
        echo "ERROR: Link required"
        continue
    fi

    echo "Checking link"
    if check_link "$MICROSOFT" && check_link "$REALDEBRID" && check_link "$NAVIDROME"; then
        echo "Link verified"
        break
    else
        echo "ERROR: One or more links are unreachable. Please re-enter all links."
    fi
done

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

# REAL DEBRID (RDT-CLIENT)
sudo apt update
sudo apt install unzip -y
wget "$MICROSOFT"
sudo dpkg -i ./packages-microsoft-prod.deb
sudo apt update
sudo apt install dotnet-sdk-10.0 -y
wget "$REALDEBRID"
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

# ARIA2

RPC_SECRET="sudo"
USER_NAME=$(whoami)
CONFIG_DIR="$HOME/.config/aria2"
CONFIG_FILE="$CONFIG_DIR/aria2.conf"

sudo apt update && sudo apt install aria2 -y

mkdir -p "$CONFIG_DIR"
tee "$CONFIG_FILE" <<EOF
max-connection-per-server=16
split=16
min-split-size=1M

disk-cache=256M
file-allocation=none
no-file-allocation-limit=0

enable-rpc=true
rpc-listen-all=false
rpc-listen-port=6800
rpc-secret=$RPC_SECRET
EOF

sudo tee /etc/systemd/system/aria2c.service <<EOF
[Unit]
Description=Aria2c RPC Service
After=network.target nfs-client.target

[Service]
User=$USER_NAME
ExecStart=/usr/bin/aria2c --conf-path=$CONFIG_FILE

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable aria2c
sudo systemctl start aria2c

# NAVIDROME
wget "$NAVIDROME"
sudo apt install ./navidrome*.deb -y
sudo sed -i 's|MusicFolder = "/opt/navidrome/music"|MusicFolder = "/mnt/server/03-Music/Music/"|' /etc/navidrome/navidrome.toml
sudo systemctl enable --now navidrome

# ZRAM
sudo apt update
sudo apt install systemd-zram-generator -y

echo "[zram0]
zram-size = ram" | sudo tee /etc/systemd/zram-generator.conf

echo "vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0" | sudo tee /etc/sysctl.d/99-zram.conf

# CRONTAB
sudo bash -c '(crontab -l 2>/dev/null; echo "0 0 * * * systemctl restart transmission-daemon.service") | crontab -'
sudo bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 30 && /usr/bin/mount -a") | crontab -'
sudo bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 60 && systemctl restart rdtc.service") | crontab -'
sudo bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 60 && systemctl restart aria2.service") | crontab -'
sudo bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 60 && systemctl restart transmission-daemon.service") | crontab -'
sudo bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 60 && systemctl restart navidrome.service") | crontab -'

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
