#!/bin/bash -x

# PURGE SNAPD
sudo apt purge snapd* -y

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

sudo cp /etc/fstab /etc/fstab.bak

echo '' | sudo tee -a /etc/fstab
echo '# Hard Disk Drive' | sudo tee -a /etc/fstab
echo 'UUID=80274962-7f78-4935-884a-c1ef00aba684 /mnt/parity1 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab
echo '' | sudo tee -a /etc/fstab
echo 'UUID=c180a0f4-c1fa-4d14-a811-32070222e595 /mnt/data1 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab
echo 'UUID=ba563c40-37ea-4a95-85a9-ba3111199db1 /mnt/data2 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab
echo 'UUID=06765f35-5626-403a-9190-0872d22edb8d /mnt/data3 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab
echo 'UUID=28fd0102-f269-43bb-88a6-959f7ea9dc65 /mnt/data4 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab
echo 'UUID=248d2eb9-6330-402d-a620-a74974b29af7 /mnt/data5 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab
echo 'UUID=64ebf1c2-a790-465d-84f7-b0eff587e446 /mnt/data6 auto nosuid,nodev,nofail 0 0' | sudo tee -a /etc/fstab

sudo systemctl daemon-reload

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

echo '' | sudo tee -a /etc/fstab
echo '# MergerFS' | sudo tee -a /etc/fstab
echo '/mnt/data* /mnt/server fuse.mergerfs allow_other,cache.files=full,dropcacheonclose=true,category.create=mfs 0 0' | sudo tee -a /etc/fstab

sudo systemctl daemon-reload

sudo mount -a

sudo chown oggy:oggy /mnt/server

# SAMBA
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak

echo '' | sudo tee -a /etc/samba/smb.conf
echo '[server]' | sudo tee -a /etc/samba/smb.conf
echo 'path = /mnt/server' | sudo tee -a /etc/samba/smb.conf
echo 'browseable = no' | sudo tee -a /etc/samba/smb.conf
echo 'read only = no' | sudo tee -a /etc/samba/smb.conf
echo 'guest ok = no' | sudo tee -a /etc/samba/smb.conf
echo 'valid users = oggy' | sudo tee -a /etc/samba/smb.conf
echo '' | sudo tee -a /etc/samba/smb.conf
echo 'vfs objects = recycle' | sudo tee -a /etc/samba/smb.conf
echo 'recycle:repository = .recycle' | sudo tee -a /etc/samba/smb.conf
echo 'recycle:directory_mode = 755' | sudo tee -a /etc/samba/smb.conf
echo 'recycle:versions = yes' | sudo tee -a /etc/samba/smb.conf

PASSWORD="sudo"

echo -e "$PASSWORD\n$PASSWORD" | sudo smbpasswd -a $(whoami)

sudo systemctl restart smbd.service

# SNAPRAID
mkdir /home/oggy/snapraid

wget https://github.com/amadvance/snapraid/releases/download/v12.4/snapraid-12.4.tar.gz -P /home/oggy/snapraid/

tar -xzf /home/oggy/snapraid/snapraid-12.4.tar.gz -C /home/oggy/snapraid/

CONFIGURESNAPRAID="/home/oggy/snapraid/snapraid-12.4/configure"

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
echo 'content /mnt/data6/snapraid.content' | sudo tee -a /etc/snapraid.conf
echo '' | sudo tee -a /etc/snapraid.conf
echo 'data data1 /mnt/data1/' | sudo tee -a /etc/snapraid.conf
echo 'data data2 /mnt/data2/' | sudo tee -a /etc/snapraid.conf
echo 'data data3 /mnt/data3/' | sudo tee -a /etc/snapraid.conf
echo 'data data4 /mnt/data4/' | sudo tee -a /etc/snapraid.conf
echo 'data data5 /mnt/data5/' | sudo tee -a /etc/snapraid.conf
echo 'data data6 /mnt/data6/' | sudo tee -a /etc/snapraid.conf
echo '' | sudo tee -a /etc/snapraid.conf
echo 'exclude lost+found/' | sudo tee -a /etc/snapraid.conf
echo 'exclude .recycle/' | sudo tee -a /etc/snapraid.conf
echo 'exclude 02-Downloads/' | sudo tee -a /etc/snapraid.conf
echo 'exclude *.part' | sudo tee -a /etc/snapraid.conf
echo 'exclude snapraid.log' | sudo tee -a /etc/snapraid.conf
echo 'exclude snapraid-output.log' | sudo tee -a /etc/snapraid.conf

# TRANSMISSION
# sudo systemctl stop transmission-daemon.service
# sudo cp /lib/systemd/system/transmission-daemon.service /lib/systemd/system/transmission-daemon.service.bak
# sudo sed -i 's|User=debian-transmission|User=oggy|g' /lib/systemd/system/transmission-daemon.service
# Temporary workaround
# sudo sed -i 's|Type=notify|Type=simple|g' /lib/systemd/system/transmission-daemon.service
# sudo systemctl daemon-reload
# sudo systemctl restart transmission-daemon.service
# sudo systemctl stop transmission-daemon.service
# sudo cp /home/oggy/.config/transmission-daemon/settings.json /home/oggy/.config/transmission-daemon/settings.json.bak
# sudo sed -i 's|"download-dir": "/home/oggy/Downloads",|"download-dir": "/mnt/server/02-Downloads/Transmission",|g' /home/oggy/.config/transmission-daemon/settings.json
# sudo sed -i 's|"rpc-authentication-required": false,|"rpc-authentication-required": true,|g' /home/oggy/.config/transmission-daemon/settings.json
# sudo sed -i 's|"rpc-username": "",|"rpc-username": "oggy",|g' /home/oggy/.config/transmission-daemon/settings.json
# sudo sed -i 's|"rpc-whitelist": "127.0.0.1,::1",|"rpc-whitelist": "127.0.0.1,10.0.0.*",|g' /home/oggy/.config/transmission-daemon/settings.json
# sudo systemctl daemon-reload
# sudo systemctl restart transmission-daemon.service

# PRINTER
sudo cp /etc/cups/cupsd.conf /etc/cups/cupsd.conf.bak

sudo cupsctl --share-printers --remote-any
sudo lpadmin -p printer -o printer-is-shared=true
sudo lpadmin -p printer -o printer-op-policy=authenticated
sudo usermod -aG lpadmin oggy
sudo systemctl restart cups

# CRONTAB
CRONTSCRIPT="/home/oggy/runner.sh"
CRONJOB="#0 0 * * * /home/oggy/runner.sh"

cat <(fgrep -i -v "$CRONTSCRIPT" <(crontab -l)) <(echo "$CRONJOB") | crontab -

# SYNC
sync && sync
