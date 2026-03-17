@echo off
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Users\beck8\.openclaw\stop-node.ps1"
timeout /t 3 /nobreak >nul
start "" wscript.exe "C:\Users\beck8\.openclaw\node-hidden.vbs"
