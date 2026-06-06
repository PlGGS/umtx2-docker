#!/bin/sh
set -e

if [ -z "$HOST_IP" ]; then
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
