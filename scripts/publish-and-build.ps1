param(
    [string]$RepoName = 'swipeclean',
    [string]$Owner = '',
    [switch]$Public
)

# Publish this project to GitHub, build it on a macOS runner and unpack the
# unsigned .ipa into dist/.
#
# Credential resolution order:
#   1. $env:GH_PAT (classic PAT with repo + workflow)
#   2. the GitHub account already stored by Git Credential Manager
#      (git-credential-manager github login --device)
#
#   powershell -ExecutionPolicy Bypass -File scripts\publish-and-build.ps1

$ErrorActionPreference = 'Stop'
$ApiBase = 'https://api.github.com'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$DistDir = Join-Path $RepoRoot 'dist'
$Gcm = 'C:\Program Files\Git\mingw64\bin\git-credential-manager.exe'

function Get-StoredToken {
    param([string]$UserName)

    $inFile = Join-Path $env:TEMP ("gcm-" + [guid]::NewGuid().ToString('N') + ".txt")
    $payload = "protocol=https`nhost=github.com`n"
    if ($UserName) { $payload += "username=$UserName`n" }
    $payload += "`n"
    [IO.File]::WriteAllText($inFile, $payload)

    $previous = $env:GCM_INTERACTIVE
    $env:GCM_INTERACTIVE = 'never'
    try {
        $raw = cmd /c "git credential fill < `"$inFile`" 2>&1"
    } finally {
        $env:GCM_INTERACTIVE = $previous
        Remove-Item $inFile -ErrorAction SilentlyContinue
    }

    $line = $raw | Where-Object { $_ -like 'password=*' } | Select-Object -First 1
    if ($line) { return $line.Substring(9).Trim() }
    return $null
}

# 1. Resolve a token.
$token = $env:GH_PAT
if (-not $token) {
    if (-not (Test-Path $Gcm)) {
        throw 'No token. Set $env:GH_PAT or install Git Credential Manager and run: git-credential-manager github login --device'
    }
    $accounts = @(& $Gcm github list 2>$null | Where-Object { $_ -and $_ -ne 'x-access-token' })
    foreach ($account in $accounts) {
        $token = Get-StoredToken -UserName $account
        if ($token) { Write-Host "== Using stored GitHub credential for $account"; break }
    }
}
if (-not $token) {
    throw 'No GitHub credential. Run: git-credential-manager github login --device'
}

$headers = @{
    Authorization          = "Bearer $token"
    Accept                 = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent'           = 'swipeclean-build'
}

$me = Invoke-RestMethod -Uri "$ApiBase/user" -Headers $headers -TimeoutSec 30
$login = $me.login
if (-not $Owner) { $Owner = $login }
Write-Host "== Authenticated as $login"

# 2. Create the repository when it does not exist (422 means it already does).
try {
    $body = @{
        name        = $RepoName
        private     = (-not $Public)
        auto_init   = $false
        description = 'SwipeClean - swipe to review and clean the iOS photo library'
    } | ConvertTo-Json
    $repo = Invoke-RestMethod -Method Post -Uri "$ApiBase/user/repos" -Headers $headers -Body $body -ContentType 'application/json' -TimeoutSec 30
    Write-Host "== Created $($repo.full_name) (private=$(-not $Public))"
} catch {
    Write-Host "== Repo $Owner/$RepoName already exists (or creation not needed)"
}

# 3. Commit and push.
Set-Location $RepoRoot
if (-not (Test-Path (Join-Path $RepoRoot '.git'))) {
    git init -b main | Out-Host
}
git config user.name $login
git config user.email "$login@users.noreply.github.com"
git add -A
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    git commit -m "chore: update SwipeClean" | Out-Host
}

$basic = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("x-access-token:$token"))
$pushOutput = git -c "http.extraheader=Authorization: Basic $basic" push "https://github.com/$Owner/$RepoName.git" HEAD:refs/heads/main --force 2>&1
$pushExit = $LASTEXITCODE
$pushOutput | Select-Object -Last 4 | Out-Host
if ($pushExit -ne 0) {
    throw 'git push failed. If GitHub rejects workflow files, grant the workflow scope or add .github/workflows through the web UI.'
}
$headSha = (git rev-parse HEAD).Trim()
Write-Host "== Pushed $headSha to https://github.com/$Owner/$RepoName"

# 4. Find the run for this commit (fall back to the latest run when the push
#    did not change anything and therefore did not trigger a build).
$run = $null
$runs = $null
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 5
    $runs = Invoke-RestMethod -Uri "$ApiBase/repos/$Owner/$RepoName/actions/runs?per_page=15" -Headers $headers -TimeoutSec 30
    $run = $runs.workflow_runs | Where-Object { $_.head_sha -eq $headSha } |
        Sort-Object -Property created_at -Descending | Select-Object -First 1
    if ($run) { break }
}
if (-not $run -and $runs) {
    $run = $runs.workflow_runs | Sort-Object -Property created_at -Descending | Select-Object -First 1
}
if (-not $run) { throw 'No workflow run appeared' }
Write-Host "== Run #$($run.run_number) id=$($run.id)"
Write-Host "== $($run.html_url)"

# 5. Poll until finished.
$deadline = (Get-Date).AddMinutes(40)
while ($run.status -ne 'completed' -and (Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 20
    $run = Invoke-RestMethod -Uri "$ApiBase/repos/$Owner/$RepoName/actions/runs/$($run.id)" -Headers $headers -TimeoutSec 30
    Write-Host ("== [{0}] {1} / {2}" -f (Get-Date -Format 'HH:mm:ss'), $run.status, $run.conclusion)
}
Write-Host "== Final: $($run.status) $($run.conclusion)"

if ($run.conclusion -ne 'success') {
    try {
        $logZip = Join-Path $env:TEMP "swipeclean-logs-$($run.id).zip"
        Invoke-WebRequest -Uri "$ApiBase/repos/$Owner/$RepoName/actions/runs/$($run.id)/logs" -Headers $headers -OutFile $logZip -UseBasicParsing -TimeoutSec 300
        $logDir = Join-Path $env:TEMP "swipeclean-logs-$($run.id)"
        Expand-Archive -Path $logZip -DestinationPath $logDir -Force
        Get-ChildItem $logDir -Recurse -File | ForEach-Object {
            Write-Host "----- $($_.Name) -----"
            Get-Content $_.FullName -Tail 120
        }
    } catch {
        Write-Host "Could not fetch logs: $($_.Exception.Message)"
    }
    throw "Build failed: $($run.conclusion)"
}

# 6. Download and unpack the artifact.
$arts = Invoke-RestMethod -Uri "$ApiBase/repos/$Owner/$RepoName/actions/runs/$($run.id)/artifacts" -Headers $headers -TimeoutSec 30
$artifact = $arts.artifacts | Where-Object { $_.name -eq 'SwipeClean-ipa' } | Select-Object -First 1
if (-not $artifact) { throw 'IPA artifact not found' }
Write-Host "== Artifact $($artifact.name) $([math]::Round($artifact.size_in_bytes / 1MB, 2)) MB"

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
$zipPath = Join-Path $DistDir 'swipeclean-artifact.zip'
Invoke-WebRequest -Uri "$ApiBase/repos/$Owner/$RepoName/actions/artifacts/$($artifact.id)/zip" -Headers $headers -OutFile $zipPath -UseBasicParsing -TimeoutSec 600
Expand-Archive -Path $zipPath -DestinationPath $DistDir -Force
Remove-Item $zipPath -Force

$ipa = Get-ChildItem $DistDir -Filter '*.ipa' | Select-Object -First 1
if (-not $ipa) { throw 'IPA was not unpacked' }
Write-Host "== IPA: $($ipa.FullName) ($([math]::Round($ipa.Length / 1KB)) KB)"
Write-Host '== DONE'

