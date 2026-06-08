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
sudo apt install mergerfs samba -y

# FSTAB
sudo mkdir -p /mnt/parity1 /mnt/data{1..6}
sudo cp /etc/fstab /etc/fstab.bak

sudo tee -a /etc/fstab <<'EOF'

# Hard Disk Drive
UUID=80274962-7f78-4935-884a-c1ef00aba684 /mnt/parity1 auto nosuid,nodev,nofail 0 0
UUID=c180a0f4-c1fa-4d14-a811-32070222e595 /mnt/data1 auto nosuid,nodev,nofail 0 0
UUID=3cd34620-4876-4f14-90cc-8260281baf4b /mnt/data2 auto nosuid,nodev,nofail 0 0
UUID=06765f35-5626-403a-9190-0872d22edb8d /mnt/data3 auto nosuid,nodev,nofail 0 0
UUID=28fd0102-f269-43bb-88a6-959f7ea9dc65 /mnt/data4 auto nosuid,nodev,nofail 0 0
UUID=248d2eb9-6330-402d-a620-a74974b29af7 /mnt/data5 auto nosuid,nodev,nofail 0 0
UUID=64ebf1c2-a790-465d-84f7-b0eff587e446 /mnt/data6 auto nosuid,nodev,nofail 0 0
EOF

sudo systemctl daemon-reload
sudo mount -a
sudo chown oggy:oggy /mnt/parity1 /mnt/data{1..6}

# MERGERFS
sudo mkdir -p /mnt/server

sudo tee -a /etc/fstab <<'EOF'

# MergerFS
/mnt/data* /mnt/server mergerfs cache.files=off,category.create=pfrd,func.getattr=newest,dropcacheonclose=false 0 0
EOF

sudo systemctl daemon-reload
sudo mount -a
sudo chown oggy:oggy /mnt/server

# SAMBA
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak

sudo tee -a /etc/samba/smb.conf <<'EOF'

[server]
path = /mnt/server
browseable = no
read only = no
guest ok = no
valid users = oggy
vfs objects = recycle
recycle:repository = .recycle
recycle:directory_mode = 755
recycle:versions = yes

[pve_backup]
path = /mnt/server/10-Backup/pve
browseable = no
read only = no
guest ok = no
valid users = oggy
EOF

SAMBAPASSWORD="sudo"

echo -e "$SAMBAPASSWORD\n$SAMBAPASSWORD" | sudo smbpasswd -a oggy
sudo systemctl restart smbd.service

# NFS
sudo apt update
sudo apt install nfs-kernel-server -y
echo "/mnt/server 10.0.0.31(rw,async,no_root_squash,no_subtree_check,fsid=0)" | sudo tee -a /etc/exports
echo "/mnt/server 10.0.0.42(rw,async,no_root_squash,no_subtree_check,fsid=0)" | sudo tee -a /etc/exports
echo "/mnt/server 10.0.0.43(rw,async,no_root_squash,no_subtree_check,fsid=0)" | sudo tee -a /etc/exports
echo "/mnt/server 10.0.0.49(rw,async,no_root_squash,no_subtree_check,fsid=0)" | sudo tee -a /etc/exports
sudo exportfs -ra
sudo systemctl restart nfs-kernel-server

# SNAPRAID
SNAPRAIDLINK="https://github.com/amadvance/snapraid/releases/download/v14.2/snapraid_14.2-1_amd64.deb"
SNAPRAIDDEB="/home/oggy/snapraid.deb"

wget -O "$SNAPRAIDDEB" "$SNAPRAIDLINK"
sudo dpkg -i "$SNAPRAIDDEB"
rm -fv "$SNAPRAIDDEB"

SNAPRAIDDAEMONLINK="https://github.com/amadvance/snapraid-daemon/releases/download/v1.6/snapraid-daemon_1.6-1_amd64.deb"
SNAPRAIDDAEMONDEB="/home/oggy/snapraid-daemon.deb"

wget -O "$SNAPRAIDDAEMONDEB" "$SNAPRAIDDAEMONLINK"
sudo dpkg -i "$SNAPRAIDDAEMONDEB"
rm -fv "$SNAPRAIDDAEMONDEB"

SNAPRAIDDCONF="/etc/snapraidd.conf"

sudo sed -i \
  -e 's|^#net_port = 127.0.0.1:7627|net_port = 7627|' \
  -e 's|^#net_acl = +127.0.0.1|net_acl = +127.0.0.1,+10.0.0.0/24|' \
  -e 's|^maintenance_schedule = 02:00|maintenance_schedule = 00:00|' \
  -e 's|^sync_threshold_deletes = 50|sync_threshold_deletes = 0|' \
  -e 's|^sync_threshold_updates = 100|sync_threshold_updates = 0|' \
  -e 's|^#sync_prehash = 1|sync_prehash = 1|' \
  -e 's|^scrub_percentage = 0.7|scrub_percentage = 1|' \
  -e 's|^probe_interval_minutes = 3|probe_interval_minutes = 0|' \
  -e 's|^spindown_idle_minutes = 15|#spindown_idle_minutes = 15|' \
  "$SNAPRAIDDCONF"

sudo tee /etc/snapraid.conf <<'EOF'

parity /mnt/parity1/snapraid.parity

content /mnt/data1/snapraid.content
content /mnt/data2/snapraid.content
content /mnt/data3/snapraid.content
content /mnt/data4/snapraid.content
content /mnt/data5/snapraid.content
content /mnt/data6/snapraid.content

data data1 /mnt/data1/
data data2 /mnt/data2/
data data3 /mnt/data3/
data data4 /mnt/data4/
data data5 /mnt/data5/
data data6 /mnt/data6/

