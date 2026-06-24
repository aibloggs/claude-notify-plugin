#!/usr/bin/env bash
# Cross-environment dispatcher: fires the Windows toast notifier from either a
# native-Windows (Git Bash) or a WSL2 Claude Code session.
#   $1 = event: "done" (Stop) | "needs" (Notification)
# The hook's stdin JSON is forwarded to powershell.exe so the toast can show
# Claude's real message.
set -u
EVENT="${1:-done}"
SELF="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SELF")" 2>/dev/null && pwd)"
PS1_SCRIPT="$SCRIPT_DIR/claude-notify.ps1"

if grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; then
  # WSL2: convert the Linux path to a Windows UNC path powershell.exe can read.
  WIN_PS1="$(wslpath -w "$PS1_SCRIPT" 2>/dev/null || echo "$PS1_SCRIPT")"
  SRC="wsl"
else
  # Native Windows (Git Bash): convert the MSYS path to a Windows path.
  WIN_PS1="$(cygpath -w "$PS1_SCRIPT" 2>/dev/null || echo "$PS1_SCRIPT")"
  SRC="windows"
fi

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_PS1" -Event "$EVENT" -Source "$SRC" 2>/dev/null
exit 0
