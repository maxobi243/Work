$port = 1233
$listener = [System.Net.Sockets.TcpListener]::new(
    [System.Net.IPAddress]::Any,
    $port
)
$listener.Start()
Write-Host "Listening on port $port"

while ($true) {
    $client = $listener.AcceptTcpClient()
    Write-Host "Client connected from $($client.Client.RemoteEndPoint)"

    $rs = [RunspaceFactory]::CreateRunspace()
    $rs.Open()

    $ps = [PowerShell]::Create()
    $ps.Runspace = $rs

    $ps.AddScript({
        param($client)

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