exclude lost+found/
exclude .recycle/
exclude 02-Downloads/
exclude 09-Work/RAW/tmp/
EOF

# DOCKER
sudo apt update
sudo apt install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# DOCKGE
sudo mkdir -p /opt/stacks /opt/dockge
sudo curl -sL https://raw.githubusercontent.com/louislam/dockge/master/compose.yaml --output /opt/dockge/compose.yaml
sudo docker compose -f /opt/dockge/compose.yaml up -d

# PROWLARR
sudo mkdir -p /opt/stacks/prowlarr
sudo tee /opt/stacks/prowlarr/compose.yaml <<'EOF'
services:
  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
    volumes:
      - /opt/stacks/prowlarr:/config
    ports:
      - 9696:9696
    restart: unless-stopped
EOF
sudo chown $USER:$USER -R /opt/stacks/prowlarr
sudo docker compose -f /opt/stacks/prowlarr/compose.yaml up -d

# RADARR
sudo mkdir -p /opt/stacks/radarr
sudo tee /opt/stacks/radarr/compose.yaml <<'EOF'
services:
  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
    volumes:
      - /opt/stacks/radarr:/config
      - /mnt/server/02-Downloads/radarr:/movies #optional
      - /mnt/server/02-Downloads/qbittorent/downloads:/downloads #optional
    ports:
      - 7878:7878
    restart: unless-stopped
EOF
sudo chown $USER:$USER -R /opt/stacks/radarr
sudo docker compose -f /opt/stacks/radarr/compose.yaml up -d

# SONARR
sudo mkdir -p /opt/stacks/sonarr
sudo tee /opt/stacks/sonarr/compose.yaml <<'EOF'
services:
  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
    volumes:
      - /opt/stacks/sonarr:/config
      - /mnt/server/02-Downloads/sonarr:/tv #optional
      - /mnt/server/02-Downloads/qbittorent/downloads:/downloads #optional
    ports:
      - 8989:8989
    restart: unless-stopped
EOF
sudo chown $USER:$USER -R /opt/stacks/sonarr
sudo docker compose -f /opt/stacks/sonarr/compose.yaml up -d

# LIDARR
sudo mkdir -p /opt/stacks/lidarr
sudo tee /opt/stacks/lidarr/compose.yaml <<'EOF'
services:
  lidarr:
    image: lscr.io/linuxserver/lidarr:latest
    container_name: lidarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
    volumes:
      - /opt/stacks/lidarr:/config
      - /mnt/server/03-Music/Music:/music #optional
      - /mnt/server/02-Downloads/qbittorent/downloads:/downloads #optional
    ports:
      - 8686:8686
    restart: unless-stopped
EOF
sudo chown $USER:$USER -R /opt/stacks/lidarr
sudo docker compose -f /opt/stacks/lidarr/compose.yaml up -d

# BAZARR
sudo mkdir -p /opt/stacks/bazarr
sudo tee /opt/stacks/bazarr/compose.yaml <<'EOF'
services:
  bazarr:
    image: lscr.io/linuxserver/bazarr:latest
    container_name: bazarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
    volumes:
      - /opt/stacks/bazarr:/config
      - /mnt/server/02-Downloads/radarr:/movies #optional
      - /mnt/server/02-Downloads/sonarr:/tv #optional
    ports:
      - 6767:6767
    restart: unless-stopped
EOF
sudo chown $USER:$USER -R /opt/stacks/bazarr
sudo docker compose -f /opt/stacks/bazarr/compose.yaml up -d

# BYPARR
sudo mkdir -p /opt/stacks/byparr
sudo tee /opt/stacks/byparr/compose.yaml <<'EOF'
services:
  byparr:
    image: ghcr.io/thephaseless/byparr:latest
    restart: unless-stopped
    init: true
    build:
      context: .
      dockerfile: Dockerfile
    # Uncomment below to use byparr outside of internal network
    # ports:
    #   - "8191:8191"
EOF
sudo chown $USER:$USER -R /opt/stacks/byparr
sudo docker compose -f /opt/stacks/byparr/compose.yaml up -d

# JELLYFIN
sudo mkdir -p /opt/stacks/jellyfin
sudo tee /opt/stacks/jellyfin/compose.yaml <<'EOF'
services:
  jellyfin:
    image: lscr.io/linuxserver/jellyfin:latest
    container_name: jellyfin
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - JELLYFIN_PublishedServerUrl=http://10.0.0.21 #optional
    volumes:
      - /opt/stacks/jellyfin:/config
      - /mnt/server:/media
    ports:
      - 8096:8096
      - 8920:8920 #optional
      - 7359:7359/udp #optional
      - 1900:1900/udp #optional
    restart: unless-stopped
EOF
sudo chown $USER:$USER -R /opt/stacks/jellyfin
sudo docker compose -f /opt/stacks/jellyfin/compose.yaml up -d

# NAVIDROME
sudo mkdir -p /opt/stacks/navidrome
sudo tee /opt/stacks/navidrome/compose.yaml <<'EOF'
services:
  navidrome:
    image: deluan/navidrome:latest
    user: 1000:1000 # should be owner of volumes
    ports:
      - "4533:4533"
    restart: unless-stopped
    volumes:
      - "/opt/stacks/navidrome:/data"
      - "/mnt/server/03-Music/Music:/music:ro"
EOF
sudo chown $USER:$USER -R /opt/stacks/navidrome
sudo docker compose -f /opt/stacks/navidrome/compose.yaml up -d

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

sudo chmod 755 -v /home/oggy/update.sh
sudo bash -c "(crontab -l 2>/dev/null; echo '0 6 * * 1 /home/oggy/update.sh > /home/oggy/update.log 2>&1') | crontab -"
