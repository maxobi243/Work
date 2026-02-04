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

        $stream.Write(
            [Text.Encoding]::ASCII.GetBytes("Password:`n"),
            0,
            10
        )

        $readAmmt = $stream.Read($passBuf, 0, $passBuf.Length)
        $sendPass = [Text.Encoding]::ASCII.GetString($passBuf, 0, $readAmmt)
        $plaintext = "01000000d08c9ddf0115d1118c7a00c04fc297eb01000000194f8e5ed645714e8a9a0ee176f9085800000000020000000000106600000001000020000000ff0a58066975f1027a0f0ac15fa83959e158404d4a1b6488c52d7ceea714a87f000000000e80000000020000200000000f9ce8f59c81ddac974f762d0a73fa0f278aa3d240279f9ab21974c7354f7af520000000dfdbf29e86ff8d76b4ce9c273736b71a38315f48bc1d1df8dfe666e92a0d100e40000000e614212e3663671b3059342b9e1c0c619cd1aaedd0d0fe1c15743e958373a9842d430a5bee8d29a95d490df68af568b9b4896a9dacce83aacb641e4f37c1f724"
        $secure =ConvertTo-SecureString $plaintext
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        )


        if ($sendPass -ne $plain) {
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
