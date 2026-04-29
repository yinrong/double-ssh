# clip2c.ps1 — Windows 11 twin of clip2c.sh.
# Reads a bitmap off the clipboard, saves PNG, scp's to <target>:~/claude-clips/,
# prints the remote path. Exits 1 silently if no image is available so WezTerm
# can fall back to a normal text paste.
[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [string]$Target = 'C'
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$img = [System.Windows.Forms.Clipboard]::GetImage()
if ($null -eq $img) { exit 1 }

$ts     = Get-Date -Format 'yyyyMMdd-HHmmss'
$name   = "wtc-$ts.png"
$tmp    = Join-Path $env:TEMP $name
$img.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)

$remoteDir  = '~/claude-clips'
$remotePath = "$remoteDir/$name"

# Defensive mkdir; BatchMode avoids an interactive prompt stalling WezTerm.
& ssh -o BatchMode=yes $Target "mkdir -p $remoteDir" 2>$null | Out-Null

& scp -q $tmp "${Target}:$remotePath"
Remove-Item $tmp -ErrorAction SilentlyContinue

Write-Output $remotePath
