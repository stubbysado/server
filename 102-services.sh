#!/bin/bash -x

# REMOVE SOURCES.LIST
sudo rm -f /etc/apt/sources.list

# SOURCES.LIST
sudo tee /etc/apt/sources.list.d/debian.sources <<'EOF'
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

# SPEED TEST
check_github_speed() {
    local GITHUBTESTURL="http://prowlarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=x64"
    while true; do
        echo "Testing download (15s)"
        GITHUBSPEED=$(curl -L --max-time 15 --progress-bar -o /dev/null -w "%{speed_download}" "$GITHUBTESTURL" 2>/dev/tty)
        GITHUBSPEEDKB=$(awk "BEGIN {printf \"%.1f\", $GITHUBSPEED / 1024}")
        echo "Speed: ${GITHUBSPEEDKB} KB/s"
        read -rp "[P]roceed / [R]etry / [A]bort: " CHOICE
        case "${CHOICE,,}" in
            p) break ;;
            r) continue ;;
            a) exit 1 ;;
            *) echo "Invalid" ;;
        esac
    done
}

check_github_speed

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

# LIDARR
sudo apt update
sudo apt install curl mediainfo sqlite3 libchromaprint-tools -y
wget --content-disposition 'http://lidarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=x64'
tar -xvzf ./Lidarr*.linux*.tar.gz
sudo mv ./Lidarr/ /opt
sudo chown oggy:oggy -Rv /opt/Lidarr
sudo mkdir -p /var/lib/lidarr
sudo chown -R oggy:oggy /var/lib/lidarr

sudo tee /etc/systemd/system/lidarr.service <<'EOF'
[Unit]
Description=Lidarr Daemon
After=syslog.target network.target

[Service]
User=oggy
Group=oggy
Type=simple

ExecStart=/opt/Lidarr/Lidarr -nobrowser -data=/var/lib/lidarr/
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now lidarr
rm ./Lidarr*.linux*.tar.gz

# BAZARR
BAZARRINSTALLDIR="/opt/bazarr"
BAZARRVENVDIR="/opt/bazarr-venv"
BAZARRSERVICEFILE="/etc/systemd/system/bazarr.service"
BAZARRRUNUSER="${SUDO_USER:-$USER}"

BAZARRDEBIANVERSION=$(. /etc/os-release && echo "$VERSION_ID")
sudo apt-get update -qq
if [[ "$BAZARRDEBIANVERSION" -ge 12 ]] 2>/dev/null; then
  sudo apt-get install -y 7zip python3-dev python3-pip python3-setuptools \
    python3-venv python3-full unrar unzip
else
  sudo apt-get install -y 7zip python3-dev python3-pip python3-distutils \
    python3-venv unrar unzip
fi

BAZARRTMPZIP=$(mktemp /tmp/bazarr_XXXXXX.zip)
wget -q -O "$BAZARRTMPZIP" https://github.com/morpheus65535/bazarr/releases/latest/download/bazarr.zip
sudo mkdir -p "$BAZARRINSTALLDIR"
sudo unzip -q -o "$BAZARRTMPZIP" -d "$BAZARRINSTALLDIR"
rm -f "$BAZARRTMPZIP"

sudo python3 -m venv "$BAZARRVENVDIR"
sudo "$BAZARRVENVDIR/bin/pip" install --no-warn-script-location \
  -r "$BAZARRINSTALLDIR/requirements.txt"

sudo chown -R "$BAZARRRUNUSER":"$BAZARRRUNUSER" "$BAZARRINSTALLDIR" "$BAZARRVENVDIR"

BAZARRPYTHONBIN="$BAZARRVENVDIR/bin/python3"

printf '[Unit]\nDescription=Bazarr\nAfter=network.target\n\n[Service]\nType=simple\nUser=%s\nWorkingDirectory=%s\nEnvironment="PATH=%s/bin:/usr/local/bin:/usr/bin:/bin"\nExecStart=%s %s/bazarr.py\nRestart=on-failure\nRestartSec=5\nTimeoutStopSec=20\n\n[Install]\nWantedBy=multi-user.target\n' \
  "$BAZARRRUNUSER" "$BAZARRINSTALLDIR" "$BAZARRVENVDIR" "$BAZARRPYTHONBIN" "$BAZARRINSTALLDIR" \
  | sudo tee "$BAZARRSERVICEFILE" > /dev/null

sudo systemctl daemon-reload
sudo systemctl enable --now bazarr

# NAVIDROME
NAVIDROMELINK="https://github.com/navidrome/navidrome/releases/download/v0.62.0/navidrome_0.62.0_linux_amd64.deb"
NAVIDROMEDEB="/home/oggy/navidrome.deb"

wget -O "$NAVIDROMEDEB" "$NAVIDROMELINK"
sudo apt install "$NAVIDROMEDEB" -y
sudo sed -i 's|MusicFolder = "/opt/navidrome/music"|MusicFolder = "/mnt/server/03-Music/Music/"|' /etc/navidrome/navidrome.toml
sudo systemctl enable --now navidrome

# JELLYFIN
sudo umount -l /tmp
curl -s https://repo.jellyfin.org/install-debuntu.sh | sudo bash

# CRONTAB
sudo bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 30 && systemctl restart prowlarr.service") | crontab -'
sudo bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 30 && systemctl restart radarr.service") | crontab -'
sudo bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 30 && systemctl restart sonarr.service") | crontab -'
sudo bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 30 && systemctl restart lidarr.service") | crontab -'
sudo bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 30 && systemctl restart bazarr.service") | crontab -'
sudo bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 30 && systemctl restart jellyfin.service") | crontab -'
sudo bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 30 && systemctl restart navidrome.service") | crontab -'

# ZRAM
sudo apt update
sudo apt install systemd-zram-generator -y

echo "[zram0]
zram-size = ram" | sudo tee /etc/systemd/zram-generator.conf

echo "vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0" | sudo tee /etc/sysctl.d/99-zram.conf

sudo systemctl daemon-reload
sudo sysctl --system
sudo systemctl start /dev/zram0

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
