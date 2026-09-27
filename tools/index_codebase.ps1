# tools/index_codebase.ps1
# Codebase indexer for Godot 4 project Kamdraaa

$projectDir = "e:\kamdraaa-game"
$scriptsDir = "$projectDir\scripts"
$scenesDir = "$projectDir\scenes"
$projectGodot = "$projectDir\project.godot"
$outputMd = "$projectDir\PROJECT_INDEX.md"
$outputJson = "$projectDir\.agents\codebase_index.json"

Write-Host "Indexing Godot codebase..." -ForegroundColor Cyan

# 1. Parse project.godot
$autoloads = @()
$inputActions = @()
$mainScene = ""

if (Test-Path $projectGodot) {
    $godotContent = Get-Content $projectGodot -Raw
    
    # Autoloads
    if ($godotContent -match '(?ms)\[autoload\]\s*(.*?)(?=\r?\n\[|\Z)') {
        $autoloadBlock = $matches[1]
        $autoloadLines = $autoloadBlock -split '\r?\n'
        foreach ($line in $autoloadLines) {
            if ($line -match '^\s*([A-Za-z0-9_]+)\s*=\s*"\*?(res://[^"]+)"') {
                $autoloads += [PSCustomObject]@{
                    Name = $matches[1]
                    Path = $matches[2]
                }
            }
        }
    }

    # Main Scene
    if ($godotContent -match 'main_scene="([^"]+)"') {
        $mainScene = $matches[1]
    }

    # Input Actions
    if ($godotContent -match '(?ms)\[input\]\s*(.*?)(?=\r?\n\[|\Z)') {
        $inputBlock = $matches[1]
        $inputLines = $inputBlock -split '\r?\n'
        foreach ($line in $inputLines) {
            if ($line -match '^\s*([A-Za-z0-9_]+)\s*=\{') {
                $inputActions += $matches[1]
            }
        }
    }
}

# 2. Parse Scripts (*.gd)
$parsedScripts = @()
$scriptFiles = Get-ChildItem -Path $scriptsDir -Filter "*.gd" -File | Sort-Object Name

foreach ($sf in $scriptFiles) {
    $lines = Get-Content $sf.FullName -Encoding UTF8
    $className = ""
    $extendsClass = ""
    $signals = @()
    $exports = @()
    $functions = @()
    $description = ""

    foreach ($line in $lines) {
        $trimmed = $line.Trim()

        if ($description -eq "" -and $trimmed -match '^#\s*(.+)$') {
            $description = $matches[1]
        }
        elseif ($trimmed -match '^class_name\s+([A-Za-z0-9_]+)') {
            $className = $matches[1]
        }
        elseif ($trimmed -match '^extends\s+([A-Za-z0-9_]+)') {
            $extendsClass = $matches[1]
        }
        elseif ($trimmed -match '^signal\s+([A-Za-z0-9_]+(\(.*?\))?)') {
            $signals += $matches[1]
        }
        elseif ($trimmed -match '^@export\s+(var\s+[A-Za-z0-9_]+(\s*:\s*[A-Za-z0-9_]+)?)') {
            $exports += $matches[1]
        }
        elseif ($trimmed -match '^func\s+([a-zA-Z0-9_]+)\s*(\([^\)]*\))(\s*->\s*[A-Za-z0-9_]+)?\s*:') {
            $fnName = $matches[1]
            $fnArgs = $matches[2]
            $fnRet = if ($matches[3]) { $matches[3].Trim() } else { "" }
            $functions += "$fnName$fnArgs$fnRet"
        }
    }

    $parsedScripts += [PSCustomObject]@{
        Name = $sf.Name
        Path = "scripts/$($sf.Name)"
        ClassName = $className
        Extends = $extendsClass
        Lines = $lines.Count
        Description = $description
        Signals = $signals
        Exports = $exports
        Functions = $functions
    }
}

# 3. Parse Scenes (*.tscn)
$parsedScenes = @()
$sceneFiles = Get-ChildItem -Path $scenesDir -Filter "*.tscn" -File | Sort-Object Name

foreach ($sc in $sceneFiles) {
    $lines = Get-Content $sc.FullName
    $rootNode = ""
    $rootType = ""
    $nodes = @()

    foreach ($line in $lines) {
        if ($line -match '^\[node\s+name="([^"]+)"\s+type="([^"]+)"(?:\s+parent="([^"]*)")?') {
            $nName = $matches[1]
            $nType = $matches[2]
            $nParent = if ($matches[3]) { $matches[3] } else { "(root)" }
            
            if ($nParent -eq "(root)") {
                $rootNode = $nName
                $rootType = $nType
            } else {
                $nodes += "$nParent/$nName ($nType)"
            }
        }
    }

    $parsedScenes += [PSCustomObject]@{
        Name = $sc.Name
        Path = "scenes/$($sc.Name)"
        RootNode = $rootNode
        RootType = $rootType
        NodeCount = $nodes.Count + 1
        Nodes = $nodes
    }
}

