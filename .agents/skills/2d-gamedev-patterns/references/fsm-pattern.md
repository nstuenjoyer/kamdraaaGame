# Finite State Machine (FSM) Reference Guide

## Typical Character States

### 1. Idle State
```gdscript
class_name PlayerIdleState
extends State

func enter() -> void:
    actor.velocity = Vector2.ZERO

func physics_update(delta: float) -> void:
    var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if direction != Vector2.ZERO:
        transitioned.emit("move")
```

### 2. Move State
```gdscript
class_name PlayerMoveState
extends State

func physics_update(delta: float) -> void:
    var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if direction == Vector2.ZERO:
        transitioned.emit("idle")
        return

    actor.velocity = actor.velocity.move_toward(direction * actor.max_speed, actor.acceleration * delta)
    actor.move_and_slide()
```

### 3. Interacting / Locked State
```gdscript
class_name PlayerInteractingState
extends State

func enter() -> void:
    actor.velocity = Vector2.ZERO
    # Disable movement input while in dialogue or cutscene

func exit() -> void:
    # Re-enable inputs
    pass
```
