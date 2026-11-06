param(
    [string]$GodotExe = 'C:\Users\ilya\Desktop\Godot_v4.7.2-stable_win64.exe',
    [switch]$Visual,
    [switch]$Route,
    [switch]$EnemyOnly,
    [switch]$AnimationOnly,
    [switch]$Entry
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$reviewData = Join-Path $projectRoot ('.godot/3d-check-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $reviewData -Force | Out-Null
$previousAppData = $env:APPDATA
$previousCapture = $env:KAMDRAAA_3D_CAPTURE_DIR
try {
    $env:APPDATA = $reviewData
    $env:KAMDRAAA_3D_CAPTURE_DIR = Join-Path $reviewData 'captures'
    $log = Join-Path $reviewData 'checks.log'
    $checkScript = if ($Entry) { 'res://AI/review/check_3d_entry.gd' } elseif ($AnimationOnly) { 'res://AI/review/check_dasha_animation.gd' } else { 'res://AI/review/check_chapter_3d.gd' }
    $arguments = @('--path', $projectRoot, '--log-file', $log, '--script', $checkScript)
    if ($Visual) {
        $arguments += @('--resolution', '1280x720', '--rendering-method', 'forward_plus', '--', '--visual')
    } else { $arguments = @('--headless') + $arguments }
    if ($Route) { $arguments += @('--', '--route') }
    if ($EnemyOnly) { $arguments += @('--', '--enemy-only') }
    $process = Start-Process -FilePath $GodotExe -ArgumentList $arguments -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(180000)) {
        Stop-Process -Id $process.Id
        throw '3D checks exceeded 180 seconds'
    }
    $report = Get-Content -LiteralPath $log -Encoding UTF8
    $report | Write-Output
    # This Windows host reports the same certificate-store startup error in the
    # untouched 2D baseline. Keep it visible; it is unrelated to offline checks.
    $unexpectedErrors = $report | Where-Object { $_ -match 'SCRIPT ERROR|^ERROR:|^FAIL ' -and $_ -ne 'ERROR: Failed to read the root certificate store.' }
    if ($process.ExitCode -ne 0 -or $unexpectedErrors) { throw "3D check failed. Log: $log" }
} finally {
    $env:APPDATA = $previousAppData
    $env:KAMDRAAA_3D_CAPTURE_DIR = $previousCapture
}
