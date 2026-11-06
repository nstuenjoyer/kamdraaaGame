# Pack actual Blender review frames into animated GIFs using stock Windows WPF.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$previewRoot = Join-Path $projectRoot 'assets/models/characters/dasha_meshy/locomotion_v1/previews'
$durations = @{ walk = 4; run = 3; sneak = 6 }
foreach ($clip in @('walk', 'run', 'sneak')) {
    $encoder = New-Object System.Windows.Media.Imaging.GifBitmapEncoder
    foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $previewRoot $clip) -Filter '*.png' | Sort-Object Name)) {
        $source = New-Object System.Windows.Media.Imaging.BitmapImage
        $source.BeginInit()
        $source.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $source.UriSource = New-Object System.Uri($file.FullName)
        $source.EndInit()
        $metadata = New-Object System.Windows.Media.Imaging.BitmapMetadata('gif')
        $metadata.SetQuery('/grctlext/Delay', [uint16]$durations[$clip])
        $metadata.SetQuery('/grctlext/Disposal', [byte]2)
        $frame = [System.Windows.Media.Imaging.BitmapFrame]::Create($source, $null, $metadata, $null)
        $encoder.Frames.Add($frame)
    }
    $output = [System.IO.File]::Create((Join-Path $previewRoot ($clip + '.gif')))
    try { $encoder.Save($output) } finally { $output.Dispose() }
    # Netscape loop extension: play indefinitely. Insert after the global palette.
    $gifPath = Join-Path $previewRoot ($clip + '.gif')
    $bytes = [System.IO.File]::ReadAllBytes($gifPath)
    $paletteLength = if ($bytes[10] -band 128) { 3 * [math]::Pow(2, (($bytes[10] -band 7) + 1)) } else { 0 }
    $offset = 13 + [int]$paletteLength
    [byte[]]$loop = 0x21,0xff,0x0b,0x4e,0x45,0x54,0x53,0x43,0x41,0x50,0x45,0x32,0x2e,0x30,0x03,0x01,0,0,0
    [byte[]]$animated = $bytes[0..($offset-1)] + $loop + $bytes[$offset..($bytes.Length-1)]
    [System.IO.File]::WriteAllBytes($gifPath, $animated)
}
