extends Node2D

# Сцена: Стартовая комната (Похмельное пробуждение Даши)
@onready var player: CharacterBody2D = $Player
@onready var quest_item: Area2D = $QuestItem
@onready var door: StaticBody2D = $Door

func _ready() -> void:
	# Применяем данные загрузки, если игра запущена из меню сохранений
	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	var has_pending_save: bool = false
	if save_mgr and save_mgr.has_method("apply_pending_save_if_any"):
		has_pending_save = save_mgr.apply_pending_save_if_any(self)
	
	if not has_pending_save:
		var paranoia_mgr: Node = get_node_or_null("/root/ParanoiaManager")
		if paranoia_mgr and paranoia_mgr.has_method("reset_to_default"):
			paranoia_mgr.reset_to_default()
		var inv_mgr: Node = get_node_or_null("/root/InventoryManager")
		if inv_mgr and inv_mgr.has_method("reset_inventory"):
			inv_mgr.reset_inventory()

	# Запускаем фоновый нуарный саундтрек
	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("start_bg_music"):
		sound_mgr.start_bg_music()

	print("\n=======================================================")
	print("🥃 [НЕОНУАР]: Утро после катастрофы.")
	print("Даша открывает глаза в незнакомой комнате с тяжёлым похмельем.")
	print("В висках стучит кровь. В полумраке надрывается стационарный телефон.")
	print("Подсказка:")
	print("  • WASD / Стрелки — Перемещение")
	print("  • E / Пробел / Enter — Взаимодействие / Диалог")
	print("  • F — Фонарик (вкл/выкл)")
	print("  • I — Инвентарь и использование предметов")
	print("  • ESC / P — Пауза и меню сохранений")
	print("  • F5 / K (или F6) — Быстрое сохранение")
	print("  • F9 / L (или F8) — Быстрая загрузка")
	print("  • F11 — Полный экран")
	print("=======================================================\n")

