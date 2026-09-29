# Kamdraaa — Developer & Agent Architecture Guide

Welcome to **Kamdraaa** — a top-down psychological noir detective thriller built with **Godot Engine 4.7.2** on Windows.

This file serves as the primary system map for AI agents and human developers, providing instant architectural orientation, conventions, and key APIs.

---

## 1. Engine & Stack Specifications

- **Engine Version**: Godot Engine 4.7.2 stable (64-bit Windows)
- **Language**: GDScript 2.0 (Strict static typing preferred: `var x: int = 0`)
- **Display Resolution**: 1280 × 720 (Viewport stretch mode: `canvas_items`, aspect: `keep`)
- **Main Scene Entry**: `res://scenes/main_menu.tscn`
- **Game Scene**: `res://scenes/main.tscn`
- **Distribution**: Standalone PCK + Exe and Inno Setup installer (`installer/Kamdraaa_Setup_v0.2.0.exe`)

---

## 2. Global Autoload Singletons

All singletons are configured in `project.godot` and accessible from any script via `/root/<Name>` or direct identifier:

| Singleton | Script Path | Core Responsibility |
|---|---|---|
| **`SoundManager`** | [scripts/sound_manager.gd](file:///e:/kamdraaa-game/scripts/sound_manager.gd) | Procedural audio synthesis (sine/square/noise waveforms). Footsteps, phone ringing/pickup, clue discovery chimes, paper rustle, glass break, heartbeat paranoia, UI hover/click. |
| **`SettingsManager`** | [scripts/settings_manager.gd](file:///e:/kamdraaa-game/scripts/settings_manager.gd) | Audio bus levels (`Master`, `Music`, `SFX`), Fullscreen, V-Sync, CRT shader toggle, custom action key rebinding via `InputMap`. Saves to `user://settings.cfg`. |
| **`SaveManager`** | [scripts/save_manager.gd](file:///e:/kamdraaa-game/scripts/save_manager.gd) | Slot-based JSON saves (`slot_1` - `slot_3`, quicksaves), timestamping, player position, door state, clue records. Emits `toast_requested`, `save_deleted`. |
| **`ClueManager`** | [scripts/clue_manager.gd](file:///e:/kamdraaa-game/scripts/clue_manager.gd) | Detective case file tracking 5 core clues (`receipt`, `mirror`, `phone`, `bottle`, `door`), Mind Palace deduction synthesis («Чертоги разума»), discovery timestamps, hints, and signals (`clue_discovered`, `deduction_unlocked`, `clues_updated`). |
| **`ParanoiaManager`** | [scripts/paranoia_manager.gd](file:///e:/kamdraaa-game/scripts/paranoia_manager.gd) | Heart rate (BPM) & mental strain system. Calculates dynamic pulse (68-172 BPM), drives heartbeat audio loop, stress decay/spikes, panic state transitions. |
| **`InventoryManager`** | [scripts/inventory_manager.gd](file:///e:/kamdraaa-game/scripts/inventory_manager.gd) | Detective physical item inventory (`pills`, keycards, etc.). Tracks items, counts, usability, and persistence in saves. |

---

## 3. Scene Architecture & Node Paths

### 🎬 Main Game Room: [scenes/main.tscn](file:///e:/kamdraaa-game/scenes/main.tscn)
- **Root**: `Node2D` with script [scripts/main.gd](file:///e:/kamdraaa-game/scripts/main.gd)
- **Room Dimensions**: 840 × 520 (boundaries: X: 220–1060, Y: 100–620)
- **Key Entities**:
  - `Player` (`CharacterBody2D` with [scripts/player.gd](file:///e:/kamdraaa-game/scripts/player.gd)): Starts at `(480, 290)`. Contains `Flashlight` component ([scripts/flashlight.gd](file:///e:/kamdraaa-game/scripts/flashlight.gd)) with dynamic cone spotlight, PCF5 shadows, volumetric beam, smooth mouse aiming (clamped to 90° radius when running), and toggle hotkeys (`F` / `ПКМ`).
  - `Window` (`Node2D` with [scripts/window_lighting.gd](file:///e:/kamdraaa-game/scripts/window_lighting.gd) & [scripts/window_rain_drawer.gd](file:///e:/kamdraaa-game/scripts/window_rain_drawer.gd)): NW wall `(310, 305)`. Rainy glass, Venetian blinds with shadow occluder slats, neon sign flicker, and sweeping car headlights.
  - `RoomLights` (`Node2D`): `Room1CeilingLight` (wide fill light illuminating Room 1), `DeskLampLight` (with PCF5 shadows), `MirrorLight`, and `DoorLockLight` (red/green lock status).
  - `Furniture/Bed` (`StaticBody2D`): Located at NE wall `(680, 290)` with `BedOccluder` (`LightOccluder2D`).
  - `Pills` (`Area2D` + [scripts/pills_item.gd](file:///e:/kamdraaa-game/scripts/pills_item.gd)): Near bed `(620, 335)`. Blister pack of sedative pills picked up into inventory.
  - `Furniture/MirrorWithLipstick` (`Area2D` + [scripts/interactive_clue.gd](file:///e:/kamdraaa-game/scripts/interactive_clue.gd)): NW wall `(380, 270)`. Inspects lipstick message "ПОМНИ 04:15".
  - `Furniture/BarReceipt` (`Area2D` + [scripts/interactive_clue.gd](file:///e:/kamdraaa-game/scripts/interactive_clue.gd)): Floor `(530, 410)`. Paper rustle audio + cryptic warning note.
  - `Furniture/SpilledBottle` (`Area2D` + [scripts/interactive_clue.gd](file:///e:/kamdraaa-game/scripts/interactive_clue.gd)): Near center `(450, 360)`.
  - `QuestItem` (`Area2D` + [scripts/quest_item.gd](file:///e:/kamdraaa-game/scripts/quest_item.gd)): Telephone nightstand at `(600, 250)` with `NightstandOccluder` (`LightOccluder2D`). Triggers phone call dialog & unlocks door clue.
  - `Door` (`StaticBody2D` + [scripts/door.gd](file:///e:/kamdraaa-game/scripts/door.gd)): SE wall `(740, 450)`. Dynamic `DoorLockLight` (red -> green) and `DoorOccluder`. Unlocks after telephone interaction.
  - `DarkRoomProps` (`Node2D`): Dark storage room behind the door with `DarkRoomCrates` (`LightOccluder2D`), `DarkRoomSafe` (`Area2D` clue inspection), `BloodStain`, and `EmergencyFlickerLight`.
  - `DarkZone` (`Area2D`): Trigger zone encompassing the dark corridor and storage room for darkness anxiety calculation.
  - `DarknessAnxiety` (`Node` + [scripts/darkness_anxiety.gd](file:///e:/kamdraaa-game/scripts/darkness_anxiety.gd)): Drives panic in the dark (BPM spike, paranoia bar increase, fear whispers, and relief upon lighting up).
  - `HUDParanoia` (`CanvasLayer` + [scripts/hud_paranoia.gd](file:///e:/kamdraaa-game/scripts/hud_paranoia.gd)): Real-time cardio monitor HUD, ECG waveform graph, BPM ticker, stress gauge, panic screen vignette.
  - `InventoryDialog` (`CanvasLayer` + [scripts/inventory_dialog.gd](file:///e:/kamdraaa-game/scripts/inventory_dialog.gd)): In-game physical item inventory & evidence inspector (`I`).
  - `UI` (`CanvasLayer` + [scripts/dialogue_box.gd](file:///e:/kamdraaa-game/scripts/dialogue_box.gd)): Dialogue box with paranoia jitter, character portraits, and typewriter effect.
  - `PauseMenu` (`CanvasLayer` + [scripts/pause_menu.gd](file:///e:/kamdraaa-game/scripts/pause_menu.gd)): In-game pause, case file / clues & mind palace dialog, save/load, settings.

### 🎬 Pause Menu Hierarchy: [scenes/pause_menu.tscn](file:///e:/kamdraaa-game/scenes/pause_menu.tscn)
- Root: `CanvasLayer` (`process_mode = PROCESS_MODE_ALWAYS`)
  - `$PauseContainer/MenuPanel`: Buttons `BtnResume`, `BtnClues`, `BtnSave`, `BtnLoad`, `BtnSettings`, `BtnMainMenu`
  - `$PauseContainer/CluesDialog`: Detective investigation dossier (`DossierView` on tab 1) and Mind Palace board (`MindPalaceView` on tab 2)
  - `$PauseContainer/SaveDialog` & `$PauseContainer/LoadDialog`: Slot selection cards
  - `$PauseContainer/SettingsDialog`: Audio sliders, graphic toggles, key rebind list
  - `$PauseContainer/SettingsConfirmDialog`: Unsaved changes prompt
  - `$ToastNotification`: Dynamic popup banner

---

## 4. Input Map & Hotkeys

| Action | Primary Key | Secondary Key | Function |
|---|---|---|---|
| `move_left`, `move_right`, `move_up`, `move_down` | `A`, `D`, `W`, `S` | Arrow Keys | 8-way movement with acceleration & friction |
| `interact` | `E` | `Space` | Object proximity interaction / Advance dialogue |
| `toggle_flashlight` | `F` | `ПКМ` (Right Click) | Toggle Dasha's flashlight (вкл/выкл фонарик) |
| `toggle_inventory` | `I` | — | Open/Close Physical Item Inventory |
| `toggle_clues` | `Tab` | `J` | Open/Close Case File (Clues Dossier) |
| `toggle_mind_palace` | `M` | — | Open/Close Mind Palace (Доска улик / Соединение зацепок) |
| `toggle_history` | `H` | `Mouse Wheel Up` | Open/Close Dialogue Backlog (History) |
| `ui_cancel` | `Escape` | `P` | Pause menu / Back / Close modal |
| `quick_save` | `F5` | `K` | Instant quick save to Slot 1 |
| `quick_load` | `F9` | `L` | Instant quick load from Slot 1 |
| `toggle_fullscreen` | `F11` | `Alt + Enter` | Toggle Fullscreen / Windowed mode |

---

## 5. Coding Standards & Conventions

1. **Static Typing in GDScript**:
   Always specify types for function signatures and variables:
   ```gdscript
   func calculate_paranoia(delta: float, distance_to_danger: float) -> float:
   ```
2. **Theme Overrides in Code**:
   In Godot 4 scripts, do **NOT** use slash property assignment (e.g. `node.theme_override_colors/font_color = Color(...)` is invalid GDScript syntax).
   Always use API methods:
   ```gdscript
   node.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 1.0))
   node.add_theme_font_size_override("font_size", 14)
   ```
3. **Sound Feedback**:
   Every interactive button or prompt must bind hover and click audio:
   ```gdscript
   btn.mouse_entered.connect(func(): SoundManager.play_hover())
   btn.pressed.connect(func(): SoundManager.play_click())
   ```
4. **Dialogue Flow**:
   When dialogue starts, player movement should be locked (`player.set_physics_process(false)`) and restored on completion (`player.set_physics_process(true)`).

---

## 6. Automation & Developer Tools

- **Codebase Indexer**:
  - Run [tools/index_codebase.bat](file:///e:/kamdraaa-game/tools/index_codebase.bat) to scan the project and update [PROJECT_INDEX.md](file:///e:/kamdraaa-game/PROJECT_INDEX.md) and `.agents/codebase_index.json`.
- **Game Packaging & Installer**:
  - Run [build_installer.bat](file:///e:/kamdraaa-game/build_installer.bat) to export Godot PCK, compile the Inno Setup installer ([installer/Kamdraaa_Setup_v0.2.0.exe](file:///e:/kamdraaa-game/installer/Kamdraaa_Setup_v0.2.0.exe)), and create portable ZIP.
- **Web Research Skill**:
  - Consult [.agents/skills/web-research/SKILL.md](file:///e:/kamdraaa-game/.agents/skills/web-research/SKILL.md) for optimized Godot 4 search formulas, version validation, and vetted documentation hubs.
