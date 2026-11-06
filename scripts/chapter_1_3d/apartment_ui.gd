extends ApartmentUI

var map_floor: int = 1

func _location_text(value: String) -> String:
	return value.replace("в задний коридор", "в зимний сад на втором этаже").replace("за галереей, рядом с постирочной", "на втором этаже, за галереей").replace("в конце гостиной, за поперечной галереей", "на втором этаже, за галереей").replace("шнур с полки в гостиной", "шнур из гардеробной")

func message(title: String, body: String, after: Callable = Callable()) -> void:
	super.message(title, _location_text(body), after)

func notify(value: String, duration: float = 5.0) -> void:
	super.notify(_location_text(value), duration)

func _update_prompt() -> void:
	prompt_panel.visible = not prompt.text.is_empty() and modal_kind.is_empty() and not host.intro_active
	if not prompt_panel.visible: return
	var point: Vector3 = host.player.global_position + Vector3(0, 1.6, 0)
	if host.world.interactables.has(host.selected): point = host.world.interactables[host.selected].global_position
	if host.selected == "enemy" and is_instance_valid(host.enemy): point = host.enemy.global_position + Vector3.UP
	if host.camera.is_position_behind(point):
		prompt_panel.visible = false
		return
	var screen: Vector2 = host.camera.unproject_position(point) / Vector2(host.viewport_3d.size) * root.size
	prompt_panel.size = Vector2(300, 44)
	prompt_panel.position = Vector2(clampf(screen.x + 28, 20, root.size.x - 320), clampf(screen.y - 45, 110, root.size.y - 150))

func apartment_map() -> void:
	open("map", "План двухуровневой квартиры", "Парадная лестница: прихожая ↔ галерея. Служебная: кухонный проход ↔ зимний сад.")
	var row: HBoxContainer = HBoxContainer.new()
	content.add_child(row)
	for floor_index: int in 2:
		button("Первый этаж" if floor_index == 0 else "Второй этаж", func() -> void: map_floor = floor_index; apartment_map(), row)
	var map: Control = Control.new()
	map.set_script(preload("res://scripts/chapter_1_3d/apartment_map.gd"))
	map.floor_index = map_floor
	map.host = host
	map.custom_minimum_size = Vector2(0, 320)
	content.add_child(map)

func load_slots() -> void:
	open("loads", "Сохранения · 3D", "Слоты этой версии хранятся отдельно от 2D-главы.")
	for slot: String in ["slot_1", "slot_2", "slot_3", "autosave"]:
		var row: HBoxContainer = HBoxContainer.new()
		content.add_child(row)
		button("Сохранить · " + slot, func() -> void: close(); host.save_slot(slot), row)
		var load_button: Button = button("Загрузить · " + slot, func() -> void: close(); host.load_slot(slot), row)
		load_button.disabled = not FileAccess.file_exists(host.save_path(slot))

func settings() -> void:
	super.settings()
	button("PSX · дизеринг: " + ("вкл" if host.dither_enabled else "выкл"), func() -> void: host.set_dither(not host.dither_enabled); settings())
	button("PSX · CRT: " + ("вкл" if host.crt_enabled else "выкл"), func() -> void: host.set_retro_options(not host.crt_enabled, host.vertex_snap_enabled, host.affine_enabled); settings())
	button("PSX · дрожание вершин: " + ("вкл" if host.vertex_snap_enabled else "выкл"), func() -> void: host.set_retro_options(host.crt_enabled, not host.vertex_snap_enabled, host.affine_enabled); settings())
	button("PSX · искажение текстур: " + ("вкл" if host.affine_enabled else "выкл"), func() -> void: host.set_retro_options(host.crt_enabled, host.vertex_snap_enabled, not host.affine_enabled); settings())
