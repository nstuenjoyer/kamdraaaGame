---
name: godot4-2d-game
description: >-
  Use this skill when developing 2D games in Godot 4.x, including isometric or top-down perspectives,
  CharacterBody2D physics movement, TileMapLayer setups, Y-sorting depth, Camera2D, AnimationTree,
  and 2D scene composition.
---

# Godot 4.x 2D Game Development Skill

This skill provides step-by-step guidance, patterns, and best practices for developing 2D games in Godot 4 (with emphasis on isometric and top-down games).

---

## 1. 2D Movement & Physics (`CharacterBody2D`)

### Standard 8-Way & Isometric Movement
When controlling a 2D character, always use acceleration and friction for smooth movement without jarring stops:

```gdscript
extends CharacterBody2D

@export var max_speed: float = 240.0
@export var acceleration: float = 2200.0
@export var friction: float = 2600.0

func _physics_process(delta: float) -> void:
    var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    
    # Optional: For true isometric projection (2:1 ratio) movement scaling:
    # direction = Vector2(direction.x, direction.y * 0.5).normalized()

    if direction != Vector2.ZERO:
        velocity = velocity.move_toward(direction * max_speed, acceleration * delta)
    else:
        velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

    move_and_slide()
```

> **Important**: In Godot 4, `velocity` is a built-in property on `CharacterBody2D`. NEVER pass arguments to `move_and_slide()`.

---

## 2. Depth Sorting (Y-Sort) for Isometric & Top-Down Games

To ensure characters properly walk in front of and behind objects (trees, walls, furniture, other characters):

1. **Enable Y-Sort on Parent Container**:
   Set `y_sort_enabled = true` on the parent node containing all world entities (or on the `TileMapLayer` / `Node2D` root).
2. **Enable Y-Sort on Entities**:
   Set `y_sort_enabled = true` on the `CharacterBody2D` and any static/interactive object nodes.
3. **Anchor at Feet / Base**:
   - The Sprite's origin (pivot) should be positioned such that `(0, 0)` is at the feet of the character or the base contact point of an object.
   - The `CollisionShape2D` should be placed at the bottom where the entity touches the ground (not centered over the entire height of the sprite).

---

## 3. TileMapLayer (Godot 4.3+) & Isometric Grids

Godot 4.3 replaced the monolithic `TileMap` with individual `TileMapLayer` nodes:
- Set `tile_shape = TileSet.TILE_SHAPE_ISOMETRIC` for diamond isometric tiles.
- Standard tile size is typically 2:1 (e.g. `64 x 32` or `32 x 16`).
- Enable `y_sort_enabled = true` on each `TileMapLayer` that contains vertical objects.

### Coordinate Conversion:
```gdscript
# Convert screen coordinates to isometric grid cell
func screen_to_iso(screen_pos: Vector2, tile_width: float, tile_height: float) -> Vector2:
    var x: float = (screen_pos.x / (tile_width / 2.0) + screen_pos.y / (tile_height / 2.0)) / 2.0
    var y: float = (screen_pos.y / (tile_height / 2.0) - screen_pos.x / (tile_width / 2.0)) / 2.0
    return Vector2(floor(x), floor(y))

# Convert isometric grid cell to screen coordinates
func iso_to_screen(cell: Vector2, tile_width: float, tile_height: float) -> Vector2:
    var screen_x: float = (cell.x - cell.y) * (tile_width / 2.0)
    var screen_y: float = (cell.x + cell.y) * (tile_height / 2.0)
    return Vector2(screen_x, screen_y)
```

---

## 4. Camera2D Setup & Screen Shake

A good 2D camera provides smooth tracking and screen effects:

```gdscript
extends Camera2D

@export var target: Node2D
@export var smooth_speed: float = 10.0

var _shake_intensity: float = 0.0
var _shake_decay: float = 5.0

func _process(delta: float) -> void:
    if target:
        global_position = global_position.lerp(target.global_position, smooth_speed * delta)
    
    if _shake_intensity > 0.0:
        offset = Vector2(
            randf_range(-_shake_intensity, _shake_intensity),
            randf_range(-_shake_intensity, _shake_intensity)
        )
        _shake_intensity = move_toward(_shake_intensity, 0.0, _shake_decay * delta * 100.0)
    else:
        offset = Vector2.ZERO

func shake(intensity: float = 8.0, decay: float = 5.0) -> void:
    _shake_intensity = intensity
    _shake_decay = decay
```

---

## 5. Animation Management (`AnimationTree` & 8 directions)

For multi-directional movement animations (idle, walk):
1. Use an `AnimationTree` with a `StateMachine` root.
2. For each state (e.g. `Idle`, `Walk`), use a `BlendSpace2D`.
3. Set the blend space points for 4 or 8 directions (`(0, 1)` for Down, `(0, -1)` for Up, `(1, 0)` for Right, `(-1, 0)` for Left, plus diagonals).
4. Update parameters in script:
   ```gdscript
   @onready var anim_tree: AnimationTree = $AnimationTree
   
   func update_animations(direction: Vector2) -> void:
       if direction != Vector2.ZERO:
           anim_tree.set("parameters/Idle/blend_position", direction)
           anim_tree.set("parameters/Walk/blend_position", direction)
           anim_tree.get("parameters/playback").travel("Walk")
       else:
           anim_tree.get("parameters/playback").travel("Idle")
   ```

---

## 6. References & Deep Guides
For advanced topics, check:
- [Isometric Depth & Math](references/isometric-guide.md)
- [Godot 4 Traps & Migration Checklist](references/godot4-migration-gotchas.md)
