# OpenClaw Node Widget - Technical Specification

## 1. Overview & Motivation

**Type**: cross-platform system tray utility | **Rewrite**: AHK v1.4 → Rust

A lightweight system tray widget that monitors and controls individual OpenClaw Node instances. Unlike the full gateway dashboard, this tool focuses solely on Node process management with minimal resource footprint.

**Motivation**: The existing AHK v1.4 version is Windows-only and lacks the reliability needed for production use. A Rust rewrite provides:
- Cross-platform support (Windows/macOS/Linux)
- Single static binary with no runtime dependencies
- Better process management and error handling
- Modern configuration format (TOML vs INI)
- Proper WebSocket integration for real-time status

**Scope**: Each machine runs its own widget instance to manage its own Node. One widget = one Node.

**Deployment model**: Download binary → double-click → setup wizard asks Gateway URL + token → done.

---

## 2. Network Architecture

### Connection Model

```
┌──────────────┐    WebSocket (WS/WSS)    ┌──────────────┐
│  Widget      │ ◄──────────────────────► │  Gateway     │
│  (per machine)│    + operator token      │  (central)   │
└──────────────┘                          └──────────────┘
       │                                         │
       ▼                                         ▼
┌──────────────┐                          ┌──────────────┐
│  Node Process│                          │  Other Nodes │
│  (local)     │                          │  (remote)    │
└──────────────┘                          └──────────────┘
```

### Scenarios

| Scenario | Gateway URL | Transport | Token |
|----------|------------|-----------|-------|
| Same machine | `ws://localhost:3000` | Plain WS | Optional |
| LAN / Tailscale | `ws://100.x.x.x:3000` | Plain WS | Required |
| Public / Internet | `wss://gateway.example.com` | WSS (TLS) | Required |

### Connection Behavior

- **Startup**: Connect to Gateway WebSocket as operator role
- **Auth**: Send gateway token on handshake (read from config or auto-discovered from `~/.openclaw/openclaw.json`)
- **Heartbeat**: Gateway sends periodic pings; widget responds with pong
- **Reconnect**: On disconnect → exponential backoff (1s, 2s, 4s, 8s… max 60s)
- **Offline fallback**: If Gateway unreachable for 30s+ → fall back to local process detection (`sysinfo` crate, check for `openclaw node run` in command line)

### Status Detection Priority

1. **WebSocket**: Gateway reports Node registered + connected → Online
2. **Process scan**: `node.exe`/`node` process with `openclaw node run` in args → Online (degraded)
3. **Both fail** → Offline

---

## 3. BDD Scenarios

### First Launch

```gherkin
Scenario: First time setup
  Given the user downloads and runs the widget binary
  And no config.toml exists
  When the widget starts
  Then a setup wizard window appears
  And asks for Gateway URL (default: ws://localhost:3000)
  And asks for Gateway token (with "paste here" field)
  And has a "Test Connection" button
  When the user fills in valid values and clicks "Save"
  Then config.toml is created at ~/.config/openclaw-node-widget/config.toml
  And the widget minimizes to system tray
  And begins monitoring
```

### Normal Operation

```gherkin
Scenario: Node is running normally
  Given the widget is connected to Gateway
  And the Node is registered and online
  Then the tray icon shows green (online)
  And the tooltip shows "OpenClaw Node: Online"

Scenario: Node goes offline
  Given the widget detects Node offline
  When 3 consecutive checks fail (45 seconds)
  And auto-restart is enabled
  Then the widget restarts the Node silently
  And shows a notification "Node restarted"
  And the tray icon changes to green after Node comes back

Scenario: User manually stops Node
  Given the user right-clicks → "Stop Node"
  Then the Node process is killed
  And a 120-second cooldown starts
  And auto-restart is suppressed during cooldown
  And the tray icon shows red (offline)
```

### Network Failures

```gherkin
Scenario: Gateway connection lost
  Given the widget was connected to Gateway
  When the WebSocket connection drops
  Then the widget switches to process-scan fallback
  And the tooltip shows "OpenClaw Node: Online (no gateway)"
  And reconnection attempts start with exponential backoff

Scenario: Gateway unreachable on startup
  Given the Gateway URL is configured but not reachable
  When the widget starts
  Then it falls back to process-scan mode immediately
  And shows a notification "Gateway unreachable, using local detection"
  And retries Gateway connection every 60 seconds in background
```

