param([string]$GodotExe = $env:GODOT_EXE)

$ErrorActionPreference = 'Stop'
if (-not $GodotExe) { $GodotExe = (Get-Command godot -ErrorAction Stop).Source }
$projectDir = Split-Path $PSScriptRoot -Parent
$testDir = Join-Path $projectDir ('.godot\review-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testDir -Force | Out-Null
$originalAppData = $env:APPDATA
try {
    $env:APPDATA = $testDir
    $logPath = Join-Path $testDir 'regression.log'
    $checkArgs = '--headless --path "{0}" --script res://AI/review/reproduce.gd --quit-after 1800 --log-file "{1}"' -f $projectDir, $logPath
    $checkProcess = Start-Process -FilePath $GodotExe -ArgumentList $checkArgs -WindowStyle Hidden -Wait -PassThru
    if ($checkProcess.ExitCode -ne 0) { throw "Godot exited with $($checkProcess.ExitCode). See $logPath" }
    $logText = Get-Content -LiteralPath $logPath -Raw
    if ($logText -match 'SCRIPT ERROR|ERROR:|FAIL ' -or $logText -notmatch 'REGRESSION_RESULT checks=\d+ failures=0') {
        throw "Regression checks failed. See $logPath"
    }
    Write-Host "Checks passed. Log: $logPath"
} finally {
    $env:APPDATA = $originalAppData
}
