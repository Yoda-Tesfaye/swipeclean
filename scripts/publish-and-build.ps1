# Publish SwipeClean, build it on GitHub's macOS runner and unpack the .ipa.
#
# Uses the GitHub credential already stored by Git Credential Manager, so no
# token has to be typed into a chat window. Run it after:
#   git-credential-manager github login --device
#
#   pwsh -File scripts\publish-and-build.ps1

$ErrorActionPreference = 'Stop'
$ApiBase = 'https://api.github.com'
$RepoName = 'swipeclean'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$DistDir = Join-Path $RepoRoot 'dist'

# 1. Reuse the credential that GCM stored during the device login.
$credential = "protocol=https`nhost=github.com`n`n" | git credential fill 2>$null
if (-not $credential) { throw 'No GitHub credential found. Run: git-credential-manager github login --device' }
$username = ''
$token = ''
foreach ($line in ($credential -split "`n")) {
  if ($line -like 'username=*') { $username = $line.Substring(9).Trim() }
  if ($line -like 'password=*') { $token = $line.Substring(9).Trim() }
}
if (-not $token) { throw 'Could not read the token from Git Credential Manager' }

$Headers = @{
  Authorization          = "Bearer $token"
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
    Method     = $Method
    Uri        = "$ApiBase$Path"
    Headers    = $Headers
    TimeoutSec = 120
  }
  if ($null -ne $Body) {
    $params.Body = ($Body | ConvertTo-Json -Depth 8)
    $params.ContentType = 'application/json'
  }
  if ($AllowHttpErrors) { $params.SkipHttpErrorCheck = $true }
  Invoke-WebRequest @params
}

$me = (Invoke-GitHub -Path '/user').Content | ConvertFrom-Json
$Login = $me.login
Write-Host "== Authenticated as $Login"

# 2. Create the private repo when needed.
$probe = Invoke-GitHub -Path "/repos/$Login/$RepoName" -AllowHttpErrors
if ($probe.StatusCode -ne 200) {
  Write-Host "== Creating private repo $Login/$RepoName"
  $created = Invoke-GitHub -Method POST -Path '/user/repos' -Body @{
    name        = $RepoName
    private     = $true
    auto_init   = $false
    description = 'SwipeClean - swipe to review and clean the iOS photo library'
  }
  Write-Host "== Repo status $($created.StatusCode)"
} else {
  Write-Host "== Repo $Login/$RepoName already exists"
}

# 3. Commit and push.
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

$remoteUrl = "https://x-access-token:$token@github.com/$Login/$RepoName.git"
git remote remove origin 2>$null
git remote add origin $remoteUrl
git push origin HEAD:refs/heads/main --force | Out-Host
if ($LASTEXITCODE -ne 0) {
  throw 'git push failed. If GitHub complains about workflow scope, remove .github/workflows and add the file through the web UI.'
}
Write-Host "== Pushed to https://github.com/$Login/$RepoName"

# 4. Wait for the push-triggered run.
Start-Sleep -Seconds 10
$run = $null
for ($i = 0; $i -lt 20; $i++) {
  $runs = (Invoke-GitHub -Path "/repos/$Login/$RepoName/actions/runs?per_page=10").Content | ConvertFrom-Json
  $run = $runs.workflow_runs | Where-Object { $_.head_branch -eq 'main' } |
    Sort-Object -Property created_at -Descending | Select-Object -First 1
  if ($run) { break }
  Start-Sleep -Seconds 6
}
if (-not $run) { throw 'No workflow run appeared' }
Write-Host "== Run #$($run.run_number) id=$($run.id)"
Write-Host "== $($run.html_url)"

# 5. Poll until finished.
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

# 6. Download and unpack the artifact.
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
