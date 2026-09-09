# Godot 4 vs Godot 3: Traps & Migration Checklist

Avoid these common mistakes when writing GDScript in Godot 4:

| Feature | Godot 3 (Do NOT use) | Godot 4 (ALWAYS use) |
| :--- | :--- | :--- |
| **Movement** | `velocity = move_and_slide(velocity)` | `velocity = target_velocity`<br>`move_and_slide()` |
| **Character Class** | `KinematicBody2D` | `CharacterBody2D` |
| **Coroutines / Timers** | `yield(timer, "timeout")` | `await timer.timeout` |
| **Signal Connection** | `connect("body_entered", self, "_on_enter")` | `body_entered.connect(_on_enter)` |
| **Signal Emission** | `emit_signal("my_signal", arg)` | `my_signal.emit(arg)` |
| **Export Syntax** | `export(int) var count` | `@export var count: int` |
| **Onready Syntax** | `onready var sprite = $Sprite` | `@onready var sprite: Sprite2D = $Sprite` |
| **Tilemaps (4.3+)** | Single `TileMap` node with layers tab | Individual `TileMapLayer` nodes |
| **Random Floats** | `rand_range(min, max)` | `randf_range(min, max)` |
| **Instance Scene** | `packed_scene.instance()` | `packed_scene.instantiate()` |
| **Set Deferred** | `set_deferred("property", val)` | Same, but often typed or using `Callable.call_deferred()` |
| **Tweens** | `Tween` node added to scene tree | Lightweight `create_tween()` |

## Tweening Example (Godot 4)
```gdscript
# Create a smooth fade-in
var tween: Tween = create_tween()
tween.set_trans(Tween.TRANS_SINE)
tween.set_ease(Tween.EASE_OUT)
tween.tween_property(sprite, "modulate:a", 1.0, 0.5)
```
