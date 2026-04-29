#!/usr/bin/env bash
# double-ssh B-side setup (jump host).
# Ensures sshd allows TCP forwarding so ProxyJump works, and appends A's pubkey
# to this user's authorized_keys. Needs sudo to touch /etc/ssh/sshd_config.
set -euo pipefail

SSHD_CFG="/etc/ssh/sshd_config"

if [ "$(id -u)" -ne 0 ]; then
  exec sudo -E bash "$0" "$@"
fi

ensure_line() {
  # ensure_line <key> <value>  — set "key value" in sshd_config, replacing
  # any existing or commented line for that key.
  local key="$1" val="$2"
  if grep -Eq "^[# ]*${key}[[:space:]]+" "$SSHD_CFG"; then
    sed -i -E "s|^[# ]*${key}[[:space:]]+.*|${key} ${val}|" "$SSHD_CFG"
  else
    echo "${key} ${val}" >>"$SSHD_CFG"
  fi
}

ensure_line AllowTcpForwarding yes
ensure_line GatewayPorts       no

# Validate; refuse to reload if sshd_config is broken.
sshd -t

# authorized_keys goes under the invoking user's home, not root's.
INVOKER="${SUDO_USER:-$USER}"
HOME_DIR="$(getent passwd "$INVOKER" | cut -d: -f6)"
if [ -z "$HOME_DIR" ] || [ ! -d "$HOME_DIR" ]; then
  echo "Cannot locate home for user $INVOKER." >&2
  exit 1
fi

AUTH_DIR="$HOME_DIR/.ssh"
AUTH_FILE="$AUTH_DIR/authorized_keys"
install -d -m 0700 -o "$INVOKER" -g "$INVOKER" "$AUTH_DIR"
touch "$AUTH_FILE"
chown "$INVOKER:$INVOKER" "$AUTH_FILE"
chmod 600 "$AUTH_FILE"

echo
echo "Paste A's public key (one line). End with EOF (Ctrl-D):"
PUBKEY="$(cat)"
PUBKEY="$(printf '%s' "$PUBKEY" | tr -d '\r')"

if [ -z "${PUBKEY// /}" ]; then
  echo "No key entered; skipping authorized_keys update."
else
  # Dedup: only append if not already present.
  if grep -qF "$PUBKEY" "$AUTH_FILE" 2>/dev/null; then
    echo "Key already present in $AUTH_FILE"
  else
    printf '%s\n' "$PUBKEY" >>"$AUTH_FILE"
    echo "Appended key to $AUTH_FILE"
  fi
fi

systemctl reload ssh || systemctl reload sshd
echo "B-side sshd reloaded. Done."
