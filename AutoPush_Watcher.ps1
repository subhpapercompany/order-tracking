# =====================================================================
# SUBH PAPER COMPANY - AUTO GIT PUSH WATCHER (fully automatic)
# ---------------------------------------------------------------------
# Runs hidden in the background. Monitors this folder; when tracked
# files change and settle (no further edits for ~20s), it commits
# automatically and pushes to GitHub. If a push fails (offline / auth),
# it retries with backoff until it succeeds. Never loses a commit:
# commits are always saved locally first, push happens separately.
#
# FIRST-TIME SETUP (run ONCE from this folder in a normal terminal):
#     git remote add origin https://github.com/<user>/<repo>.git
#     git push -u origin main
#   -> the 2nd command asks for your GitHub login ONCE; Windows
#      Credential Manager stores it, so this watcher then pushes
#      silently forever after (no prompts).
#
# Log file: autopush.log (this folder, auto-rotated, git-ignored)
# =====================================================================

$Repo = $PSScriptRoot
if (-not $Repo) { $Repo = (Get-Location).Path }

# Make sure git is reachable even if this hidden process started before
# the Git installer's PATH change was picked up by an interactive shell.
$env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
            [System.Environment]::GetEnvironmentVariable('Path', 'User')

$LogFile     = Join-Path $Repo 'autopush.log'
$PollSec     = 5      # check for changes every 5s
$SettleRds   = 4      # quiet rounds before commit (5s x 4 = 20s settle)
$FailBackoff = 45     # wait this long before retrying a failed push

function Write-Log([string]$Msg) {
    $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Msg
    try { Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8 } catch {}
    try {                                  # keep the log small
        $f = Get-Item -LiteralPath $LogFile -ErrorAction SilentlyContinue
        if ($f -and $f.Length -gt 1MB) {
            Set-Content -LiteralPath $LogFile -Value (Get-Content -LiteralPath $LogFile -Tail 200) -Encoding UTF8
        }
    } catch {}
}

Push-Location $Repo
Write-Log "===== AutoPush watcher started (repo: $Repo) ====="

$remote0 = git remote get-url origin 2>$null
if ($remote0) { Write-Log "origin = $remote0" }
else { Write-Log "No 'origin' remote yet - commits stay local until you: git remote add origin <repo-url>" }

$needsPush  = $false   # a local commit is waiting to reach GitHub
$pushBackoff = 0       # seconds left to wait after a failed push
$noRemoteLogged = $false

while ($true) {
    Start-Sleep -Seconds $PollSec

    # ---------- 1) COMMIT any settled working-tree changes ----------
    $dirty = git status --porcelain 2>$null
    if ($dirty) {
        # let edits settle (stop typing) before we snapshot
        $quiet = 0
        $last  = $dirty
        while ($quiet -lt $SettleRds) {
            Start-Sleep -Seconds $PollSec
            $now = git status --porcelain 2>$null
            if ($now -eq $last) { $quiet++ } else { $quiet = 0; $last = $now }
        }
        if (-not $last) { continue }

        git add -A 2>&1 | Out-Null
        $staged = git diff --cached --name-only 2>$null
        if (-not $staged) { continue }

        $n   = @($staged).Count
        $msg = 'auto-sync: ' + ((@($staged) | Select-Object -First 4) -join ', ') +
               $(if ($n -gt 4) { " (+$($n - 4) more)" } else { '' })
        git commit -q -m $msg 2>&1 | Out-Null
        Write-Log "Committed ($n file(s)): $msg"
        $needsPush = $true
    }

    # ---------- 2) PUSH pending commits to GitHub ----------
    if (-not $needsPush) { continue }

    if (-not (git remote get-url origin 2>$null)) {
        if (-not $noRemoteLogged) {
            Write-Log "No origin remote configured - will auto-push as soon as you add one."
            $noRemoteLogged = $true
        }
        continue                      # cheap local check; keeps $needsPush alive
    }

    if ($pushBackoff -gt 0) {         # throttled after a failed push
        $pushBackoff -= $PollSec
        if ($pushBackoff -gt 0) { continue }
    }

    $out = git push -u origin main 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Log 'Pushed to origin/main OK'
        $needsPush   = $false
        $pushBackoff = 0
        $noRemoteLogged = $false
    } else {
        Write-Log "Push FAILED (retry in ${FailBackoff}s): $($out -join ' ')"
        $pushBackoff = $FailBackoff
    }
}

Pop-Location
