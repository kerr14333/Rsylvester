<#
.SYNOPSIS
  Build + R CMD check --as-cran the sylvester package across several R versions
  using rocker/r-ver Docker images.

.EXAMPLE
  ./docker/run-matrix.ps1
  ./docker/run-matrix.ps1 -Versions 4.3.1,4.5.1
#>
param(
    [string[]] $Versions = @('4.2.3', '4.3.3', '4.5.1')
)

# NOTE: do NOT use $ErrorActionPreference='Stop' here. Docker BuildKit writes
# its progress to stderr; under 'Stop', PowerShell turns the first stderr line
# into a terminating error and aborts the build. We drive off $LASTEXITCODE
# instead. --progress=plain also keeps the logs readable.
$ErrorActionPreference = 'Continue'
$env:DOCKER_BUILDKIT = '1'

# Repo root = parent of this script's dir; build context must be repo root.
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir
$LogDir    = Join-Path $ScriptDir 'logs'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

# Fail fast if the daemon is down.
docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker daemon not reachable. Start Docker Desktop and retry." -ForegroundColor Red
    exit 2
}

$results = @()
foreach ($v in $Versions) {
    $tag = "sylvester-check:$v"
    $log = Join-Path $LogDir "R-$v.log"
    Write-Host "==== R $v : build image ===="
    docker build --progress=plain -f (Join-Path $ScriptDir 'Dockerfile') `
        --build-arg "R_VERSION=$v" -t $tag $RepoRoot 2>&1 |
        Tee-Object -FilePath $log
    $buildOk = ($LASTEXITCODE -eq 0)

    $checkOk = $false
    if ($buildOk) {
        Write-Host "==== R $v : R CMD check --as-cran ===="
        docker run --rm $tag 2>&1 | Tee-Object -FilePath $log -Append
        $checkOk = ($LASTEXITCODE -eq 0)
    }

    $status = if (-not $buildOk) { 'BUILD-FAIL' } elseif ($checkOk) { 'PASS' } else { 'CHECK-FAIL' }
    $results += [pscustomobject]@{ R = $v; Status = $status; Log = $log }
}

Write-Host "`n================ SUMMARY ================"
$results | Format-Table -AutoSize
if ($results.Status -contains 'CHECK-FAIL' -or $results.Status -contains 'BUILD-FAIL') { exit 1 }
