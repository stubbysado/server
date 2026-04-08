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
sudo exportfs -ra
sudo systemctl restart nfs-kernel-server

# SNAPRAID
SNAPRAIDLINK="https://github.com/amadvance/snapraid/releases/download/v14.1/snapraid_14.1-1_amd64.deb"
SNAPRAIDDEB="/home/oggy/snapraid.deb"

wget -O "$SNAPRAID_DEB" "$SNAPRAIDLINK"
sudo dpkg -i "$SNAPRAID_DEB"
rm -fv "$SNAPRAID_DEB"

SNAPRAIDDAEMONLINK="https://github.com/amadvance/snapraid-daemon/releases/download/v1.5/snapraid-daemon_1.5-1_amd64.deb"
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

sudo systemctl daemon-reload
sleep 5
sudo systemctl restart snapraidd.service

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
EOF

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
