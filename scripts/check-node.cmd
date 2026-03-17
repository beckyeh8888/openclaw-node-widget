@echo off
powershell -NoProfile -Command "if((Get-CimInstance Win32_Process -Filter 'name=''node.exe''' | Where-Object { $_.CommandLine -like '*openclaw*node run*' }).Count -gt 0){ Write-Output 'ONLINE' } else { Write-Output 'OFFLINE' }"
