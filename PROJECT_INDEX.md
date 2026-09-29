# Kamdraaa - Codebase Index and Architecture Map
*Auto-generated on 2026-09-30 00:59:31 for instant AI navigation.*

## 1. Project Overview
- **Game**: Kamdraaa (Psychological Noir Detective Adventure)
- **Engine**: Godot Engine 4.7.2 stable (Windows 64-bit)
- **Main Scene**: `res://scenes/main_menu.tscn`
- **Resolution**: 1280x720 (stretch mode: canvas_items)

## 2. Autoload Singletons (Global Systems)
| Singleton | Script Path | Responsibility |
|---|---|---|
| `SoundManager` | `res://scripts/sound_manager.gd` | Procedural audio synth (footsteps, phone, clue chimes, rustle, clicks, ambient) |
| `SettingsManager` | `res://scripts/settings_manager.gd` | Audio bus volumes, CRT shader, V-Sync, Fullscreen, key rebinding |
| `SaveManager` | `res://scripts/save_manager.gd` | JSON slots save/load, quicksave F5/K, quickload F9/L, persistent data |
| `ClueManager` | `res://scripts/clue_manager.gd` | Investigation case file, 5 clues discovery, hints, signals |
| `ParanoiaManager` | `res://scripts/paranoia_manager.gd` | Global Autoload |
| `InventoryManager` | `res://scripts/inventory_manager.gd` | Global Autoload |

## 3. Input Actions
`ui_cancel`, `move_left`, `move_right`, `move_up`, `move_down`, `interact`, `quick_save`, `quick_load`, `toggle_fullscreen`, `toggle_clues`, `toggle_history`, `toggle_mind_palace`, `toggle_flashlight`

## 4. Scripts Inventory (21 scripts in scripts/)
### [clue_manager.gd](scripts/clue_manager.gd) (385 lines)
*Глобальный менеджер улик, подсказок и чертогов разума (ClueManager)*

- **Extends**: `Node`
- **Signals**: `clue_discovered(clue_id: String, clue_data: Dictionary)`, `clues_updated`, `deduction_unlocked(deduction_id: String, deduction_data: Dictionary)`, `deduction_failed(clue_a: String, clue_b: String, reason: String)`
- **Key Functions**:
  - `_ready()-> void`
  - `discover_clue(clue_id: String)-> bool`
  - `is_clue_discovered(clue_id: String)-> bool`
  - `get_clue(clue_id: String)-> Dictionary`
  - `get_discovered_count()-> int`
  - `get_total_count()-> int`
  - `connect_clues(clue_a: String, clue_b: String)-> Dictionary`
  - `get_mismatch_reason(clue_a: String, clue_b: String)-> String`
  - `is_deduction_unlocked(deduction_id: String)-> bool`
  - `get_deduction(deduction_id: String)-> Dictionary`
  - *... and 5 more functions*

### [darkness_anxiety.gd](scripts/darkness_anxiety.gd) (121 lines)
*DarknessAnxiety — Механика паники и тревоги в темноте (Fear of the Dark)*

- **Extends**: `Node`
- **Class**: `DarknessAnxiety`
- **Exports**: `var player: CharacterBody2D`, `var dark_zone: Area2D`
- **Key Functions**:
  - `_ready()-> void`
  - `_on_dark_zone_body_entered(body: Node2D)-> void`
  - `_on_dark_zone_body_exited(body: Node2D)-> void`
  - `_process(delta: float)-> void`
  - `_handle_darkness(delta: float)-> void`
  - `_trigger_darkness_whisper()-> void`
  - `_resolve_darkness_relief(lit_by_flashlight: bool)-> void`

### [dialogue_box.gd](scripts/dialogue_box.gd) (765 lines)
*Портреты персонажей в диалогах*