### Settings

```gherkin
Scenario: Change settings via tray menu
  Given the user right-clicks → "Settings"
  Then the setup wizard window reopens with current values
  When the user changes Gateway URL and clicks "Save"
  Then config.toml is updated
  And the widget reconnects to the new Gateway
```

---

## 4. Setup Wizard

A minimal native window (single panel, not multi-tab) shown on:
- First launch (no config found)
- Right-click → "Settings"

### Fields

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| Gateway URL | text input | `ws://localhost:3000` | Validates URL format |
| Gateway Token | password input | (empty) | "Paste from `openclaw status`" hint |
| Auto-restart | checkbox | ✅ on | |
| Auto-start on login | checkbox | ☐ off | |

### Buttons
- **Test Connection** — attempts WebSocket handshake, shows ✅/❌
- **Save** — writes config.toml, closes window, starts monitoring
- **Cancel** — exits app (first launch) or closes window (settings)

### Implementation
- Use `native-dialog` or `rfd` crate for simple cross-platform dialogs
- Or minimal `egui` window (adds ~1MB to binary but gives full control)
- Decision: defer to implementation phase, try `native-dialog` first

---

## 5. CLI Interface

The widget supports both GUI (default) and CLI modes.

### Usage

```bash
# GUI mode (default) — starts tray widget, shows setup wizard if no config
openclaw-node-widget

# CLI flags override config.toml (useful for scripting / one-off)
openclaw-node-widget --gateway ws://100.68.12.51:3000 --token abc123

# Setup wizard from CLI (writes config.toml interactively in terminal)
openclaw-node-widget setup
  Gateway URL [ws://localhost:3000]: ws://100.68.12.51:3000
  Gateway Token: ********
  Testing connection... ✅ Connected (Node: Online)
  Auto-restart? [Y/n]: Y
  Auto-start on login? [y/N]: y
  Config saved to ~/.config/openclaw-node-widget/config.toml

# Headless mode — no tray, just monitor + auto-restart (for servers / SSH)
openclaw-node-widget daemon

# One-shot status check (for scripts / health checks)
openclaw-node-widget status
  Node: Online (PID 12345)
  Gateway: Connected (ws://localhost:3000)
  Uptime: 3d 14h 22m

# Stop / restart node from CLI
openclaw-node-widget stop
openclaw-node-widget restart

# Show current config
openclaw-node-widget config
```

### Startup Logic

```
START
  ├─ Has CLI flags (--gateway/--token)? → Use flags, skip config
  ├─ Has config.toml? → Load config → Start tray widget
  └─ No config?
       ├─ Is TTY (terminal)? → Run interactive `setup` in terminal
       └─ Is GUI (double-click)? → Show setup wizard window
```

---

## 6. Features & Priority

### P0 - Core (Must Have)
- [ ] **Status indicator**: System tray icon showing Node online/offline state
- [ ] **Process monitoring**: Detect Node status via WebSocket connection to gateway
- [ ] **Manual controls**: Start/stop Node via right-click menu
- [ ] **Auto-restart**: Restart Node after N consecutive offline checks
- [ ] **Cross-platform**: Windows/macOS/Linux support with single binary

### P1 - Important (Should Have)
- [ ] **Auto-start**: Register with OS startup (registry/launchd/systemd)
- [ ] **Silent startup**: Spawn Node without visible terminal window
- [ ] **Configurable intervals**: Check interval (default 15s), restart threshold (default 3)
- [ ] **Process detection fallback**: When WebSocket unavailable, check for running Node process

### P2 - Nice to Have
- [ ] **Native notifications**: Desktop notifications on status change
- [ ] **Multi-node monitoring**: Support for multiple Node instances
- [ ] **Custom icons**: User-provided icon sets
- [ ] **Gateway token auto-discovery**: Read from OpenClaw config automatically
- [ ] **Dark mode icon variants**: Themed icons for dark/light modes
- [ ] **Stats overlay**: Right-click menu shows basic stats

