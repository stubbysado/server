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
sudo apt install htop transmission-daemon curl -y

# LINK
check_link() {
    if ! curl --output /dev/null --silent --head --fail "$1"; then
        return 1
    fi
}

while true; do
    echo "--- INVALID LINK (Ctrl+C to exit) ---"
    
    read -p "MICROSOFT link (Default: https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb): " MICROSOFT
    MICROSOFT=${MICROSOFT:-https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb}

    read -p "REAL DEBRID link: " REALDEBRID
    read -p "FILEBROWSER QUANTUM link: " FILEBROWSER
    read -p "NAVIDROME link: " NAVIDROME

    if [ -z "$REALDEBRID" ] || [ -z "$FILEBROWSER" ] || [ -z "$NAVIDROME" ]; then
        echo "ERROR: Link required"
        continue
    fi

    echo "Checking link"
    if check_link "$MICROSOFT" && check_link "$REALDEBRID" && check_link "$FILEBROWSER" && check_link "$NAVIDROME"; then
        echo "Link verified"
        break
    else
        echo "ERROR: One or more links are unreachable. Please re-enter all links."
    fi
done

# NFS
sudo apt update
sudo apt install nfs-common -y
sudo mkdir -p /mnt/server
sudo chown oggy:oggy /mnt/server
echo "10.0.0.21:/mnt/server /mnt/server nfs defaults 0 0" | sudo tee -a /etc/fstab
sudo mount -a

# TRANSMISSION
sudo systemctl stop transmission-daemon.service
sudo systemctl start transmission-daemon.service
sudo systemctl stop transmission-daemon.service
sleep 3
sudo cp /lib/systemd/system/transmission-daemon.service /lib/systemd/system/transmission-daemon.service.bak
sudo sed -i 's|User=debian-transmission|User=oggy|g' /lib/systemd/system/transmission-daemon.service
sudo sed -i 's|Type=notify|Type=simple|g' /lib/systemd/system/transmission-daemon.service
sudo systemctl daemon-reload
sudo systemctl start transmission-daemon.service
sleep 3
sudo systemctl stop transmission-daemon.service
sudo systemctl start transmission-daemon.service
sudo systemctl stop transmission-daemon.service
sleep 3
sudo cp /home/oggy/.config/transmission-daemon/settings.json /home/oggy/.config/transmission-daemon/settings.json.bak
sudo sed -i 's|"encryption": 1,|"encryption": 2,|g' /home/oggy/.config/transmission-daemon/settings.json
sudo sed -i 's|"download-dir": "/home/oggy/Downloads",|"download-dir": "/mnt/server/02-Downloads/Transmission",|g' /home/oggy/.config/transmission-daemon/settings.json
sudo sed -i 's|"rpc-authentication-required": false,|"rpc-authentication-required": true,|g' /home/oggy/.config/transmission-daemon/settings.json
sudo sed -i 's|"rpc-username": "",|"rpc-username": "oggy",|g' /home/oggy/.config/transmission-daemon/settings.json
sudo sed -i 's|"rpc-password": .*|"rpc-password": "sudo",|' /home/oggy/.config/transmission-daemon/settings.json
sudo sed -i 's|"rpc-whitelist": "127.0.0.1,::1",|"rpc-whitelist": "127.0.0.1,10.0.0.*",|g' /home/oggy/.config/transmission-daemon/settings.json
sudo systemctl daemon-reload
sudo systemctl start transmission-daemon.service

# CRONTAB
sudo bash -c '(crontab -l 2>/dev/null; echo "0 0 * * * systemctl restart transmission-daemon.service") | crontab -'
sudo bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 30 && /usr/bin/mount -a") | crontab -'
sudo bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 60 && systemctl restart transmission-daemon.service") | crontab -'

# PROWLARR
sudo apt update
sudo apt install curl sqlite3 libicu-dev -y
wget --content-disposition 'http://prowlarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=x64'
tar -xvzf ./Prowlarr*.linux*.tar.gz
sudo mv ./Prowlarr/ /opt
sudo chown oggy:oggy -Rv /opt/Prowlarr
sudo mkdir -p /var/lib/prowlarr
sudo chown -R oggy:oggy /var/lib/prowlarr
sudo tee /etc/systemd/system/prowlarr.service <<'EOF'
[Unit]
Description=Prowlarr Daemon
After=syslog.target network.target
[Service]
User=oggy
Group=oggy
Type=simple

ExecStart=/opt/Prowlarr/Prowlarr -nobrowser -data=/var/lib/prowlarr/
TimeoutStopSec=20
KillMode=process
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now prowlarr
rm ./Prowlarr*.linux*.tar.gz

# REAL DEBRID (RDT-CLIENT)
sudo apt update
sudo apt install unzip -y
wget "$MICROSOFT"
sudo dpkg -i ./packages-microsoft-prod.deb
sudo apt update
sudo apt install dotnet-sdk-10.0 -y
wget "$REALDEBRID"
mkdir -p ./rdtc
unzip ./RealDebridClient.zip -d ./rdtc
sed -i 's@/data/db/@@g' ./rdtc/appsettings.json
sudo tee /etc/systemd/system/rdtc.service <<'EOF'
[Unit]
Description=RdtClient Service

[Service]
WorkingDirectory=/home/oggy/rdtc
ExecStart=/usr/bin/dotnet RdtClient.Web.dll
SyslogIdentifier=RdtClient
User=oggy

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable rdtc
sudo systemctl start rdtc

