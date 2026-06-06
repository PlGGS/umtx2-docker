#!/bin/sh
set -eu

APP_DIR="${APP_DIR:-/app}"
PAYLOAD_DIR="${PAYLOAD_DIR:-$APP_DIR/document/en/ps5/payloads}"

echo "Normalizing elfldr payload..."

mkdir -p "$PAYLOAD_DIR"

rm -f "$PAYLOAD_DIR"/elfldr-*.elf
rm -f "$PAYLOAD_DIR"/elfldr_*.elf

current_version="$(cat "$PAYLOAD_DIR/elfldr.version" 2>/dev/null || true)"

if [ "${AUTO_UPDATE_PAYLOADS:-false}" != "true" ] &&
   [ "${AUTO_UPDATE_PAYLOADS:-false}" != "1" ] &&
   [ "${AUTO_UPDATE_PAYLOADS:-false}" != "yes" ] &&
   [ "${AUTO_UPDATE_PAYLOADS:-false}" != "on" ]; then
  echo "elfldr auto-update disabled."
  exit 0
fi

echo "elfldr auto-update enabled."

latest_json_file="$(mktemp)"

if ! curl -fsSL "https://api.github.com/repos/ps5-payload-dev/elfldr/releases/latest" -o "$latest_json_file"; then
  echo "ERROR: Failed to fetch latest elfldr release metadata."
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

    if re.match(r"^elfldr.*\.elf$", name, re.IGNORECASE) and url:
        print(url)
        break
PY
)"

rm -f "$latest_json_file"

if [ -z "$asset_url" ]; then
  echo "ERROR: Could not find elfldr .elf asset in latest release."
  exit 1
fi

echo "Current elfldr: ${current_version:-none}"
echo "Latest elfldr:  $latest_version"

if [ "$current_version" != "$latest_version" ] || [ ! -f "$PAYLOAD_DIR/elfldr.elf" ]; then
  tmp_file="$(mktemp)"

  if ! curl -fL "$asset_url" -o "$tmp_file"; then
    echo "ERROR: Failed to download elfldr payload."
    rm -f "$tmp_file"
    exit 1
  fi

  mv "$tmp_file" "$PAYLOAD_DIR/elfldr.elf"
  echo "$latest_version" > "$PAYLOAD_DIR/elfldr.version"

  echo "elfldr updated to $latest_version."
else
  echo "elfldr already current."
fi
