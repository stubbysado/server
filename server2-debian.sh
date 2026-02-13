#!/bin/bash -x

# SOURCES.LIST
sudo tee /etc/apt/sources.list.d/debian.sources <<'EOF'
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

# PACKAGES
sudo apt update
sudo apt upgrade -y
sudo apt install gcc htop make mergerfs samba screen -y

# RE-CHECK UPDATE
sudo apt update
sudo apt upgrade -y
sudo apt clean
sudo apt autoremove -y

# FSTAB
sudo mkdir -p /mnt/parity1 /mnt/data{1..4}
sudo cp /etc/fstab /etc/fstab.bak

sudo tee -a /etc/fstab <<'EOF'

# Hard Disk Drive
UUID=1326ca8d-bae5-442f-8abd-ce838a1eb5e3 /mnt/parity1 auto nosuid,nodev,nofail 0 0

UUID=bb3142a8-5b8d-4b99-b27f-166b9cb1060d /mnt/data1   auto nosuid,nodev,nofail 0 0
UUID=5ce59e64-be1a-4235-a291-b94b8217667e /mnt/data2   auto nosuid,nodev,nofail 0 0
UUID=2e8f3d3d-1664-4cf4-9a2f-d59834aa0315 /mnt/data3   auto nosuid,nodev,nofail 0 0
UUID=b365421e-db36-4faf-9816-14503d7685d7 /mnt/data4   auto nosuid,nodev,nofail 0 0
EOF

sudo systemctl daemon-reload
sudo mount -a
sudo chown oggy:oggy /mnt/parity1 /mnt/data{1..4}

# MERGERFS
sudo mkdir -p /mnt/server2

sudo tee -a /etc/fstab <<'EOF'

# MergerFS
/mnt/data* /mnt/server2 mergerfs cache.files=off,category.create=pfrd,func.getattr=newest,dropcacheonclose=false 0 0
EOF

sudo chown oggy:oggy /mnt/server2
sudo systemctl daemon-reload
sudo mount -a

# SAMBA
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak

sudo tee -a /etc/samba/smb.conf <<'EOF'

[server2]
   path = /mnt/server2
   browseable = no
   read only = no
   guest ok = no
   valid users = oggy
   vfs objects = recycle
   recycle:repository = .recycle
   recycle:directory_mode = 775
   recycle:versions = yes
EOF

PASSWORD="sudo"

echo -e "$PASSWORD\n$PASSWORD" | sudo smbpasswd -a oggy
sudo systemctl restart smbd.service

# SNAPRAID
mkdir /home/oggy/snapraid
wget https://github.com/amadvance/snapraid/releases/download/v13.0/snapraid-13.0.tar.gz -P /home/oggy/snapraid/
tar -xzf /home/oggy/snapraid/snapraid-13.0.tar.gz -C /home/oggy/snapraid/

CONFIGURESNAPRAID="/home/oggy/snapraid/snapraid-13.0/configure"

cd /home/oggy/snapraid && $CONFIGURESNAPRAID
make -C /home/oggy/snapraid
sudo make install
rm -rfv /home/oggy/snapraid

sudo tee /etc/snapraid.conf <<'EOF'

parity /mnt/parity1/snapraid.parity

content /mnt/data1/snapraid.content
content /mnt/data2/snapraid.content
content /mnt/data3/snapraid.content
content /mnt/data4/snapraid.content

data data1 /mnt/data1/
data data2 /mnt/data2/
data data3 /mnt/data3/
data data4 /mnt/data4/

exclude lost+found/
EOF

# EXTRA HDD
sudo mkdir -p /mnt/data-ext{1,2}

sudo tee -a /etc/fstab <<'EOF'

# Extra Hard Disk Drives
UUID=23b3c9e4-4799-4a1c-a95e-a4b536d67a7f /mnt/data-ext1 auto nosuid,nodev,nofail 0 0
UUID=27a9aa12-c992-4c6c-aac6-cacc7b49c5ff /mnt/data-ext2 auto nosuid,nodev,nofail 0 0
EOF

sudo systemctl daemon-reload
sudo mount -a
sudo chown oggy:oggy /mnt/data-ext{1,2}

# ALIAS
echo "alias ll='ls -la'" >> /home/oggy/.bashrc
