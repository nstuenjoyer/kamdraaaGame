"""Crop/register generated accessory parts; does not paint or deform the artwork.

Run with the bundled Python (Pillow/numpy) from any directory.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw

DEST = Path(__file__).resolve().parent
source = Image.open(DEST / "source.png").convert("RGBA")
pixels = np.array(source)
pixels[pixels[:, :, 3] < 16] = 0
source = Image.fromarray(pixels)
manifest = {
    "source": "source.png",
    "source_size": list(source.size),
    "coordinate_space": "Dasha atlas pixels (standing character height200)",
    "orientation": "proximal joint is on right, distal joint/torch lens on left",
    "parts": {},
}
names = ["upper_arm", "forearm", "hand", "flashlight"]
widths = {"upper_arm": 42, "forearm": 36, "hand": 13, "flashlight": 28}

for row, view in enumerate(["front", "back"]):
    for col, name in enumerate(names):
        cell_box = (col * source.width // 4, row * source.height // 2,
                    (col + 1) * source.width // 4, (row + 1) * source.height // 2)
        cell = source.crop(cell_box)
        ys, xs = np.where(np.array(cell)[:, :, 3] > 128)
        box = tuple(map(int, (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)))
        crop = cell.crop(box)
        if name == "hand":
            # Generated third column includes an optional sleeve. Keep the fist
            # only, since runtime already supplies a separate forearm.
            crop = crop.crop((0, 32, 138, crop.height))
            ys, xs = np.where(np.array(crop)[:, :, 3] > 128)
            crop = crop.crop(tuple(map(int, (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))))
        width = widths[name]
        size = (width, round(crop.height * width / crop.width))
        crop = crop.resize(size, Image.Resampling.NEAREST)
        filename = f"{view}_{name}.png"
        crop.save(DEST / filename)
        if name == "upper_arm":
            pivots = {"proximal": [round(size[0] * .80), round(size[1] * .19)],
                      "distal": [round(size[0] * .15), round(size[1] * .78)]}
        elif name == "forearm":
            pivots = {"proximal": [round(size[0] * .85), round(size[1] * .29)],
                      "distal": [round(size[0] * .15), round(size[1] * .70)]}
        elif name == "hand":
            pivots = {"proximal": [size[0] - 1, round(size[1] * .44)],
                      "grip": [round(size[0] * .48), round(size[1] * .58)]}
        else:
            pivots = {"grip": [round(size[0] * .72), round(size[1] * .52)],
                      "muzzle": [1, round(size[1] * .52)]}
        manifest["parts"][f"{view}_{name}"] = {
            "file": filename, "size": list(size),
            "source_cell": list(cell_box), "source_crop": list(box), **pivots,
        }

(DEST / "parts.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
preview = Image.new("RGBA", (800, 300), (24, 29, 29, 255))
draw = ImageDraw.Draw(preview)
for row, view in enumerate(["front", "back"]):
    for col, name in enumerate(names):
        part = Image.open(DEST / f"{view}_{name}.png")
        part = part.resize((part.width * 3, part.height * 3), Image.Resampling.NEAREST)
        preview.alpha_composite(part, (col * 200 + 20, row * 150 + 25))
        draw.text((col * 200 + 20, row * 150 + 120), f"{view} {name}", fill="#dedbd2")
preview.convert("RGB").save(DEST / "parts_preview.png")
print("Registered eight generated flashlight-arm parts")
