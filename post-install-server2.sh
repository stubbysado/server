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

# FSTAB
sudo mkdir /mnt/parity1
sudo mkdir /mnt/data1
sudo mkdir /mnt/data2
sudo mkdir /mnt/data3

echo '' | sudo tee -a /etc/fstab
echo '# Hard Disk Drive' | sudo tee -a /etc/fstab
echo '/dev/sdb1 /mnt/parity1 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab
echo '/dev/sdc1 /mnt/data1 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab
echo '/dev/sdd1 /mnt/data2 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab
echo '/dev/sde1 /mnt/data3 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab

sudo mount -a

sudo chown oggy:oggy /mnt/parity1
sudo chown oggy:oggy /mnt/data1
sudo chown oggy:oggy /mnt/data2
sudo chown oggy:oggy /mnt/data3

# MERGERFS
sudo mkdir /mnt/server2

sudo mergerfs -o use_ino,cache.files=off,dropcacheonclose=true,allow_other,category.create=mfs,fsname=server2 /mnt/data* /mnt/server2

echo '' | sudo tee -a /etc/fstab
echo '# MergerFS' | sudo tee -a /etc/fstab
echo '/mnt/data* /mnt/server2 fuse.mergerfs use_ino,cache.files=off,dropcacheonclose=true,allow_other,category.create=mfs,fsname=server2,nonempty 0 0' | sudo tee -a /etc/fstab

sudo chown oggy:oggy /mnt/server2

sudo mount -a

# SAMBA
echo '' | sudo tee -a /etc/samba/smb.conf
echo '[server2]' | sudo tee -a /etc/samba/smb.conf
echo 'path = /mnt/server2' | sudo tee -a /etc/samba/smb.conf
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

echo 'content /mnt/data1/snapraid.content' | sudo tee -a /etc/snapraid.conf
echo 'content /mnt/data2/snapraid.content' | sudo tee -a /etc/snapraid.conf
echo 'content /mnt/data3/snapraid.content' | sudo tee -a /etc/snapraid.conf

echo 'data data1 /mnt/data1/' | sudo tee -a /etc/snapraid.conf
echo 'data data2 /mnt/data2/' | sudo tee -a /etc/snapraid.conf
echo 'data data3 /mnt/data3/' | sudo tee -a /etc/snapraid.conf

echo 'exclude /lost+found/' | sudo tee -a /etc/snapraid.conf

# NETDATA
sudo sed -i 's|127.0.0.1|192.168.0.102|g' /etc/netdata/netdata.conf

sudo systemctl restart netdata

# SYNC
sync && sync

echo -e "*** System restart required ***"
