# =============================================================================
# server_watchdog.ps1 — SubhOrderTrackingServer ka bodyguard
#
# Kyun: 13 Nov 2026 ko server 0xC000013A (console close) se mar gaya aur
# Scheduled Task ne restart nahi kiya — poora din localhost:8080 dead raha,
# QR hub blank (502) aur app ko SW ka PURANA cached shell mila ("update nahi
# huwa"). Ye watchdog har 5 min port 8080 ping karti hai — dead ho to khud
# start karti hai. Task: SubhOrderTrackingWatchdog (AtLogon + 5-min repeat).
#
# Koi log SPAM nahi: sirf tab likho jab restart/detection ho.
# =============================================================================
$ErrorActionPreference = 'SilentlyContinue'
$pingOk = $false
try {
  $r = Invoke-WebRequest -Uri "http://localhost:8080/api/ping" -UseBasicParsing -TimeoutSec 5
  if ($r.StatusCode -eq 200) { $pingOk = $true }
} catch {}

if ($pingOk) { exit 0 }   # server zinda — kuch mat karo

$root = if ($PSScriptRoot) { $PSScriptRoot } else { "C:\Users\user\order-tracking" }
$logDir = Join-Path $root "data"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$log = Join-Path $logDir "watchdog.log"

$task = Get-ScheduledTask -TaskName "SubhOrderTrackingServer" -ErrorAction SilentlyContinue
$state = if ($task) { $task.State.ToString() } else { "MISSING" }

$msg = "[{0}] ping FAIL (task state={1})" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $state

if ($state -eq "Running") {
  # Port dead hai but task "Running" chhup raha hai (hung process) — maar ke naya chalao
  try { Stop-ScheduledTask -TaskName "SubhOrderTrackingServer" } catch {}
  Start-Sleep -Seconds 2
  Start-ScheduledTask -TaskName "SubhOrderTrackingServer"
  $msg += " -> STOP+START (hung)"
} else {
  Start-ScheduledTask -TaskName "SubhOrderTrackingServer"
  $msg += " -> START"
}

Add-Content -Path $log -Value $msg -Encoding UTF8

# Purana log badhta jaye na — 200 lines se zyada ho to aadha kaat do
try {
  $lines = Get-Content $log -Encoding UTF8
  if ($lines.Count -gt 200) { $lines | Select-Object -Last 100 | Set-Content $log -Encoding UTF8 }
} catch {}
