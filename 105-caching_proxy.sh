#!/bin/bash -x

# DELETE SOURCES.LIST
rm -f /etc/apt/sources.list.d/debian.sources

# SOURCES.LIST.D
tee /etc/apt/sources.list.d/debian.sources <<'EOF'
Types: deb deb-src
URIs: https://mirror.twds.com.tw/debian
Suites: trixie trixie-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: https://mirror.twds.com.tw/debian-security
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
    keys_zone=deb_cache:20m
    max_size=5g
    inactive=180d
    use_temp_path=off;
server {
    listen 80;
    server_name 10.0.0.41;
    resolver 10.0.0.1 valid=5m;
    access_log off;
    error_log /dev/null;
    proxy_cache deb_cache;
    proxy_cache_key "$host$request_uri";
    proxy_cache_valid 200 302 180d;
    proxy_cache_valid 404 1m;
    proxy_cache_lock on;
    proxy_cache_use_stale error timeout invalid_header updating http_500 http_502 http_503 http_504;
    proxy_ignore_headers Cache-Control Expires;
    proxy_ssl_server_name on;
    proxy_connect_timeout 10s;
    proxy_read_timeout 60s;
    add_header X-Cache-Status $upstream_cache_status;
    location ~* (InRelease|Release(\.gpg)?|Packages(\.xz|\.gz|\.bz2)?|Sources(\.xz|\.gz)?|Translation-[a-z]+(\.xz)?)$ {
        proxy_pass https://mirror.twds.com.tw;
        proxy_set_header Host mirror.twds.com.tw;
        proxy_no_cache 1;
        proxy_cache_bypass 1;
    }
    location / {
        proxy_pass https://mirror.twds.com.tw/;
        proxy_set_header Host mirror.twds.com.tw;
        proxy_cache_valid 200 302 180d;
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

# CRONTAB
sudo bash -c '(crontab -l 2>/dev/null; echo "0 0 * * 1 systemctl restart nginx.service") | crontab -'
