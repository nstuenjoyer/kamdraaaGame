param([string]$Installer = '', [string]$AppId = '{D37F2C0B-97A4-4A6E-8041-EE5277189A0C}')
$ErrorActionPreference = 'Stop'
$workspace = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
if (-not $Installer) { $Installer = Join-Path $workspace 'installer/Kamdraaa_Setup_v0.2.0.exe' }
$registryPaths = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\${AppId}_is1",
    "HKCU:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\${AppId}_is1",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\${AppId}_is1",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\${AppId}_is1"
)
foreach ($key in $registryPaths) {
    if (Test-Path -LiteralPath $key) { throw 'An existing installation uses this AppId. Use an isolated test build; do not overwrite the real installation.' }
}
$token = [guid]::NewGuid().ToString('N')
$testRoot = Join-Path $workspace ('.godot/installer-check-' + $token)
$installDir = [IO.Path]::GetFullPath((Join-Path $testRoot 'Камдраа тест'))
if (-not $installDir.StartsWith($workspace + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Test path must stay in the workspace' }
$group = 'Kamdraaa check ' + $token
$groupPath = Join-Path ([Environment]::GetFolderPath('Programs')) $group
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$report = [Collections.Generic.List[string]]::new()
function Check([string]$Label, [bool]$Condition) {
    $line = if ($Condition) { 'PASS ' + $Label } else { 'FAIL ' + $Label }
    $report.Add($line)
    Write-Output $line
    if (-not $Condition) { throw $line }
}
function Install([string]$LogName) {
    $log = Join-Path $testRoot $LogName
    $arguments = @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-','/CURRENTUSER','/LANG=russian',('/DIR="' + $installDir + '"'),('/GROUP="' + $group + '"'),'/MERGETASKS="!desktopicon"',('/LOG="' + $log + '"'))
    $process = Start-Process -FilePath $Installer -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
    Check ('installer exit ' + $LogName) ($process.ExitCode -eq 0)
}
$ownedRegistry = $null
try {
    Install 'install.log'
    foreach ($name in @('Kamdraaa.exe','Kamdraaa.pck','unins000.exe','unins000.dat','Удалить Kamdraaa.lnk')) {
        Check ('installed ' + $name) (Test-Path -LiteralPath (Join-Path $installDir $name))
    }
    foreach ($name in @('Kamdraaa.exe','Kamdraaa.pck')) {
        $installedHash = (Get-FileHash -LiteralPath (Join-Path $installDir $name)).Hash
        $sourceHash = (Get-FileHash -LiteralPath (Join-Path $workspace ('build/dist/' + $name))).Hash
        Check ('payload hash ' + $name) ($installedHash -eq $sourceHash)
    }
    $ownedRegistry = $registryPaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    Check 'registered in Windows installed apps' ($null -ne $ownedRegistry)
    $entry = Get-ItemProperty -LiteralPath $ownedRegistry
    Check 'registry points to test installation' ($entry.InstallLocation.TrimEnd('\') -eq $installDir.TrimEnd('\'))
    Check 'registered uninstall command exists' ($entry.UninstallString -like '*unins000.exe*')
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut((Join-Path $installDir 'Удалить Kamdraaa.lnk'))
    Check 'folder uninstall shortcut target' ($link.TargetPath -eq (Join-Path $installDir 'unins000.exe'))
    $menuLinks = @(Get-ChildItem -LiteralPath $groupPath -Filter '*.lnk')
    Check 'Start menu game and uninstall shortcuts' ($menuLinks.Count -eq 2)
    $customFile = Join-Path $installDir 'user-owned-note.txt'
    Set-Content -LiteralPath $customFile -Value 'Keep user-owned files.' -Encoding UTF8
    Install 'reinstall.log'
    Check 'reinstall keeps user-owned file' (Test-Path -LiteralPath $customFile)
    Check 'reinstall reuses single uninstaller' (@(Get-ChildItem -LiteralPath $installDir -Filter 'unins*.exe').Count -eq 1)
    $oldAppData = $env:APPDATA
    try {
        $env:APPDATA = Join-Path $testRoot 'player-profile'
        $saveDir = Join-Path $env:APPDATA 'Godot/app_userdata/KamdraaaGame/saves'
        New-Item -ItemType Directory -Path $saveDir -Force | Out-Null
        $sentinel = Join-Path $saveDir 'installer-check.txt'
        Set-Content -LiteralPath $sentinel -Value 'Keep saved progress.' -Encoding UTF8
        $gameLog = Join-Path $testRoot 'installed-game.log'
        $game = Start-Process -FilePath (Join-Path $installDir 'Kamdraaa.exe') -WorkingDirectory $installDir -ArgumentList @('--resolution','1280x720','--quit-after','120','--log-file',('"' + $gameLog + '"')) -WindowStyle Hidden -Wait -PassThru
        Check 'installed game starts and exits' ($game.ExitCode -eq 0)
        $output = Get-Content -LiteralPath $gameLog -Raw -Encoding UTF8
        Check 'installed game has no resource/script errors' ($output -notmatch 'SCRIPT ERROR|(?m)^ERROR:|Failed to load')
    } finally { $env:APPDATA = $oldAppData }
    $uninstallLog = Join-Path $testRoot 'uninstall.log'
    $uninstaller = Join-Path $installDir 'unins000.exe'
    $uninstall = Start-Process -FilePath $uninstaller -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',('/LOG="' + $uninstallLog + '"')) -WindowStyle Hidden -Wait -PassThru
    Check 'uninstaller exit' ($uninstall.ExitCode -eq 0)
    for ($i = 0; $i -lt 30 -and (Test-Path -LiteralPath $uninstaller); $i++) { Start-Sleep -Milliseconds 100 }
    foreach ($name in @('Kamdraaa.exe','Kamdraaa.pck','unins000.exe','unins000.dat','Удалить Kamdraaa.lnk')) {
        Check ('removed ' + $name) (-not (Test-Path -LiteralPath (Join-Path $installDir $name)))
    }
    Check 'Windows uninstall entry removed' (-not (Test-Path -LiteralPath $ownedRegistry))
    Check 'Start menu shortcuts removed' (-not (Test-Path -LiteralPath $groupPath))
    Check 'user-owned file preserved' (Test-Path -LiteralPath $customFile)
    Check 'saved progress preserved' ((Get-Content -LiteralPath $sentinel -Raw).Trim() -eq 'Keep saved progress.')
    $report.Add('INSTALLER_CHECK PASSED')
} finally {
    $report | Set-Content -LiteralPath (Join-Path $testRoot 'report.txt') -Encoding UTF8
    Write-Output ('REPORT ' + (Join-Path $testRoot 'report.txt'))
}
