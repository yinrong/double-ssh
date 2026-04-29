#!/usr/bin/env bash
# clip2c — read an image from the local clipboard, scp it to $1:~/claude-clips/,
# and print the remote path. Exits 1 (with no stdout) if the clipboard has no image,
# so WezTerm can fall back to a normal text paste.
set -euo pipefail

TARGET="${1:-C}"
TS=$(date +%Y%m%d-%H%M%S)
TMP=$(mktemp --suffix=.png)
trap 'rm -f "$TMP"' EXIT

if [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-paste >/dev/null 2>&1; then
  wl-paste --type image/png >"$TMP" 2>/dev/null || true
elif command -v xclip >/dev/null 2>&1; then
  xclip -selection clipboard -t image/png -o >"$TMP" 2>/dev/null || true
fi

[ -s "$TMP" ] || exit 1

REMOTE_DIR='~/claude-clips'
REMOTE_PATH="$REMOTE_DIR/wtc-$TS.png"

# Defensive mkdir in case install-c.sh wasn't run on a fresh account.
ssh -o BatchMode=yes "$TARGET" "mkdir -p $REMOTE_DIR" 2>/dev/null || true

scp -q "$TMP" "$TARGET:$REMOTE_PATH"
echo "$REMOTE_PATH"
