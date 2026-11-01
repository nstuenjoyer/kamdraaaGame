param(
    [string]$GodotExe = 'C:\Users\ilya\Desktop\Godot_v4.7.2-stable_win64.exe',
    [switch]$PackedGame,
    [ValidateSet('gl_compatibility','forward_plus')][string]$Renderer = 'gl_compatibility'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$reviewData = Join-Path $projectRoot ('.godot/chapter-check-arm-motion-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $reviewData -Force | Out-Null
$previousAppData = $env:APPDATA
$previousReviewRoot = $env:KAMDRAAA_ARM_REVIEW_ROOT
try {
    $env:APPDATA = $reviewData
    $env:KAMDRAAA_ARM_REVIEW_ROOT = $projectRoot
    $log = Join-Path $reviewData 'arm-motion.log'
    $arguments = @('--path',$projectRoot,'--resolution','1280x720','--rendering-method',$Renderer,'--audio-driver','Dummy','--log-file',$log,'--script','res://AI/review/check_arm_motion.gd')
    if ($PackedGame) {
        $GodotExe = Join-Path $projectRoot 'build/dist/Kamdraaa.exe'
        $arguments[$arguments.IndexOf('--script')+1] = Join-Path $projectRoot 'AI/review/check_arm_motion.gd'
        $arguments += @('--main-pack',(Join-Path $projectRoot 'build/dist/Kamdraaa.pck'))
    }
    $process = Start-Process -FilePath $GodotExe -ArgumentList $arguments -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(90000)) { Stop-Process -Id $process.Id; throw 'Arm motion checks timed out' }
    $report = Get-Content -LiteralPath $log -Encoding UTF8
    $report | Write-Output
    if ($process.ExitCode -ne 0 -or $report -match 'SCRIPT ERROR|^ERROR:|^FAIL ') { throw "Arm motion checks failed: $log" }
    $python = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
    if (-not (Test-Path -LiteralPath $python)) {
        $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
        if ($pythonCommand) { $python = $pythonCommand.Source }
    }
    if (Test-Path -LiteralPath $python) {
        @'
from pathlib import Path
import os
from PIL import Image
root = Path(os.environ['KAMDRAAA_ARM_REVIEW_ROOT'])
streams = [('draw-stow',84,33),('sweep',61,50),('turn-draw',30,66)]
for name, count, duration in streams:
    folder = root/'.godot/arm-motion-frames'/name
    files = [folder/f'{i:03d}.png' for i in range(count)]
    assert all(path.is_file() for path in files), name
    frames = [Image.open(path).convert('RGB') for path in files]
    durations = [30,30,40]*(count//3) if duration ==33 else [60,70,70]*(count//3) if duration ==66 else duration
    target = root/'AI/review/images/arm-motion'/f'{name}.gif'
    frames[0].save(target,save_all=True,append_images=frames[1:],duration=durations,loop=0,disposal=2)
    print(target)
'@ | & $python -X utf8 -
        if ($LASTEXITCODE -ne 0) { throw 'Could not assemble the arm motion preview GIFs' }
    } else {
        Write-Warning 'Python/Pillow unavailable; PNG motion frames and contact sheets were saved.'
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:KAMDRAAA_ARM_REVIEW_ROOT = $previousReviewRoot
}