- **Extends**: `CanvasLayer`
- **Signals**: `dialogue_started`, `dialogue_finished`
- **Key Functions**:
  - `_ready()-> void`
  - `_setup_panel_style()-> void`
  - `_on_dialogue_gui_input(event: InputEvent)-> void`
  - `_setup_history_ui()-> void`
  - `_process(_delta: float)-> void`
  - `_reset_panel_position()-> void`
  - `start_dialogue(lines: Array)-> void`
  - `_show_next_line()-> void`
  - `_on_typing_completed()-> void`
  - `_finish_typing_instantly()-> void`
  - *... and 11 more functions*

### [door.gd](scripts/door.gd) (93 lines)
*Скрипт двери с электрозамком*

- **Extends**: `StaticBody2D`
- **Key Functions**:
  - `_ready()-> void`
  - `set_state(opened: bool)-> void`
  - `open()-> void`
  - `close()-> void`

### [flashlight.gd](scripts/flashlight.gd) (228 lines)
*Flashlight — Система налобного/карманного фонарика Даши с динамическими тенями*

- **Extends**: `Node2D`
- **Class**: `Flashlight`
- **Signals**: `flashlight_toggled(is_on: bool)`
- **Exports**: `var is_flashlight_on: bool`, `var beam_color: Color`, `var ambient_color: Color`, `var beam_energy: float`, `var ambient_energy: float`, `var smooth_speed: float`
- **Key Functions**:
  - `_ready()-> void`
  - `_setup_lights()-> void`
  - `_input(event: InputEvent)-> void`
  - `toggle_flashlight(enable_state: Variant = null)-> void`
  - `is_on()-> bool`
  - `_update_light_states()-> void`
  - `_process(delta: float)-> void`
  - `_get_or_create_cone_texture()-> ImageTexture`
  - `_get_or_create_radial_texture()-> ImageTexture`

### [hud_paranoia.gd](scripts/hud_paranoia.gd) (214 lines)
*HUD: Монитор биоритмов и шкала паранойи (Heart Rate & Paranoia System)*

- **Extends**: `CanvasLayer`
- **Key Functions**:
  - `_ready()-> void`
  - `_process(delta: float)-> void`
  - `_on_heartbeat_pulsed(bpm: int, intensity: float)-> void`
  - `_on_paranoia_changed(new_level: float, _delta: float, _reason: String)-> void`
  - `_on_panic_state_changed(is_panic: bool)-> void`
  - `_update_display(level: float, bpm: int)-> void`
  - `_on_ecg_draw()-> void`
  - `draw_line_grid(target: Control, size: Vector2, grid_color: Color)-> void`

### [interactive_clue.gd](scripts/interactive_clue.gd) (259 lines)
*Универсальный скрипт интерактивного объекта / улики расследования*

- **Extends**: `Area2D`
- **Exports**: `var clue_id: String`, `var prompt_title: String`, `var sound_method: String`, `var dialogue_box: CanvasLayer`, `var player: CharacterBody2D`
- **Key Functions**:
  - `_ready()-> void`
  - `_start_pulse_animation()-> void`
  - `_unhandled_input(event: InputEvent)-> void`
  - `_on_body_entered(body: Node2D)-> void`
  - `_on_body_exited(body: Node2D)-> void`
  - `_update_label()-> void`
  - `interact()-> void`
  - `_on_inspection_finished()-> void`

### [inventory_dialog.gd](scripts/inventory_dialog.gd) (207 lines)
*InventoryDialog — Окно инвентаря и вещевых доказательств Даши*

- **Extends**: `CanvasLayer`
- **Key Functions**:
  - `_ready()-> void`
  - `_unhandled_input(event: InputEvent)-> void`
  - `toggle_inventory()-> void`
  - `open_inventory()-> void`
  - `close_inventory()-> void`
  - `_refresh_ui()-> void`
  - `_select_item(id: String)-> void`
  - `_on_use_pressed()-> void`

### [inventory_manager.gd](scripts/inventory_manager.gd) (151 lines)
*InventoryManager — Глобальный менеджер инвентаря Даши (Detective Inventory System)*

