"""Register arm anchors and visible free-hand masks without changing image assets.

`hand` describes the original free hand ONLY when `erase` is true. `rest` is an
independent anatomical wrist. No smoothing crosses different animation phases.
Use --preview for annotated contact sheets under .godot/hand-socket-review/.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
CELL = (160, 256)

# Some rear source drawings swap the handbag side. Only these far/right free
# hands are actually visible; the others are bag hands, boots, or occluded.
# This is registration per drawing, not averaging across a gait cycle.
REAR_VISIBLE: dict[str, set[tuple[int, int]]] = {
    "main": {(4, 0), (4, 1), (4, 4), (6, 0), (6, 4), (6, 6), (6, 7), (7, 0)},
    "idle": {(1, column) for column in range(8)},
}


def components(mask: np.ndarray) -> list[np.ndarray]:
    """Separate fists from disconnected buttons/trim before finding centroids."""
    remaining = mask.copy()
    found: list[np.ndarray] = []
    while remaining.any():
        yy, xx = np.where(remaining)
        todo = [(int(yy[0]), int(xx[0]))]
        remaining[todo[0]] = False
        pixels = []
        while todo:
            y, x = todo.pop()
            pixels.append((x, y))
            for ny in range(max(0, y - 1), min(CELL[1], y + 2)):
                for nx in range(max(0, x - 1), min(CELL[0], x + 2)):
                    if remaining[ny, nx]:
                        remaining[ny, nx] = False
                        todo.append((ny, nx))
        points = np.asarray(pixels)
        span = np.ptp(points, axis=0)
        if 2 <= len(points) <= 120 and span[0] <= 16 and span[1] <= 19:
            found.append(points)
    return found


def register(cell: np.ndarray, table: str, row: int, column: int) -> dict:
    back = row >= 4 if table == "main" else row % 2 == 1
    r, g, b, alpha = [cell[:, :, channel] for channel in range(4)]
    yy, _ = np.where(alpha > 128)
    top, bottom = int(yy.min()), int(yy.max())
    height = bottom - top + 1
    head_x = float(np.where(alpha[top:top + 25] > 128)[1].mean())

    # Rear shoulder sits towards the coat seam, behind the hair, rather than at
    # its old lower-middle anchor. Follow the individual registered pose.
    shoulder = np.array([head_x + (21 if back else -14),
                         top + min(64, height * .32) - (6 if back else 0)])
    kind = row % 4 if table == "main" else (2 if row >= 2 else 0)
    crouch = float(column) / 7 if table == "main" and kind == 3 else float(kind == 2)
    rest = shoulder + np.array([4 if back else -6, 42 - 14 * crouch])
    if kind == 1:
        rest = shoulder + np.array([5 if back else -7, 29])

    hand = rest.copy()
    erase = False
    if not back or (row, column) in REAR_VISIBLE[table]:
        skin = ((alpha > 128) & (r > 95) & (g > 45) & (b > 28)
                & (r - g > 18) & (g - b > 8) & (r - b > 30))
        grid_y, grid_x = np.indices(skin.shape)
        lower_extent = 46 if kind in (1, 2) else 54
        zone = ((grid_y >= shoulder[1] + 6)
                & (grid_y <= shoulder[1] + lower_extent))
        if back:
            zone &= ((grid_x > head_x + 10) & (grid_x <= shoulder[0] + 36))
        else:
            zone &= ((grid_x < head_x - 8)
                     & (grid_x >= shoulder[0] - 30)
                     & (grid_x <= shoulder[0] + 10))
        candidates = components(skin & zone)
        if candidates:
            expected = shoulder + np.array([15 if back else -7,
                                             42 - 15 * crouch if kind != 1 else 23])
            selected = min(candidates, key=lambda points: float(np.linalg.norm(points.mean(axis=0) - expected)))
            hand = selected.mean(axis=0)
            erase = True
    return {
        "shoulder": np.round(shoulder, 2).tolist(),
        "hand": np.round(hand, 2).tolist(),
        "rest": np.round(rest, 2).tolist(),
        "body_x": round(head_x, 2),
        "erase": erase,
    }


def preview(atlases: dict[str, Image.Image], poses: dict[str, list[dict]]) -> Path:
    output = ROOT / ".godot/hand-socket-review"
    output.mkdir(parents=True, exist_ok=True)
    tiles: dict[tuple[str, int, int], Image.Image] = {}
    for table, sheet in atlases.items():
        for row in range(sheet.height // CELL[1]):
            contact = Image.new("RGB", (1280, 1080), (36, 40, 46))
            for column in range(8):
                cell = sheet.crop((column * CELL[0], row * CELL[1], (column + 1) * CELL[0], (row + 1) * CELL[1]))
                p = poses[table][row * 8 + column]
                d = ImageDraw.Draw(cell)
                d.line([tuple(p["shoulder"]), tuple(p["rest"])], fill="cyan", width=1)
                if p["erase"]:
                    d.line([tuple(p["shoulder"]), tuple(p["hand"])], fill="orange", width=1)
                for key, color, radius in [("shoulder", "red", 2), ("rest", "cyan", 2),
                                           ("hand", "lime" if p["erase"] else "gray", 1)]:
                    x, y = p[key]
                    d.ellipse((x-radius, y-radius, x+radius, y+radius), fill=color)
                d.text((3, 3), f'{table} {row}/{column}', fill="white")
                d.text((3, 15), f'erase={p["erase"]}', fill="white")
                tile = cell.resize((320, 512), Image.Resampling.NEAREST)
                tiles[table, row, column] = tile
                contact.paste(tile, ((column % 4)*320, (column // 4)*512), tile)
            ImageDraw.Draw(contact).text((12, 1030), "RED shoulder | CYAN anatomical rest | GREEN visible free hand | GRAY hidden/unreliable: no erasure", fill="white")
            contact.save(output / f"{table}-{row}.png")
    exceptions = Image.new("RGB", (1280, 1080), (36, 40, 46))
    selection = [("idle", 0, 2), ("idle", 0, 3), ("idle", 1, 0), ("main", 4, 0),
                 ("main", 4, 2), ("main", 5, 2), ("main", 5, 3), ("main", 6, 0)]
    for index, key in enumerate(selection):
        tile = tiles[key]
        exceptions.paste(tile, ((index % 4)*320, (index // 4)*512), tile)
    ImageDraw.Draw(exceptions).text((12, 1030), "RED shoulder | CYAN anatomical rest | GREEN visible free hand | GRAY hidden/unreliable: no erasure", fill="white")
    exceptions.save(output / "exceptions.png")
    return output


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview", action="store_true")
    arguments = parser.parse_args()
    poses: dict[str, list[dict]] = {}
    atlases: dict[str, Image.Image] = {}
    for table, name in [("main", "dasha_atlas.png"), ("idle", "dasha_idle_atlas.png")]:
        sheet = Image.open(ROOT / "assets/sprites/dasha_animation" / name).convert("RGBA")
        atlases[table] = sheet
        pixels = np.asarray(sheet).astype(int)
        poses[table] = []
        for row in range(sheet.height // CELL[1]):
            for column in range(8):
                cell = pixels[row*256:(row+1)*256, column*160:(column+1)*160]
                poses[table].append(register(cell, table, row, column))
    text = ("extends RefCounted\n\n# Generated by tools/art/register_hand_sockets.py. Coordinates within 160x256 cell.\n"
            "# hand/erase describe visible original art; rest is an independent anatomical wrist.\n"
            "const POSES: Dictionary = " + json.dumps(poses, ensure_ascii=False, indent=2) + "\n")
    (ROOT / "scripts/dasha_hand_sockets.gd").write_text(text, encoding="utf-8")
    visible = sum(p["erase"] for entries in poses.values() for p in entries)
    print(f"Registered {sum(map(len, poses.values()))} sockets; {visible} visible free hands, remainder explicitly occluded.")
    print("idle/front2", poses["idle"][2])
    print("idle/front3", poses["idle"][3])
    if arguments.preview:
        print("Annotated QA:", preview(atlases, poses))


if __name__ == "__main__":
    main()
