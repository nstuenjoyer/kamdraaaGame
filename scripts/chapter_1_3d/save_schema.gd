extends RefCounted

static func number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

static func vector(value: Variant) -> bool:
	if not value is Array or value.size() != 3: return false
	return number(value[0], -18, 18) and number(value[1], -1, 9) and number(value[2], -10, 18)

static func valid(data: Variant, depth: int = 0) -> bool:
	if not data is Dictionary or depth > 1: return false
	if data.get("version") != 4 or data.get("layout_revision") != 1 or data.get("scene") != "res://scenes/chapter_1_3d/apartment.tscn": return false
	for field: String in ["chapter", "inventory", "player", "checkpoint", "enemy"]:
		if not data.get(field) is Dictionary: return false
	var p: Dictionary = data.player
	if not number(p.get("x"), -17, 17) or not number(p.get("y"), -0.4, 5.2) or not number(p.get("z"), -8, 15) or not number(p.get("yaw"), -100, 100): return false
	var point: Vector2 = Vector2(float(p.x), float(p.z))
	var inside: bool = false
	var floor_index: int = 1 if float(p.y) > 2.8 else 0
	for row: Array in ApartmentLayout3D.ROOMS.values():
		if int(row[0]) == floor_index and (row[1] as Rect2).has_point(point): inside = true
	# Real stair corridors and their landings.
	if Rect2(-15.2, -5.2, 4.5, 11.4).has_point(point) or Rect2(10.7, 0.3, 4.5, 12.5).has_point(point): inside = true
	if not inside or not number(data.get("stress"), 0, 100) or not data.get("flashlight_on") is bool: return false
	var chapter: Dictionary = data.chapter
	if not chapter.get("flags") is Dictionary or not chapter.get("documents") is Array or not chapter.get("events") is Dictionary: return false
	if chapter.get("phase") not in ["exploration", "coat_done", "encounter", "resolved", "complete"]: return false
	if chapter.get("diary_choice") not in ["", "trust", "dismiss"] or chapter.get("outcome") not in ["", "stealth", "restrained", "lethal"]: return false
	if not number(chapter.get("belief"), 0, 100) or not number(chapter.get("charge"), 0, 20): return false
	for id: Variant in chapter.flags:
		if id not in ApartmentState.FLAGS or not chapter.flags[id] is bool: return false
	for id: Variant in chapter.documents:
		if id not in ["bedside", "diary", "bathroom", "hall_mirror", "bath_note", "messages", "phone_note", "pocket_note", "desk_note", "clock_note", "outage_note", "service_log", "cabinet_note"]: return false
	if chapter.flags.get("dose", false) and (not chapter.flags.get("bed", false) or not chapter.flags.get("pills", false)): return false
	if chapter.phase in ["coat_done", "encounter", "resolved", "complete"] and (not chapter.flags.get("coat", false) or not chapter.flags.get("front_key", false) or chapter.diary_choice.is_empty()): return false
	if chapter.phase == "resolved" and chapter.outcome not in ["restrained", "lethal"]: return false
	if chapter.phase == "complete" and chapter.outcome.is_empty(): return false
	if data.flashlight_on and not chapter.flags.get("flashlight", false): return false
	for event: Variant in chapter.events.values():
		if not event is Dictionary or event.get("version") != 1 or event.get("outcome") not in ["stealth", "restrained", "lethal"]: return false
		if event.get("chaos") != (2 if event.outcome == "lethal" else 0): return false
	for id: Variant in data.inventory:
		var item: Variant = data.inventory[id]
		if not item is Dictionary or not number(item.get("count"), 1, 99): return false
		for field: String in ["id", "name", "description", "icon"]:
			if not item.get(field) is String: return false
		if item.id != id or not item.get("usable") is bool: return false
	if chapter.phase in ["encounter", "resolved"] and data.enemy.is_empty(): return false
	if not data.enemy.is_empty():
		var enemy: Dictionary = data.enemy
		if not vector(enemy.get("position")) or not vector(enemy.get("target")): return false
		if not number(enemy.get("mode"), 0, 5): return false
		for field: String in ["stun", "grace", "lost", "patrol"]:
			if not number(enemy.get(field), 0, 100000): return false
	if not data.checkpoint.is_empty() and not valid(data.checkpoint, depth + 1): return false
	return true