# 4. Generate JSON Index
$indexData = [PSCustomObject]@{
    GeneratedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
    ProjectName = "Kamdraaa"
    Engine = "Godot 4.7.2"
    MainScene = $mainScene
    Autoloads = $autoloads
    InputActions = $inputActions
    Scripts = $parsedScripts
    Scenes = $parsedScenes
}

$jsonDir = Split-Path $outputJson -Parent
if (-not (Test-Path $jsonDir)) { New-Item -ItemType Directory -Path $jsonDir -Force | Out-Null }
$indexData | ConvertTo-Json -Depth 6 | Set-Content -Path $outputJson -Encoding UTF8

# 5. Generate Markdown Index
$mdLines = [System.Collections.Generic.List[string]]::new()
$b = [char]96

$mdLines.Add("# Kamdraaa - Codebase Index and Architecture Map")
$mdLines.Add("*Auto-generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') for instant AI navigation.*`n")

$mdLines.Add("## 1. Project Overview")
$mdLines.Add("- **Game**: Kamdraaa (Psychological Noir Detective Adventure)")
$mdLines.Add("- **Engine**: Godot Engine 4.7.2 stable (Windows 64-bit)")
$mdLines.Add("- **Main Scene**: $b$mainScene$b")
$mdLines.Add("- **Resolution**: 1280x720 (stretch mode: canvas_items)`n")

$mdLines.Add("## 2. Autoload Singletons (Global Systems)")
$mdLines.Add("| Singleton | Script Path | Responsibility |")
$mdLines.Add("|---|---|---|")
foreach ($al in $autoloads) {
    $desc = switch ($al.Name) {
        "SoundManager" { "Procedural audio synth (footsteps, phone, clue chimes, rustle, clicks, ambient)" }
        "SaveManager" { "JSON slots save/load, quicksave F5/K, quickload F9/L, persistent data" }
        "SettingsManager" { "Audio bus volumes, CRT shader, V-Sync, Fullscreen, key rebinding" }
        "ClueManager" { "Investigation case file, 5 clues discovery, hints, signals" }
        default { "Global Autoload" }
    }
    $mdLines.Add("| $b$($al.Name)$b | $b$($al.Path)$b | $desc |")
}
$mdLines.Add("")

$mdLines.Add("## 3. Input Actions")
$actionsFormatted = ($inputActions | ForEach-Object { "$b$_$b" }) -join ", "
$mdLines.Add($actionsFormatted)
$mdLines.Add("")

$mdLines.Add("## 4. Scripts Inventory ($($parsedScripts.Count) scripts in `scripts/`)")
foreach ($s in $parsedScripts) {
    $mdLines.Add("### [$($s.Name)]($($s.Path)) ($($s.Lines) lines)")
    if ($s.Description) { $mdLines.Add("*$($s.Description)*`n") }
    if ($s.Extends) { $mdLines.Add("- **Extends**: $b$($s.Extends)$b") }
    if ($s.ClassName) { $mdLines.Add("- **Class**: $b$($s.ClassName)$b") }
    if ($s.Signals.Count -gt 0) { 
        $sigStr = ($s.Signals | ForEach-Object { "$b$_$b" }) -join ", "
        $mdLines.Add("- **Signals**: $sigStr") 
    }
    if ($s.Exports.Count -gt 0) { 
        $expStr = ($s.Exports | ForEach-Object { "$b$_$b" }) -join ", "
        $mdLines.Add("- **Exports**: $expStr") 
    }
    if ($s.Functions.Count -gt 0) {
        $mdLines.Add("- **Key Functions**:")
        $topFns = $s.Functions | Select-Object -First 10
        foreach ($fn in $topFns) {
            $mdLines.Add("  - $b$fn$b")
        }
        if ($s.Functions.Count -gt 10) {
            $mdLines.Add("  - *... and $($s.Functions.Count - 10) more functions*")
        }
    }
    $mdLines.Add("")
}

$mdLines.Add("## 5. Scenes Inventory ($($parsedScenes.Count) scenes in `scenes/`)")
foreach ($sc in $parsedScenes) {
    $mdLines.Add("### [$($sc.Name)]($($sc.Path)) (Root: $b$($sc.RootNode)$b [$($sc.RootType)])")
    $mdLines.Add("- Node count: $($sc.NodeCount)")
    if ($sc.Nodes.Count -gt 0) {
        $mdLines.Add("- **Node Tree Hierarchy**:")
        $topNodes = $sc.Nodes | Select-Object -First 16
        foreach ($nd in $topNodes) {
            $mdLines.Add("  - $nd")
        }
        if ($sc.Nodes.Count -gt 16) {
            $mdLines.Add("  - *... and $($sc.Nodes.Count - 16) more child nodes*")
        }
    }
    $mdLines.Add("")
}

$mdLines | Set-Content -Path $outputMd -Encoding UTF8

Write-Host "Index generated successfully:" -ForegroundColor Green
Write-Host "  - Markdown Index: $outputMd" -ForegroundColor Green
Write-Host "  - JSON Schema:    $outputJson" -ForegroundColor Green
