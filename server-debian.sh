#!/bin/bash -x

# REMOVE SOURCES.LIST
sudo rm -f /etc/apt/sources.list

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
sudo mkdir -p /mnt/parity1 /mnt/data{1..6}
sudo cp /etc/fstab /etc/fstab.bak

sudo tee -a /etc/fstab <<'EOF'

# Hard Disk Drive
UUID=80274962-7f78-4935-884a-c1ef00aba684 /mnt/parity1 auto nosuid,nodev,nofail 0 0
UUID=c180a0f4-c1fa-4d14-a811-32070222e595 /mnt/data1   auto nosuid,nodev,nofail 0 0
UUID=3cd34620-4876-4f14-90cc-8260281baf4b /mnt/data2   auto nosuid,nodev,nofail 0 0
UUID=06765f35-5626-403a-9190-0872d22edb8d /mnt/data3   auto nosuid,nodev,nofail 0 0
UUID=28fd0102-f269-43bb-88a6-959f7ea9dc65 /mnt/data4   auto nosuid,nodev,nofail 0 0
UUID=248d2eb9-6330-402d-a620-a74974b29af7 /mnt/data5   auto nosuid,nodev,nofail 0 0
UUID=64ebf1c2-a790-465d-84f7-b0eff587e446 /mnt/data6   auto nosuid,nodev,nofail 0 0
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
exclude *.part
exclude snapraid.log
exclude snapraid-output.log
EOF

# CRONTAB
bash -c '(crontab -l 2>/dev/null; echo "0 0 * * * /home/oggy/runner.sh") | crontab -'

# ALIAS
echo "alias ll='ls -la'" >> /home/oggy/.bashrc

# INSTALL NFS
sudo apt update
sudo apt install nfs-kernel-server -y
echo "/mnt/server 10.0.0.41(rw,no_root_squash,fsid=0)" | sudo tee -a /etc/exports
sudo exportfs -ra
sudo systemctl restart nfs-kernel-server
