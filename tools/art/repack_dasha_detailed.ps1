Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$dir = Join-Path $root 'assets/sprites/dasha_animation'
function Remove-LowAlpha([System.Drawing.Bitmap]$bitmap, [int[]]$rows) {
    foreach ($row in $rows) {
        for ($y = $row * 256; $y -lt ($row + 1) * 256; $y++) {
            for ($x = 0; $x -lt $bitmap.Width; $x++) {
                $alpha = $bitmap.GetPixel($x, $y).A
                if ($alpha -gt 0 -and $alpha -lt 16) {
                    $bitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0))
                }
            }
        }
    }
}
function Build-Atlas([string]$sourceName, [string]$baseName, [string]$outputName, [int]$columns, [int]$rows, [int[]]$targetRows) {
    $source = [System.Drawing.Bitmap]::FromFile((Join-Path $dir $sourceName))
    $base = [System.Drawing.Bitmap]::FromFile((Join-Path $dir $baseName))
    $out = New-Object System.Drawing.Bitmap($base.Width, $base.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($out)
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $g.DrawImageUnscaled($base, 0, 0)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    if ($sourceName -in @('detailed_motion_source.png', 'detailed_motion_proportions_source.png')) {
        # The generator laid out these poses on a shared grid. Preserve that
        # coordinate system: per-pose bounding-box alignment caused visible
        # head jumps and pulled fragments from neighbouring frames into view.
        $scale = 0.8
        for ($row = 0; $row -lt $rows; $row++) {
            $top = [int][Math]::Floor($row * $source.Height / $rows)
            $bottom = [int][Math]::Floor(($row + 1) * $source.Height / $rows)
            for ($col = 0; $col -lt $columns; $col++) {
                $left = [int][Math]::Floor($col * $source.Width / $columns) + 20
                $right = [int][Math]::Floor(($col + 1) * $source.Width / $columns)
                $targetRow = $targetRows[$row]
                $g.FillRectangle([System.Drawing.Brushes]::Transparent, $col * 160, $targetRow * 256, 160, 256)
                $dst = New-Object System.Drawing.Rectangle(($col * 160 + 8), ($targetRow * 256 + 50), ([int][Math]::Round(($right-$left)*$scale)), ([int][Math]::Round(($bottom-$top)*$scale)))
                $g.DrawImage($source, $dst, $left, $top, ($right-$left), ($bottom-$top), [System.Drawing.GraphicsUnit]::Pixel)
            }
        }
        Remove-LowAlpha $out $targetRows
        $out.Save((Join-Path $dir $outputName), [System.Drawing.Imaging.ImageFormat]::Png)
        $g.Dispose(); $out.Dispose(); $base.Dispose(); $source.Dispose()
        return
    }
    for ($row = 0; $row -lt $rows; $row++) {
        $boxes = @(); $maxHeight = 0; $maxWidth = 0
        for ($col = 0; $col -lt $columns; $col++) {
            $left = [int][Math]::Floor($col * $source.Width / $columns)
            $right = [int][Math]::Floor(($col + 1) * $source.Width / $columns)
            $top = [int][Math]::Floor($row * $source.Height / $rows)
            $bottom = [int][Math]::Floor(($row + 1) * $source.Height / $rows)
            if ($sourceName -in @('detailed_crouch_source.png', 'detailed_crouch_proportions_source.png')) {
                # The crouched rows in this generated sheet are shorter than
                # standing rows; equal quarters cut off feet and capture heads.
                $bounds = @(0, 310, 515, 805, 1024)
                $top = $bounds[$row]; $bottom = $bounds[$row+1]
                # Ignore thin fragments belonging to neighbouring figures.
                $left += 12; $right -= 12
                if ($row -gt 0) { $top += 8 }
            }
            $minX = $right; $maxX = $left; $minY = $bottom; $maxY = $top
            for ($y = $top; $y -lt $bottom; $y++) {
                for ($x = $left; $x -lt $right; $x++) {
                    $threshold = if ($sourceName -eq 'detailed_idle_registered_source.png') { 128 } else { 32 }
                    if ($source.GetPixel($x, $y).A -ge $threshold) {
                        $minX = [Math]::Min($minX, $x); $maxX = [Math]::Max($maxX, $x)
                        $minY = [Math]::Min($minY, $y); $maxY = [Math]::Max($maxY, $y)
                    }
                }
            }
            if ($maxX -le $minX -or $maxY -le $minY) { throw "Empty pose $row/$col" }
            $box = @{ X=$minX; Y=$minY; W=($maxX-$minX+1); H=($maxY-$minY+1) }
            $boxes += $box; $maxHeight = [Math]::Max($maxHeight, $box.H); $maxWidth = [Math]::Max($maxWidth, $box.W)
        }
        $heightTarget = if ($sourceName -in @('detailed_crouch_source.png', 'detailed_crouch_proportions_source.png') -and $row % 2 -eq 1) { 130.0 } else { 200.0 }
        if ($sourceName -eq 'detailed_crouch_proportions_source.png') {
            # Preserve the original body scale when only the head is reduced.
            # These are the original sheet's row bounds under the same crop.
            $maxHeight = @(293, 192, 276, 202)[$row]
            $maxWidth = @(142, 168, 142, 168)[$row]
        }
        $scale = [Math]::Min($heightTarget / $maxHeight, 152.0 / $maxWidth)
        for ($col = 0; $col -lt 8; $col++) {
            $box = $boxes[$col % $columns]; $w = [int][Math]::Round($box.W * $scale); $h = [int][Math]::Round($box.H * $scale)
            $targetRow = $targetRows[$row]
            $g.FillRectangle([System.Drawing.Brushes]::Transparent, $col * 160, $targetRow * 256, 160, 256)
            $lift = if ($sourceName -eq 'detailed_motion_source.png' -and $row % 2 -eq 1 -and $col % 4 -eq 1) { 5 } else { 0 }
            $dst = New-Object System.Drawing.Rectangle(($col*160 + [int]((160-$w)/2)), ($targetRow*256+244-$h-$lift), $w, $h)
            $g.DrawImage($source, $dst, $box.X, $box.Y, $box.W, $box.H, [System.Drawing.GraphicsUnit]::Pixel)
        }
    }
    Remove-LowAlpha $out $targetRows
    $out.Save((Join-Path $dir $outputName), [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $out.Dispose(); $base.Dispose(); $source.Dispose()
}
Build-Atlas 'detailed_motion_proportions_source.png' 'dasha_atlas.png' 'detailed_motion_standing.png' 8 4 @(0,1,4,5)
Build-Atlas 'detailed_crouch_proportions_source.png' 'detailed_motion_standing.png' 'detailed_motion_atlas.png' 8 4 @(3,2,7,6)
# Two columns are front/back, so treat them as two rows through a separate copy below.
$idle = [System.Drawing.Bitmap]::FromFile((Join-Path $dir 'detailed_idle_source.png'))
$rotated = New-Object System.Drawing.Bitmap([int]($idle.Width/2), ($idle.Height*2), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$ig = [System.Drawing.Graphics]::FromImage($rotated)
for ($i=0; $i -lt 2; $i++) {
    $dest = New-Object System.Drawing.Rectangle(0, ($i*$idle.Height), [int]($idle.Width/2), $idle.Height)
    $ig.DrawImage($idle, $dest, ($i*[int]($idle.Width/2)), 0, [int]($idle.Width/2), $idle.Height, [System.Drawing.GraphicsUnit]::Pixel)
}
$ig.Dispose(); $idle.Dispose()
$rotated.Save((Join-Path $dir 'detailed_idle_registered_source.png'), [System.Drawing.Imaging.ImageFormat]::Png); $rotated.Dispose()
Build-Atlas 'detailed_idle_registered_source.png' 'dasha_idle_atlas.png' 'detailed_idle_atlas.png' 1 2 @(0,1)
# Crouch rest reuses the actual final transition pose to avoid a posture jump.
$motion = [System.Drawing.Bitmap]::FromFile((Join-Path $dir 'detailed_motion_atlas.png'))
$idleBase = [System.Drawing.Bitmap]::FromFile((Join-Path $dir 'detailed_idle_atlas.png'))
$idleOut = New-Object System.Drawing.Bitmap($idleBase.Width, $idleBase.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$ig = [System.Drawing.Graphics]::FromImage($idleOut)
$ig.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
$ig.DrawImageUnscaled($idleBase, 0, 0)
for ($row=0; $row -lt 2; $row++) {
    for ($col=0; $col -lt 8; $col++) {
        $dest = New-Object System.Drawing.Rectangle(($col*160), (($row+2)*256), 160, 256)
        $ig.DrawImage($motion, $dest, 1120, ((3+$row*4)*256), 160, 256, [System.Drawing.GraphicsUnit]::Pixel)
    }
}
$ig.Dispose(); $idleBase.Dispose()
# Copy exact RGBA bytes, including transparent pixels, for identical endpoints.
for ($row=0; $row -lt 2; $row++) {
    for ($col=0; $col -lt 8; $col++) {
        for ($y=0; $y -lt 256; $y++) {
            for ($x=0; $x -lt 160; $x++) {
                $idleOut.SetPixel($col*160+$x, ($row+2)*256+$y, $motion.GetPixel(1120+$x, (3+$row*4)*256+$y))
            }
        }
    }
}
$motion.Dispose()
$idleOut.Save((Join-Path $dir 'detailed_idle_complete.png'), [System.Drawing.Imaging.ImageFormat]::Png); $idleOut.Dispose()
Move-Item -Force (Join-Path $dir 'detailed_idle_complete.png') (Join-Path $dir 'detailed_idle_atlas.png')
