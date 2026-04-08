#!/bin/bash -x

# DELETE SOURCES.LIST
rm -f /etc/apt/sources.list.d/debian.sources

# SOURCES.LIST.D
tee /etc/apt/sources.list.d/debian.sources <<'EOF'
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

# UPDATE
apt update
apt upgrade -y
apt clean
apt autoremove -y

# NGINX
apt install nginx -y

# NGINX REVERSE CACHING PROXY
apt update && apt install nginx -y
mkdir -p /var/cache/nginx/reverse-proxy
chown www-data:www-data /var/cache/nginx/reverse-proxy

tee /etc/nginx/sites-available/reverse-proxy <<'EOF'
proxy_cache_path /var/cache/nginx/reverse-proxy
    levels=1:2
    keys_zone=deb_cache:10m
    max_size=5g
    inactive=180d
    use_temp_path=off;
server {
    listen 80;
    server_name 10.0.0.41;
    access_log /var/log/nginx/reverse-proxy.log;
    error_log off;
    proxy_cache deb_cache;
    proxy_cache_valid 200 302 1h;
    proxy_cache_lock on;
    proxy_cache_use_stale error timeout invalid_header updating http_500 http_502 http_503 http_504;
    proxy_ssl_server_name on;
    add_header X-Cache-Status $upstream_cache_status;
    location / {
        proxy_pass https://mirror.sg.gs/;
        proxy_set_header Host mirror.sg.gs;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/reverse-proxy /etc/nginx/sites-enabled/

if nginx -t; then
    systemctl restart nginx
    echo "--- NGINX REVERSE CACHING PROXY IS RUNNING ---"
else
    echo "[!] FAILED [!]"
    exit 1
fi

bash -c '(crontab -l 2>/dev/null; echo "@reboot sleep 30 && systemctl restart nginx") | crontab -'
