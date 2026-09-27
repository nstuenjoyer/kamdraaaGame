---
name: web-research
description: >-
  Use this skill when researching Godot 4.x documentation, GDScript 2.0 APIs, shaders, audio synthesis,
  Inno Setup configuration, bug fixes, or general game development solutions on the web.
---

# Web Research & Technical Documentation Skill

This skill defines standardized workflows and best practices for querying the internet, validating developer documentation, and retrieving high-accuracy technical information for Godot 4 and game development.

---

## 1. Core Principles for Web Search

1. **Precision Querying**: Always include exact engine versions (`Godot 4.3`, `Godot 4.4`, `Godot 4.x`) and technical keywords.
2. **Deprecation Filtering**: Explicitly avoid Godot 3 syntax. Never adopt snippets using `KinematicBody2D`, `yield()`, `Tween.interpolate_property()`, or `move_and_slide(velocity)`.
3. **Official First**: Prioritize official documentation and community hubs over generic blog aggregators.
4. **Targeted Reading**: Use `read_url_content` on official doc pages and GitHub PRs/issues for exact signatures and class methods.

---

## 2. Priority Domains & Authorities

When performing queries using `search_web`, target or prioritize these vetted sources:

| Domain | Specialty | Example Search Focus |
|---|---|---|
| `docs.godotengine.org/en/4.x` | Official Godot 4 Documentation & Class Reference | API signatures, node lifecycle, methods |
| `godotshaders.com` | Verified 2D/3D Shaders & Visual Effects | CRT shaders, glitch, dissolve, neon glow |
| `forum.godotengine.org` | Godot Engine Official Forum | Solved issues, real-world patterns |
| `github.com/godotengine/godot` | Engine Source, Proposals & Issues | Edge-case bug reports, engine limitations |
| `jrsoftware.org/ishelp` | Inno Setup 6 Official Help | Installer directives, flags, desktop shortcuts |
| `freesound.org` / `opengameart.org` | Sound design & procedural audio recipes | Audio frequencies, waveforms, ADSR envelopes |

---

## 3. Query Construction Formulas

Use these query patterns for maximum hit rate:

### A. Godot 4 API & Node Methods
```
"Godot 4" <ClassName> <method_or_property> site:docs.godotengine.org/en/4.x
```
*Example:* `"Godot 4" AudioStreamWAV format data stereo site:docs.godotengine.org/en/4.x`

### B. GDScript 2.0 Idioms & Type System
```
"Godot 4" "GDScript" <feature> example
```
*Example:* `"Godot 4" "GDScript" typed dictionary callable custom signal example`

### C. Visual Effects & 2D Shaders
```
"Godot 4" canvas_item shader <effect_name> site:godotshaders.com OR site:github.com
```
*Example:* `"Godot 4" canvas_item shader crt scanlines site:godotshaders.com`

### D. Packaging & Deployment
```
"Inno Setup 6" <directive_or_issue> site:jrsoftware.org OR site:stackoverflow.com
```
*Example:* `"Inno Setup 6" autopf PrivilegesRequired lowest modern wizard`

---

## 4. Godot 4 vs Godot 3 Deprecation Checklist

Before using any code found via web search, verify that it adheres to Godot 4 standards:

| Godot 3 (DEPRECATED - DO NOT USE) | Godot 4 (CORRECT) |
|---|---|
| `KinematicBody2D` | `CharacterBody2D` |
| `move_and_slide(velocity)` | `velocity = ...` then `move_and_slide()` (no arguments) |
| `yield(node, "signal")` | `await node.signal` |
| `onready var x = get_node(...)` | `@onready var x: Node = $...` |
| `export(int) var speed` | `@export var speed: int = 100` |
| `set_position(pos)` / `get_position()` | `position = pos` |
| `node.connect("pressed", self, "_on_pressed")` | `node.pressed.connect(_on_pressed)` |
| `btn.theme_override_colors/font_color = Color(...)` | `btn.add_theme_color_override("font_color", Color(...))` |
| `TileMap` (all-in-one node) | `TileMapLayer` (preferred in Godot 4.3+) |

---

## 5. Web Research Workflow

1. **Formulate Query**: Construct targeted query using formulas in Section 3.
2. **Execute Search**: Call `search_web(query="...")`.
3. **Inspect Sources**: Look for official Godot documentation, official GitHub repositories, or verified answers.
4. **Fetch Details**: Call `read_url_content(Url="...")` to obtain exact parameters, method names, and return types.
5. **Synthesize & Validate**: Cross-reference with the existing project codebase conventions before applying changes.
