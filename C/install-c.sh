#!/usr/bin/env bash
# double-ssh C-side installer (Ubuntu/Debian).
# Installs openssh-server, Node.js 20 (NodeSource — 24.04's default 18.x is too
# old for Claude Code), Claude Code CLI, creates ~/claude-clips/ for clip2c uploads,
# and appends A's pubkey to authorized_keys.
set -euo pipefail

require_sudo() {
  if ! sudo -n true 2>/dev/null; then
    echo "This installer uses sudo. You may be prompted for your password."
  fi
}

install_base() {
  require_sudo
  sudo apt-get update
  sudo apt-get install -y openssh-server git curl ca-certificates gnupg
  sudo systemctl enable --now ssh || sudo systemctl enable --now sshd
}

install_node20() {
  # Skip if a modern Node is already present.
  if command -v node >/dev/null 2>&1; then
    local major; major="$(node -v | sed 's/^v\([0-9]*\).*/\1/')"
    if [ "$major" -ge 20 ]; then
      echo "Node $(node -v) already installed; skipping NodeSource."
      return
    fi
  fi
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
}

install_claude_code() {
  if command -v claude >/dev/null 2>&1; then
    echo "Claude Code already installed ($(claude --version 2>/dev/null || echo unknown))."
  else
    sudo npm install -g @anthropic-ai/claude-code
  fi
}

prepare_clips_dir() {
  mkdir -p "$HOME/claude-clips"
  chmod 700 "$HOME/claude-clips"
}

append_authorized_key() {
  mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
  local auth="$HOME/.ssh/authorized_keys"
  touch "$auth"; chmod 600 "$auth"

  echo
  echo "Paste A's public key (one line). End with EOF (Ctrl-D):"
  local pub; pub="$(cat)"
  pub="$(printf '%s' "$pub" | tr -d '\r')"
  if [ -z "${pub// /}" ]; then
    echo "No key entered; skipping."
    return
  fi
  if grep -qF "$pub" "$auth" 2>/dev/null; then
    echo "Key already present in $auth"
  else
    printf '%s\n' "$pub" >>"$auth"
    echo "Appended key to $auth"
  fi
}

main() {
  install_base
  install_node20
  install_claude_code
  prepare_clips_dir
  append_authorized_key

  echo
  echo "========================================================================"
  echo "C-side install complete."
  echo "Next: authenticate Claude Code with one of:"
  echo "    claude /login          # interactive browser login"
  echo "    export ANTHROPIC_API_KEY=sk-ant-...    # add to ~/.bashrc for persistence"
  echo "Upload target directory: $HOME/claude-clips"
}

main "$@"