## 7. Architecture

```
┌─────────────────────────────┐
│      Main Thread            │
│  ┌───────────────────────┐  │
│  │   Tray Event Loop     │◄─┼─┐            ┌────────────────────┐
│  │   (tray-icon crate)   │  │ │            │    Node Process    │
│  └───────────────────────┘  │ │            │ (openclaw node)  │
│            │                │ │            └────────────────────┘
│            ▼                │ │                    ▲        │
│  ┌───────────────────────┐ │ │                    │        │
│  │   Monitor Task        │ │ │                    │        │
│  │   (tokio runtime)     │ │ │             ┌──────┴────┐   │
│  │   - Gateway WS check  │ │ │             │  Gateway   │   │
│  │   - Process fallback  │ │ └───────────┤ WebSocket │   │
│  │   - Auto-restart      │ │             │  (status)  │   │
│  │   - Config reload     │ │             └────────────┘   │
│  └───────────────────────┘ │                                │
│            │                │                                │
│            ▼                │                                │
│  ┌───────────────────────┐ │                                │
│  │   Config (TOML)       │ │                                │
│  │   - gateway URL       │ │                                │
│  │   - autostart settings│ │                                │
│  │   - check interval    │ │                                │
│  └───────────────────────┘ │                                │
└─────────────────────────────┘                                │
                                                               │
┌─────────────────────────────┐                                │
│   Platform Services         │◄───────────────────────────────┘
│   - Windows Registry        │
│   - macOS Launchd         │
│   - Linux Systemd/XDG      │
└─────────────────────────────┘
```

**Threading Model**:
- **Main thread**: GTK/Cocoa/Win32 event loop (via tray-icon crate)
- **Background task**: Tokio runtime for WebSocket and periodic checks
- **Process spawning**: Platform-specific (CreateProcessW on Windows, fork/exec on *nix)

## 8. Configuration File Specification

**Location**: `~/.openclaw/config.toml` (reads automatically) or `~/.config/openclaw-node-widget/config.toml`

```toml
[gateway]
# WebSocket URL for OpenClaw Gateway
url = "ws://localhost:3000"
# Optional: gateway token (reads ~/.openclaw/config.toml if empty)
token = ""
# Timeout for WebSocket connection
connect_timeout_secs = 5

[node]
# Command to start Node
command = "openclaw node run"
# Optional: working directory (default: ~/.openclaw)
working_dir = ""
# Additional arguments passed to node
args = []
# Environment variables
env = { "DEBUG" = "openclaw:*" }

[widget]
# Check interval in seconds
check_interval_secs = 15
# Auto-restart on failure
auto_restart = true
restart_threshold = 3
restart_cooldown_secs = 120
max_restart_attempts = 5

[startup]
# Register with OS startup
auto_start = false
# Platform-specific paths (auto-detected if empty)
xdg_desktop_path = ""        # Linux: ~/.config/autostart/openclaw-node-widget.desktop
launchd_plist_path = ""     # macOS: ~/Library/LaunchAgents/com.openclaw.node-widget.plist
registry_key = ""           # Windows: HKCU\Software\Microsoft\Windows\CurrentVersion\Run

[appearance]
# Optional: custom icon paths (embedded PNG overrides this)
online_icon = ""
offline_icon = ""
unknown_icon = ""
# Tray tooltip format (status variables: {status}, {pid})
tooltip_format = "OpenClaw Node: {status}"

# Advanced
[log]
level = "info"      # trace, debug, info, warn, error
file = ""          # Optional: log file path
syslog = false     # Use system logger on *nix
```

## 9. Platform-Specific Behavior

| Feature               | Windows              | macOS                | Linux (Gnome/KDE)    | Linux (headless)     |
|---------------------|---------------------|---------------------|---------------------|---------------------|
| **Tray Framework**  | winapi/shell32      | Cocoa NSStatusItem  | libappindicator     | libappindicator      |
| **Process Spawn**   | CreateProcessW      | posix_spawn         | fork + exec         | fork + exec          |
| **Auto-start**      | Registry key        | LaunchAgent plist   | XDG autostart       | systemd user service |
| **No-window flag**  | CREATE_NO_WINDOW    | LSBackgroundOnly      | setsid + nohup      | --                  |
| **Icon format**     | ICO/PNG             | PNG/ICNS            | PNG                 | PNG                  |
| **Path separator**  | \                    | /                   | /                   | /                   |
| **Process kill**    | TerminateProcess    | kill(pid, SIGTERM)  | kill(pid, SIGTERM)  | kill(pid, SIGTERM)   |