- **Extends**: `Node`
- **Signals**: `inventory_updated`, `item_added(item_id: String, count: int)`, `item_removed(item_id: String, count: int)`, `item_used(item_id: String, success: bool)`, `toast_requested(message: String)`
- **Key Functions**:
  - `_ready()-> void`
  - `add_item(id: String, name: String, count: int = 1, icon: String = "📦", description: String = "", usable: bool = false)-> void`
  - `remove_item(id: String, count: int = 1)-> bool`
  - `has_item(id: String)-> bool`
  - `get_item_count(id: String)-> int`
  - `get_item(id: String)-> Dictionary`
  - `use_item(id: String)-> bool`
  - `_use_pills()-> bool`
  - `get_save_data()-> Dictionary`
  - `load_save_data(data: Dictionary)-> void`
  - *... and 1 more functions*

### [main.gd](scripts/main.gd) (42 lines)
*Сцена: Стартовая комната (Похмельное пробуждение Даши)*

- **Extends**: `Node2D`
- **Key Functions**:
  - `_ready()-> void`

### [main_menu.gd](scripts/main_menu.gd) (744 lines)
*Скрипт главного меню (MainMenu)*

- **Extends**: `Control`
- **Key Functions**:
  - `_ready()-> void`
  - `_update_load_button_state()-> void`
  - `_process(delta: float)-> void`
  - `_connect_main_buttons()-> void`
  - `_connect_modal_buttons()-> void`
  - `_bind_sound_feedback(buttons: Array[Button])-> void`
  - `_on_play_pressed()-> void`
  - `_on_continue_pressed()-> void`
  - `_on_new_game_pressed()-> void`
  - `_start_fresh_game()-> void`
  - *... and 25 more functions*

### [paranoia_manager.gd](scripts/paranoia_manager.gd) (151 lines)
*ParanoiaManager — Глобальный менеджер пульса, стресса и паранойи (Heart Rate & Paranoia System)*

- **Extends**: `Node`
- **Signals**: `paranoia_changed(new_level: float, delta: float, reason: String)`, `heartbeat_pulsed(bpm: int, intensity: float)`, `panic_state_changed(is_panic: bool)`
- **Key Functions**:
  - `_ready()-> void`
  - `_process(delta: float)-> void`
  - `_update_bpm(_delta: float)-> void`
  - `_trigger_heartbeat()-> void`
  - `add_paranoia(amount: float, reason: String = "")-> void`
  - `reduce_paranoia(amount: float)-> void`
  - `set_paranoia(level: float)-> void`
  - `get_paranoia()-> float`
  - `get_bpm()-> int`
  - `is_panic()-> bool`
  - *... and 3 more functions*

### [pause_menu.gd](scripts/pause_menu.gd) (1216 lines)
*Скрипт меню паузы во время игры (PauseMenu)*

- **Extends**: `CanvasLayer`
- **Key Functions**:
  - `_ready()-> void`
  - `_unhandled_input(event: InputEvent)-> void`
  - `close_menu()-> void`
  - `toggle_pause()-> void`
  - `_connect_buttons()-> void`
  - `_bind_sound_feedback(buttons: Array[Button])-> void`
  - `_on_save_pressed()-> void`
  - `_on_load_pressed()-> void`
  - `_on_settings_pressed()-> void`
  - `_on_main_menu_pressed()-> void`
  - *... and 36 more functions*

### [pills_item.gd](scripts/pills_item.gd) (90 lines)
*Интерактивный предмет: Блистер с успокоительными таблетками (PillsItem)*

- **Extends**: `Area2D`
- **Exports**: `var prompt_title: String`, `var dialogue_box: CanvasLayer`, `var player: CharacterBody2D`
- **Key Functions**:
  - `_ready()-> void`
  - `_start_subtle_glow()-> void`
  - `_process(_delta: float)-> void`
  - `_on_body_entered(body: Node2D)-> void`
  - `_on_body_exited(body: Node2D)-> void`
  - `_update_label()-> void`
  - `pick_up_pills()-> void`

