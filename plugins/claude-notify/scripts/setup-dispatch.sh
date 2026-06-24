#!/usr/bin/env bash
# One-time, idempotent machine setup. Runs on SessionStart but no-ops after the
# first successful run (sentinel file). Installs BurntToast and registers the
# claude-focus: click-to-focus protocol on the Windows host.
set -u
SENTINEL="$HOME/.claude/.claude-notify-setup-done"
[ -f "$SENTINEL" ] && exit 0

SELF="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SELF")" 2>/dev/null && pwd)"

if grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; then
  WIN_SETUP="$(wslpath -w "$SCRIPT_DIR/setup.ps1" 2>/dev/null || echo "$SCRIPT_DIR/setup.ps1")"
  WIN_FOCUS="$(wslpath -w "$SCRIPT_DIR/focus-window.ps1" 2>/dev/null || echo "$SCRIPT_DIR/focus-window.ps1")"
else
  WIN_SETUP="$(cygpath -w "$SCRIPT_DIR/setup.ps1" 2>/dev/null || echo "$SCRIPT_DIR/setup.ps1")"
  WIN_FOCUS="$(cygpath -w "$SCRIPT_DIR/focus-window.ps1" 2>/dev/null || echo "$SCRIPT_DIR/focus-window.ps1")"
fi

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_SETUP" -FocusScript "$WIN_FOCUS" 2>/dev/null
if [ $? -eq 0 ]; then
  mkdir -p "$HOME/.claude"
  : > "$SENTINEL"
fi
exit 0
