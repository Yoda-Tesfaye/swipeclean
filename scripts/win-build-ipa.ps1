# Build SwipeClean as an unsigned .ipa from Windows.
#
# Requires: a classic GitHub PAT with `repo` + `workflow` scopes in $env:GH_PAT.
# What it does: create (or reuse) a private repo -> push this project ->
# GitHub's macOS runner compiles it -> download and unpack the .ipa into dist/.
#
#   $env:GH_PAT = 'ghp_xxx'
#   pwsh -File scripts\win-build-ipa.ps1

$ErrorActionPreference = 'Stop'
$ApiBase = 'https://api.github.com'
$RepoName = 'swipeclean'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$DistDir = Join-Path $RepoRoot 'dist'

$Token = $env:GH_PAT
if (-not $Token) { throw 'GH_PAT is not set (needs repo + workflow scopes)' }

$Headers = @{
  Authorization          = "Bearer $Token"
  Accept                 = 'application/vnd.github+json'
  'X-GitHub-Api-Version' = '2022-11-28'
  'User-Agent'           = 'swipeclean-build'
}

function Invoke-GitHub {
  param(
    [string]$Method = 'GET',
    [string]$Path,
    $Body,
    [switch]$AllowHttpErrors
  )
  $params = @{
    Method  = $Method
    Uri     = "$ApiBase$Path"
    Headers = $Headers
    TimeoutSec = 120
  }
  if ($null -ne $Body) {
    $params.Body = ($Body | ConvertTo-Json -Depth 8)
    $params.ContentType = 'application/json'
  }
  if ($AllowHttpErrors) { $params.SkipHttpErrorCheck = $true }
  Invoke-WebRequest @params
}

# 1. who am I
$me = (Invoke-GitHub -Path '/user').Content | ConvertFrom-Json
$Login = $me.login
Write-Host "== Authenticated as $Login"

# 2. create the repo when it does not exist yet
$exists = $true
try {
  Invoke-GitHub -Path "/repos/$Login/$RepoName" -AllowHttpErrors | Out-Null
  $probe = Invoke-GitHub -Path "/repos/$Login/$RepoName" -AllowHttpErrors
  $exists = $probe.StatusCode -eq 200
} catch {
  $exists = $false
}
if (-not $exists) {
  Write-Host "== Creating private repo $Login/$RepoName"
  $created = Invoke-GitHub -Method POST -Path '/user/repos' -Body @{
    name      = $RepoName
    private   = $true
    auto_init = $false
    description = 'SwipeClean - swipe to review and clean the iOS photo library'
  }
  if ($created.StatusCode -notin 200, 201) { throw "Repo creation failed: $($created.StatusCode)" }
} else {
  Write-Host "== Repo $Login/$RepoName already exists"
}

# 3. commit and push
Set-Location $RepoRoot
if (-not (Test-Path (Join-Path $RepoRoot '.git'))) {
  git init -b main | Out-Host
}
git config user.name $Login
git config user.email "$Login@users.noreply.github.com"
git add -A
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
  git commit -m "feat: SwipeClean iOS app" | Out-Host
}

$remoteUrl = "https://x-access-token:$Token@github.com/$Login/$RepoName.git"
git remote remove origin 2>$null
git remote add origin $remoteUrl
$startedAt = (Get-Date).ToUniversalTime().AddSeconds(-30)
git push origin HEAD:refs/heads/main --force | Out-Host
Write-Host "== Pushed to https://github.com/$Login/$RepoName"

# 4. wait for the run that the push just started
Start-Sleep -Seconds 10
$run = $null
for ($i = 0; $i -lt 20; $i++) {
  $runs = (Invoke-GitHub -Path "/repos/$Login/$RepoName/actions/runs?per_page=10").Content | ConvertFrom-Json
  $candidate = $runs.workflow_runs |
    Where-Object { $_.head_branch -eq 'main' } |
    Sort-Object -Property created_at -Descending |
    Select-Object -First 1
  if ($candidate) { $run = $candidate; break }
  Start-Sleep -Seconds 6
}
if (-not $run) { throw 'No workflow run appeared' }
Write-Host "== Run #$($run.run_number) id=$($run.id)"
Write-Host "== $($run.html_url)"

# 5. poll
$deadline = (Get-Date).AddMinutes(40)
while ($run.status -ne 'completed' -and (Get-Date) -lt $deadline) {
  Start-Sleep -Seconds 20
  $run = (Invoke-GitHub -Path "/repos/$Login/$RepoName/actions/runs/$($run.id)").Content | ConvertFrom-Json
  Write-Host ("== [{0}] {1} / {2}" -f (Get-Date -Format 'HH:mm:ss'), $run.status, $run.conclusion)
}
Write-Host "== Final: $($run.status) $($run.conclusion)"

if ($run.conclusion -ne 'success') {
  try {
    $logs = Invoke-GitHub -Path "/repos/$Login/$RepoName/actions/runs/$($run.id)/logs" -AllowHttpErrors
    if ($logs.StatusCode -eq 302) {
      $zip = Join-Path $env:TEMP "swipeclean-logs-$($run.id).zip"
      Invoke-WebRequest -Uri $logs.Headers.Location -OutFile $zip -TimeoutSec 300
      $dir = Join-Path $env:TEMP "swipeclean-logs-$($run.id)"
      Expand-Archive $zip -DestinationPath $dir -Force
      Get-ChildItem $dir -Recurse -File | ForEach-Object {
        Write-Host "----- $($_.Name) -----"
        Get-Content $_.FullName -Tail 120
      }
    }
  } catch { Write-Host "Could not fetch logs: $($_.Exception.Message)" }
  throw "Build failed: $($run.conclusion)"
}

# 6. download artifact
$arts = (Invoke-GitHub -Path "/repos/$Login/$RepoName/actions/runs/$($run.id)/artifacts").Content | ConvertFrom-Json
$artifact = $arts.artifacts | Where-Object { $_.name -eq 'SwipeClean-ipa' } | Select-Object -First 1
if (-not $artifact) { throw 'IPA artifact not found' }
Write-Host "== Artifact $($artifact.name) $([math]::Round($artifact.size_in_bytes / 1MB, 2)) MB"

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
$zipPath = Join-Path $DistDir 'swipeclean-artifact.zip'
$resp = Invoke-GitHub -Path "/repos/$Login/$RepoName/actions/artifacts/$($artifact.id)/zip" -AllowHttpErrors
if ($resp.StatusCode -eq 302) {
  Invoke-WebRequest -Uri $resp.Headers.Location -OutFile $zipPath -TimeoutSec 600
} else {
  [IO.File]::WriteAllBytes($zipPath, $resp.Content)
}
Expand-Archive $zipPath -DestinationPath $DistDir -Force
Remove-Item $zipPath -Force
Get-ChildItem $DistDir | Select-Object Name, Length | Format-Table -AutoSize
Write-Host '== DONE'
