# =============================================================================
# serve_local.ps1 — Order Tracking local web server (NO Python, NO admin)
#
# Kyun: server.py ko chalane ke liye Python chahiye aur HttpListener-based
# (purane) PowerShell server sirf "localhost" par bind hota tha — LAN/Wi-Fi IP
# (http://192.168.x.x:8080/) par 400 Bad Request aata tha, isliye mobile QR
# (Wi-Fi / Hotspot / Cloudflare tunnel) SAB fail hote the.
#
# Ye script System.Net.Sockets.TcpListener use karti hai jo bina admin/urlacl
# ke SAARE interfaces par bind hoti hai — office Wi-Fi, mobile hotspot aur
# cloudflared tunnel teeno chalte hain. Ye server.py ke routes ka copy hai:
#   GET  /api/ping           -> {"status":"ok"}
#   GET  /api/version        -> DB file mtime version
#   GET  /api/load           -> data/Order_Tracking_Database.json
#   POST /api/save           -> DB file disk par save
#   GET  /api/network-info   -> LAN IP + Wi-Fi/hotspot/tunnel URLs (QR hub ke liye)
#   GET  /*                  -> static files (index.html, mobile_access.html, ...)
#
# Cloudflared present ho to server ke start hote hi tunnel apne aap start hota
# hai (Connectivity Hub ka Card 2 / 4G-5G access) — Launch_Software.bat ki tarah.
# =============================================================================
$root = if ($PSScriptRoot) { $PSScriptRoot } else { "C:\Users\user\order-tracking" }
$dataDir = Join-Path $root "data"
$dbFile = Join-Path $dataDir "Order_Tracking_Database.json"
$PORT = 8080

$mime = @{
  ".html" = "text/html; charset=utf-8"
  ".js"   = "application/javascript; charset=utf-8"
  ".json" = "application/json; charset=utf-8"
  ".css"  = "text/css; charset=utf-8"
  ".png"  = "image/png"
  ".svg"  = "image/svg+xml"
  ".ico"  = "image/x-icon"
  ".map"  = "application/json"
  ".woff2"= "font/woff2"
  ".txt"  = "text/plain; charset=utf-8"
  ".md"   = "text/plain; charset=utf-8"
  ".bat"  = "text/plain; charset=utf-8"
  ".ps1"  = "text/plain; charset=utf-8"
  ".gs"   = "text/plain; charset=utf-8"
  ".py"   = "text/plain; charset=utf-8"
}

$StatusText = @{
  200 = "OK"; 204 = "No Content"; 400 = "Bad Request"
  404 = "Not Found"; 405 = "Method Not Allowed"; 500 = "Internal Server Error"
}

# --------------------------------------------------------------- LAN IP ----
function Get-LocalIPAddress {
  # UDP "connect" (packet nahi bhejta) — OS route table se best LAN IP milta hai
  try {
    $s = New-Object System.Net.Sockets.Socket(
      [System.Net.Sockets.AddressFamily]::InterNetwork,
      [System.Net.Sockets.SocketType]::Dgram,
      [System.Net.Sockets.ProtocolType]::Udp)
    $s.Connect("8.8.8.8", 53)
    $ip = $s.LocalEndPoint.Address.ToString()
    $s.Close()
    if ($ip -and $ip -notlike "127.*") { return $ip }
  } catch {}
  # Fallback: hostname resolve (offline bhi kaam karta hai)
  try {
    $ip2 = [System.Net.Dns]::GetHostAddresses($env:COMPUTERNAME) |
      Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork -and
                     $_.IPAddressToString -ne "127.0.0.1" } |
      Select-Object -First 1 -ExpandProperty IPAddressToString
    if ($ip2) { return $ip2 }
  } catch {}
  return "192.168.1.4"
}

