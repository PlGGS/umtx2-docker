#!/bin/sh
set -eu

APP_DIR="${APP_DIR:-/app}"
PAYLOAD_DIR="${PAYLOAD_DIR:-$APP_DIR/document/en/ps5/payloads}"
MAP_FILE="${MAP_FILE:-$APP_DIR/document/en/ps5/payload_map.js}"

patch_websrv_map() {
  WEBSRV_VERSION_FOR_MAP="$1"
  WEBSRV_BINARY_SOURCE_FOR_MAP="$2"
  export MAP_FILE WEBSRV_VERSION_FOR_MAP WEBSRV_BINARY_SOURCE_FOR_MAP

  python - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ["MAP_FILE"])
text = path.read_text()

pattern = r'(\{\s*displayTitle:\s*"websrv".*?\})'

def patch(match):
    block = match.group(1)

    block = re.sub(
        r'fileName:\s*"[^"]+"',
        'fileName: "websrv.elf"',
        block
    )

    block = re.sub(
        r'version:\s*"[^"]+"',
        f'version: "{os.environ["WEBSRV_VERSION_FOR_MAP"]}"',
        block
    )

    block = re.sub(
        r'projectSource:\s*"[^"]+"',
        'projectSource: "https://github.com/ps5-payload-dev/websrv"',
        block
    )

    block = re.sub(
        r'binarySource:\s*"[^"]+"',
        f'binarySource: "{os.environ["WEBSRV_BINARY_SOURCE_FOR_MAP"]}"',
        block
    )

    return block

new_text, count = re.subn(pattern, patch, text, count=1, flags=re.DOTALL)

if count != 1:
    raise SystemExit("ERROR: Could not find websrv entry in payload_map.js")

path.write_text(new_text)
PY
}

echo "Normalizing websrv payload..."

mkdir -p "$PAYLOAD_DIR"

rm -f "$PAYLOAD_DIR"/websrv-*.elf
rm -f "$PAYLOAD_DIR"/websrv_*.elf
rm -f "$PAYLOAD_DIR"/websrv*.elf

current_version="$(cat "$PAYLOAD_DIR/websrv.version" 2>/dev/null || true)"

if [ "${AUTO_UPDATE_PAYLOADS:-false}" != "true" ] &&
   [ "${AUTO_UPDATE_PAYLOADS:-false}" != "1" ] &&
   [ "${AUTO_UPDATE_PAYLOADS:-false}" != "yes" ] &&
   [ "${AUTO_UPDATE_PAYLOADS:-false}" != "on" ]; then
  echo "websrv auto-update disabled."

  if [ -n "$current_version" ]; then
    patch_websrv_map "$current_version" "https://github.com/ps5-payload-dev/websrv/releases/tag/$current_version"
  else
    patch_websrv_map "latest" "https://github.com/ps5-payload-dev/websrv/releases/latest"
  fi

  exit 0
fi

echo "websrv auto-update enabled."

latest_json_file="$(mktemp)"

if ! curl -fsSL "https://api.github.com/repos/ps5-payload-dev/websrv/releases/latest" -o "$latest_json_file"; then
  echo "ERROR: Failed to fetch latest websrv release metadata."
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

    if re.match(r"^websrv.*\.elf$", name, re.IGNORECASE) and url:
        print(url)
        break
PY
)"

rm -f "$latest_json_file"

if [ -z "$asset_url" ]; then
  echo "ERROR: Could not find websrv .elf asset in latest release."
  exit 1
fi

echo "Current websrv: ${current_version:-none}"
echo "Latest websrv:  $latest_version"

if [ "$current_version" != "$latest_version" ] || [ ! -f "$PAYLOAD_DIR/websrv.elf" ]; then
  tmp_file="$(mktemp)"

  if ! curl -fL "$asset_url" -o "$tmp_file"; then
    echo "ERROR: Failed to download websrv payload."
    rm -f "$tmp_file"
    exit 1
  fi

  mv "$tmp_file" "$PAYLOAD_DIR/websrv.elf"
  echo "$latest_version" > "$PAYLOAD_DIR/websrv.version"

  echo "websrv updated to $latest_version."
else
  echo "websrv already current."
fi

patch_websrv_map "$latest_version (latest)" "https://github.com/ps5-payload-dev/websrv/releases/tag/$latest_version"
