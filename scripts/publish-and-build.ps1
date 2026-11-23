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
# Network note: this machine's PowerShell HTTP stack often prefers a broken
# IPv6 route, so every GitHub API call goes through curl -4 instead.
#
#   powershell -ExecutionPolicy Bypass -File scripts\publish-and-build.ps1

$ErrorActionPreference = 'Stop'
$ApiBase = 'https://api.github.com'
$Curl = Join-Path $env:SystemRoot 'System32\curl.exe'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$DistDir = Join-Path $RepoRoot 'dist'
$Gcm = 'C:\Program Files\Git\mingw64\bin\git-credential-manager.exe'

# Git writes progress and warnings to stderr; with ErrorActionPreference=Stop
# Windows PowerShell turns that into a terminating error. Run native commands
# with Continue and inspect the exit code ourselves.
function Invoke-Native {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& $FilePath @Arguments 2>&1 | ForEach-Object { "$_" })
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    return [pscustomobject]@{ Output = $output; Code = $code }
}

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

# 2. API calls through curl -4 (IPv4), returning parsed JSON or a file.
function Invoke-Api {
    param(
        [string]$Method = 'GET',
        [string]$Path,
        $Body,
        [string]$OutFile
    )

    $arguments = @(
        '-4', '-sS', '-L', '--fail-with-body', '-m', '180',
        '-X', $Method,
        "$ApiBase$Path",
        '-H', "Authorization: Bearer $token",
        '-H', 'Accept: application/vnd.github+json',
        '-H', 'X-GitHub-Api-Version: 2022-11-28',
        '-H', 'User-Agent: swipeclean-build'
    )

    $tempBody = $null
    if ($null -ne $Body) {
        $tempBody = [IO.Path]::GetTempFileName()
        [IO.File]::WriteAllText($tempBody, ($Body | ConvertTo-Json -Depth 10 -Compress))
        $arguments += @('--data-binary', "@$tempBody", '-H', 'Content-Type: application/json')
    }

    try {
        if ($OutFile) {
            $arguments += @('-o', $OutFile)
            & $Curl @arguments | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "curl exit $LASTEXITCODE while downloading $Path" }
            return $null
        }

        $raw = & $Curl @arguments
        if ($LASTEXITCODE -ne 0) {
            $detail = ($raw | Out-String).Trim()
            if ($detail.Length -gt 500) { $detail = $detail.Substring(0, 500) }
            throw "curl exit $LASTEXITCODE for $Method $Path :: $detail"
        }
        $text = ($raw | Out-String).Trim()
        if (-not $text) { return $null }
        return ($text | ConvertFrom-Json)
    } finally {
        if ($tempBody) { Remove-Item $tempBody -Force -ErrorAction SilentlyContinue }
    }
}

$me = Invoke-Api -Path '/user'
$login = $me.login
if (-not $Owner) { $Owner = $login }
Write-Host "== Authenticated as $login"

# 3. Create the repository when it does not exist (404).
try {
    Invoke-Api -Path "/repos/$Owner/$RepoName" | Out-Null
    Write-Host "== Repo $Owner/$RepoName already exists"
} catch {
    $body = @{
        name        = $RepoName
        private     = (-not $Public)
        auto_init   = $false
        description = 'SwipeClean - swipe to review and clean the iOS photo library'
    }
    $repo = Invoke-Api -Method Post -Path '/user/repos' -Body $body
    Write-Host "== Created $($repo.full_name)"
}

# 4. Commit and push.
Set-Location $RepoRoot
if (-not (Test-Path (Join-Path $RepoRoot '.git'))) {
    $init = Invoke-Native -FilePath 'git' -Arguments @('init', '-b', 'main')
    $init.Output | Out-Host
}
Invoke-Native -FilePath 'git' -Arguments @('config', 'user.name', $login) | Out-Null
Invoke-Native -FilePath 'git' -Arguments @('config', 'user.email', "$login@users.noreply.github.com") | Out-Null
Invoke-Native -FilePath 'git' -Arguments @('add', '-A') | Out-Null
$staged = Invoke-Native -FilePath 'git' -Arguments @('diff', '--cached', '--quiet')
if ($staged.Code -ne 0) {
    $commit = Invoke-Native -FilePath 'git' -Arguments @('commit', '-m', 'chore: update SwipeClean')
    $commit.Output | Out-Host
}

