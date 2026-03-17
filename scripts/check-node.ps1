$r = @(Get-CimInstance Win32_Process -Filter "name='node.exe'" | Where-Object { $_.CommandLine -like '*openclaw*node run*' })
if($r.Count -gt 0){ $s = 'ONLINE' } else { $s = 'OFFLINE' }
[IO.File]::WriteAllText("$env:TEMP\ocnw_status.txt", $s)
