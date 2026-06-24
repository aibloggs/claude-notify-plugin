# claude-notify

A Claude Code plugin that pops a **desktop toast + sound** when Claude finishes a turn or needs your input, and lets you **click the toast to jump straight back to the session window**. Works from a native Windows terminal, the VS Code/IDE extension, and **WSL2** (the toast appears on the Windows desktop either way).

## What you get

| Event | When it fires | Toast |
|------|----------------|-------|
| `Stop` | Claude finished its turn and is waiting for you | "Claude is done" |
| `Notification` | Claude needs input: a question, a permission prompt, or an idle nudge | "Claude has a question / needs you" + Claude's actual message |

- **Click to focus.** Clicking the toast (or its "Go to session" button) brings the originating terminal/VS Code window to the front and restores it if minimized.
- **Sound included.** Uses the standard Windows notification sound.
- **Non-blocking.** All hooks run async, so they never delay Claude.

## Requirements

- Windows 10/11.
- Claude Code with **Git Bash** available (its hooks run in bash; this is the default on Windows installs).
- Optional: **WSL2** if you run Claude inside Linux. The toast still shows on Windows.
- Internet on first run (to install the BurntToast module).

## Install

```text
/plugin marketplace add aibloggs/claude-notify-plugin
/plugin install claude-notify@claude-notify
```

(Replace `aibloggs/claude-notify-plugin` with wherever you host this repo.)

On the **first session start** after install, a one-time setup runs automatically (idempotent, guarded by a sentinel at `~/.claude/.claude-notify-setup-done`):
1. Installs the `BurntToast` PowerShell module for your user (if missing).
2. Copies the focus helper to `%LOCALAPPDATA%\claude-notify\` and registers the `claude-focus:` URL protocol used by the click-to-focus.

If notifications don't appear immediately after install, open `/hooks` once (reloads config) or restart Claude. WSL sessions install the plugin into the Linux `~/.claude/plugins/` and pick it up the same way.

## Behavior notes

- `Stop` fires on every turn end (each time Claude hands control back). That is intentional: every turn end is a "your turn now" moment. If it's too frequent, disable just the `Stop` hook via `/hooks`.
- Click-to-focus targets the **window**, not a specific **tab**. Windows offers no way for an outside click to select a particular terminal tab, so with multiple sessions tabbed in one window it focuses the window. One session per window = exact targeting.
- From WSL, the originating window is detected best-effort (most-recently-active terminal/editor), since a WSL process has no Windows-side parent chain to walk.

## How it works

```
Claude Code hook (Stop / Notification)
  -> bash scripts/notify-dispatch.sh done|needs        (forwards the hook's stdin JSON)
       -> powershell.exe claude-notify.ps1             (runs on the Windows host)
            -> BurntToast toast + sound, clickable
                 -> click -> claude-focus:<hwnd>  -> focus-window.ps1 -> SetForegroundWindow
```

`SessionStart -> scripts/setup-dispatch.sh -> scripts/setup.ps1` performs the one-time setup.

## Uninstall

```text
/plugin uninstall claude-notify@claude-notify
```

To fully clean up the one-time setup: delete `~/.claude/.claude-notify-setup-done`, remove the registry key `HKCU\Software\Classes\claude-focus`, and delete `%LOCALAPPDATA%\claude-notify\`. (BurntToast can be left installed or removed with `Uninstall-Module BurntToast`.)

## License

MIT
