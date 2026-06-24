param([string]$FocusScript = "")
# Idempotent setup: install BurntToast if missing; copy focus-window.ps1 to a
# stable local path and register the claude-focus: URL protocol to it.
$ErrorActionPreference = "SilentlyContinue"

# 1) BurntToast (reliable Windows toasts).
if (-not (Get-Module -ListAvailable -Name BurntToast)) {
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
      Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null
    }
    Install-Module BurntToast -Scope CurrentUser -Force -AllowClobber
  } catch {}
}

# 2) Stable local copy of the focus helper, so click-to-focus does not depend on
#    the WSL filesystem being mounted when the toast is later clicked.
$localDir   = Join-Path $env:LOCALAPPDATA "claude-notify"
$localFocus = Join-Path $localDir "focus-window.ps1"
try {
  New-Item -ItemType Directory -Force -Path $localDir | Out-Null
  if ($FocusScript -and (Test-Path $FocusScript)) {
    Copy-Item -LiteralPath $FocusScript -Destination $localFocus -Force
  }
} catch {}

# 3) Register the claude-focus: protocol -> local focus helper.
if (Test-Path $localFocus) {
  try {
    $base  = "HKCU:\Software\Classes\claude-focus"
    $psExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
    $cmd   = '"' + $psExe + '" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $localFocus + '" "%1"'
    New-Item -Path $base -Force | Out-Null
    Set-ItemProperty -Path $base -Name "(default)" -Value "URL:Claude Focus Protocol"
    Set-ItemProperty -Path $base -Name "URL Protocol" -Value ""
    New-Item -Path "$base\shell\open\command" -Force | Out-Null
    Set-ItemProperty -Path "$base\shell\open\command" -Name "(default)" -Value $cmd
  } catch {}
}
exit 0
