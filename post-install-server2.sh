#!/bin/bash -x

# PURGE SNAPD
sudo apt purge snapd* -y

# DOWNLOAD PACKAGE
sudo apt update -y
sudo apt upgrade -y
sudo apt install gcc make mergerfs samba -y

# RE-CHECK UPDATE
sudo apt update -y
sudo apt upgrade -y
sudo apt clean -y
sudo apt autoclean -y
sudo apt autoremove -y

# TIMEZONE
sudo timedatectl set-timezone Asia/Kuala_Lumpur

# DISABLE NETWORKD
sudo systemctl disable systemd-networkd-wait-online.service
sudo systemctl mask systemd-networkd-wait-online.service

# FSTAB
sudo mkdir /mnt/parity1
sudo mkdir /mnt/data1
sudo mkdir /mnt/data2
sudo mkdir /mnt/data3
sudo mkdir /mnt/data4

sudo cp /etc/fstab /etc/fstab.bak

echo '' | sudo tee -a /etc/fstab
echo '# Hard Disk Drive' | sudo tee -a /etc/fstab
echo 'UUID=1326ca8d-bae5-442f-8abd-ce838a1eb5e3 /mnt/parity1 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab
echo '' | sudo tee -a /etc/fstab
echo 'UUID=bb3142a8-5b8d-4b99-b27f-166b9cb1060d /mnt/data1 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab
echo 'UUID=5ce59e64-be1a-4235-a291-b94b8217667e /mnt/data2 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab
echo 'UUID=2e8f3d3d-1664-4cf4-9a2f-d59834aa0315 /mnt/data3 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab
echo 'UUID=b365421e-db36-4faf-9816-14503d7685d7 /mnt/data4 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab

sudo mount -a

sudo chown oggy:oggy /mnt/parity1
sudo chown oggy:oggy /mnt/data1
sudo chown oggy:oggy /mnt/data2
sudo chown oggy:oggy /mnt/data3
sudo chown oggy:oggy /mnt/data4

# MERGERFS
sudo mkdir /mnt/server2

echo '' | sudo tee -a /etc/fstab
echo '# MergerFS' | sudo tee -a /etc/fstab
echo '/mnt/data* /mnt/server2 fuse.mergerfs allow_other,cache.files=full,dropcacheonclose=true,category.create=mfs 0 0' | sudo tee -a /etc/fstab

sudo chown oggy:oggy /mnt/server2

sudo mount -a

# SAMBA
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak

echo '' | sudo tee -a /etc/samba/smb.conf
echo '[server2]' | sudo tee -a /etc/samba/smb.conf
echo 'path = /mnt/server2' | sudo tee -a /etc/samba/smb.conf
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

echo -e "$PASSWORD\n$PASSWORD" | sudo smbpasswd -a $(whoami)

sudo systemctl restart smbd.service

# SNAPRAID
mkdir /home/oggy/snapraid

wget https://github.com/amadvance/snapraid/releases/download/v12.3/snapraid-12.3.tar.gz -P /home/oggy/snapraid/

tar -xzf /home/oggy/snapraid/snapraid-12.3.tar.gz -C /home/oggy/snapraid/

CONFIGURESNAPRAID="/home/oggy/snapraid/snapraid-12.3/configure"

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
echo '' | sudo tee -a /etc/snapraid.conf
echo 'data data1 /mnt/data1/' | sudo tee -a /etc/snapraid.conf
echo 'data data2 /mnt/data2/' | sudo tee -a /etc/snapraid.conf
echo 'data data3 /mnt/data3/' | sudo tee -a /etc/snapraid.conf
echo 'data data4 /mnt/data4/' | sudo tee -a /etc/snapraid.conf
echo '' | sudo tee -a /etc/snapraid.conf
echo 'exclude lost+found/' | sudo tee -a /etc/snapraid.conf

# EXTRA HDD
sudo mkdir /mnt/ext1

echo '' | sudo tee -a /etc/fstab
echo '# Extra Hard Disk Drive' | sudo tee -a /etc/fstab
echo 'UUID=23b3c9e4-4799-4a1c-a95e-a4b536d67a7f /mnt/ext1 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab

sudo mount -a

sudo chown oggy:oggy /mnt/ext1

echo '' | sudo tee -a /etc/samba/smb.conf
echo '[server2a]' | sudo tee -a /etc/samba/smb.conf
echo 'path = /mnt/ext1' | sudo tee -a /etc/samba/smb.conf
echo 'browseable = yes' | sudo tee -a /etc/samba/smb.conf
echo 'read only = no' | sudo tee -a /etc/samba/smb.conf
echo 'guest ok = no' | sudo tee -a /etc/samba/smb.conf
echo 'valid users = oggy' | sudo tee -a /etc/samba/smb.conf
echo '' | sudo tee -a /etc/samba/smb.conf
echo 'vfs objects = recycle' | sudo tee -a /etc/samba/smb.conf
echo 'recycle:repository = .recycle' | sudo tee -a /etc/samba/smb.conf
echo 'recycle:directory_mode = 775' | sudo tee -a /etc/samba/smb.conf
echo 'recycle:versions = yes' | sudo tee -a /etc/samba/smb.conf

sudo systemctl restart smbd.service

# EXTRA HDD 02
sudo mkdir /mnt/ext2

echo '' | sudo tee -a /etc/fstab
echo '# Extra Hard Disk Drive 2' | sudo tee -a /etc/fstab
echo 'UUID=27a9aa12-c992-4c6c-aac6-cacc7b49c5ff /mnt/ext2 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab

sudo mount -a

sudo chown oggy:oggy /mnt/ext2

echo '' | sudo tee -a /etc/samba/smb.conf
echo '[server2b]' | sudo tee -a /etc/samba/smb.conf
echo 'path = /mnt/ext2' | sudo tee -a /etc/samba/smb.conf
echo 'browseable = yes' | sudo tee -a /etc/samba/smb.conf
echo 'read only = no' | sudo tee -a /etc/samba/smb.conf
echo 'guest ok = no' | sudo tee -a /etc/samba/smb.conf
echo 'valid users = oggy' | sudo tee -a /etc/samba/smb.conf
echo '' | sudo tee -a /etc/samba/smb.conf
echo 'vfs objects = recycle' | sudo tee -a /etc/samba/smb.conf
echo 'recycle:repository = .recycle' | sudo tee -a /etc/samba/smb.conf
echo 'recycle:directory_mode = 775' | sudo tee -a /etc/samba/smb.conf
echo 'recycle:versions = yes' | sudo tee -a /etc/samba/smb.conf

# SYNC
sync && sync