# ------------------------------------------------------- Tunnel URL detect ----
function Get-ActiveTunnelUrl {
  # Sirf tabhi URL do jab cloudflared CHAL RAHA ho — warna purana (dead) URL
  # QR me chhap jaata tha aur mobile scan karke fail hota tha (server.py rule).
  $running = $false
  try { $running = [bool](Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue) } catch {}
  if (-not $running) { return $null }

  # naye log pehle (cf.log / cf.err.log) — Start-Process dono alag redirect karta hai
  $candidates = @(
    (Join-Path $dataDir "cf.log"), (Join-Path $root "cf.log"),
    (Join-Path $dataDir "cf.err.log"), (Join-Path $root "cf.err.log"),
    (Join-Path $dataDir "cloudflared.log"), (Join-Path $root "cloudflared.log")
  )
  $bestUrl = $null
  $bestTime = [DateTime]::MinValue
  foreach ($lp in $candidates) {
    if (-not (Test-Path $lp)) { continue }
    try {
      # cloudflared apni file par exclusive handle rakhta hai — shared read chahiye
      $fs = New-Object System.IO.FileStream($lp, [System.IO.FileMode]::Open,
             [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
      $sr = New-Object System.IO.StreamReader($fs)
      $txt = $sr.ReadToEnd()
      $sr.Close(); $fs.Close()
      $ms = [regex]::Matches($txt, "https://[a-zA-Z0-9-]+\.trycloudflare\.com")
      if ($ms.Count -gt 0) {
        $mt = (Get-Item $lp).LastWriteTime
        if ($mt -gt $bestTime) { $bestTime = $mt; $bestUrl = $ms[$ms.Count - 1].Value }
      }
    } catch {}
  }
  return $bestUrl
}

function Start-TunnelIfMissing {
  # Connectivity Hub Card 2 (4G/5G) ke liye — Launch_Software.bat jaisa hi rule:
  # cloudflared chal raha ho to skip, exe hi na ho to chup-chap skip.
  try { if (Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue) { return } } catch {}
  $cf = Join-Path $root "cloudflared.exe"
  if (-not (Test-Path $cf)) { return }
  if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
  Remove-Item (Join-Path $dataDir "cf.log") -Force -ErrorAction SilentlyContinue
  Remove-Item (Join-Path $dataDir "cf.err.log") -Force -ErrorAction SilentlyContinue
  try {
    Start-Process -FilePath $cf -ArgumentList @("tunnel", "--url", "http://localhost:8080") `
      -RedirectStandardOutput (Join-Path $dataDir "cf.log") `
      -RedirectStandardError  (Join-Path $dataDir "cf.err.log") `
      -WindowStyle Hidden | Out-Null
    Write-Output "[TUNNEL] cloudflared starting — trycloudflare URL ~5-10s me aayega"
  } catch {
    Write-Output "[TUNNEL] start FAILED: $_"
  }
}

# ------------------------------------------------------------- HTTP write ----
function Send-Bytes($stream, $code, $contentType, $bodyBytes) {
  if ($null -eq $bodyBytes) { $bodyBytes = [byte[]]@() }
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append("HTTP/1.1 $code $($StatusText[$code])`r`n")
  if ($contentType) { [void]$sb.Append("Content-Type: $contentType`r`n") }
  [void]$sb.Append("Content-Length: $($bodyBytes.Length)`r`n")
  [void]$sb.Append("Access-Control-Allow-Origin: *`r`n")
  [void]$sb.Append("Cache-Control: no-cache, no-store, must-revalidate`r`n")
  [void]$sb.Append("Connection: close`r`n")
  [void]$sb.Append("`r`n")
  $hb = [Text.Encoding]::ASCII.GetBytes($sb.ToString())
  $stream.Write($hb, 0, $hb.Length)
  if ($bodyBytes.Length -gt 0) { $stream.Write($bodyBytes, 0, $bodyBytes.Length) }
}

function Send-Json($stream, $obj, $code) {
  $bytes = [Text.Encoding]::UTF8.GetBytes(($obj | ConvertTo-Json -Compress -Depth 6))
  Send-Bytes $stream $code "application/json; charset=utf-8" $bytes
}

# --------------------------------------------------- One client connection ----
function Handle-Client($client) {
  $client.ReceiveTimeout = 4000    # idle/preconnect client ko jaldi chhodo
  $client.SendTimeout = 20000
  $stream = $client.GetStream()
  $buf = New-Object byte[] 16384
  $ms = New-Object System.IO.MemoryStream

  # 1) Headers padho jab tak \r\n\r\n na mile
  $headerLen = 0
  $found = $false
  while (-not $found) {
    $n = $stream.Read($buf, 0, $buf.Length)
    if ($n -le 0) { return }
    $ms.Write($buf, 0, $n)
    if ($ms.Length -gt 1048576) { return }   # header-bomb guard
    $bytes = $ms.ToArray()
    for ($i = 0; $i -le $bytes.Length - 4; $i++) {
      if ($bytes[$i] -eq 13 -and $bytes[$i+1] -eq 10 -and $bytes[$i+2] -eq 13 -and $bytes[$i+3] -eq 10) {
        $found = $true; $headerLen = $i + 4; break
      }
    }
  }
  $bytes = $ms.ToArray()
  $headerText = [Text.Encoding]::ASCII.GetString($bytes, 0, $headerLen)

  if ($headerText -match "(?im)^Expect:\s*100-continue") {
    $cont = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 100 Continue`r`n`r`n")
    $stream.Write($cont, 0, $cont.Length)
  }

  # 2) Body (agar Content-Length ho)
  $contentLen = 0
  if ($headerText -match "(?im)^Content-Length:\s*(\d+)") { $contentLen = [int]$Matches[1] }
  $received = $bytes.Length - $headerLen
  while ($received -lt $contentLen) {
    $n = $stream.Read($buf, 0, $buf.Length)
    if ($n -le 0) { break }
    $ms.Write($buf, 0, $n)
    $received += $n
  }
  $bytes = $ms.ToArray()

  # 3) Request line parse — "GET /path?query HTTP/1.1"
  $firstLine = ($headerText -split "`r`n")[0]
  $lineParts = $firstLine -split " "
  if ($lineParts.Count -lt 2) { return }
  $method = $lineParts[0].ToUpper()
  $target = $lineParts[1]

  # cloudflared/proxy absolute-form target bhej sakta hai — usko path me badlo
  if ($target -match "^https?://") {
    try { $target = ([Uri]$target).PathAndQuery } catch {}
  }
  $qIdx = $target.IndexOf("?")
  if ($qIdx -ge 0) { $target = $target.Substring(0, $qIdx) }
  $path = [Uri]::UnescapeDataString($target)
  if ($path -eq "/" -or $path -eq "") { $path = "/index.html" }

  $body = ""
  if ($contentLen -gt 0 -and $bytes.Length -ge ($headerLen + $contentLen)) {
    $body = [Text.Encoding]::UTF8.GetString($bytes, $headerLen, $contentLen)
  }

  # 4) CORS preflight
  if ($method -eq "OPTIONS") {
    Send-Bytes $stream 204 $null ([byte[]]@())
    return
  }

  # 5) API routes (server.py parity)
  if ($path -eq "/api/ping") {
    Send-Json $stream @{ status = "ok" } 200; return
  }

  if ($path -eq "/api/version") {
    # NOTE: [int] overflow — ticks/10000 ≈ 6.4e13 > Int32.Max! [long] chahiye
    # (server.py ka int() Python me arbitrary-precision hai, isliye wahan theek tha).
    $v = [long]0
    if (Test-Path $dbFile) { $v = [long]((Get-Item $dbFile).LastWriteTimeUtc.Ticks / 10000) }
    Send-Json $stream @{ status = "ok"; version = $v } 200; return
  }

  if ($path -eq "/api/load") {
    if (Test-Path $dbFile) {
      Send-Bytes $stream 200 "application/json; charset=utf-8" ([IO.File]::ReadAllBytes($dbFile))
    } else {
      Send-Json $stream @{ status = "error"; message = "No database file found on disk" } 404
    }
    return
  }

  if ($path -eq "/api/save" -and $method -eq "POST") {
    try {
      if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
      [IO.File]::WriteAllText($dbFile, $body, (New-Object Text.UTF8Encoding($false)))
      Send-Json $stream @{ status = "success"; message = "Database saved directly to server disk!" } 200
    } catch {
      Send-Json $stream @{ status = "error"; message = "$_" } 500
    }
    return
  }

  if ($path -eq "/api/network-info") {
    # Connectivity Hub (mobile_access.html) isi se QR/links banata hai
    $lip = Get-LocalIPAddress
    Send-Json $stream @{
      status      = "ok"
      local_ip    = $lip
      port        = $PORT
      wifi_url    = "http://${lip}:$PORT/"
      hotspot_url = "http://192.168.137.1:$PORT/"
      tunnel_url  = (Get-ActiveTunnelUrl)
      hostname    = $env:COMPUTERNAME
    } 200
    return
  }

  # 6) Static files
  $rel = $path.TrimStart("/").Replace("/", [IO.Path]::DirectorySeparatorChar)
  $file = [IO.Path]::GetFullPath((Join-Path $root $rel))   # ".." resolve hota hai
  $rootFull = [IO.Path]::GetFullPath($root).TrimEnd("\")
  if ((Test-Path $file -PathType Leaf) -and
      ($file -eq $rootFull -or $file.StartsWith($rootFull + "\", [StringComparison]::OrdinalIgnoreCase))) {
    $ext = [IO.Path]::GetExtension($file).ToLower()
    $ct = $mime[$ext]
    if (-not $ct) { $ct = "application/octet-stream" }
    Send-Bytes $stream 200 $ct ([IO.File]::ReadAllBytes($file))
  } else {
    Send-Bytes $stream 404 "text/plain; charset=utf-8" ([Text.Encoding]::UTF8.GetBytes("Not found: $path"))
  }
}

# ================================================================ MAIN ========
$rootFull = [IO.Path]::GetFullPath($root).TrimEnd("\")
$root = $rootFull   # static guard ke liye consistent

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $PORT)

# Port abhi bhi busy ho sakta hai (purane instance ka TIME_WAIT/zombie socket) —
# 20 tak retry karo, warna exit taki Launch_Software/Scheduled Task ko pata chale.
$started = $false
for ($try = 1; $try -le 20; $try++) {
  try { $listener.Start(); $started = $true; break } catch {
    Write-Output ("START TRY {0}/20 failed: {1}" -f $try, $_.Exception.Message)
    Start-Sleep -Seconds 2
  }
}
if (-not $started) {
  Write-Output "[FATAL] Port $PORT could not be bound after 20 tries — exiting."
  exit 1
}

$lanIP = Get-LocalIPAddress
Write-Output "SERVING ON http://localhost:$PORT/  LAN: http://${lanIP}:$PORT/  ROOT=$root"

# CRITICAL: socket handle ko NON-INHERITABLE banao. .NET Framework ke sockets
# inheritable hote hain — Start-Process se cloudflared child ye handle inherit
# kar leta tha. Server marne ke baad bhi cloudflared port 8080 zinda rakhta tha
# (ghost LISTEN socket) aur naya server kabhi bind nahi ho paata tha.
try {
  Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class SpcHandleUtil {
  [DllImport("kernel32.dll", SetLastError = true)]
  public static extern bool SetHandleInformation(IntPtr hObject, uint dwMask, uint dwFlags);
  public const uint HANDLE_FLAG_INHERIT = 0x1;
}
"@
  [void][SpcHandleUtil]::SetHandleInformation($listener.Server.Handle, [SpcHandleUtil]::HANDLE_FLAG_INHERIT, 0)
  Write-Output "[BIND] listener handle made non-inheritable (ghost-port guard)"
} catch {
  Write-Output "[BIND] SetHandleInformation skipped: $_"
}

Start-TunnelIfMissing

while ($true) {
  $client = $null
  try {
    $client = $listener.AcceptTcpClient()
    Handle-Client $client
  } catch {
    # Listener zinda nahi hai to busy-loop mat chalao — bahar nikal jao.
    if (-not $listener.Server.IsBound) {
      Write-Output ("FATAL: listener unbound — " + $_.Exception.Message)
      exit 1
    }
    Write-Output ("ERR: " + $_.Exception.Message)
    Start-Sleep -Milliseconds 250   # error-storm guard
  } finally {
    if ($client) { try { $client.Close() } catch {} }
  }
}
