param([string]$GodotExe='C:\Users\ilya\Desktop\Godot_v4.7.2-stable_win64.exe',[switch]$PackedGame)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$reviewData=Join-Path $projectRoot ('.godot/chapter-check-held-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $reviewData -Force | Out-Null
$previousAppData=$env:APPDATA
$previousReviewRoot=$env:KAMDRAAA_HELD_REVIEW_ROOT
try {
    $env:APPDATA=$reviewData
    $env:KAMDRAAA_HELD_REVIEW_ROOT=$projectRoot
    $log=Join-Path $reviewData 'held.log'
    $arguments=@('--path',$projectRoot,'--resolution','1280x720','--rendering-method','gl_compatibility','--log-file',$log,'--script','res://AI/review/check_held_flashlight.gd')
    if ($PackedGame) {
        $GodotExe=Join-Path $projectRoot 'build/dist/Kamdraaa.exe'
        $arguments[$arguments.IndexOf('--script')+1]=Join-Path $projectRoot 'AI/review/check_held_flashlight.gd'
        $arguments+=@('--main-pack',(Join-Path $projectRoot 'build/dist/Kamdraaa.pck'))
    }
    $process=Start-Process -FilePath $GodotExe -ArgumentList $arguments -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(60000)) { Stop-Process -Id $process.Id; throw 'Held flashlight checks timed out' }
    $report=Get-Content -LiteralPath $log -Encoding UTF8
    $report | Write-Output
    if ($process.ExitCode -ne 0 -or $report -match 'SCRIPT ERROR|^ERROR:|^FAIL ') { throw "Held flashlight check failed: $log" }
} finally {
    $env:APPDATA=$previousAppData
    $env:KAMDRAAA_HELD_REVIEW_ROOT=$previousReviewRoot
}
