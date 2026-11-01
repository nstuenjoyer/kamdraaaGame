extends Node

enum Stage { PHONE, SEARCH_BED, PICKUP, USE, DONE }
var stage: int = Stage.PHONE
var _call_active: bool = false
var _search_pending: bool = false
var _goal: Label
var _bed_prompt: Label
var _ui: CanvasLayer
var _player: CharacterBody2D

func _ready() -> void:
	_ui = get_parent().get_node("UI") as CanvasLayer
	_player = get_parent().get_node("Player") as CharacterBody2D
	_ui.dialogue_line_shown.connect(_on_line)
	_ui.dialogue_finished.connect(_on_finished)
	_ui.dialogue_cancelled.connect(_on_cancelled)
	InventoryManager.item_added.connect(_on_item_added)
	InventoryManager.item_used.connect(_on_item_used)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_goal = Label.new()
	_goal.position = Vector2(260, 16)
	_goal.size = Vector2(maxf(220.0, get_viewport().get_visible_rect().size.x - 660.0), 105)
	_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal.add_theme_font_size_override("font_size", 16)
	_goal.add_theme_constant_override("outline_size", 5)
	_goal.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 1.0))
	_goal.add_theme_color_override("font_color", Color(0.87, 0.92, 1.0))
	layer.add_child(_goal)
	_bed_prompt = get_parent().get_node("Bed/BedLabel") as Label
	_bed_prompt.offset_left = -100.0
	_bed_prompt.offset_right = 100.0
	apply_stage(Stage.PHONE)

func _exit_tree() -> void:
	ParanoiaManager.is_decay_active = true

func apply_stage(value: int) -> void:
	stage = clampi(value, Stage.PHONE, Stage.DONE)
	_call_active = false
	_search_pending = false
	ParanoiaManager.is_decay_active = not (stage >= Stage.SEARCH_BED and stage < Stage.DONE)
	var pills: Node = get_parent().get_node("Pills")
	pills.visible = stage >= Stage.PICKUP and not pills.picked_up
	pills.set_process(pills.visible)
	_update_goal()

func begin_call() -> void:
	if stage == Stage.PHONE:
		_call_active = true
		ParanoiaManager.is_decay_active = false

func _on_line(index: int) -> void:
	if not _call_active:
		return
	var count: int = _ui.dialogue_lines.size()
	var target: float = lerpf(22.0, 100.0, float(index) / maxf(1.0, float(count - 1)))
	ParanoiaManager.add_paranoia(maxf(0.0, target - ParanoiaManager.target_paranoia), "Звонок")

func finish_call() -> void:
	if stage != Stage.PHONE:
		return
	ParanoiaManager.set_paranoia(100.0)
	apply_stage(Stage.SEARCH_BED)

func _process(_delta: float) -> void:
	_update_goal()
	if stage == Stage.SEARCH_BED:
		_bed_prompt.text = "НАЙТИ ТАБЛЕТКИ [%s]" % SettingsManager.get_action_key_name("interact")
		_bed_prompt.modulate = Color(0.5, 1.0, 0.85)
	else:
		_bed_prompt.text = "Кровать"
		_bed_prompt.modulate = Color.WHITE

func _update_goal() -> void:
	var interact: String = SettingsManager.get_action_key_name("interact")
	var inventory: String = SettingsManager.get_action_key_name("toggle_inventory")
	match stage:
		Stage.PHONE:
			_goal.text = "Подойдите к телефону и нажмите [%s]. Во время разговора та же клавиша продолжает реплики." % interact
		Stage.SEARCH_BED:
			_goal.text = "ЦЕЛЬ: НАЙТИ УСПОКОИТЕЛЬНЫЕ\nПодойдите к кровати и нажмите [%s], чтобы обыскать её. Таблетки помогут снизить шкалу СТРЕСС слева сверху." % interact
		Stage.PICKUP:
			_goal.text = "ЦЕЛЬ: ЗАБРАТЬ ТАБЛЕТКИ\nОбыск обнаружил упаковку на полу у ножки кровати. Подойдите к ней и нажмите [%s]." % interact
		Stage.USE:
			_goal.text = "Откройте инвентарь [%s], выберите таблетки и нажмите «Использовать». Одна доза снимает 40 пунктов тревоги." % inventory
		Stage.DONE:
			_goal.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if stage != Stage.SEARCH_BED or _ui.is_active or get_parent().get_node("InventoryDialog").is_open:
		return
	if not event.is_action_pressed("interact") or event.is_echo():
		return
	var bed: Node2D = get_parent().get_node("Bed") as Node2D
	if _player.global_position.distance_to(bed.global_position) > 95.0:
		return
	get_viewport().set_input_as_handled()
	search_bed()

func search_bed() -> void:
	if stage != Stage.SEARCH_BED or _ui.is_active:
		return
	_search_pending = true
	_player.set_control_locked(true)
	SoundManager.play_material_interact("wood")
	_ui.start_dialogue([{"speaker": "Даша", "text": "Под подушкой пусто... А вот на полу у ножки кровати — блистер. Нужно забрать его и принять таблетку. От этого сердцебиения невозможно думать.", "paranoia": false}])

func _on_finished() -> void:
	if not get_parent().get_node("InventoryDialog").is_open:
		_player.set_control_locked(false)
	if not _search_pending:
		return
	_player.set_control_locked(false)
	apply_stage(Stage.PICKUP)

func _on_cancelled() -> void:
	_call_active = false
	_search_pending = false
	_player.set_control_locked(false)
	ParanoiaManager.is_decay_active = not (stage >= Stage.SEARCH_BED and stage < Stage.DONE)

func _on_item_added(id: String, _count: int) -> void:
	if id == "pills" and stage == Stage.PICKUP:
		apply_stage(Stage.USE)

func _on_item_used(id: String, success: bool) -> void:
	if id == "pills" and success and stage == Stage.USE:
		apply_stage(Stage.DONE)
		SaveManager.toast_requested.emit("Тревога снизилась на 40 пунктов. Свет останавливает страх темноты, а таблетки помогают снять накопившийся стресс.")
