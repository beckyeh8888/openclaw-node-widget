Dim shell, exec, output
Set shell = CreateObject("WScript.Shell")
Set exec = shell.Exec("powershell.exe -NoProfile -WindowStyle Hidden -Command ""if((Get-CimInstance Win32_Process -Filter 'name=''''node.exe''''' | Where-Object { $_.CommandLine -like '*openclaw*node run*' }).Count -gt 0){'ONLINE'}else{'OFFLINE'}""")
output = exec.StdOut.ReadAll()
Dim fso, f
Set fso = CreateObject("Scripting.FileSystemObject")
Set f = fso.CreateTextFile(shell.ExpandEnvironmentStrings("%TEMP%") & "\ocnw_status.txt", True)
f.Write output
f.Close
