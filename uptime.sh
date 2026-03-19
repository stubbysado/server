#!/bin/bash

# REMOVE SOURCES.LIST
rm -f /etc/apt/sources.list

# SOURCES.LIST
tee /etc/apt/sources.list.d/debian.sources <<'EOF'
Types: deb deb-src
URIs: http://10.0.0.41/debian
Suites: trixie trixie-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: http://10.0.0.41/debian-security
Suites: trixie-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

# PACKAGES
apt update
apt upgrade -y
apt clean
apt autoremove -y

# TIMEZONE
timedatectl set-timezone Asia/Kuala_Lumpur

# UPTIME
set -e

CONF_FILE="/etc/uptime/uptime.conf"
LOG_FILE="/var/log/uptime.log"
DATA_DIR="/var/lib/uptime"
WWW_DIR="/var/www/uptime"
NGINX_CONF="/etc/nginx/sites-available/uptime"
CHECK_SCRIPT="/opt/uptime/check.sh"

echo "[1/7] INSTALL DEPENDENCIES"
apt update
apt install -y nginx iputils-ping curl bc

echo "[2/7] CREATE DIRECTORIES"
mkdir -p /opt/uptime
mkdir -p /etc/uptime
mkdir -p "$DATA_DIR"
mkdir -p "$WWW_DIR"

echo "[3/7] WRITE DEFAULT CONFIG"
if [ ! -f "$CONF_FILE" ]; then
cat > "$CONF_FILE" << 'EOF'
# uptime.conf
#
# Format: name | target
#
# IP  (ping) : opnsense | 10.0.0.1
# HTTP/HTTPS (curl): Jellyfin | http://10.0.0.42:8096
#
# Changes take effect on the next hourly check, no restart needed.

opnsense | 10.0.0.1
EOF
echo "CONFIG: $CONF_FILE"
else
echo "CONFIG EXISTS, SKIP"
fi

echo "[4/7] WRITE CHECK SCRIPT"
cat > "$CHECK_SCRIPT" << 'CHECKEOF'
#!/bin/bash
# check.sh
# Runs every hour via cron. Reads uptime.conf, pings/curls each target,
# stores results, then regenerates the HTML dashboard.

CONF_FILE="/etc/uptime/uptime.conf"
DATA_DIR="/var/lib/uptime"
WWW_DIR="/var/www/uptime"
LOG_FILE="/var/log/uptime.log"

NOW=$(date '+%Y-%m-%d %H:%M')
TS=$(date '+%s')

echo "[$NOW] Starting check..." >> "$LOG_FILE"

