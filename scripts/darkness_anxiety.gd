class_name DarknessAnxiety
extends Node

# DarknessAnxiety — Механика паники и тревоги в темноте (Fear of the Dark)
# Отслеживает нахождение Даши в неосвещенных зонах.
# Если героиня находится в темной комнате без включенного фонарика:
# - Нарастает уровень стресса и паранойи (ParanoiaManager)
# - Пульс (BPM) учащается, учащается сердцебиение
# - Появляются зловещие слуховые шепоты и визуальные искажения
# - Включение фонарика или возвращение в светлую комнату приносит облегчение.

@export var player: CharacterBody2D
@export var dark_zone: Area2D

var _is_player_in_dark_zone: bool = false
var _is_in_darkness: bool = false
var _darkness_duration: float = 0.0
var _whisper_timer: float = 0.0
var _toast_shown: bool = false
var _was_in_darkness: bool = false

const WHISPERS: Array[String] = [
	"«...во тьме что-то шевелится... включи свет...»",
	"«...я ничего не вижу... нужен фонарик [F / ПКМ]...»",
	"«...оно подходит сзади... включи луч!...»",
	"«...в висках гудит кровь... не оставайся во тьме...»",
	"«...они знают, что ты здесь... освети комнату!...»"
]

func _ready() -> void:
	if dark_zone:
		dark_zone.body_entered.connect(_on_dark_zone_body_entered)
		dark_zone.body_exited.connect(_on_dark_zone_body_exited)

func _on_dark_zone_body_entered(body: Node2D) -> void:
	if body == player:
		_is_player_in_dark_zone = true

func _on_dark_zone_body_exited(body: Node2D) -> void:
	if body == player:
		_is_player_in_dark_zone = false
		if _is_in_darkness:
			_resolve_darkness_relief(true)

func _process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		return

	# Проверяем состояние фонарика
	var flashlight: Node = player.get_node_or_null("Flashlight")
	var is_flashlight_lit: bool = false
	if flashlight and flashlight.has_method("is_on"):
		is_flashlight_lit = flashlight.is_on()
	elif flashlight and "is_flashlight_on" in flashlight:
		is_flashlight_lit = bool(flashlight.get("is_flashlight_on"))

	# В темноте ли персонаж?
	var now_in_darkness: bool = _is_player_in_dark_zone and not is_flashlight_lit

	if now_in_darkness:
		_handle_darkness(delta)
	else:
		if _was_in_darkness:
			_resolve_darkness_relief(is_flashlight_lit)
		_darkness_duration = 0.0
		_whisper_timer = 0.0
		_toast_shown = false

	_was_in_darkness = now_in_darkness
	_is_in_darkness = now_in_darkness

func _handle_darkness(delta: float) -> void:
	_darkness_duration += delta
	_whisper_timer += delta

	# Плавное нарастание паранойи (12.5% в секунду в полной тьме)
	var paranoia_mgr: Node = get_node_or_null("/root/ParanoiaManager")
	if paranoia_mgr and paranoia_mgr.has_method("add_paranoia"):
		paranoia_mgr.add_paranoia(delta * 13.5, "Темнота")

	# Напоминание игроку о фонарике через 2 секунды
	if _darkness_duration >= 2.0 and not _toast_shown:
		_toast_shown = true
		var save_mgr: Node = get_node_or_null("/root/SaveManager")
		if save_mgr and save_mgr.has_signal("toast_requested"):
			save_mgr.toast_requested.emit("⚠️ Слишком темно! Нажмите [F] или [ПКМ], чтобы включить фонарик!")

	# Психологический шёпот страха каждые 3.8 секунды
	if _whisper_timer >= 3.8:
		_whisper_timer = 0.0
		_trigger_darkness_whisper()

func _trigger_darkness_whisper() -> void:
	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_paranoia_pulse"):
		sound_mgr.play_paranoia_pulse()

	var whisper_text: String = WHISPERS.pick_random()
	var ui: Node = get_node_or_null("/root/Main/UI")
	if ui and ui.has_method("show_whisper"):
		ui.show_whisper(whisper_text)
	else:
		var save_mgr: Node = get_node_or_null("/root/SaveManager")
		if save_mgr and save_mgr.has_signal("toast_requested"):
			save_mgr.toast_requested.emit(whisper_text)

func _resolve_darkness_relief(lit_by_flashlight: bool) -> void:
	var paranoia_mgr: Node = get_node_or_null("/root/ParanoiaManager")
	if paranoia_mgr and paranoia_mgr.has_method("reduce_paranoia"):
		paranoia_mgr.reduce_paranoia(15.0)

	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_hover"):
		sound_mgr.play_hover()

	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_signal("toast_requested"):
		if lit_by_flashlight:
			save_mgr.toast_requested.emit("🔦 Свет разгоняет тьму. Пульс успокаивается.")
		else:
			save_mgr.toast_requested.emit("💡 Возвращение к свету. Тревога отступает.")
