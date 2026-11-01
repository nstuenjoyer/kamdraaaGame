class_name ApartmentState
extends RefCounted

const VERSION: int = 3
const LAYOUT_REVISION: int = 2
const SCENE: String = "res://scenes/chapter_1/apartment.tscn"
const FLAGS: Array[String] = ["intro", "bed", "pills", "dose", "flashlight", "front_key", "phone", "vase", "cupboard_key", "cupboard", "pepper", "screwdriver", "fuse", "power", "coat", "coat_trap", "throwable", "rope", "heavy", "phone_charging", "phone_ready", "exit_checked", "jacket_checked", "study_key", "study_unlocked", "cabinet_checked", "cabinet_unlocked", "clock_seen", "outage_seen", "sofa_searched", "latch_released", "tap_closed", "record_checked", "entered_study", "entered_utility", "entered_back_hall", "record_playing", "opening_done"]

var flags: Dictionary = {}
var documents: Array[String] = []
var diary_choice: String = ""
var belief: float = 0.0
var phase: String = "exploration"
var outcome: String = ""
var charge: float = 0.0
var events: Dictionary = {}
var checkpoint: Dictionary = {}

func has(id: String) -> bool:
	return bool(flags.get(id, false))

func mark(id: String) -> bool:
	if has(id):
		return false
	flags[id] = true
	return true

func choose(value: String) -> bool:
	if not diary_choice.is_empty() or value not in ["trust", "dismiss"]:
		return false
	diary_choice = value
	belief = 35.0 if value == "trust" else 5.0
	return true

func record_outcome(value: String) -> bool:
	if not outcome.is_empty() or value not in ["stealth", "restrained", "lethal"]:
		return false
	outcome = value
	events["chapter_1.encounter"] = {"version": 1, "outcome": value, "chaos": 2 if value == "lethal" else 0}
	return true

func chaos_total() -> int:
	var total: int = 0
	for event: Dictionary in events.values(): total += int(event.get("chaos", 0))
	return total

func serialize() -> Dictionary:
	return {"flags": flags.duplicate(true), "documents": documents.duplicate(), "diary_choice": diary_choice, "belief": belief, "phase": phase, "outcome": outcome, "charge": charge, "events": events.duplicate(true)}

func restore(data: Dictionary) -> void:
	flags = data.get("flags", {}).duplicate(true)
	documents.assign(data.get("documents", []))
	diary_choice = str(data.get("diary_choice", ""))
	belief = clampf(float(data.get("belief", 0.0)), 0.0, 100.0)
	phase = str(data.get("phase", "exploration"))
	outcome = str(data.get("outcome", ""))
	charge = clampf(float(data.get("charge", 0.0)), 0.0, 20.0)
	events = data.get("events", {}).duplicate(true)

static func valid(data: Dictionary, depth: int = 0) -> bool:
	if not (data.get("version") is int or data.get("version") is float):
		return false
	if depth > 1 or int(data.version) != VERSION or data.get("layout_revision", 0) != LAYOUT_REVISION or data.get("scene", "") != SCENE:
		return false
	for field: String in ["chapter", "inventory", "player", "checkpoint", "enemy"]:
		if not data.get(field) is Dictionary:
			return false
	var chapter: Dictionary = data.chapter
	if not chapter.get("flags") is Dictionary or not chapter.get("documents") is Array or not chapter.get("events") is Dictionary:
		return false
	if chapter.get("phase", "") not in ["exploration", "coat_done", "encounter", "resolved", "complete"]:
		return false
	if chapter.get("diary_choice", "") not in ["", "trust", "dismiss"] or chapter.get("outcome", "") not in ["", "stealth", "restrained", "lethal"]:
		return false
	for id: Variant in chapter.flags:
		if id not in FLAGS or not chapter.flags[id] is bool:
			return false
	for id: Variant in chapter.documents:
		if id not in ["bedside", "diary", "bathroom", "hall_mirror", "bath_note", "messages", "phone_note", "pocket_note", "desk_note", "clock_note", "outage_note", "service_log", "cabinet_note"]:
			return false
	for value: Variant in [data.get("stress"), data.player.get("x"), data.player.get("y"), chapter.get("belief"), chapter.get("charge")]:
		if not (value is float or value is int) or not is_finite(float(value)):
			return false
	if absf(float(data.player.x)) > 4000.0 or absf(float(data.player.y)) > 4000.0:
		return false
	if not data.get("flashlight_on") is bool or float(data.stress) < 0 or float(data.stress) > 100:
		return false
	if float(chapter.belief) < 0 or float(chapter.belief) > 100 or float(chapter.charge) < 0 or float(chapter.charge) > 20:
		return false
	if chapter.flags.get("dose", false) and (not chapter.flags.get("pills", false) or not chapter.flags.get("bed", false) or not chapter.flags.get("intro", false)):
		return false
	if chapter.phase in ["coat_done", "encounter", "resolved", "complete"] and (not chapter.flags.get("coat", false) or not chapter.flags.get("front_key", false) or chapter.diary_choice.is_empty()):
		return false
	if chapter.phase == "resolved" and chapter.outcome not in ["restrained", "lethal"]: return false
	if chapter.phase == "complete" and chapter.outcome.is_empty(): return false
	var logical: Vector2 = Vector2(float(data.player.y) + float(data.player.x) * 0.5, float(data.player.y) - float(data.player.x) * 0.5)
	if not Rect2(0, 0, 1560, 2360).has_point(logical): return false
	if not data.checkpoint.is_empty() and (depth > 0 or not valid(data.checkpoint, depth + 1)):
		return false
	if chapter.phase in ["encounter", "resolved"] and data.enemy.is_empty():
		return false
	if not data.enemy.is_empty():
		for key: String in ["mode", "x", "y", "target_x", "target_y", "stun", "lost", "state_time", "grace", "patrol"]:
			var value: Variant = data.enemy.get(key)
			if not (value is float or value is int) or not is_finite(float(value)):
				return false
		if float(data.enemy.mode) < 0 or float(data.enemy.mode) > 5: return false
	for event: Variant in chapter.events.values():
		if not event is Dictionary or event.get("version") != 1 or event.get("outcome") not in ["stealth", "restrained", "lethal"]:
			return false
		if not (event.get("chaos") is int or event.get("chaos") is float) or int(event.chaos) not in [0, 2]:
			return false
	for item: Variant in data.inventory.values():
		if not item is Dictionary or not item.get("count") is float and not item.get("count") is int:
			return false
		if float(item.count) < 0.0 or float(item.count) > 99.0:
			return false
		for field: String in ["id", "name", "description", "icon"]:
			if not item.get(field, "") is String:
				return false
		if not item.get("usable", false) is bool:
			return false
	return true