### [player.gd](scripts/player.gd) (145 lines)
*Скорость передвижения персонажа (пикселей в секунду)*

- **Extends**: `CharacterBody2D`
- **Exports**: `var speed: float`, `var acceleration: float`, `var friction: float`
- **Key Functions**:
  - `_ready()-> void`
  - `set_control_locked(locked: bool)-> void`
  - `_process(delta: float)-> void`
  - `apply_shake(amount: float)-> void`
  - `_physics_process(delta: float)-> void`
  - `_update_sprite_animation(delta: float)-> void`

### [quest_item.gd](scripts/quest_item.gd) (217 lines)
*Ссылки на связанные узлы сцены*

- **Extends**: `Area2D`
- **Exports**: `var door_to_open: StaticBody2D`, `var dialogue_box: CanvasLayer`, `var player: CharacterBody2D`
- **Key Functions**:
  - `_ready()-> void`
  - `_exit_tree()-> void`
  - `_start_ringing_animation()-> void`
  - `_process(_delta: float)-> void`
  - `_on_body_entered(body: Node2D)-> void`
  - `_on_body_exited(body: Node2D)-> void`
  - `set_phone_state(answered: bool)-> void`
  - `answer_phone()-> void`
  - `_on_dialogue_finished()-> void`
  - `open_door()-> void`

### [save_manager.gd](scripts/save_manager.gd) (411 lines)
*Менеджер системы сохранений (SaveManager)*

- **Extends**: `Node`
- **Signals**: `game_saved(slot_id: String, success: bool)`, `game_loaded(slot_id: String, success: bool)`, `save_deleted(slot_id: String)`, `toast_requested(message: String)`
- **Key Functions**:
  - `_ready()-> void`
  - `_ensure_saves_dir_exists()-> void`
  - `_ensure_initial_saves_exist()-> void`
  - `create_sample_saves()-> void`
  - `create_sample_save_for_slot(slot_id: String)-> bool`
  - `get_slot_path(slot_id: String)-> String`
  - `save_exists(slot_id: String)-> bool`
  - `get_save_info(slot_id: String)-> Dictionary`
  - `_get_default_slot_title(slot_id: String)-> String`
  - `has_any_save()-> bool`
  - *... and 6 more functions*

### [settings_manager.gd](scripts/settings_manager.gd) (281 lines)
*Менеджер настроек (SettingsManager)*

- **Extends**: `Node`
- **Signals**: `settings_updated`, `keybinds_updated`
- **Key Functions**:
  - `_ready()-> void`
  - `_record_default_keybinds()-> void`
  - `load_settings()-> void`
  - `save_settings()-> void`
  - `get_typewriter_char_duration()-> float`
  - `get_speed_title(mode: int = -1)-> String`
  - `set_text_speed(mode: int, auto_save: bool = false)-> void`
  - `set_auto_advance(enabled: bool, auto_save: bool = false)-> void`
  - `set_auto_advance_delay(delay: float, auto_save: bool = false)-> void`
  - `_apply_action_key(action_name: String, key_code: Key)-> void`
  - *... and 15 more functions*

### [sound_manager.gd](scripts/sound_manager.gd) (598 lines)
*Менеджер процедурных звуковых эффектов (SoundManager)*

- **Extends**: `Node`
- **Key Functions**:
  - `_ready()-> void`
  - `_generate_procedural_sounds()-> void`
  - `_create_sound(duration: float, sample_rate: int, generator: Callable)-> AudioStreamWAV`
  - `_create_footstep(is_left: bool, sample_rate: int = 22050)-> AudioStreamWAV`
  - `_create_phone_ring(sample_rate: int = 22050)-> AudioStreamWAV`
  - `_create_phone_pickup(sample_rate: int = 22050)-> AudioStreamWAV`
  - `_create_dialogue_advance(sample_rate: int = 22050)-> AudioStreamWAV`
  - `_create_looping_music(duration: float, sample_rate: int)-> AudioStreamWAV`
  - `start_bg_music()-> void`
  - `stop_bg_music()-> void`
  - *... and 26 more functions*

