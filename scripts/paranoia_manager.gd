extends Node

# ParanoiaManager — Глобальный менеджер пульса, стресса и паранойи (Heart Rate & Paranoia System)
# Управляет уровнем тревоги Даши, рассчитывает динамический BPM, генерирует сердечные импульсы
# и синхронизирует звуковые и визуальные эффекты паники.

signal paranoia_changed(new_level: float, delta: float, reason: String)
signal heartbeat_pulsed(bpm: int, intensity: float)
signal panic_state_changed(is_panic: bool)

# Константы уровней тревоги
const BASE_FLOOR: float = 14.0 # Похмельная фоновая тревога (не опускается до нуля в мрачном номере)
const CALM_THRESHOLD: float = 35.0
const ANXIETY_THRESHOLD: float = 60.0
const SEVERE_THRESHOLD: float = 80.0
const MAX_PARANOIA: float = 100.0

# Текущие показатели
var paranoia_level: float = 22.0 # Текущий сглаженный уровень (0.0 — 100.0)
var target_paranoia: float = 22.0 # Целевой уровень для плавного lerp
var current_bpm: int = 74
var _heartbeat_timer: float = 0.8
var _is_panic_active: bool = false

# Параметры затухания и реакции
var decay_rate: float = 0.65 # Пункты шкалы в секунду после выхода из опасности
var is_decay_active: bool = false
var is_active: bool = false:
	set(value):
		is_active = value
		if not value:
			_heartbeat_timer = 0.35
			_stop_heartbeat_audio()
var _decay_delay_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_update_bpm(0.0)
	get_tree().scene_changed.connect(_on_scene_changed)

func _process(delta: float) -> void:
	if not is_active or get_tree().paused or not _in_gameplay_scene():
		_heartbeat_timer = 0.35
		_stop_heartbeat_audio()
		return

	# 1. Плавный переход текущей паранойи к целевой
	var prev_paranoia: float = paranoia_level
	if absf(paranoia_level - target_paranoia) > 0.05:
		var response_rate: float = 65.0 if target_paranoia > paranoia_level else 1.2
		paranoia_level = move_toward(paranoia_level, target_paranoia, delta * response_rate)
		if not is_equal_approx(prev_paranoia, paranoia_level):
			paranoia_changed.emit(paranoia_level, paranoia_level - prev_paranoia, "")

	# 2. Естественное затухание тревоги со временем (после короткой задержки от шока)
	if _decay_delay_timer > 0.0:
		_decay_delay_timer -= delta
	elif is_decay_active and target_paranoia > BASE_FLOOR:
		target_paranoia = move_toward(target_paranoia, BASE_FLOOR, delta * decay_rate)

	# 3. Расчёт пульса (BPM) с органической микро-вариативностью
	_update_bpm(delta)

	# 4. Таймер сердечного ритма
	var beat_interval: float = 60.0 / float(max(45, current_bpm))
	_heartbeat_timer -= delta
	if _heartbeat_timer <= 0.0:
		_heartbeat_timer = maxf(0.03, _heartbeat_timer + beat_interval)
		_trigger_heartbeat()

func _in_gameplay_scene() -> bool:
	var scene: Node = get_tree().current_scene
	return scene != null and (scene.has_method("export_chapter_save") or scene.scene_file_path == "res://scenes/main.tscn")

func _on_scene_changed() -> void:
	is_active = _in_gameplay_scene()
	_heartbeat_timer = 0.35
	_stop_heartbeat_audio()

func _stop_heartbeat_audio() -> void:
	var sound: Node = get_node_or_null("/root/SoundManager")
	if sound != null and sound.has_method("stop_heartbeat"): sound.stop_heartbeat()

