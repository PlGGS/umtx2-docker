#!/bin/sh
set -eu

APP_DIR="/app"
PAYLOAD_DIR="$APP_DIR/document/en/ps5/payloads"
MAP_FILE="$APP_DIR/document/en/ps5/payload_map.js"

AUTO_UPDATE_PAYLOADS="${AUTO_UPDATE_PAYLOADS:-false}"

is_true() {
  case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
    true|1|yes|y|on) return 0 ;;
    *) return 1 ;;
  esac
}

patch_etahen_map() {
  ETAHEN_VERSION_FOR_MAP="$1"
  ETAHEN_BINARY_SOURCE_FOR_MAP="$2"
  export MAP_FILE ETAHEN_VERSION_FOR_MAP ETAHEN_BINARY_SOURCE_FOR_MAP

  python - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ["MAP_FILE"])
text = path.read_text()

pattern = r'(\{\s*displayTitle:\s*"etaHEN".*?\})'

def patch(match):
    block = match.group(1)

    block = re.sub(
        r'fileName:\s*"[^"]+"',
        'fileName: "etaHEN.bin"',
        block
    )

    block = re.sub(
        r'version:\s*"[^"]+"',
        f'version: "{os.environ["ETAHEN_VERSION_FOR_MAP"]}"',
        block
    )

    block = re.sub(
        r'binarySource:\s*"[^"]+"',
        f'binarySource: "{os.environ["ETAHEN_BINARY_SOURCE_FOR_MAP"]}"',
        block
    )

    return block

new_text, count = re.subn(pattern, patch, text, count=1, flags=re.DOTALL)

if count != 1:
    raise SystemExit("ERROR: Could not find etaHEN entry in payload_map.js")

path.write_text(new_text)
PY
}

echo "Normalizing managed payloads..."

mkdir -p "$PAYLOAD_DIR"

rm -f "$PAYLOAD_DIR"/etaHEN-*.bin

current_version="$(cat "$PAYLOAD_DIR/etaHEN.version" 2>/dev/null || true)"

if ! is_true "$AUTO_UPDATE_PAYLOADS"; then
  echo "Payload auto-update disabled."

  if [ -n "$current_version" ]; then
    patch_etahen_map "$current_version" "https://github.com/etaHEN/etaHEN/releases/tag/$current_version"
  else
    patch_etahen_map "latest" "https://github.com/etaHEN/etaHEN/releases/latest"
  fi
else
  echo "Payload auto-update enabled."

  latest_json_file="$(mktemp)"

  if ! curl -fsSL "https://api.github.com/repos/etaHEN/etaHEN/releases/latest" -o "$latest_json_file"; then
    echo "ERROR: Failed to fetch latest etaHEN release metadata."
    rm -f "$latest_json_file"
    exit 1
  fi

  latest_version="$(python - "$latest_json_file" <<'PY'
import json
import sys

with open(sys.argv[1], "rb") as f:
    data = json.load(f)

print(data["tag_name"])
PY
)"

  asset_url="$(python - "$latest_json_file" <<'PY'
import json
import re
import sys

with open(sys.argv[1], "rb") as f:
    data = json.load(f)

for asset in data.get("assets", []):
    name = asset.get("name", "")
    url = asset.get("browser_download_url", "")
    if re.match(r"^etaHEN-.*\.bin$", name) and url:
        print(url)
        break
PY
)"

  rm -f "$latest_json_file"

  if [ -z "$asset_url" ]; then
    echo "ERROR: Could not find etaHEN .bin asset in latest release."
    exit 1
  fi

  echo "Current etaHEN: ${current_version:-none}"
  echo "Latest etaHEN:  $latest_version"

  if [ "$current_version" != "$latest_version" ] || [ ! -f "$PAYLOAD_DIR/etaHEN.bin" ]; then
    tmp_file="$(mktemp)"

    if ! curl -fL "$asset_url" -o "$tmp_file"; then
      echo "ERROR: Failed to download etaHEN payload."
      rm -f "$tmp_file"
      exit 1
    fi

    mv "$tmp_file" "$PAYLOAD_DIR/etaHEN.bin"
    echo "$latest_version" > "$PAYLOAD_DIR/etaHEN.version"

    echo "etaHEN updated to $latest_version."
  else
    echo "etaHEN already current."
  fi

  patch_etahen_map "latest" "https://github.com/etaHEN/etaHEN/releases/tag/$latest_version"
fi

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
