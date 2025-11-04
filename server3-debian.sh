#!/bin/bash -x

# SOURCES.LIST
echo 'Types: deb deb-src' | sudo tee -a /etc/apt/sources.list.d/debian.sources
echo 'URIs: https://mirror.twds.com.tw/debian' | sudo tee -a /etc/apt/sources.list.d/debian.sources
echo 'Suites: trixie trixie-updates' | sudo tee -a /etc/apt/sources.list.d/debian.sources
echo 'Components: main contrib non-free non-free-firmware' | sudo tee -a /etc/apt/sources.list.d/debian.sources
echo 'Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg' | sudo tee -a /etc/apt/sources.list.d/debian.sources
echo '' | sudo tee -a /etc/apt/sources.list.d/debian.sources
echo 'Types: deb deb-src' | sudo tee -a /etc/apt/sources.list.d/debian.sources
echo 'URIs: https://mirror.twds.com.tw/debian-security' | sudo tee -a /etc/apt/sources.list.d/debian.sources
echo 'Suites: trixie-security' | sudo tee -a /etc/apt/sources.list.d/debian.sources
echo 'Components: main contrib non-free non-free-firmware' | sudo tee -a /etc/apt/sources.list.d/debian.sources
echo 'Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg' | sudo tee -a /etc/apt/sources.list.d/debian.sources

# INSTALL PACKAGES
sudo apt update -y
sudo apt upgrade -y
sudo apt install htop make mergerfs samba screen -y

# RE-CHECK UPDATE
sudo apt update -y
sudo apt upgrade -y
sudo apt clean -y
sudo apt autoclean -y
sudo apt autoremove -y

# FSTAB
sudo mkdir /mnt/parity1
sudo mkdir /mnt/data1
sudo mkdir /mnt/data2
sudo mkdir /mnt/data3
sudo mkdir /mnt/data4
sudo mkdir /mnt/data5

sudo cp /etc/fstab /etc/fstab.bak

echo '' | sudo tee -a /etc/fstab
echo '# Hard Disk Drive' | sudo tee -a /etc/fstab
echo 'UUID=dd43886e-07ea-4c66-baae-84c333eab877 /mnt/parity1 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab
echo '' | sudo tee -a /etc/fstab
echo 'UUID=61ce7573-4a44-4cfa-83df-c3d1046b13ae /mnt/data1 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab
echo 'UUID=947f2157-352e-44f3-ac73-87ec4075db2e /mnt/data2 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab
echo 'UUID=ef3bdd10-22cf-42fe-aedb-660d41386008 /mnt/data3 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab
echo 'UUID=f4b3eba6-b51b-4641-89b2-cadecbb2775f /mnt/data4 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab
echo 'UUID=04873b05-2b65-4e8a-b8e4-43bf7be51a58 /mnt/data5 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab

sudo systemctl daemon-reload

sudo mount -a

sudo chown oggy:oggy /mnt/parity1
sudo chown oggy:oggy /mnt/data1
sudo chown oggy:oggy /mnt/data2
sudo chown oggy:oggy /mnt/data3
sudo chown oggy:oggy /mnt/data4
sudo chown oggy:oggy /mnt/data5

# MERGERFS
sudo mkdir /mnt/server3

echo '' | sudo tee -a /etc/fstab
echo '# MergerFS' | sudo tee -a /etc/fstab
echo '/mnt/data* /mnt/server3 fuse.mergerfs allow_other,cache.files=full,dropcacheonclose=true,category.create=mfs 0 0' | sudo tee -a /etc/fstab

sudo chown oggy:oggy /mnt/server3

sudo systemctl daemon-reload

sudo mount -a

# SAMBA
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak

echo '' | sudo tee -a /etc/samba/smb.conf
echo '[server3]' | sudo tee -a /etc/samba/smb.conf
echo 'path = /mnt/server3' | sudo tee -a /etc/samba/smb.conf
echo 'browseable = no' | sudo tee -a /etc/samba/smb.conf
echo 'read only = no' | sudo tee -a /etc/samba/smb.conf
echo 'guest ok = no' | sudo tee -a /etc/samba/smb.conf
echo 'valid users = oggy' | sudo tee -a /etc/samba/smb.conf
echo '' | sudo tee -a /etc/samba/smb.conf
echo 'vfs objects = recycle' | sudo tee -a /etc/samba/smb.conf
echo 'recycle:repository = .recycle' | sudo tee -a /etc/samba/smb.conf
echo 'recycle:directory_mode = 775' | sudo tee -a /etc/samba/smb.conf
echo 'recycle:versions = yes' | sudo tee -a /etc/samba/smb.conf

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

echo 'parity /mnt/parity1/snapraid.parity' | sudo tee -a /etc/snapraid.conf
echo '' | sudo tee -a /etc/snapraid.conf
echo 'content /mnt/data1/snapraid.content' | sudo tee -a /etc/snapraid.conf
echo 'content /mnt/data2/snapraid.content' | sudo tee -a /etc/snapraid.conf
echo 'content /mnt/data3/snapraid.content' | sudo tee -a /etc/snapraid.conf
echo 'content /mnt/data4/snapraid.content' | sudo tee -a /etc/snapraid.conf
echo 'content /mnt/data5/snapraid.content' | sudo tee -a /etc/snapraid.conf
echo '' | sudo tee -a /etc/snapraid.conf
echo 'data data1 /mnt/data1/' | sudo tee -a /etc/snapraid.conf
echo 'data data2 /mnt/data2/' | sudo tee -a /etc/snapraid.conf
echo 'data data3 /mnt/data3/' | sudo tee -a /etc/snapraid.conf
echo 'data data4 /mnt/data4/' | sudo tee -a /etc/snapraid.conf
echo 'data data5 /mnt/data5/' | sudo tee -a /etc/snapraid.conf
echo '' | sudo tee -a /etc/snapraid.conf
echo 'exclude lost+found/' | sudo tee -a /etc/snapraid.conf

# ALIAS
echo "alias ll='ls -la'" | sudo tee -a /home/oggy/.bashrc

# SYNC
sync && sync
