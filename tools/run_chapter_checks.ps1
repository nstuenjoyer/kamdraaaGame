param(
    [string]$GodotExe = 'C:\Users\ilya\Desktop\Godot_v4.7.2-stable_win64.exe',
    [switch]$Visual,
    [switch]$PackedGame,
    [switch]$Route,
    [ValidateSet('gl_compatibility','forward_plus')][string]$Renderer = 'gl_compatibility'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$reviewData = Join-Path $projectRoot ('.godot/chapter-check-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $reviewData -Force | Out-Null
$previousAppData = $env:APPDATA
try {
    $env:APPDATA = $reviewData
    $log = Join-Path $reviewData 'checks.log'
    $arguments = @('--path', $projectRoot, '--log-file', $log, '--script', 'res://docs/review/check_chapter.gd')
    if ($Visual) {
        $arguments = @('--path', $projectRoot, '--resolution', '1280x720', '--rendering-method', $Renderer, '--log-file', $log, '--script', 'res://docs/review/capture_chapter.gd')
    } else {
        $arguments = @('--headless') + $arguments
    }
    if ($Route) { $arguments[$arguments.IndexOf('--script') + 1] = 'res://docs/review/check_apartment_route.gd' }
    if ($PackedGame) {
        $GodotExe = Join-Path $projectRoot 'build/dist/Kamdraaa.exe'
        $scriptName = if ($Visual) { 'capture_chapter.gd' } elseif ($Route) { 'check_apartment_route.gd' } else { 'check_chapter.gd' }
        $arguments[$arguments.IndexOf('--script') + 1] = Join-Path $projectRoot ('docs/review/' + $scriptName)
        $arguments += @('--main-pack', (Join-Path $projectRoot 'build/dist/Kamdraaa.pck'))
    }
    $process = Start-Process -FilePath $GodotExe -ArgumentList $arguments -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(180000)) {
        Stop-Process -Id $process.Id
        throw 'Chapter checks exceeded 180 seconds'
    }
    $report = Get-Content -LiteralPath $log -Encoding UTF8
    $report | Write-Output
    if ($process.ExitCode -ne 0 -or $report -match 'SCRIPT ERROR|^ERROR:|^FAIL ') {
        throw "Chapter check failed. Log: $log"
    }
} finally {
    $env:APPDATA = $previousAppData
}
