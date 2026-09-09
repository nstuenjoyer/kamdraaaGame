# Godot 4.x & GDScript Guidelines

When working with Godot 4.x and GDScript in this repository, strictly adhere to the following rules:

## 1. GDScript 2.0 Syntax (Strict Godot 4 Only)
- **Static Typing**: Always use explicit static typing for variables, parameters, and return types (e.g. `var speed: float = 240.0`, `func move(delta: float) -> void:`).
- **Exporting Variables**: Use the `@export` annotation (e.g. `@export var speed: float = 200.0`, `@export var target: Node2D`), NEVER the obsolete Godot 3 `export(float) var speed`.
- **Onready Variables**: Use `@onready` (e.g. `@onready var sprite: Sprite2D = $Sprite2D`).
- **Signals**:
  - Connect with callables: `my_signal.connect(_on_my_signal)` (NEVER `connect("my_signal", self, "_on_my_signal")`).
  - Emit with `.emit()`: `health_changed.emit(new_health)` (NEVER `emit_signal("health_changed", ...)`).
  - Declare signals in past tense or event name: `signal health_changed(new_health: int)`, `signal door_opened`.
- **Awaiting / Coroutines**:
  - Use `await` (e.g. `await get_tree().create_timer(1.0).timeout`, `await animation_player.animation_finished`).
  - NEVER use `yield` (it was removed in Godot 4).
- **Physics**:
  - For `CharacterBody2D`, assign `velocity` directly and call `move_and_slide()` without arguments (NEVER pass `velocity` into `move_and_slide()`).
  - Use `_physics_process(delta: float)` for movement and physics calculations.
  - Use `set_deferred("disabled", true)` when disabling collisions inside physics callbacks to avoid engine warnings.

## 2. Architecture & Best Practices
- **"Call down, Signal up"**:
  - A node should only directly call methods or modify properties of its direct children.
  - A node should NEVER reach up into its parent or grandparent directly (avoid `get_parent().get_parent()`).
  - Children communicate changes up to parents via `signals`.
- **Decoupled Systems (EventBus / Autoload)**:
  - For cross-scene or global events (quests, inventory, audio, UI notifications), use an Autoload EventBus singleton rather than tight coupling.
- **Node References**:
  - Prefer `@export var target_node: Node2D` for scene-to-scene wiring via the inspector, rather than brittle hardcoded paths.
  - If using path lookups, verify with `get_node_or_null()` before calling methods.

## 3. 2D & Isometric Conventions
- **Y-Sorting**:
  - Any node rendered in isometric perspective should have `y_sort_enabled = true` on the parent container (e.g. `YSort` / `Node2D` container / `TileMapLayer`).
  - The pivot point (offset) of sprites and collision shapes MUST be at the bottom (feet) of characters and base of objects.
- **Isometric Coordinates**:
  - Standard isometric tile ratio is 2:1 (width:height).
  - Movement directions should feel natural in isometric view (smooth diagonal projection or screen-space aligned).