## 10. Repository Structure

```
openclaw-node-widget/
├── Cargo.toml                  # Core dependencies + platform targets
├── README.md                   # Quick setup guide
├── CONTRIBUTING.md             # Build/dev instructions
├── LICENSE                     # MIT
├── CHANGELOG.md               # Version history
├── config.example.toml         # Configuration template
├── justfile                    # Build commands (optimized for cross-compile)
├── build.rs                    # Embed icons + platform detection
├── src/
│   ├── main.rs                 # Entry point, argument parsing
│   ├── tray.rs                 # Cross-platform tray icon and menu
│   ├── monitor.rs              # Node status monitoring + auto-restart
│   ├── gateway.rs              # WebSocket client for gateway status
│   ├── process.rs              # Process start/stop/detection (impl per platform)
│   ├── autostart.rs            # OS startup registration
│   ├── config.rs               # TOML config + validation
│   └── error.rs                # Error types
├── assets/
│   ├── icon_online.png         # Green tray icon
│   ├── icon_offline.png        # Red tray icon
│   └── icon_unknown.png        # Gray tray icon
└── scripts/                    # Legacy AHK scripts (reference only)
    └── v1.4/
```

## 11. Build & Release

### Dependencies (Cargo.toml)

| Crate | Purpose |
|-------|---------|
| `tray-icon` | Cross-platform system tray (Tauri team) |
| `tokio` | Async runtime |
| `tokio-tungstenite` | WebSocket client |
| `serde` + `toml` | Config deserialization |
| `sysinfo` | Process detection fallback |
| `clap` | CLI argument parsing |
| `tracing` | Structured logging |
| `dirs` | XDG/platform path resolution |

### Cross-compile

```bash
# Native
cargo build --release

# Cross-compile (requires `cross` or platform SDK)
cross build --release --target x86_64-pc-windows-gnu
cross build --release --target x86_64-unknown-linux-gnu
cross build --release --target aarch64-apple-darwin
```

### GitHub Actions CI

- On push to `main`: build all 3 platforms
- On tag `v*`: build + create GitHub Release with binaries
- Matrix: `windows-latest`, `macos-latest`, `ubuntu-latest`
- Artifact: single binary per platform (~3-5 MB)

## 12. Migration Path from AHK v1.4

| AHK v1.4 | Rust v2.0 |
|-----------|-----------|
| `ProcessExist("node.exe")` | WebSocket status check (primary) + `sysinfo` process scan (fallback) |
| `A_ComSpec /c taskkill` | `TerminateProcess` / `kill(SIGTERM)` |
| `wscript.exe node-hidden.vbs` | `CreateProcessW(CREATE_NO_WINDOW)` / `posix_spawn` |
| Registry `HKCU\...\Run` | Platform-specific autostart module |
| Hardcoded paths | `config.toml` + `dirs` crate |
| `SetTimer` with negative ms | Tokio interval timer |
| ICO from System.Drawing | Embedded PNG via `include_bytes!` |

**Transition**: Ship Rust v2.0 alongside AHK v1.4. AHK scripts moved to `scripts/v1.4/` for reference. No migration tool needed — just replace the binary and create `config.toml`.

## 13. Future Ideas (P2+)

- **Multi-node dashboard**: Monitor multiple nodes from one widget (remote gateways)
- **Desktop notifications**: Toast/banner on status change (online→offline, restart events)
- **Gateway token auto-discovery**: Read `~/.openclaw/openclaw.json` to extract gateway token
- **Log viewer**: Right-click → "View Logs" opens tail of node output
- **Update checker**: Notify when new release available on GitHub
- **Phone companion**: Pair with mobile app for remote monitoring
- **CLI mode**: `openclaw-node-widget --status` for headless/scripting use