### [window_lighting.gd](scripts/window_lighting.gd) (321 lines)
*WindowLighting — Нуарное окно в ночной дождливый город*

- **Extends**: `Node2D`
- **Class**: `WindowLighting`
- **Exports**: `var is_active: bool`
- **Key Functions**:
  - `_ready()-> void`
  - `_create_window_visuals()-> void`
  - `_create_blinds_and_occluders()-> void`
  - `_create_lights()-> void`
  - `_setup_car_timer()-> void`
  - `_init_rain_droplets()-> void`
  - `_process(delta: float)-> void`
  - `_update_neon_sign(delta: float)-> void`
  - `_trigger_car_pass()-> void`
  - `_update_car_pass(delta: float)-> void`
  - *... and 3 more functions*

### [window_rain_drawer.gd](scripts/window_rain_drawer.gd) (41 lines)
*WindowRainDrawer — Отрисовка капель и струек дождя на изометрическом стекле окна*

- **Extends**: `Node2D`
- **Class**: `WindowRainDrawer`
- **Key Functions**:
  - `set_droplets(drops: Array)-> void`
  - `_draw()-> void`

## 5. Scenes Inventory (5 scenes in scenes/)
### [hud_paranoia.tscn](scenes/hud_paranoia.tscn) (Root: `HUDParanoia` [CanvasLayer])
- Node count: 16
- **Node Tree Hierarchy**:
  - ./PanicVignette (ColorRect)
  - ./HUDContainer (Control)
  - HUDContainer/Panel (PanelContainer)
  - HUDContainer/Panel/MarginContainer (MarginContainer)
  - HUDContainer/Panel/MarginContainer/VBoxContainer (VBoxContainer)
  - HUDContainer/Panel/MarginContainer/VBoxContainer/TopRow (HBoxContainer)
  - HUDContainer/Panel/MarginContainer/VBoxContainer/TopRow/HeartIcon (Label)
  - HUDContainer/Panel/MarginContainer/VBoxContainer/TopRow/BPMLabel (Label)
  - HUDContainer/Panel/MarginContainer/VBoxContainer/TopRow/StatusBadge (Label)
  - HUDContainer/Panel/MarginContainer/VBoxContainer/ECGContainer (PanelContainer)
  - HUDContainer/Panel/MarginContainer/VBoxContainer/ECGContainer/ECGWave (Control)
  - HUDContainer/Panel/MarginContainer/VBoxContainer/BottomRow (HBoxContainer)
  - HUDContainer/Panel/MarginContainer/VBoxContainer/BottomRow/ParanoiaTitle (Label)
  - HUDContainer/Panel/MarginContainer/VBoxContainer/BottomRow/ParanoiaBar (ProgressBar)
  - HUDContainer/Panel/MarginContainer/VBoxContainer/BottomRow/ParanoiaPercent (Label)

### [inventory_dialog.tscn](scenes/inventory_dialog.tscn) (Root: `InventoryDialog` [CanvasLayer])
- Node count: 24
- **Node Tree Hierarchy**:
  - ./Backdrop (ColorRect)
  - ./WindowPanel (PanelContainer)
  - WindowPanel/Margin (MarginContainer)
  - WindowPanel/Margin/VBox (VBoxContainer)
  - WindowPanel/Margin/VBox/HeaderHBox (HBoxContainer)
  - WindowPanel/Margin/VBox/HeaderHBox/TitleLabel (Label)
  - WindowPanel/Margin/VBox/HeaderHBox/HotkeyHint (Label)
  - WindowPanel/Margin/VBox/HeaderHBox/BtnClose (Button)
  - WindowPanel/Margin/VBox/ContentHBox (HBoxContainer)
  - WindowPanel/Margin/VBox/ContentHBox/LeftCol (VBoxContainer)
  - WindowPanel/Margin/VBox/ContentHBox/LeftCol/ColHeader (Label)
  - WindowPanel/Margin/VBox/ContentHBox/LeftCol/Scroll (ScrollContainer)
  - WindowPanel/Margin/VBox/ContentHBox/LeftCol/Scroll/ItemListContainer (VBoxContainer)
  - WindowPanel/Margin/VBox/ContentHBox/LeftCol/EmptyLabel (Label)
  - WindowPanel/Margin/VBox/ContentHBox/RightCol (VBoxContainer)
  - WindowPanel/Margin/VBox/ContentHBox/RightCol/DetailPanel (PanelContainer)
  - *... and 7 more child nodes*

