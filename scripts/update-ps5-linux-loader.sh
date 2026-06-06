#!/bin/sh
set -eu

APP_DIR="${APP_DIR:-/app}"
PAYLOAD_DIR="${PAYLOAD_DIR:-$APP_DIR/document/en/ps5/payloads}"
MAP_FILE="${MAP_FILE:-$APP_DIR/document/en/ps5/payload_map.js}"

patch_ps5_linux_loader_map() {
  PS5_LINUX_LOADER_VERSION_FOR_MAP="$1"
  PS5_LINUX_LOADER_BINARY_SOURCE_FOR_MAP="$2"
  export MAP_FILE PS5_LINUX_LOADER_VERSION_FOR_MAP PS5_LINUX_LOADER_BINARY_SOURCE_FOR_MAP

  python - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ["MAP_FILE"])
text = path.read_text()

version = os.environ["PS5_LINUX_LOADER_VERSION_FOR_MAP"]
binary_source = os.environ["PS5_LINUX_LOADER_BINARY_SOURCE_FOR_MAP"]

new_entry = f'''    {{
        displayTitle: "PS5 Linux Loader",
        description: "Linux loader for PS5",
        fileName: "ps5-linux-loader.elf",
        author: "ps5-linux",
        projectSource: "https://github.com/ps5-linux/ps5-linux-loader",
        binarySource: "{binary_source}",
        version: "{version}",
        toPort: 9021
    }}'''

pattern = r'(\{\s*displayTitle:\s*"PS5 Linux Loader".*?\})'

def patch(match):
    block = match.group(1)

    block = re.sub(r'fileName:\s*"[^"]+"', 'fileName: "ps5-linux-loader.elf"', block)
    block = re.sub(r'version:\s*"[^"]+"', f'version: "{version}"', block)
    block = re.sub(r'projectSource:\s*"[^"]+"', 'projectSource: "https://github.com/ps5-linux/ps5-linux-loader"', block)
    block = re.sub(r'binarySource:\s*"[^"]+"', f'binarySource: "{binary_source}"', block)

    return block

new_text, count = re.subn(pattern, patch, text, count=1, flags=re.DOTALL)

if count == 0:
    new_text = re.sub(
        r'(\]\s*;?\s*)$',
        ',\n' + new_entry + '\n\\1',
        text,
        count=1
    )

    if new_text == text:
        raise SystemExit("ERROR: Could not find end of payload_map.js array")

path.write_text(new_text)
PY
}

echo "Normalizing ps5-linux-loader payload..."

mkdir -p "$PAYLOAD_DIR"

rm -f "$PAYLOAD_DIR"/ps5-linux-loader-*.elf
rm -f "$PAYLOAD_DIR"/ps5-linux-loader_*.elf
rm -f "$PAYLOAD_DIR"/ps5-linux-loader*.elf

current_version="$(cat "$PAYLOAD_DIR/ps5-linux-loader.version" 2>/dev/null || true)"

if [ "${AUTO_UPDATE_PAYLOADS:-false}" != "true" ] &&
   [ "${AUTO_UPDATE_PAYLOADS:-false}" != "1" ] &&
   [ "${AUTO_UPDATE_PAYLOADS:-false}" != "yes" ] &&
   [ "${AUTO_UPDATE_PAYLOADS:-false}" != "on" ]; then
  echo "ps5-linux-loader auto-update disabled."

  if [ -n "$current_version" ]; then
    patch_ps5_linux_loader_map "$current_version" "https://github.com/ps5-linux/ps5-linux-loader/releases/tag/$current_version"
  else
    patch_ps5_linux_loader_map "latest" "https://github.com/ps5-linux/ps5-linux-loader/releases/latest"
  fi

  exit 0
fi

echo "ps5-linux-loader auto-update enabled."

latest_json_file="$(mktemp)"

if ! curl -fsSL "https://api.github.com/repos/ps5-linux/ps5-linux-loader/releases/latest" -o "$latest_json_file"; then
  echo "ERROR: Failed to fetch latest ps5-linux-loader release metadata."
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

    if re.match(r"^ps5-linux-loader.*\.elf$", name, re.IGNORECASE) and url:
        print(url)
        break
PY
)"

rm -f "$latest_json_file"

if [ -z "$asset_url" ]; then
  echo "ERROR: Could not find ps5-linux-loader .elf asset in latest release."
  exit 1
fi

echo "Current ps5-linux-loader: ${current_version:-none}"
echo "Latest ps5-linux-loader:  $latest_version"

if [ "$current_version" != "$latest_version" ] || [ ! -f "$PAYLOAD_DIR/ps5-linux-loader.elf" ]; then
  tmp_file="$(mktemp)"

  if ! curl -fL "$asset_url" -o "$tmp_file"; then
    echo "ERROR: Failed to download ps5-linux-loader payload."
    rm -f "$tmp_file"
    exit 1
  fi

  mv "$tmp_file" "$PAYLOAD_DIR/ps5-linux-loader.elf"
  echo "$latest_version" > "$PAYLOAD_DIR/ps5-linux-loader.version"

  echo "ps5-linux-loader updated to $latest_version."
else
  echo "ps5-linux-loader already current."
fi

patch_ps5_linux_loader_map "$latest_version (latest)" "https://github.com/ps5-linux/ps5-linux-loader/releases/tag/$latest_version"
