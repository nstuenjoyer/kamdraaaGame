param(
    [string]$GodotExe = 'C:\Users\ilya\Desktop\Godot_v4.7.2-stable_win64.exe'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$previousAppData = $env:APPDATA
try {
    foreach ($resolution in @('960x600','1536x864')) {
        $reviewData = Join-Path $projectRoot ('.godot/chapter-check-front-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $reviewData -Force | Out-Null
        $env:APPDATA = $reviewData
        $log = Join-Path $reviewData 'frontend.log'
        $arguments = @('--path', $projectRoot, '--resolution', $resolution, '--rendering-method', 'gl_compatibility', '--log-file', $log, '--script', 'res://docs/review/check_frontend.gd')
        $process = Start-Process -FilePath $GodotExe -ArgumentList $arguments -WindowStyle Hidden -PassThru
        if (-not $process.WaitForExit(60000)) {
            Stop-Process -Id $process.Id
            throw 'Frontend checks exceeded 60 seconds'
        }
        $report = Get-Content -LiteralPath $log -Encoding UTF8
        $report | Write-Output
        if ($process.ExitCode -ne 0 -or $report -match 'SCRIPT ERROR|^ERROR:|^FAIL ') {
            throw "Frontend checks failed. Log: $log"
        }
    }
} finally {
    $env:APPDATA = $previousAppData
}