### [main.tscn](scenes/main.tscn) (Root: `Main` [Node2D])
- Node count: 156
- **Node Tree Hierarchy**:
  - ./CanvasModulate (CanvasModulate)
  - ./Floor (Node2D)
  - Floor/RoomFloor (Polygon2D)
  - Floor/FloorGridLine1 (Line2D)
  - Floor/FloorGridLine2 (Line2D)
  - Floor/FloorGridLine3 (Line2D)
  - Floor/FloorGridLine4 (Line2D)
  - Floor/FloorBorder (Line2D)
  - Floor/DarkRoomFloor (Polygon2D)
  - Floor/DarkRoomGrid1 (Line2D)
  - Floor/DarkRoomGrid2 (Line2D)
  - Floor/DarkRoomGrid3 (Line2D)
  - Floor/DarkRoomBorder (Line2D)
  - Floor/BloodStain (Polygon2D)
  - ./Walls (StaticBody2D)
  - Walls/WallNW_Collision (CollisionPolygon2D)
  - *... and 139 more child nodes*

### [main_menu.tscn](scenes/main_menu.tscn) (Root: `MainMenu` [Control])
- Node count: 104
- **Node Tree Hierarchy**:
  - ./Background (ColorRect)
  - ./RainOverlay (ColorRect)
  - ./DecorIsoGrid (Node2D)
  - DecorIsoGrid/Line1 (Line2D)
  - DecorIsoGrid/Line2 (Line2D)
  - DecorIsoGrid/Line3 (Line2D)
  - DecorIsoGrid/Line4 (Line2D)
  - DecorIsoGrid/Line5 (Line2D)
  - DecorIsoGrid/Line6 (Line2D)
  - ./Vignette (ColorRect)
  - ./Content (Control)
  - Content/Header (VBoxContainer)
  - Content/Header/Category (Label)
  - Content/Header/Title (Label)
  - Content/Header/Subtitle (Label)
  - Content/Divider (ColorRect)
  - *... and 87 more child nodes*

### [pause_menu.tscn](scenes/pause_menu.tscn) (Root: `PauseMenu` [CanvasLayer])
- Node count: 157
- **Node Tree Hierarchy**:
  - ./PauseContainer (Control)
  - PauseContainer/Backdrop (ColorRect)
  - PauseContainer/MenuPanel (PanelContainer)
  - PauseContainer/MenuPanel/Margin (MarginContainer)
  - PauseContainer/MenuPanel/Margin/VBox (VBoxContainer)
  - PauseContainer/MenuPanel/Margin/VBox/Title (Label)
  - PauseContainer/MenuPanel/Margin/VBox/Subtitle (Label)
  - PauseContainer/MenuPanel/Margin/VBox/Spacer (Control)
  - PauseContainer/MenuPanel/Margin/VBox/BtnResume (Button)
  - PauseContainer/MenuPanel/Margin/VBox/BtnClues (Button)
  - PauseContainer/MenuPanel/Margin/VBox/BtnSave (Button)
  - PauseContainer/MenuPanel/Margin/VBox/BtnLoad (Button)
  - PauseContainer/MenuPanel/Margin/VBox/BtnSettings (Button)
  - PauseContainer/MenuPanel/Margin/VBox/BtnMainMenu (Button)
  - PauseContainer/SaveDialog (PanelContainer)
  - PauseContainer/SaveDialog/Margin (MarginContainer)
  - *... and 140 more child nodes*