function Get-RemoteBlobMap {
    $map = @{}
    try {
        $ref = Invoke-Api -Path "/repos/$Owner/$RepoName/git/ref/heads/main"
        $commit = Invoke-Api -Path "/repos/$Owner/$RepoName/git/commits/$($ref.object.sha)"
        $tree = Invoke-Api -Path "/repos/$Owner/$RepoName/git/trees/$($commit.tree.sha)?recursive=1"
        foreach ($entry in $tree.tree) {
            if ($entry.type -eq 'blob') { $map[$entry.path] = $entry.sha }
        }
    } catch { }
    return $map
}

function Push-GitHubApi {
    $remoteBlobs = Get-RemoteBlobMap
    $fileList = (Invoke-Native -FilePath 'git' -Arguments @('ls-files')).Output |
        Where-Object { $_ -and (Test-Path (Join-Path $RepoRoot $_)) }

    $treeEntries = @()
    $uploaded = 0
    foreach ($file in $fileList) {
        $relative = $file -replace '\\', '/'
        $localSha = ((Invoke-Native -FilePath 'git' -Arguments @('hash-object', $file)).Output |
            Select-Object -First 1).Trim()
        $sha = $remoteBlobs[$relative]
        if (-not $sha -or $sha -ne $localSha) {
            $bytes = [IO.File]::ReadAllBytes((Join-Path $RepoRoot $file))
            $blobBody = @{ content = [Convert]::ToBase64String($bytes); encoding = 'base64' }
            $blob = $null
            for ($attempt = 1; $attempt -le 5 -and -not $blob; $attempt++) {
                try {
                    $blob = Invoke-Api -Method Post -Path "/repos/$Owner/$RepoName/git/blobs" -Body $blobBody
                } catch {
                    $message = $_.Exception.Message
                    Write-Host "== blob '$relative' attempt $attempt failed: $message"
                    if ($message -match '403') {
                        Start-Sleep -Seconds 60
                    } else {
                        Start-Sleep -Seconds 2
                    }
                }
            }
            if (-not $blob) { throw "Could not upload $relative" }
            $sha = $blob.sha
            $uploaded++
            Start-Sleep -Seconds 2
        }
        $treeEntries += @{ path = $relative; mode = '100644'; type = 'blob'; sha = $sha }
    }
    Write-Host "== Uploaded $uploaded changed file(s) of $($treeEntries.Count)"

    $tree = Invoke-Api -Method Post -Path "/repos/$Owner/$RepoName/git/trees" -Body @{ tree = $treeEntries }
    if (-not $tree -or -not $tree.sha) { throw 'Could not create the tree' }

    $parent = $null
    try {
        $ref = Invoke-Api -Path "/repos/$Owner/$RepoName/git/ref/heads/main"
        $parent = $ref.object.sha
    } catch { }

    $commitPayload = if ($parent) {
        @{ message = 'chore: update SwipeClean'; tree = $tree.sha; parents = @($parent) }
    } else {
        @{ message = 'chore: update SwipeClean'; tree = $tree.sha; parents = @() }
    }
    $commit = Invoke-Api -Method Post -Path "/repos/$Owner/$RepoName/git/commits" -Body $commitPayload
    if (-not $commit -or -not $commit.sha) { throw 'Could not create the commit' }

    Invoke-Api -Method Patch -Path "/repos/$Owner/$RepoName/git/refs/heads/main" -Body @{ sha = $commit.sha; force = $true } | Out-Null
    return $commit.sha
}

$basic = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("x-access-token:$token"))
$push = Invoke-Native -FilePath 'git' -Arguments @(
    '-c', "http.extraheader=Authorization: Basic $basic",
    'push', "https://github.com/$Owner/$RepoName.git", 'HEAD:refs/heads/main', '--force'
)
$push.Output | Select-Object -Last 4 | ForEach-Object { Write-Host $_ }

