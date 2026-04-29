# double-ssh A-side installer for Windows 11.
# Installs VSCode + Remote-SSH + Claude Code extension, WezTerm, OpenSSH client,
# generates an ed25519 key, writes %USERPROFILE%\.ssh\config, drops wezterm.lua
# and clip2c.ps1 into place. Prints the pubkey at the end.
#
# Usage (from an elevated PowerShell):
#   Set-ExecutionPolicy -Scope Process Bypass -Force
#   .\install-windows.ps1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot  = Split-Path -Parent $scriptDir
$sshDir    = Join-Path $env:USERPROFILE '.ssh'
$keyPath   = Join-Path $sshDir 'id_ed25519_double-ssh'

function Ensure-Winget {
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'winget is required but not found. Install "App Installer" from the Microsoft Store, then re-run.'
  }
}

function Winget-Install($id) {
  Write-Host ">>> winget install $id"
  & winget install --id $id --silent --accept-package-agreements --accept-source-agreements --scope user
  if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {
    Write-Warning "winget install $id returned exit code $LASTEXITCODE (continuing)."
  }
}

function Ensure-OpenSSH {
  if (Get-Command ssh -ErrorAction SilentlyContinue) { return }
  $cap = Get-WindowsCapability -Online -Name 'OpenSSH.Client*' -ErrorAction SilentlyContinue
  if ($cap -and $cap.State -ne 'Installed') {
    Add-WindowsCapability -Online -Name $cap.Name | Out-Null
  }
}

function Generate-Key {
  if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir | Out-Null }
  if (-not (Test-Path $keyPath)) {
    & ssh-keygen -t ed25519 -f $keyPath -N '""' -C "double-ssh@$env:COMPUTERNAME"
  } else {
    Write-Host "Reusing existing key: $keyPath"
  }
  # Start ssh-agent service and add the key so scp in clip2c doesn't re-prompt.
  Set-Service ssh-agent -StartupType Automatic -ErrorAction SilentlyContinue
  Start-Service ssh-agent -ErrorAction SilentlyContinue
  & ssh-add $keyPath 2>$null | Out-Null
}

function Prompt-With-Default($msg, $default) {
  $raw = Read-Host "$msg [$default]"
  if ([string]::IsNullOrWhiteSpace($raw)) { return $default } else { return $raw }
}

function Write-SshConfig {
  $userB = Prompt-With-Default 'B username' $env:USERNAME
  $hostB = Read-Host 'B host (address)'
  $userC = Prompt-With-Default 'C username' $env:USERNAME
  $hostC = Read-Host 'C host (address)'

  $configPath = Join-Path $sshDir 'config'
  if (-not (Test-Path $configPath)) { New-Item -ItemType File -Path $configPath | Out-Null }

  # Idempotent: strip any prior double-ssh block.
  $raw = Get-Content $configPath -Raw -ErrorAction SilentlyContinue
  if ($null -eq $raw) { $raw = '' }
  $raw = [regex]::Replace($raw, '(?ms)# BEGIN double-ssh.*?# END double-ssh\r?\n?', '')

  $template = Get-Content (Join-Path $repoRoot 'ssh\config.template') -Raw
  # Windows OpenSSH accepts forward-slash paths; rewrite for clarity.
  $identity = $keyPath -replace '\\', '/'
  $rendered = $template `
    -replace '__USER_B__', $userB `
    -replace '__HOST_B__', $hostB `
    -replace '__USER_C__', $userC `
    -replace '__HOST_C__', $hostC `
    -replace '__IDENTITY__', $identity

  $block = "# BEGIN double-ssh`r`n$rendered# END double-ssh`r`n"
  Set-Content -Path $configPath -Value ($raw + $block) -Encoding ASCII -NoNewline
}

function Install-Assets {
  $wezDir = Join-Path $env:USERPROFILE '.config\wezterm'
  $binDir = Join-Path $env:USERPROFILE 'bin'
  New-Item -ItemType Directory -Force -Path $wezDir | Out-Null
  New-Item -ItemType Directory -Force -Path $binDir | Out-Null
  Copy-Item (Join-Path $repoRoot 'wezterm\wezterm.lua') (Join-Path $wezDir 'wezterm.lua') -Force
  Copy-Item (Join-Path $repoRoot 'clip2c\clip2c.ps1')   (Join-Path $binDir 'clip2c.ps1')   -Force
}

function Install-VSCodeExtensions {
  if (Get-Command code -ErrorAction SilentlyContinue) {
    & code --install-extension ms-vscode-remote.remote-ssh 2>$null | Out-Null
    & code --install-extension anthropic.claude-code       2>$null | Out-Null
  } else {
    Write-Warning "'code' CLI not yet on PATH. Open VSCode once, then run:
    code --install-extension ms-vscode-remote.remote-ssh
    code --install-extension anthropic.claude-code"
  }
}

# --- main ---
Ensure-Winget
Ensure-OpenSSH
Winget-Install 'Microsoft.VisualStudioCode'
Winget-Install 'wez.wezterm'
Generate-Key
Write-SshConfig
Install-Assets
Install-VSCodeExtensions

Write-Host ''
Write-Host '========================================================================'
Write-Host 'A-side install complete.'
Write-Host ''
Write-Host "Copy this pubkey into B and C's ~/.ssh/authorized_keys:"
Write-Host '------------------------------------------------------------------------'
Get-Content "${keyPath}.pub"
Write-Host '------------------------------------------------------------------------'
Write-Host 'Then run B/setup-sshd.sh on B and C/install-c.sh on C.'
Write-Host 'Test with:  ssh C'
