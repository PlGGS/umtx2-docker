#!/bin/sh
set -eu

APP_DIR="/app"
PAYLOAD_DIR="$APP_DIR/document/en/ps5/payloads"
MAP_FILE="$APP_DIR/document/en/ps5/payload_map.js"

export APP_DIR PAYLOAD_DIR MAP_FILE

echo "Updating managed payloads..."
/app/scripts/update-etahen.sh
/app/scripts/update-kstuff.sh
/app/scripts/update-websrv.sh
/app/scripts/update-ftpsrv.sh
/app/scripts/update-klogsrv.sh
/app/scripts/update-shsrv.sh
/app/scripts/update-gdbsrv.sh
/app/scripts/update-ps5debug.sh
/app/scripts/update-elfldr.sh
/app/scripts/update-ps5-linux-loader.sh
/app/scripts/update-browser-appcache-remove.sh

if [ -z "${HOST_IP:-}" ]; then
  echo "ERROR: HOST_IP is not set"
  exit 1
fi

echo "Setting dns.conf to HOST_IP=$HOST_IP"

cat > /app/dns.conf <<EOF
A manuals.playstation.net $HOST_IP
EOF

echo "Starting fake DNS..."
python /app/fakedns.py -c /app/dns.conf &

echo "Starting HTTPS host..."
exec python /app/host.py
