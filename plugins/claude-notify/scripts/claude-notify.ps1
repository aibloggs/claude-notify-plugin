param(
  [string]$Event   = "done",   # "done" (Stop) | "needs" (Notification)
  [string]$Source  = "",       # windows / wsl - shown in attribution line
  [string]$Message = ""        # optional explicit override; else from stdin / defaults
)

# ----------------------------------------------------------------------------
# Claude Code pipes the hook payload as JSON on stdin. For Notification events
# it carries the actual text (permission request / question / idle nudge), so
# surface that instead of a generic line. Only read when stdin is redirected,
# otherwise an interactive run would block on ReadToEnd.
# ----------------------------------------------------------------------------
$payloadMsg = ""
try {
  if ([Console]::IsInputRedirected) {
    $raw = [Console]::In.ReadToEnd()
    if ($raw -and $raw.Trim()) {
      $j = $raw.Trim() | ConvertFrom-Json -ErrorAction Stop
      foreach ($k in 'message','body','title') {
        if ($j.PSObject.Properties.Name -contains $k -and $j.$k) { $payloadMsg = [string]$j.$k; break }
      }
    }
  }
} catch {}

if (-not $Message) { $Message = $payloadMsg }
if ($Event -eq "needs") {
  $Title = "Claude has a question / needs you"
  if (-not $Message) { $Message = "Waiting for your input" }
} else {
  $Title = "Claude is done"
  if (-not $Message) { $Message = "Finished - waiting for you" }
}

# ----------------------------------------------------------------------------
# Find the window to focus when the toast is clicked.
#   1. Walk this process's ancestor chain; first ancestor that owns a top-level
#      window wins (native-Windows terminal + VS Code sessions).
#   2. Fallback (e.g. launched from WSL): most-recently-started terminal/editor.
# ----------------------------------------------------------------------------
function Get-TargetHwnd {
  try {
    $byPid = @{}
    foreach ($p in Get-CimInstance Win32_Process) { $byPid[[int]$p.ProcessId] = $p }
    $cur = $PID
    $guard = 0
    while ($cur -and $guard -lt 40) {
      $guard++
      $proc = $byPid[[int]$cur]
      if (-not $proc) { break }
      try {
        $h = (Get-Process -Id $cur -ErrorAction Stop).MainWindowHandle
        if ($h -ne 0 -and $cur -ne $PID) { return [int64]$h }
      } catch {}
      $cur = [int]$proc.ParentProcessId
    }
  } catch {}
  try {
    $names = 'WindowsTerminal','Code','Code - Insiders','wezterm-gui','alacritty','mintty','Hyper','conemu','ConEmu64','pwsh'
    $cand = Get-Process -ErrorAction SilentlyContinue |
      Where-Object { $names -contains $_.ProcessName -and $_.MainWindowHandle -ne 0 } |
      Sort-Object StartTime -Descending | Select-Object -First 1
    if ($cand) { return [int64]$cand.MainWindowHandle }
  } catch {}
  return 0
}

$attr = @($Source, (Split-Path -Leaf (Get-Location).Path)) | Where-Object { $_ }
$attrLine = ($attr -join "  -  ")

$hwnd = Get-TargetHwnd

try {
  Import-Module BurntToast -ErrorAction Stop
  $text = @($Title, $Message)
  if ($attrLine) { $text += $attrLine }
  $audio = New-BTAudio -Source 'ms-winsoundevent:Notification.Default'

  if ($hwnd -ne 0) {
    $launch  = "claude-focus:$hwnd"
    $btn     = New-BTButton -Content 'Go to session' -Arguments $launch -ActivationType Protocol
    $action  = New-BTAction -Buttons $btn
    $content = New-BTContent -Text $text -Actions $action -Audio $audio -Launch $launch -ActivationType Protocol
  } else {
    $content = New-BTContent -Text $text -Audio $audio
  }
  Submit-BTNotification -Content $content -ErrorAction Stop
}
catch {
  try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $ni = New-Object System.Windows.Forms.NotifyIcon
    $ni.Icon = [System.Drawing.SystemIcons]::Information
    $ni.Visible = $true
    $body = if ($attrLine) { "$Message`n$attrLine" } else { $Message }
    $ni.ShowBalloonTip(6000, $Title, $body, [System.Windows.Forms.ToolTipIcon]::Info)
    Start-Sleep -Milliseconds 1500
    $ni.Dispose()
  } catch {}
  try { [System.Media.SystemSounds]::Asterisk.Play(); Start-Sleep -Milliseconds 600 } catch {}
}
