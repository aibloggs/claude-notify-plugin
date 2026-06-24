param([string]$Arg)

# Invoked by the "claude-focus:" URL protocol when a Claude toast is clicked.
# $Arg looks like "claude-focus:123456" (a decimal HWND). Bring that window to front.

$raw = $Arg -replace '^claude-focus:', ''
$raw = $raw.Trim().TrimEnd('/')
$hwndVal = 0
if (-not [Int64]::TryParse($raw, [ref]$hwndVal) -or $hwndVal -eq 0) { exit 0 }

$sig = @"
using System;
using System.Runtime.InteropServices;
public static class WinFocus {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, IntPtr pid);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
}
"@
Add-Type -TypeDefinition $sig -ErrorAction SilentlyContinue

$h = [IntPtr]$hwndVal
if (-not [WinFocus]::IsWindow($h)) { exit 0 }

# Restore if minimized (9 = SW_RESTORE).
if ([WinFocus]::IsIconic($h)) { [WinFocus]::ShowWindow($h, 9) | Out-Null }

# Foreground-stealing requires attaching to the current foreground thread first.
$fg = [WinFocus]::GetForegroundWindow()
$curThread = [WinFocus]::GetCurrentThreadId()
$fgThread  = [WinFocus]::GetWindowThreadProcessId($fg, [IntPtr]::Zero)
[WinFocus]::AttachThreadInput($curThread, $fgThread, $true) | Out-Null
[WinFocus]::BringWindowToTop($h) | Out-Null
[WinFocus]::SetForegroundWindow($h) | Out-Null
[WinFocus]::ShowWindow($h, 5) | Out-Null   # 5 = SW_SHOW
[WinFocus]::AttachThreadInput($curThread, $fgThread, $false) | Out-Null
exit 0
