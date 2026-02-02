$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:8080/")
$listener.Start()

Write-Host "Web server listening on http://localhost:8080/"

# Path to your HTML page
$htmlFile = Join-Path $PSScriptRoot "index.html"
$htmlFile

while ($listener.IsListening) {
    $context  = $listener.GetContext()   # blocks until request
    $request  = $context.Request
    $response = $context.Response

    Write-Host "$($request.HttpMethod) $($request.RawUrl)"

    if (Test-Path $htmlFile) {
        $body = Get-Content -Path $htmlFile -Raw
    } else {
        $body = "<html><body><h1>File not found 😢</h1></body></html>"
    }

    $bytes = [Text.Encoding]::UTF8.GetBytes($body)

    $response.ContentType = "text/html"
    $response.ContentLength64 = $bytes.Length
    $response.OutputStream.Write($bytes, 0, $bytes.Length)
    $response.Close()
}
