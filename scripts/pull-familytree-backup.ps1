$ErrorActionPreference = 'Stop'

$server = 'root@192.168.1.36'
$remoteDir = '/var/backups/familytree'
$localDir = 'D:\family-genealogy\backups'
$retentionDays = 30

New-Item -ItemType Directory -Force -Path $localDir | Out-Null

$latest = Join-Path $localDir 'latest.sql.gz'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$target = Join-Path $localDir "familytree-$stamp.sql.gz"

& scp -q -o BatchMode=yes "${server}:${remoteDir}/latest.sql.gz" $target
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $target)) {
    throw 'scp failed'
}
& scp -q -o BatchMode=yes "${server}:${remoteDir}/latest.sql.gz.sha256" "${target}.sha256"
Copy-Item -LiteralPath $target -Destination $latest -Force

$hashLine = Get-Content -LiteralPath "${target}.sha256" -TotalCount 1
if ($hashLine) {
    $expected = ($hashLine -split '\s+')[0].ToLowerInvariant()
    $actual = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($expected -ne $actual) {
        throw 'backup checksum mismatch'
    }
}

Get-ChildItem -LiteralPath $localDir -Filter 'familytree-*.sql.gz' |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$retentionDays) } |
    Remove-Item -Force -ErrorAction SilentlyContinue

Write-Output "pulled $target"