# CHECK TARGET, UPDATE STATE FILES
while IFS='|' read -r name target; do
    name=$(echo "$name" | xargs)
    target=$(echo "$target" | xargs)
    [[ -z "$name" || "$name" == \#* ]] && continue

    slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g')
    datafile="$DATA_DIR/${slug}.log"
    statefile="$DATA_DIR/${slug}.state"

    status="DOWN"
    ping_ms="—"

    if [[ "$target" == http://* || "$target" == https://* ]]; then
        result=$(curl -o /dev/null -s -w "%{http_code} %{time_total}" \
            --max-time 10 --connect-timeout 5 "$target" 2>/dev/null || echo "000 0")
        http_code=$(echo "$result" | awk '{print $1}')
        time_total=$(echo "$result" | awk '{print $2}')
        if [[ "$http_code" =~ ^[23] ]]; then
            status="UP"
            ping_ms=$(echo "$time_total * 1000 / 1" | bc)
        fi
    else
        result=$(ping -c 1 -W 5 "$target" 2>/dev/null | grep 'time=' || true)
        if [[ -n "$result" ]]; then
            status="UP"
            ping_ms=$(echo "$result" | grep -oP 'time=\K[0-9.]+' | awk '{printf "%d", $1}')
        fi
    fi

    # APPEND TO DATA LOG
    echo "${TS}|${status}|${ping_ms}" >> "$datafile"
    tail -n 720 "$datafile" > "${datafile}.tmp" && mv "${datafile}.tmp" "$datafile"

    # READ CURRENT STATE
    prev_status=$(grep '^prev_status=' "$statefile" 2>/dev/null | cut -d'=' -f2)
    down_since=$(grep '^down_since=' "$statefile" 2>/dev/null | cut -d'=' -f2-)
    last_down=$(grep '^last_down=' "$statefile" 2>/dev/null | cut -d'=' -f2-)
    down_count=$(grep '^down_count=' "$statefile" 2>/dev/null | cut -d'=' -f2)
    down_count=${down_count:-0}

    if [[ "$status" == "DOWN" && "$prev_status" != "DOWN" ]]; then
        # UP -> DOWN: record outage start, increment counter
        down_since="$NOW"
        down_count=$((down_count + 1))
    elif [[ "$status" == "UP" && "$prev_status" == "DOWN" ]]; then
        # DOWN -> UP: move down_since to last_down, clear down_since
        last_down="$down_since ($down_count x)"
        down_since=""
    fi

    printf 'prev_status=%s\ndown_since=%s\nlast_down=%s\ndown_count=%s\n' \
        "$status" "$down_since" "$last_down" "$down_count" > "$statefile"

    echo "[$NOW]   $name ($target) -> $status ${ping_ms}ms" >> "$LOG_FILE"

done < "$CONF_FILE"

# REGENERATE HTML DASHBOARD
ROWS=""
TOTAL=0
UP_COUNT=0
DOWN_COUNT=0

while IFS='|' read -r name target; do
    name=$(echo "$name" | xargs)
    target=$(echo "$target" | xargs)
    [[ -z "$name" || "$name" == \#* ]] && continue

    TOTAL=$((TOTAL + 1))
    slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g')
    datafile="$DATA_DIR/${slug}.log"
    statefile="$DATA_DIR/${slug}.state"

    # CURRENT STATUS
    if [[ -f "$datafile" ]]; then
        last=$(tail -n 1 "$datafile")
        cur_status=$(echo "$last" | cut -d'|' -f2)
        cur_ping=$(echo "$last" | cut -d'|' -f3)
    else
        cur_status="DOWN"
        cur_ping="—"
    fi

    # 24H UPTIME
    cutoff_24h=$((TS - 86400))
    total_24h=0; up_24h=0
    if [[ -f "$datafile" ]]; then
        while IFS='|' read -r t s p; do
            [[ "$t" -ge "$cutoff_24h" ]] || continue
            total_24h=$((total_24h + 1))
            [[ "$s" == "UP" ]] && up_24h=$((up_24h + 1))
        done < "$datafile"
    fi
    if [[ $total_24h -gt 0 ]]; then
        pct_24h=$(echo "scale=1; $up_24h * 100 / $total_24h" | bc)
    else
        pct_24h="—"
    fi

    # 30D UPTIME
    cutoff_30d=$((TS - 2592000))
    total_30d=0; up_30d=0
    if [[ -f "$datafile" ]]; then
        while IFS='|' read -r t s p; do
            [[ "$t" -ge "$cutoff_30d" ]] || continue
            total_30d=$((total_30d + 1))
            [[ "$s" == "UP" ]] && up_30d=$((up_30d + 1))
        done < "$datafile"
    fi
    if [[ $total_30d -gt 0 ]]; then
        pct_30d=$(echo "scale=1; $up_30d * 100 / $total_30d" | bc)
    else
        pct_30d="—"
    fi

    # STATUS COLORS
    if [[ "$cur_status" == "UP" ]]; then
        UP_COUNT=$((UP_COUNT + 1))
        status_class="green"
        status_label="[ UP ]"
        ping_class="green"
        [[ "$cur_ping" != "—" && "$cur_ping" -ge 200 ]] && ping_class="yellow"
    else
        DOWN_COUNT=$((DOWN_COUNT + 1))
        status_class="red"
        status_label="[DOWN]"
        ping_class="white"
        cur_ping="—"
    fi

    # UPTIME COLORS
    color_pct() {
        local p="$1"
        if [[ "$p" == "—" ]]; then echo "white"
        elif (( $(echo "$p >= 99" | bc -l) )); then echo "green"
        elif (( $(echo "$p >= 90" | bc -l) )); then echo "yellow"
        else echo "red"
        fi
    }
    c24=$(color_pct "$pct_24h")
    c30=$(color_pct "$pct_30d")

    [[ "$pct_24h" != "—" ]] && pct_24h="${pct_24h}%"
    [[ "$pct_30d" != "—" ]] && pct_30d="${pct_30d}%"
    [[ "$cur_ping" != "—" ]] && cur_ping="${cur_ping} ms"

    # READ DOWN/LAST DOWN FROM STATE FILE
    col_down="—"
    col_last_down="—"
    if [[ -f "$statefile" ]]; then
        s_down_since=$(grep '^down_since=' "$statefile" | cut -d'=' -f2-)
        s_last_down=$(grep '^last_down=' "$statefile" | cut -d'=' -f2-)
        [[ -n "$s_down_since" ]] && col_down="$s_down_since"
        [[ -n "$s_last_down" ]] && col_last_down="$s_last_down"
    fi
    down_class="white"
    [[ "$col_down" != "—" ]] && down_class="red"

    ROWS="${ROWS}
      <div class=\"row\">
        <span class=\"col-status ${status_class}\">${status_label}</span>
        <span class=\"col-name\">${name}</span>
        <span class=\"col-target\">${target}</span>
        <span class=\"col-ping ${ping_class}\">${cur_ping}</span>
        <span class=\"col-u24 ${c24}\">${pct_24h}</span>
        <span class=\"col-u30 ${c30}\">${pct_30d}</span>
        <span class=\"col-down ${down_class}\">${col_down}</span>
        <span class=\"col-lastdown white\">${col_last_down}</span>
      </div>"

done < "$CONF_FILE"

cat > "$WWW_DIR/index.html" << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>uptime</title>
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: #0d0d0d; font-family: 'Courier New', Courier, monospace; font-size: 14px; color: #e8e8e8; padding: 2rem; }
  .wrap { max-width: 1200px; margin: 0 auto; }
  .topbar { display: flex; align-items: baseline; gap: 2rem; margin-bottom: 1.5rem; flex-wrap: wrap; }
  .cyan   { color: #5fafd7; }
  .green  { color: #5faf5f; }
  .red    { color: #d75f5f; }
  .yellow { color: #d7af5f; }
  .white  { color: #e8e8e8; }
  .header, .row { display: grid; grid-template-columns: 7ch 30ch 30ch 9ch 7ch 7ch 17ch 30ch; align-items: center; padding: 5px 0; column-gap: 1.5ch; }
  .header { padding-bottom: 8px; border-bottom: 1px solid #222; margin-bottom: 4px; }
  .col-name, .col-target, .col-down, .col-lastdown { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .footer { display: flex; gap: 2rem; flex-wrap: wrap; margin-top: 1.25rem; }
  @media (max-width: 768px) {
    body { padding: 1rem; font-size: 12px; }
    .header { display: none; }
    .row { display: grid; grid-template-columns: 7ch 1fr auto; grid-template-rows: auto auto auto auto; column-gap: 8px; row-gap: 2px; padding: 10px 0; border-top: 1px solid #1c1c1c; }
    .col-status   { grid-column: 1; grid-row: 1; }
    .col-name     { grid-column: 2; grid-row: 1; }
    .col-u24      { grid-column: 3; grid-row: 1; text-align: right; }
    .col-target   { grid-column: 2; grid-row: 2; font-size: 11px; }
    .col-ping     { grid-column: 1; grid-row: 2; font-size: 11px; }
    .col-u30      { grid-column: 3; grid-row: 2; font-size: 11px; text-align: right; }
    .col-down     { grid-column: 1 / -1; grid-row: 3; font-size: 11px; }
    .col-lastdown { grid-column: 1 / -1; grid-row: 4; font-size: 11px; }
  }
</style>
</head>
<body>
<div class="wrap">

  <div class="topbar">
    <span class="cyan">uptime</span>
    <span class="white" id="next"></span>
  </div>

  <script>
    var last = ${TS}000;
    function tick() {
      var diff = 3600 - Math.floor((Date.now() - last) / 1000);
      if (diff < 0) diff = 0;
      var m = Math.floor(diff / 60), s = diff % 60;
      document.getElementById('next').textContent =
        'refresh: ' + (m < 10 ? '0' : '') + m + 'm ' + (s < 10 ? '0' : '') + s + 's';
    }
    tick(); setInterval(tick, 1000);
  </script>

  <div class="header">
    <span>status</span>
    <span>name</span>
    <span>target</span>
    <span>ping</span>
    <span>24h</span>
    <span>30d</span>
    <span>down</span>
    <span>last down</span>
  </div>

  ${ROWS}

  <div class="footer">
    <span>total: ${TOTAL}</span>
    <span class="green">up: ${UP_COUNT}</span>
    <span class="red">down: ${DOWN_COUNT}</span>
  </div>

</div>
</body>
</html>
HTMLEOF

echo "[$NOW] Dashboard regenerated." >> "$LOG_FILE"
CHECKEOF

chmod +x "$CHECK_SCRIPT"

echo "[5/7] CONFIGURE NGINX"
cat > "$NGINX_CONF" << 'EOF'
server {
    listen 80;
    server_name _;

    root /var/www/uptime;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/uptime
rm -f /etc/nginx/sites-enabled/default

nginx -t && systemctl reload nginx
echo "NGINX CONFIGURED AND RELOADED"

echo "[6/7] INSTALL CRON JOB"
CRON_LINE="30 * * * * $CHECK_SCRIPT >> $LOG_FILE 2>&1"
(crontab -l 2>/dev/null || true) | grep -v "$CHECK_SCRIPT" | { cat; echo "$CRON_LINE"; } | crontab -
echo "CRON JOB: EVERY HOUR AT :00"

echo "[7/7] RUN FIRST CHECK"
bash "$CHECK_SCRIPT"

echo "DONE!"
echo "DASHBOARD: http://$(hostname -I | awk '{print $1}')/"
echo "CONFIG: $CONF_FILE"
echo "LOGS: $LOG_FILE"
echo "ADD/REMOVE MONITORS: $CONF_FILE"
