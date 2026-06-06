#!/bin/sh
set -eu

APP_DIR="${APP_DIR:-/app}"
PAYLOAD_DIR="${PAYLOAD_DIR:-$APP_DIR/document/en/ps5/payloads}"
MAP_FILE="${MAP_FILE:-$APP_DIR/document/en/ps5/payload_map.js}"

patch_browser_appcache_remove_map() {
  BROWSER_APPCACHE_REMOVE_VERSION_FOR_MAP="$1"
  BROWSER_APPCACHE_REMOVE_BINARY_SOURCE_FOR_MAP="$2"
  export MAP_FILE BROWSER_APPCACHE_REMOVE_VERSION_FOR_MAP BROWSER_APPCACHE_REMOVE_BINARY_SOURCE_FOR_MAP

  python - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ["MAP_FILE"])
text = path.read_text()

version = os.environ["BROWSER_APPCACHE_REMOVE_VERSION_FOR_MAP"]
binary_source = os.environ["BROWSER_APPCACHE_REMOVE_BINARY_SOURCE_FOR_MAP"]

new_entry = f'''    {{
        displayTitle: "Browser appCache Remove",
        description: "Removes browser and User Guide appCache for all users",
        fileName: "browser-appcache-remove.elf",
        author: "Storm21CH",
        projectSource: "https://github.com/Storm21CH/PS5_Browser_appCache_remove",
        binarySource: "{binary_source}",
        version: "{version}",
        toPort: 9021
    }}'''

pattern = r'(\{\s*displayTitle:\s*"(?:Browser appCache Remove|PS5 Browser_appCache_remove|Browser_appCache_remove)".*?\})'

def patch(match):
    block = match.group(1)

    block = re.sub(
        r'displayTitle:\s*"[^"]+"',
        'displayTitle: "Browser appCache Remove"',
        block
    )

    block = re.sub(
        r'fileName:\s*"[^"]+"',
        'fileName: "browser-appcache-remove.elf"',
        block
    )

    block = re.sub(
        r'version:\s*"[^"]+"',
        f'version: "{version}"',
        block
    )

    block = re.sub(
        r'projectSource:\s*"[^"]+"',
        'projectSource: "https://github.com/Storm21CH/PS5_Browser_appCache_remove"',
        block
    )

    block = re.sub(
        r'binarySource:\s*"[^"]+"',
        f'binarySource: "{binary_source}"',
        block
    )

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

echo "Normalizing browser-appcache-remove payload..."

mkdir -p "$PAYLOAD_DIR"

rm -f "$PAYLOAD_DIR"/Browser_appCache_remove*.elf
rm -f "$PAYLOAD_DIR"/PS5_Browser_appCache_remove*.elf
rm -f "$PAYLOAD_DIR"/browser-appcache-remove-*.elf
rm -f "$PAYLOAD_DIR"/browser_appcache_remove*.elf

current_version="$(cat "$PAYLOAD_DIR/browser-appcache-remove.version" 2>/dev/null || true)"

if [ "${AUTO_UPDATE_PAYLOADS:-false}" != "true" ] &&
   [ "${AUTO_UPDATE_PAYLOADS:-false}" != "1" ] &&
   [ "${AUTO_UPDATE_PAYLOADS:-false}" != "yes" ] &&
   [ "${AUTO_UPDATE_PAYLOADS:-false}" != "on" ]; then
  echo "browser-appcache-remove auto-update disabled."

  if [ -n "$current_version" ]; then
    patch_browser_appcache_remove_map "$current_version" "https://github.com/Storm21CH/PS5_Browser_appCache_remove/releases/tag/$current_version"
  else
    patch_browser_appcache_remove_map "latest" "https://github.com/Storm21CH/PS5_Browser_appCache_remove/releases/latest"
  fi

  exit 0
fi

echo "browser-appcache-remove auto-update enabled."

latest_json_file="$(mktemp)"

if ! curl -fsSL "https://api.github.com/repos/Storm21CH/PS5_Browser_appCache_remove/releases/latest" -o "$latest_json_file"; then
  echo "ERROR: Failed to fetch latest browser-appcache-remove release metadata."
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

    if re.search(r"(Browser_appCache_remove|PS5_Browser_appCache_remove|appCache).*\.elf$", name, re.IGNORECASE) and url:
        print(url)
        break
PY
)"

rm -f "$latest_json_file"

if [ -z "$asset_url" ]; then
  echo "ERROR: Could not find browser-appcache-remove .elf asset in latest release."
  exit 1
fi

echo "Current browser-appcache-remove: ${current_version:-none}"
echo "Latest browser-appcache-remove:  $latest_version"

if [ "$current_version" != "$latest_version" ] || [ ! -f "$PAYLOAD_DIR/browser-appcache-remove.elf" ]; then
  tmp_file="$(mktemp)"

  if ! curl -fL "$asset_url" -o "$tmp_file"; then
    echo "ERROR: Failed to download browser-appcache-remove payload."
    rm -f "$tmp_file"
    exit 1
  fi

  mv "$tmp_file" "$PAYLOAD_DIR/browser-appcache-remove.elf"
  echo "$latest_version" > "$PAYLOAD_DIR/browser-appcache-remove.version"

  echo "browser-appcache-remove updated to $latest_version."
else
  echo "browser-appcache-remove already current."
fi

patch_browser_appcache_remove_map "$latest_version (latest)" "https://github.com/Storm21CH/PS5_Browser_appCache_remove/releases/tag/$latest_version"