# FILEBROWSER QUANTUM
wget "$FILEBROWSER"
chmod 755 ./linux-amd64-filebrowser
sudo mv ./linux-amd64-filebrowser /usr/local/bin/filebrowser
sudo mkdir -p /opt/filebrowser
sudo chown oggy:oggy /opt/filebrowser
sudo tee /opt/filebrowser/config.yaml <<'EOF'
server:
  port: 55555
  database: /opt/filebrowser/database.db
  sources:
  - name: Oggy Production
    path: /mnt/server/09-Work/RAW/
  logging:
  - levels: info|warning|error
    apiLevels: info|warning|error
    output: stdout
    noColors: false
    utc: false
frontend:
  name: Oggy Production
auth:
  adminUsername: admin
  adminPassword: fWEHt"Pg]N4G$w76
userDefaults:
  permissions:
    api: false
    admin: false
    modify: false
    share: false
    realtime: false
    delete: false
    create: false
    download: false
EOF
sudo tee /etc/systemd/system/filebrowser.service <<'EOF'
[Unit]
Description=FileBrowser Quantum
After=network.target

[Service]
Type=simple
User=oggy
WorkingDirectory=/opt/filebrowser
ExecStart=/usr/local/bin/filebrowser -c /opt/filebrowser/config.yaml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable filebrowser
sudo systemctl start filebrowser

# NAVIDROME
wget "$NAVIDROME"
sudo apt install ./navidrome*.deb -y
sudo sed -i 's|MusicFolder = "/opt/navidrome/music"|MusicFolder = "/mnt/server/03-Music/Music/"|' /etc/navidrome/navidrome.toml
sudo systemctl enable --now navidrome

# TAGGER.PY
# sudo apt update && sudo apt install python3-mutagen -y
#
# tee ./tagger.py <<'EOF'
# import os
# import re
# import readline
# import glob
# from mutagen.easyid3 import EasyID3
# from mutagen.flac import FLAC
# from mutagen.mp3 import MP3
#
# # --- Tab Autocomplete Setup ---
# def path_completer(text, state):
#     line = readline.get_line_buffer()
#     if not line:
#         return [f + "/" for f in os.listdir('.')][state]
#     else:
#         return (glob.glob(os.path.expanduser(text) + '*') + [None])[state]
#
# readline.set_completer_delims(' \t\n;')
# readline.parse_and_bind("tab: complete")
# readline.set_completer(path_completer)
#
# def process_music(root_path):
#     root_path = os.path.abspath(os.path.expanduser(root_path))
#     
#     for root, dirs, files in os.walk(root_path):
#         for file in files:
#             if not file.lower().endswith(('.flac', '.mp3')):
#                 continue
#
#             file_path = os.path.join(root, file)
#             # Split path into parts to identify Artist and Album folders
#             parts = file_path.split(os.sep)
#             
#             try:
#                 # Structure: .../[Artist]/[Year Album]/[Track Title].ext
#                 # filename is parts[-1], album folder is parts[-2], artist is parts[-3]
#                 filename = parts[-1]
#                 year_album = parts[-2]
#                 artist_name = parts[-3]
#
#                 # Parse Year and Album (e.g., "1973 Ring Ring")
#                 match_album = re.match(r"(\d{4})\s+(.*)", year_album)
#                 year = match_album.group(1) if match_album else ""
#                 album = match_album.group(2) if match_album else year_album
#
#                 # Parse Track and Title (e.g., "01 Ring Ring")
#                 match_track = re.match(r"(\d+)\s+(.*)\.", filename)
#                 track = match_track.group(1) if match_track else ""
#                 title = match_track.group(2) if match_track else filename.rsplit('.', 1)[0]
#
#                 print(f"Processing: {artist_name} - {album} [{year}] - {track}: {title}")
#
#                 if file.lower().endswith('.flac'):
#                     audio = FLAC(file_path)
#                     # .delete() on FLAC clears comments but leaves Album Art blocks intact
#                     audio.delete()
#                     audio["artist"] = artist_name
#                     audio["albumartist"] = artist_name # Contributing Artist
#                     audio["album"] = album
#                     audio["date"] = year
#                     audio["tracknumber"] = track
#                     audio["title"] = title
#                     audio.save()
#
#                 elif file.lower().endswith('.mp3'):
#                     # MP3s are trickier; must manually preserve 'APIC' (Album Art) frame
#                     audio_full = MP3(file_path)
#                     artwork = audio_full.tags.getall('APIC') if audio_full.tags else []
#                     audio_full.delete() 
#                     audio_full.save() # Wipe file clean
#
#                     # Re-load with EasyID3 for standard fields
#                     audio = EasyID3(file_path)
#                     audio["artist"] = artist_name
#                     audio["albumartist"] = artist_name
#                     audio["album"] = album
#                     audio["date"] = year
#                     audio["tracknumber"] = track
#                     audio["title"] = title
#                     audio.save()
#
#                     # Restore artwork to the clean file
#                     if artwork:
#                         audio_final = MP3(file_path)
#                         for art in artwork:
#                             audio_final.tags.add(art)
#                         audio_final.save()
#
#             except Exception as e:
#                 print(f"Error on {file}: {e}")
#
# if __name__ == "__main__":
#     path = input("Enter music path (Tab for autocomplete): ").strip()
#     if os.path.isdir(os.path.expanduser(path)):
#         process_music(path)
#         print("\nDone!")
#     else:
#         print("Invalid Directory.")
# EOF

# RE-CHECK UPDATE
sudo apt update
sudo apt upgrade -y
sudo apt clean
sudo apt autoremove -y
