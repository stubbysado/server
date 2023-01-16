#!/bin/bash -x

# DOWNLOAD PACKAGE
sudo apt update -y
sudo apt upgrade -y
sudo apt install cups gcc hplip make mergerfs samba transmission-daemon -y

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
sudo mkdir /mnt/data5
sudo mkdir /mnt/data6

echo '' | sudo tee -a /etc/fstab
echo '# Hard Disk Drive' | sudo tee -a /etc/fstab
echo 'UUID=17a06caa-bd35-4381-b15f-df39b8c08ded /mnt/parity1 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab
echo '' | sudo tee -a /etc/fstab
echo 'UUID=f7d5fb60-b454-4f2e-a44d-618c3cdadde4 /mnt/data1 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab
echo 'UUID=c8eb8767-e035-42c4-a81a-1f81a34dee8e /mnt/data2 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab
echo 'UUID=1bfc0af4-a189-4b35-823f-db5fc7d2a2de /mnt/data3 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab
echo 'UUID=dcc2de50-0031-4dea-8f92-3afa3bb2d5ef /mnt/data4 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab
echo 'UUID=fdd747b0-7e98-4048-895c-34894a669911 /mnt/data5 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab
echo 'UUID=3829786f-6f86-46e3-a5f5-a49c2d912882 /mnt/data6 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab

sudo mount -a

sudo chown oggy:oggy /mnt/parity1
sudo chown oggy:oggy /mnt/data1
sudo chown oggy:oggy /mnt/data2
sudo chown oggy:oggy /mnt/data3
sudo chown oggy:oggy /mnt/data4
sudo chown oggy:oggy /mnt/data5
sudo chown oggy:oggy /mnt/data6

# MERGERFS
sudo mkdir /mnt/server

sudo mergerfs -o use_ino,cache.files=full,dropcacheonclose=true,allow_other,category.create=mfs,fsname=server /mnt/data* /mnt/server

echo '' | sudo tee -a /etc/fstab
echo '# MergerFS' | sudo tee -a /etc/fstab
echo '/mnt/data* /mnt/server fuse.mergerfs use_ino,cache.files=full,dropcacheonclose=true,allow_other,category.create=mfs,fsname=server,nonempty 0 0' | sudo tee -a /etc/fstab

sudo mount -a

sudo chown oggy:oggy /mnt/server

# SAMBA
echo '' | sudo tee -a /etc/samba/smb.conf
echo '[server]' | sudo tee -a /etc/samba/smb.conf
echo 'path = /mnt/server' | sudo tee -a /etc/samba/smb.conf
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
echo 'content /mnt/data2/snapraid.content' | sudo tee -a /etc/snapraid.conf
echo 'content /mnt/data3/snapraid.content' | sudo tee -a /etc/snapraid.conf
echo 'content /mnt/data4/snapraid.content' | sudo tee -a /etc/snapraid.conf
echo 'content /mnt/data5/snapraid.content' | sudo tee -a /etc/snapraid.conf
echo 'content /mnt/data6/snapraid.content' | sudo tee -a /etc/snapraid.conf
echo '' | sudo tee -a /etc/snapraid.conf
echo 'data data1 /mnt/data1/' | sudo tee -a /etc/snapraid.conf
echo 'data data2 /mnt/data2/' | sudo tee -a /etc/snapraid.conf
echo 'data data3 /mnt/data3/' | sudo tee -a /etc/snapraid.conf
echo 'data data4 /mnt/data4/' | sudo tee -a /etc/snapraid.conf
echo 'data data5 /mnt/data5/' | sudo tee -a /etc/snapraid.conf
echo 'data data6 /mnt/data6/' | sudo tee -a /etc/snapraid.conf
echo '' | sudo tee -a /etc/snapraid.conf
echo 'exclude /lost+found/' | sudo tee -a /etc/snapraid.conf
echo 'exclude *.part' | sudo tee -a /etc/snapraid.conf

# TRANSMISSION
sudo systemctl stop transmission-daemon.service

sudo sed -i 's|User=debian-transmission|User=oggy|g' /lib/systemd/system/transmission-daemon.service

sudo systemctl daemon-reload
sudo systemctl start transmission-daemon.service
sudo systemctl stop transmission-daemon.service

sudo sed -i 's|"download-dir": "/home/oggy/Downloads",|"download-dir": "/mnt/server/02 Downloads/Transmission",|g' /home/oggy/.config/transmission-daemon/settings.json
sudo sed -i 's|"rpc-authentication-required": false,|"rpc-authentication-required": true,|g' /home/oggy/.config/transmission-daemon/settings.json
sudo sed -i 's|"rpc-username": "",|"rpc-username": "oggy",|g' /home/oggy/.config/transmission-daemon/settings.json
sudo sed -i 's|"rpc-whitelist": "127.0.0.1,::1",|"rpc-whitelist": "127.0.0.1,192.168.*.*",|g' /home/oggy/.config/transmission-daemon/settings.json

sudo systemctl daemon-reload
sudo systemctl restart transmission-daemon.service

# PRINTER
sudo sed -i 's|Listen localhost:631|Port 631|g' /etc/cups/cupsd.conf
sudo sed -i 's|Browsing No|Browsing Yes|g' /etc/cups/cupsd.conf

sudo usermod -aG lpadmin oggy
sudo systemctl restart cups

# CRONTAB
CRONTSCRIPT="/home/oggy/runner.sh"
CRONJOB="0 0 * * * /home/oggy/runner.sh"

cat <(fgrep -i -v "$CRONTSCRIPT" <(crontab -l)) <(echo "$CRONJOB") | crontab -

# SYNC
sync && sync
