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

**Scope**: Monitor ONE node process, auto-restart on failure, provide quick access controls via tray icon.

## 2. Features & Priority

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

## 3. Architecture

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

## 4. Configuration File Specification

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

## 5. Platform-Specific Behavior

| Feature               | Windows              | macOS                | Linux (Gnome/KDE)    | Linux (headless)     |
|---------------------|---------------------|---------------------|---------------------|---------------------|
| **Tray Framework**  | winapi/shell32      | Cocoa NSStatusItem  | libappindicator     | libappindicator      |
| **Process Spawn**   | CreateProcessW      | posix_spawn         | fork + exec         | fork + exec          |
| **Auto-start**      | Registry key        | LaunchAgent plist   | XDG autostart       | systemd user service |
| **No-window flag**  | CREATE_NO_WINDOW    | LSBackgroundOnly      | setsid + nohup      | --                  |
| **Icon format**     | ICO/PNG             | PNG/ICNS            | PNG                 | PNG                  |
| **Path separator**  | \                    | /                   | /                   | /                   |
| **Process kill**    | TerminateProcess    | kill(pid, SIGTERM)  | kill(pid, SIGTERM)  | kill(pid, SIGTERM)   |

## 6. Repository Structure

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

## 7. Build & Release

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

## 8. Migration Path from AHK v1.4

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

## 9. Future Ideas (P2+)

- **Multi-node dashboard**: Monitor multiple nodes from one widget (remote gateways)
- **Desktop notifications**: Toast/banner on status change (online→offline, restart events)
- **Gateway token auto-discovery**: Read `~/.openclaw/openclaw.json` to extract gateway token
- **Log viewer**: Right-click → "View Logs" opens tail of node output
- **Update checker**: Notify when new release available on GitHub
- **Phone companion**: Pair with mobile app for remote monitoring
- **CLI mode**: `openclaw-node-widget --status` for headless/scripting use
