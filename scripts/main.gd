extends Node2D

# Сцена: Стартовая комната (Похмельное пробуждение Даши)
@onready var player: CharacterBody2D = $Player
@onready var quest_item: Area2D = $QuestItem
@onready var door: StaticBody2D = $Door

func _ready() -> void:
	# Применяем данные загрузки, если игра запущена из меню сохранений
	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("apply_pending_save_if_any"):
		save_mgr.apply_pending_save_if_any(self)

	print("\n=======================================================")
	print("🥃 [НЕОНУАР]: Утро после катастрофы.")
	print("Даша открывает глаза в незнакомой комнате с тяжёлым похмельем.")
	print("В висках стучит кровь. В полумраке надрывается стационарный телефон.")
	print("Подсказка:")
	print("  • WASD / Стрелки — Перемещение")
	print("  • E — Взять трубку / Взаимодействие")
	print("  • ESC — Пауза и меню сохранений")
	print("  • F5 — Быстрое сохранение | F9 — Быстрая загрузка")
	print("=======================================================\n")

