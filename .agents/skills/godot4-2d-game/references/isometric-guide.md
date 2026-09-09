# Isometric 2D Game Development Guide (Godot 4)

## Projection & Tile Aspect Ratio
The most common isometric projection in video games is **dimetric projection (often called 2:1 isometric)**.
In this projection:
- Width = 2 × Height (e.g. 64x32 or 32x16).
- An angle of ~26.565° (`atan(0.5)`).

## Visual Depth & Layering (Y-Sorting)
Depth sorting is crucial in isometric perspectives because objects farther up on the screen (`lower Y`) must render behind objects closer to the bottom (`higher Y`).

### Key Rules:
1. **Pivot Point (Ground Footprint)**:
   - For all characters, NPCs, and props: place the node's position `(0, 0)` at the exact point where it contacts the floor.
   - For a character sprite of size 32x64, the sprite offset should be `Vector2(0, -32)` so `(0, 0)` is at the feet.
2. **Collision Shapes**:
   - The collision shape for movement should only cover the base (feet) footprint, typically a small `CapsuleShape2D` or `CircleShape2D` flattened along the Y axis.
   - Do NOT use a collision box covering the head or body, otherwise the player cannot walk close to walls or behind furniture.
3. **Wall Occlusion**:
   - For tall objects (front walls, pillars), if the character walks behind them, either:
     - Fade the obstacle using an `Area2D` opacity trigger (`create_tween().tween_property(self, "modulate:a", 0.4, 0.2)`).
     - Or use a silhouette shader / cutout shader.

## Isometric Movement Controls
There are two common input mapping approaches:
1. **Screen-Aligned (Intuitive for Keyboard/Mouse)**:
   - W = Up (screen up)
   - S = Down (screen down)
   - A = Left (screen left)
   - D = Right (screen right)
   - Diagonal movement matches the isometric axes.
2. **Axis-Aligned (Iso-True)**:
   - W = Up-Right (along Iso-X axis)
   - S = Down-Left
   - A = Up-Left (along Iso-Y axis)
   - D = Down-Right
   *Screen-aligned is generally preferred by players unless tile-by-tile grid movement is used.*
