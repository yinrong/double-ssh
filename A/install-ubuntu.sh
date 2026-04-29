#!/usr/bin/env bash
# double-ssh A-side installer for Ubuntu 24.04.
# Installs VSCode + Remote-SSH + Claude Code extension, WezTerm (fury.io),
# wl-clipboard + xclip, generates an ed25519 key, writes ~/.ssh/config,
# drops wezterm.lua and clip2c into place. Prints the pubkey at the end
# for you to paste into B and C's authorized_keys.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY="$HOME/.ssh/id_ed25519_double-ssh"

require_sudo() {
  if ! sudo -n true 2>/dev/null; then
    echo "This installer uses sudo for apt. You may be prompted for your password."
  fi
}

prompt() {
  local varname="$1" promptmsg="$2" default="${3:-}" ans
  if [ -n "$default" ]; then
    read -r -p "$promptmsg [$default]: " ans
    ans="${ans:-$default}"
  else
    read -r -p "$promptmsg: " ans
  fi
  printf -v "$varname" '%s' "$ans"
}

install_base() {
  require_sudo
  sudo apt-get update
  sudo apt-get install -y \
    openssh-client git curl ca-certificates gnupg apt-transport-https \
    wl-clipboard xclip
}

install_vscode() {
  if command -v code >/dev/null 2>&1; then return; fi
  local kr=/usr/share/keyrings/packages.microsoft.gpg
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | sudo gpg --dearmor -o "$kr"
  echo "deb [arch=amd64,arm64,armhf signed-by=$kr] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y code
}

install_wezterm() {
  # Ubuntu 24.04's distro wezterm is too old for wezterm.action_callback.
  if command -v wezterm >/dev/null 2>&1; then
    local ver; ver=$(wezterm --version 2>/dev/null | awk '{print $2}')
    echo "WezTerm already present ($ver). Skipping install."
    return
  fi
  curl -fsSL https://apt.fury.io/wez/gpg.key \
    | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
  echo "deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *" \
    | sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y wezterm
}

install_vscode_extensions() {
  command -v code >/dev/null || return
  code --install-extension ms-vscode-remote.remote-ssh || true
  code --install-extension anthropic.claude-code || true
}

generate_key() {
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  if [ ! -f "$KEY" ]; then
    ssh-keygen -t ed25519 -f "$KEY" -N "" -C "double-ssh@$(hostname)"
  else
    echo "Reusing existing key: $KEY"
  fi
  eval "$(ssh-agent -s)" >/dev/null
  ssh-add "$KEY" 2>/dev/null || true
}

write_ssh_config() {
  local user_b host_b user_c host_c
  prompt user_b "B username" "$USER"
  prompt host_b "B host (address)"
  prompt user_c "C username" "$USER"
  prompt host_c "C host (address)"

  local config="$HOME/.ssh/config"
  touch "$config"; chmod 600 "$config"

  # Remove any previous double-ssh block so re-runs are idempotent.
  if grep -q '# BEGIN double-ssh' "$config"; then
    sed -i '/# BEGIN double-ssh/,/# END double-ssh/d' "$config"
  fi

  {
    echo "# BEGIN double-ssh"
    sed \
      -e "s|__USER_B__|$user_b|g" \
      -e "s|__HOST_B__|$host_b|g" \
      -e "s|__USER_C__|$user_c|g" \
      -e "s|__HOST_C__|$host_c|g" \
      -e "s|__IDENTITY__|$KEY|g" \
      "$HERE/ssh/config.template"
    echo "# END double-ssh"
  } >>"$config"
}

install_assets() {
  mkdir -p "$HOME/.config/wezterm" "$HOME/.local/bin"
  install -m 0644 "$HERE/wezterm/wezterm.lua" "$HOME/.config/wezterm/wezterm.lua"
  install -m 0755 "$HERE/clip2c/clip2c.sh"    "$HOME/.local/bin/clip2c"

  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) echo 'Note: add ~/.local/bin to PATH (e.g. in ~/.bashrc) so clip2c is reachable.' ;;
  esac
}

main() {
  install_base
  install_vscode
  install_wezterm
  install_vscode_extensions
  generate_key
  write_ssh_config
  install_assets

  echo
  echo "========================================================================"
  echo "A-side install complete."
  echo
  echo "Copy the following pubkey into B and C's ~/.ssh/authorized_keys:"
  echo "------------------------------------------------------------------------"
  cat "${KEY}.pub"
  echo "------------------------------------------------------------------------"
  echo "Then run B/setup-sshd.sh on B and C/install-c.sh on C."
  echo "Test with:  ssh C"
}

main "$@"
