#!/bin/bash -x

# DOWNLOAD PACKAGE
sudo apt update -y
sudo apt upgrade -y
sudo apt install gcc make mergerfs netdata samba -y

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

echo '' | sudo tee -a /etc/fstab
echo '# Hard Disk Drive' | sudo tee -a /etc/fstab
echo 'UUID=6e10f55a-2d5d-4a42-a636-5cb42ea1bd05 /mnt/parity1 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab
echo '' | sudo tee -a /etc/fstab
echo 'UUID=fbd9d55a-1ed1-47c9-8a8a-58ed3769fc70 /mnt/data1 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab

sudo mount -a

sudo chown oggy:oggy /mnt/parity1
sudo chown oggy:oggy /mnt/data1

# MERGERFS
sudo mkdir /mnt/server3

sudo mergerfs -o use_ino,cache.files=off,dropcacheonclose=true,allow_other,category.create=mfs,fsname=server3 /mnt/data* /mnt/server3

echo '' | sudo tee -a /etc/fstab
echo '# MergerFS' | sudo tee -a /etc/fstab
echo '/mnt/data* /mnt/server3 fuse.mergerfs use_ino,cache.files=off,dropcacheonclose=true,allow_other,category.create=mfs,fsname=server3,nonempty 0 0' | sudo tee -a /etc/fstab

sudo chown oggy:oggy /mnt/server3

sudo mount -a

# SAMBA
echo '' | sudo tee -a /etc/samba/smb.conf
echo '[server3]' | sudo tee -a /etc/samba/smb.conf
echo 'path = /mnt/server3' | sudo tee -a /etc/samba/smb.conf
echo 'browseable = yes' | sudo tee -a /etc/samba/smb.conf
echo 'read only = no' | sudo tee -a /etc/samba/smb.conf
echo 'guest ok = no' | sudo tee -a /etc/samba/smb.conf
echo 'valid users = oggy' | sudo tee -a /etc/samba/smb.conf
echo '' | sudo tee -a /etc/samba/smb.conf
echo 'vfs objects = recycle' | sudo tee -a /etc/samba/smb.conf
echo 'recycle:repository = .recycle' | sudo tee -a /etc/samba/smb.conf
echo 'recycle:directory_mode = 775' | sudo tee -a /etc/samba/smb.conf
echo 'recycle:versions = yes' | sudo tee -a /etc/samba/smb.conf

PASSWORD="root"

echo -e "$PASSWORD\n$PASSWORD" | sudo smbpasswd -a $(whoami)

sudo systemctl restart smbd.service

# SNAPRAID
wget https://github.com/amadvance/snapraid/releases/download/v12.2/snapraid-12.2.tar.gz

tar -xzf /home/oggy/post-install/snapraid-12.2.tar.gz

CONFIGURESNAPRAID="/home/oggy/post-install/snapraid-12.2/configure"

$CONFIGURESNAPRAID

make

sudo make install

echo 'parity /mnt/parity1/snapraid.parity' | sudo tee -a /etc/snapraid.conf
echo '' | sudo tee -a /etc/snapraid.conf
echo 'content /mnt/data1/snapraid.content' | sudo tee -a /etc/snapraid.conf
echo '' | sudo tee -a /etc/snapraid.conf
echo 'data data1 /mnt/data1/' | sudo tee -a /etc/snapraid.conf
echo '' | sudo tee -a /etc/snapraid.conf
echo 'exclude /lost+found/' | sudo tee -a /etc/snapraid.conf

# NETDATA
sudo sed -i 's|127.0.0.1|192.168.0.199|g' /etc/netdata/netdata.conf

sudo systemctl restart netdata

# SYNC
sync && sync
