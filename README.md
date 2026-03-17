# OpenClaw Node Widget

A lightweight Windows system tray widget for monitoring and controlling [OpenClaw](https://github.com/openclaw/openclaw) Node.

Built with AutoHotkey v2. Zero dependencies beyond AHK.

![Status: Beta](https://img.shields.io/badge/status-beta-yellow)

## Features

- **System tray icon** showing Node status (Online/Offline)
- **Right-click menu**: Refresh, Restart Node, Stop Node, Auto-restart toggle, Auto-start toggle, Exit
- **Auto-restart**: Automatically restarts Node if it goes offline (configurable threshold)
- **Auto-start on login**: Registers in Windows startup via Registry
- **Silent Node launch**: Starts Node without visible CMD window (via VBScript wrapper)
- **Lightweight**: Single AHK script + helper scripts, no installer needed

## Requirements

- Windows 10/11
- [AutoHotkey v2](https://www.autohotkey.com/) (install via `winget install AutoHotkey.AutoHotkey`)
- [OpenClaw](https://github.com/openclaw/openclaw) Node installed and configured

## Installation

1. Clone this repo:
   ```
   git clone https://github.com/beckyeh8888/openclaw-node-widget.git
   ```

2. Edit `openclaw-node-widget.ahk` and update `BASE_DIR` to your OpenClaw directory:
   ```ahk
   BASE_DIR := "C:\Users\YourUser\.openclaw"
   ```

3. Copy helper scripts to your OpenClaw directory:
   ```
   copy scripts\* C:\Users\YourUser\.openclaw\
   ```

4. Double-click `openclaw-node-widget.ahk` to start.

## File Structure

```
openclaw-node-widget.ahk   # Main widget (AHK v2)
scripts/
  check-node.ps1           # PowerShell: check if Node is running
  stop-node.ps1            # PowerShell: stop Node process
  restart-node.cmd         # CMD: stop + restart Node silently
  stop-node.cmd            # CMD: stop Node wrapper
  node-hidden.vbs          # VBScript: launch Node without CMD window
  check-node.cmd           # CMD: check Node status
  check-node.vbs           # VBScript: check Node status
assets/                    # Icon files (optional)
SPEC.md                    # Technical specification
```

## How It Works

The widget uses `ProcessExist("node.exe")` to detect whether OpenClaw Node is running. When offline for 3+ consecutive checks (45 seconds), it auto-restarts Node using the VBScript silent launcher.

Key design decisions:
- **No COM/WMI for detection** - `ProcessExist` is instant and reliable
- **No Sleep calls** - all delays use `SetTimer` with negative values (one-shot timers) to avoid blocking the main thread
- **`Persistent` directive** - required for AHK v2 scripts with no hotkeys
- **Stop cooldown** - 2-minute cooldown after manual Stop to prevent auto-restart from fighting you

## License

MIT
