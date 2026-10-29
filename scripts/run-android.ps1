<#
.SYNOPSIS
    Start the family_pixel emulator when needed and run the Flutter Android app.

.DESCRIPTION
    Keeps the Android SDK, AVD, Gradle cache and JDK in the locations used on
    this workstation. Extra arguments are forwarded to `flutter run`.
#>
[CmdletBinding()]
param(
    [string]$Device = 'emulator-5554',
    [switch]$ColdBoot,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$mobile = Join-Path $repo 'apps\mobile'
$sdk = $env:ANDROID_HOME
$avdHome = 'D:\AppData\Local\Android\avd'
$jdk = 'C:\Program Files\Java\jdk-22'
$gradleHome = 'D:\AppData\Local\Gradle'
$avdName = 'family_pixel'

if (-not $sdk -or -not (Test-Path -LiteralPath $sdk)) {
    throw 'ANDROID_HOME is not configured or does not exist.'
}
if (-not (Test-Path -LiteralPath $jdk)) {
    throw "JDK 22 not found at $jdk. Flutter/Gradle needs JDK 17-22 for this project."
}
if (-not (Test-Path -LiteralPath $mobile)) {
    throw "Flutter project not found at $mobile."
}

$env:JAVA_HOME = $jdk
$env:ANDROID_AVD_HOME = $avdHome
$env:GRADLE_USER_HOME = $gradleHome
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
# The Tsinghua mirror used for the SDK does not carry this version's engine
# Maven artifacts. The Flutter China mirror is fast and hosts all of them.
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'

$adb = Join-Path $sdk 'platform-tools\adb.exe'
$emulator = Join-Path $sdk 'emulator\emulator.exe'

& $adb start-server | Out-Null
$online = (& $adb devices) | Select-String -Pattern "^$([regex]::Escape($Device))\s+device"
if (-not $online) {
    Write-Host "Starting Android emulator '$avdName'..." -ForegroundColor Cyan
    $arguments = @('-avd', $avdName, '-gpu', 'host', '-no-boot-anim')
    if ($ColdBoot) {
        $arguments += '-no-snapshot-load'
    }
    Start-Process -FilePath $emulator -ArgumentList $arguments -WorkingDirectory $sdk | Out-Null

    $deadline = (Get-Date).AddMinutes(3)
    do {
        Start-Sleep -Seconds 3
        $booted = (& $adb -s $Device shell getprop sys.boot_completed 2>$null) -join ''
    } while ($booted.Trim() -ne '1' -and (Get-Date) -lt $deadline)

    if ($booted.Trim() -ne '1') {
        throw "Emulator $Device did not finish booting within 3 minutes."
    }
    Start-Sleep -Seconds 2
    Write-Host 'Emulator is ready.' -ForegroundColor Green
}

Push-Location $mobile
try {
    Write-Host "Running Flutter on $Device..." -ForegroundColor Cyan
    & flutter --no-version-check run -d $Device @FlutterArgs
}
finally {
    Pop-Location
}
