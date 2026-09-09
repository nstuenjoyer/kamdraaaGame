---
name: 2d-gamedev-patterns
description: >-
  Use this skill when designing 2D game architecture, implementing finite state machines (FSM),
  interaction systems, quest/dialogue triggers, hitbox/hurtbox combat, inventory management,
  or adding "game feel" (juice, screen shake, hit stop, tweens).
---

# 2D Game Development Patterns & Architecture

This skill provides proven architectural patterns and gameplay mechanics for 2D games, helping you build clean, maintainable, and responsive game systems.

---

## 1. The Finite State Machine (FSM) Pattern

FSM is essential for characters (Player, Enemies, NPCs) to avoid spaghetti code with dozens of boolean flags.

### Base State Interface (`state.gd`):
```gdscript
class_name State
extends Node

signal transitioned(next_state_name: String)

var actor: CharacterBody2D

func enter() -> void:
    pass

func exit() -> void:
    pass

func update(_delta: float) -> void:
    pass

func physics_update(_delta: float) -> void:
    pass
```

### State Machine Controller (`state_machine.gd`):
```gdscript
class_name StateMachine
extends Node

@export var initial_state: State

var current_state: State
var states: Dictionary = {}

func _ready() -> void:
    await owner.ready
    for child in get_children():
        if child is State:
            states[child.name.to_lower()] = child
            child.transitioned.connect(_on_state_transitioned)
            child.actor = owner as CharacterBody2D

    if initial_state:
        current_state = initial_state
        current_state.enter()

func _process(delta: float) -> void:
    if current_state:
        current_state.update(delta)

func _physics_process(delta: float) -> void:
    if current_state:
        current_state.physics_update(delta)

func _on_state_transitioned(next_state_name: String) -> void:
    var new_state: State = states.get(next_state_name.to_lower())
    if not new_state or new_state == current_state:
        return
    current_state.exit()
    current_state = new_state
    current_state.enter()
```

---

## 2. Universal Interaction System

Decouple interactive objects (doors, NPCs, chests, phones) using an `Interactable` component pattern:

### Interactable (`interactable.gd`):
```gdscript
class_name Interactable
extends Area2D

signal interacted(interactor: Node2D)

@export var prompt_text: String = "Нажмите E для взаимодействия"
@export var is_interactable: bool = true

func interact(interactor: Node2D) -> void:
    if is_interactable:
        interacted.emit(interactor)
```

### Player Interactor (`interaction_detector.gd`):
Place an `Area2D` on the player to track the nearest interactable object:
```gdscript
extends Area2D

var nearby_interactables: Array[Interactable] = []

func _ready() -> void:
    area_entered.connect(_on_area_entered)
    area_exited.connect(_on_area_exited)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("interact") and not nearby_interactables.is_empty():
        # Interact with the closest one
        var closest: Interactable = get_closest_interactable()
        if closest:
            closest.interact(owner)

func _on_area_entered(area: Area2D) -> void:
    if area is Interactable:
        nearby_interactables.append(area)

func _on_area_exited(area: Area2D) -> void:
    if area is Interactable:
        nearby_interactables.erase(area)

func get_closest_interactable() -> Interactable:
    var closest: Interactable = null
    var min_dist: float = INF
    for item in nearby_interactables:
        var dist: float = global_position.distance_to(item.global_position)
        if dist < min_dist:
            min_dist = dist
            closest = item
    return closest
```

---

## 3. EventBus (Global Signals)

Never tightly couple unrelated subsystems (e.g., player inventory calling UI directly). Instead, use an Autoload `EventBus`:

```gdscript
# EventBus.gd (Autoload singleton)
extends Node

# Player events
signal player_health_changed(current: int, max_health: int)
signal player_died

# Quest / Story events
signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)
signal dialogue_triggered(dialogue_id: String)

# UI events
signal show_notification(message: String)
```

---

## 4. "Game Feel" & Polish (Juice)

Small feedback touches turn a prototype into a satisfying game:

1. **Squash & Stretch**:
   ```gdscript
   func squash_and_stretch(sprite: CanvasItem, squash: Vector2 = Vector2(1.2, 0.8), duration: float = 0.1) -> void:
       var tween: Tween = create_tween()
       tween.tween_property(sprite, "scale", squash, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
       tween.tween_property(sprite, "scale", Vector2.ONE, duration * 1.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
   ```

2. **Hit Stop (Freeze Frame)**:
   ```gdscript
   func hit_stop(duration_sec: float = 0.05, time_scale: float = 0.05) -> void:
       Engine.time_scale = time_scale
       await get_tree().create_timer(duration_sec * time_scale).timeout
       Engine.time_scale = 1.0
   ```

3. **Floating Damage / Text Popup**:
   Spawn a lightweight `Label` that floats upwards and fades out using `create_tween()`, then calls `queue_free()`.

---

## 5. References & Deep Guides
- [FSM Implementation Examples](references/fsm-pattern.md)
- [Dialogue and Quest State Management](references/dialogue-and-quests.md)