if ($push.Code -eq 0) {
    $head = Invoke-Native -FilePath 'git' -Arguments @('rev-parse', 'HEAD')
    $headSha = ($head.Output | Select-Object -First 1).Trim()
} else {
    Write-Host '== github.com:443 is unreachable; publishing through the GitHub API instead'
    $headSha = $null
    for ($attempt = 1; $attempt -le 3 -and -not $headSha; $attempt++) {
        try {
            $headSha = Push-GitHubApi
        } catch {
            Write-Host "== API push attempt $attempt failed: $($_.Exception.Message)"
            Start-Sleep -Seconds 3
        }
    }
    if (-not $headSha) { throw 'Could not publish through the GitHub API.' }

    Start-Sleep -Seconds 6
    $recent = Invoke-Api -Path "/repos/$Owner/$RepoName/actions/runs?per_page=10"
    $existing = $recent.workflow_runs |
        Where-Object { $_.head_sha -eq $headSha -and $_.conclusion -ne 'cancelled' } |
        Select-Object -First 1
    if (-not $existing) {
        Invoke-Api -Method Post -Path "/repos/$Owner/$RepoName/actions/workflows/build-ios-ipa.yml/dispatches" -Body @{ ref = 'main' } | Out-Null
        Write-Host '== Workflow dispatched through the API'
    } else {
        Write-Host '== The ref update already queued the workflow'
    }
}
if (-not $headSha) { throw 'Could not publish the project.' }
Write-Host "== Published $headSha to https://github.com/$Owner/$RepoName"

# 5. Find the run for this commit.
$run = $null
$runs = $null
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 5
    $runs = Invoke-Api -Path "/repos/$Owner/$RepoName/actions/runs?per_page=15"
    $run = $runs.workflow_runs |
        Where-Object { $_.head_sha -eq $headSha -and $_.conclusion -ne 'cancelled' } |
        Sort-Object -Property created_at -Descending | Select-Object -First 1
    if ($run) { break }
}
if (-not $run -and $runs) {
    $run = $runs.workflow_runs |
        Where-Object { $_.conclusion -ne 'cancelled' } |
        Sort-Object -Property created_at -Descending | Select-Object -First 1
}
if (-not $run) { throw 'No workflow run appeared' }
Write-Host "== Run #$($run.run_number) id=$($run.id)"
Write-Host "== $($run.html_url)"

# 6. Poll until finished.
$deadline = (Get-Date).AddMinutes(40)
while ($run.status -ne 'completed' -and (Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 20
    $run = Invoke-Api -Path "/repos/$Owner/$RepoName/actions/runs/$($run.id)"
    Write-Host ("== [{0}] {1} / {2}" -f (Get-Date -Format 'HH:mm:ss'), $run.status, $run.conclusion)
}
Write-Host "== Final: $($run.status) $($run.conclusion)"

if ($run.conclusion -ne 'success') {
    try {
        $logZip = Join-Path $env:TEMP "swipeclean-logs-$($run.id).zip"
        Invoke-Api -Path "/repos/$Owner/$RepoName/actions/runs/$($run.id)/logs" -OutFile $logZip
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

# 7. Download and unpack the artifact.
$arts = Invoke-Api -Path "/repos/$Owner/$RepoName/actions/runs/$($run.id)/artifacts"
$artifact = $arts.artifacts | Where-Object { $_.name -eq 'SwipeClean-ipa' } | Select-Object -First 1
if (-not $artifact) { throw 'IPA artifact not found' }
Write-Host "== Artifact $($artifact.name) $([math]::Round($artifact.size_in_bytes / 1MB, 2)) MB"

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
$zipPath = Join-Path $DistDir 'swipeclean-artifact.zip'
Invoke-Api -Path "/repos/$Owner/$RepoName/actions/artifacts/$($artifact.id)/zip" -OutFile $zipPath
Expand-Archive -Path $zipPath -DestinationPath $DistDir -Force
Remove-Item $zipPath -Force

$ipa = Get-ChildItem $DistDir -Filter '*.ipa' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $ipa) { throw 'IPA was not unpacked' }
Write-Host "== IPA: $($ipa.FullName) ($([math]::Round($ipa.Length / 1KB)) KB)"
Write-Host '== DONE'
exit 0