func _update_bpm(_delta: float) -> void:
	# Рассчитываем BPM: от ~68 в спокойствии до ~172 при максимальном стрессе
	var norm: float = clampf(paranoia_level / MAX_PARANOIA, 0.0, 1.0)
	var base_bpm: float = lerpf(68.0, 172.0, norm)
	
	# Добавляем микро-вариативность дыхания
	var time_sec: float = Time.get_ticks_msec() / 1000.0
	var organic_jitter: float = sin(time_sec * 1.8) * 1.5
	current_bpm = roundi(clampf(base_bpm + organic_jitter, 55.0, 190.0))

	# Проверка входа/выхода из панического состояния
	var now_panic: bool = paranoia_level >= (70.0 if _is_panic_active else SEVERE_THRESHOLD)
	if now_panic != _is_panic_active:
		_is_panic_active = now_panic
		panic_state_changed.emit(_is_panic_active)

func _trigger_heartbeat() -> void:
	if not is_active or get_tree().paused or not _in_gameplay_scene(): return
	var intensity: float = clampf(paranoia_level / MAX_PARANOIA, 0.0, 1.0)
	heartbeat_pulsed.emit(current_bpm, intensity)

	# Процедурное воспроизведение через SoundManager
	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_heartbeat_pulse"):
		sound_mgr.play_heartbeat_pulse(current_bpm, intensity)

## Увеличить уровень паранойи с указанием причины
func add_paranoia(amount: float, reason: String = "") -> void:
	var old_target: float = target_paranoia
	target_paranoia = clampf(target_paranoia + amount, 0.0, MAX_PARANOIA)
	_decay_delay_timer = 5.0 # Свет останавливает рост, но успокоение начинается не сразу
	paranoia_changed.emit(paranoia_level, target_paranoia - old_target, reason)
	
	# При сильном резком скачке сбрасываем таймер сердцебиения для немедленного удара
	if amount >= 12.0:
		_heartbeat_timer = minf(_heartbeat_timer, 0.12)

## Снизить уровень паранойи (умывание водой, таблетки, удачное нахождение зацепки)
func reduce_paranoia(amount: float) -> void:
	var old_target: float = target_paranoia
	target_paranoia = clampf(target_paranoia - amount, BASE_FLOOR, MAX_PARANOIA)
	paranoia_level = clampf(paranoia_level - amount, BASE_FLOOR, MAX_PARANOIA)
	_decay_delay_timer = 0.0
	_update_bpm(0.0)
	paranoia_changed.emit(paranoia_level, target_paranoia - old_target, "Успокоение")

## Принудительно установить уровень паранойи (например, при загрузке сохранения)
func set_paranoia(level: float) -> void:
	_decay_delay_timer = 5.0
	paranoia_level = clampf(level, 0.0, MAX_PARANOIA)
	target_paranoia = paranoia_level
	_update_bpm(0.0)
	paranoia_changed.emit(paranoia_level, 0.0, "Загрузка")

func get_paranoia() -> float:
	return paranoia_level

func get_bpm() -> int:
	return current_bpm

func is_panic() -> bool:
	return _is_panic_active

## Текстовый статус для интерфейса
func get_status_text() -> String:
	if paranoia_level < CALM_THRESHOLD:
		return "СПОКОЙСТВИЕ"
	elif paranoia_level < ANXIETY_THRESHOLD:
		return "ТРЕВОГА"
	elif paranoia_level < SEVERE_THRESHOLD:
		return "ОСТРАЯ ПАРАНОЙЯ"
	else:
		return "ПАНИКА"

## Цветовой код статуса в неонуарной палитре
func get_status_color() -> Color:
	if paranoia_level < CALM_THRESHOLD:
		return Color(0.35, 0.88, 0.95, 1.0) # Неоново-бирюзовый
	elif paranoia_level < ANXIETY_THRESHOLD:
		return Color(0.96, 0.82, 0.32, 1.0) # Янтарно-золотой
	elif paranoia_level < SEVERE_THRESHOLD:
		return Color(1.0, 0.54, 0.22, 1.0)  # Напряжённый оранжевый
	else:
		return Color(1.0, 0.22, 0.34, 1.0)  # Кроваво-алый неоновый

## Сброс состояния к стартовому уровню новой игры
func reset_to_default() -> void:
	_decay_delay_timer = 0.0
	paranoia_level = 22.0
	target_paranoia = 22.0
	_is_panic_active = false
	_heartbeat_timer = 0.8
	_update_bpm(0.0)
