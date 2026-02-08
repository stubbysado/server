#!/bin/bash -x

# SOURCES.LIST
sudo tee /etc/apt/sources.list.d/debian.sources <<EOF
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

# INSTALL PACKAGES
sudo apt update -y
sudo apt upgrade -y
sudo apt install gcc htop make mergerfs samba screen -y

# RE-CHECK UPDATE
sudo apt update -y
sudo apt upgrade -y
sudo apt clean -y
sudo apt autoremove -y

# FSTAB
sudo mkdir -p /mnt/parity1 /mnt/data{1..6}
sudo cp /etc/fstab /etc/fstab.bak

sudo tee -a /etc/fstab <<EOF

# Hard Disk Drive
UUID=dd43886e-07ea-4c66-baae-84c333eab877 /mnt/parity1 auto nosuid,nodev,nofail 0 0

UUID=61ce7573-4a44-4cfa-83df-c3d1046b13ae /mnt/data1   auto nosuid,nodev,nofail 0 0
UUID=947f2157-352e-44f3-ac73-87ec4075db2e /mnt/data2   auto nosuid,nodev,nofail 0 0
UUID=ef3bdd10-22cf-42fe-aedb-660d41386008 /mnt/data3   auto nosuid,nodev,nofail 0 0
UUID=f4b3eba6-b51b-4641-89b2-cadecbb2775f /mnt/data4   auto nosuid,nodev,nofail 0 0
UUID=04873b05-2b65-4e8a-b8e4-43bf7be51a58 /mnt/data5   auto nosuid,nodev,nofail 0 0
UUID=3890ba1c-3b95-4df2-a979-cd81d280e994 /mnt/data6   auto nosuid,nodev,nofail 0 0
EOF

sudo systemctl daemon-reload
sudo mount -a
sudo chown oggy:oggy /mnt/parity1 /mnt/data{1..6}

# MERGERFS
sudo mkdir -p /mnt/server3

sudo tee -a /etc/fstab <<EOF

# MergerFS
/mnt/data* /mnt/server3 mergerfs cache.files=off,category.create=pfrd,func.getattr=newest,dropcacheonclose=false 0 0
EOF

sudo chown oggy:oggy /mnt/server3
sudo systemctl daemon-reload
sudo mount -a

# SAMBA
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak

sudo tee -a /etc/samba/smb.conf <<EOF

[server3]
   path = /mnt/server3
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

sudo tee /etc/snapraid.conf <<EOF

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
EOF

# ALIAS
echo "alias ll='ls -la'" >> /home/oggy/.bashrc

# SYNC
sync && sync
