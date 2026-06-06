#!/bin/sh
set -eu

APP_DIR="${APP_DIR:-/app}"
PAYLOAD_DIR="${PAYLOAD_DIR:-$APP_DIR/document/en/ps5/payloads}"
MAP_FILE="${MAP_FILE:-$APP_DIR/document/en/ps5/payload_map.js}"

patch_ps5debug_map() {
  export MAP_FILE

  python - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ["MAP_FILE"])
text = path.read_text()

pattern = r'(\{\s*displayTitle:\s*"ps5debug".*?\})'

def patch(match):
    block = match.group(1)

    block = re.sub(
        r'fileName:\s*"[^"]+"',
        'fileName: "ps5debug.elf"',
        block
    )

    block = re.sub(
        r'version:\s*"[^"]+"',
        'version: "latest"',
        block
    )

    block = re.sub(
        r'projectSource:\s*"[^"]+"',
        'projectSource: "https://github.com/devcrono/ps5debug"',
        block
    )

    block = re.sub(
        r'binarySource:\s*"[^"]+"',
        'binarySource: "https://github.com/devcrono/ps5debug"',
        block
    )

    return block

new_text, count = re.subn(pattern, patch, text, count=1, flags=re.DOTALL)

if count != 1:
    raise SystemExit("ERROR: Could not find ps5debug entry in payload_map.js")

path.write_text(new_text)
PY
}

echo "Normalizing ps5debug payload..."

mkdir -p "$PAYLOAD_DIR"

rm -f "$PAYLOAD_DIR/ps5debug_dizz.elf"

if [ -f "$PAYLOAD_DIR/ps5debug_v1.0b5.elf" ]; then
  mv "$PAYLOAD_DIR/ps5debug_v1.0b5.elf" "$PAYLOAD_DIR/ps5debug.elf"
elif [ -f "$PAYLOAD_DIR/ps5debug.elf" ]; then
  echo "ps5debug.elf already normalized."
else
  echo "ERROR: Could not find ps5debug_v1.0b5.elf or ps5debug.elf."
  exit 1
fi

echo "latest" > "$PAYLOAD_DIR/ps5debug.version"

patch_ps5debug_map

echo "ps5debug normalized to ps5debug.elf."
