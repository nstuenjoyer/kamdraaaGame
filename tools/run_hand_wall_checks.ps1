param(
    [string]$GodotExe = 'C:\Users\ilya\Desktop\Godot_v4.7.2-stable_win64.exe',
    [switch]$PackedGame,
    [ValidateSet('gl_compatibility','forward_plus')][string]$Renderer = 'gl_compatibility'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$dataRoot = Join-Path $projectRoot ('.godot/chapter-check-hand-wall-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dataRoot -Force | Out-Null
$previousAppData = $env:APPDATA
try {
    $env:APPDATA = $dataRoot
    $log = Join-Path $dataRoot 'hand-wall.log'
    $arguments = @('--path',$projectRoot,'--resolution','1280x720','--rendering-method',$Renderer,'--log-file',$log,'--script','res://AI/review/check_hand_wall_light.gd')
    if ($PackedGame) {
        $GodotExe = Join-Path $projectRoot 'build/dist/Kamdraaa.exe'
        $arguments[$arguments.IndexOf('--script')+1] = Join-Path $projectRoot 'AI/review/check_hand_wall_light.gd'
        $arguments += @('--main-pack',(Join-Path $projectRoot 'build/dist/Kamdraaa.pck'))
    }
    $process = Start-Process -FilePath $GodotExe -ArgumentList $arguments -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(60000)) { Stop-Process -Id $process.Id; throw 'Hand-wall checks timed out' }
    $report = Get-Content -LiteralPath $log -Encoding UTF8
    $report | Write-Output
    if ($process.ExitCode -ne 0 -or $report -match 'SCRIPT ERROR|^ERROR:|^FAIL ') { throw "Hand-wall checks failed: $log" }
} finally { $env:APPDATA = $previousAppData }
