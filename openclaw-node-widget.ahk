; OpenClaw Node Widget v1.4.0
; AutoHotkey v2 | MIT License
; Minimal stable: ProcessExist + SetTimer, no Sleep, no COM
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

BASE_DIR := "C:\Users\beck8\.openclaw"
REG_KEY := "OpenClawNodeWidget"
CHECK_MS := 15000
AUTO_RESTART := true
OFFLINE_COUNT := 0
RESTART_THRESHOLD := 3
STOP_COOLDOWN := false
RESTARTING := false

global currentStatusLabel := "Status: Checking..."
global currentAutoLabel := "Auto-start: Off"
global currentAutoRestartLabel := "Auto-restart: On"
global AUTO_RESTART, OFFLINE_COUNT, RESTART_THRESHOLD, STOP_COOLDOWN, RESTARTING

A_IconTip := "OpenClaw Node Widget"
icoPath := BASE_DIR "\assets\otto_icon.ico"
if FileExist(icoPath)
    TraySetIcon(icoPath)

m := A_TrayMenu
m.Delete()
m.Add(currentStatusLabel, (*) => 0)
m.Disable(currentStatusLabel)
m.Add()
m.Add("Refresh", (*) => CheckStatus())
m.Add("Restart Node", (*) => DoManualRestart())
m.Add("Stop Node", (*) => DoManualStop())
m.Add()
m.Add(currentAutoRestartLabel, (*) => ToggleAutoRestart())
m.Add(currentAutoLabel, (*) => ToggleAutoStart())
m.Add()
m.Add("Exit", (*) => ExitApp())

IsNodeRunning() {
    return ProcessExist("node.exe") ? true : false
}

DoManualRestart(*) {
    global OFFLINE_COUNT, STOP_COOLDOWN
    OFFLINE_COUNT := 0
    STOP_COOLDOWN := false
    DoRestart()
}

DoManualStop(*) {
    global OFFLINE_COUNT, STOP_COOLDOWN
    OFFLINE_COUNT := 0
    STOP_COOLDOWN := true
    try Run(A_ComSpec ' /c taskkill /f /im node.exe', , "Hide")
    TrayTip("Stop triggered", "OpenClaw Node", 1)
    SetTimer(CheckStatus, -5000)
    SetTimer(ClearCooldown, -120000)
}

ClearCooldown(*) {
    global STOP_COOLDOWN
    STOP_COOLDOWN := false
}

ToggleAutoRestart(*) {
    global AUTO_RESTART, currentAutoRestartLabel
    AUTO_RESTART := !AUTO_RESTART
    newLabel := AUTO_RESTART ? "Auto-restart: On" : "Auto-restart: Off"
    try A_TrayMenu.Rename(currentAutoRestartLabel, newLabel)
    currentAutoRestartLabel := newLabel
}

ToggleAutoStart(*) {
    global REG_KEY, currentAutoLabel
    regPath := "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
    existing := ""
    try existing := RegRead(regPath, REG_KEY)
    if (existing != "") {
        try RegDelete(regPath, REG_KEY)
        TrayTip("Auto-start disabled", "OpenClaw Node", 1)
    } else {
        try RegWrite(A_ScriptFullPath, "REG_SZ", regPath, REG_KEY)
        TrayTip("Auto-start enabled", "OpenClaw Node", 1)
    }
    newText := ""
    try newText := RegRead(regPath, REG_KEY)
    label := (newText != "") ? "Auto-start: On" : "Auto-start: Off"
    try A_TrayMenu.Rename(currentAutoLabel, label)
    currentAutoLabel := label
}

StartNodeDelayed(*) {
    global BASE_DIR, RESTARTING
    RESTARTING := false
    vbsPath := BASE_DIR "\node-hidden.vbs"
    if FileExist(vbsPath) {
        try Run('wscript.exe "' vbsPath '"',, "Hide")
    } else {
        try Run(A_ComSpec ' /c "' BASE_DIR '\node.cmd"',, "Hide")
    }
    TrayTip("Node started", "OpenClaw Node", 1)
    SetTimer(CheckStatus, -12000)
}

DoRestart(*) {
    global RESTARTING
    if RESTARTING
        return
    RESTARTING := true
    try Run(A_ComSpec ' /c taskkill /f /im node.exe', , "Hide")
    SetTimer(StartNodeDelayed, -4000)
}

CheckStatus(*) {
    global currentStatusLabel, AUTO_RESTART, OFFLINE_COUNT, RESTART_THRESHOLD, STOP_COOLDOWN, RESTARTING
    if RESTARTING
        return
    isOnline := IsNodeRunning()
    if (isOnline) {
        OFFLINE_COUNT := 0
    } else {
        OFFLINE_COUNT += 1
        if (AUTO_RESTART && !STOP_COOLDOWN && OFFLINE_COUNT >= RESTART_THRESHOLD) {
            OFFLINE_COUNT := 0
            DoRestart()
            return
        }
    }
    tag := isOnline ? "[OK]" : "[--]"
    newLabel := tag " Node: " (isOnline ? "Online" : "Offline")
    A_IconTip := "OpenClaw Node: " (isOnline ? "Online" : "Offline")
    try A_TrayMenu.Rename(currentStatusLabel, newLabel)
    try A_TrayMenu.Disable(newLabel)
    currentStatusLabel := newLabel
}

; === STARTUP ===
; Check auto-start label
regPath := "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
existing := ""
try existing := RegRead(regPath, REG_KEY)
label := (existing != "") ? "Auto-start: On" : "Auto-start: Off"
try A_TrayMenu.Rename(currentAutoLabel, label)
currentAutoLabel := label

; Auto-start node if not running
if !IsNodeRunning() {
    DoRestart()
}
SetTimer(CheckStatus, -10000)
SetTimer(CheckStatus, CHECK_MS)
