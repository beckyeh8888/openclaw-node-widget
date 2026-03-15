name: OpenClaw Node Widget
version: 0.1.0
license: MIT
author: Beck Yeh
repo: github.com/beck8/openclaw-node-widget

## Overview
A lightweight Windows system tray widget for monitoring and controlling OpenClaw Node host service.
Built with AutoHotkey v2. Zero dependencies. Works out of the box.

## Features
- System tray icon showing Node connection status (Online/Offline)
- Right-click menu: Refresh, Restart Node, Stop Node, Toggle auto-start, Exit
- Auto-refresh every 10 seconds
- Auto-start on Windows login (via Registry)
- Configurable via `config.ini`

## Configuration (config.ini)
```ini
[Node]
; Scheduled Task name created by `openclaw node install`
TaskName=OpenClaw Node

[Widget]
; Status check interval in milliseconds
CheckInterval=10000

; Registry key name for auto-start
RegistryKeyName=OpenClawNodeWidget
```

## Technical Spec

### Language
AutoHotkey v2 syntax only.

### Files
- `openclaw-node-widget.ahk` - Main source
- `config.ini` - User configuration
- `assets/online.ico` - Green icon (Node running)
- `assets/offline.ico` - Red/gray icon (Node stopped)
- `README.md` - Documentation
- `LICENSE` - MIT

### System Tray Icon
- Use `assets/online.ico` when Node is Running
- Use `assets/offline.ico` when Node is Stopped/Ready
- Tooltip: "OpenClaw Node: Online" or "OpenClaw Node: Offline"
- If icon files missing, use built-in AHK icon with color change

### Right-Click Menu
1. **Status: Online/Offline** (disabled, info only)
2. ---
3. **Refresh** - Re-check status immediately
4. **Restart Node** - `schtasks /run /tn "<TaskName>"`
5. **Stop Node** - `schtasks /end /tn "<TaskName>"`
6. ---
7. **Auto-start: On/Off** - Toggle `HKCU\Software\Microsoft\Windows\CurrentVersion\Run\<RegistryKeyName>`
8. **Exit** - Quit widget

### Status Check Logic
- Run: `schtasks /query /tn "<TaskName>" /fo csv /nh`
- Parse CSV output:
  - Contains "Running" -> Online
  - Contains "Ready" or empty/error -> Offline
- Timer: check every `CheckInterval` ms
- On schtasks failure: show TrayTip notification

### Auto-Start Registry
- Path: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run`
- Key: value from config `RegistryKeyName`
- Value: full path to `.exe` (or `.ahk` if not compiled)
- Menu text updates dynamically: "Auto-start: On" / "Auto-start: Off"

### Constraints
- No main window, tray-only
- Background execution
- Error handling: TrayTip on schtasks failures
- Must work without admin rights (user-level schtasks)
- All paths configurable, nothing hardcoded
- Clean, well-commented code suitable for open source
