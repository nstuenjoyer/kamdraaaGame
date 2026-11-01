class_name NoirUI
extends RefCounted

# Shared visual language for the front end and chapter screens.
const INK: Color = Color("101518")
const PANEL: Color = Color("181e21")
const PAPER: Color = Color("dfd5bd")
const TEXT: Color = Color("dedbd2")
const MUTED: Color = Color("939c9e")
const ACCENT: Color = Color("bfa17b")
const LINE: Color = Color("344045")

static func body_font() -> SystemFont:
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "DejaVu Sans"])
	return font

static func title_font() -> SystemFont:
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Georgia", "Noto Serif", "DejaVu Serif"])
	return font

static func surface(color: Color = INK, padding: int = 16) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_content_margin_all(padding)
	return style

static func action_style(state: String) -> StyleBoxFlat:
	var style: StyleBoxFlat = surface(Color(0, 0, 0, 0), 10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.set_corner_radius_all(2)
	if state in ["hover", "pressed", "selected"]:
		style.bg_color = Color("273035") if state != "pressed" else Color("32393b")
	if state == "selected":
		style.border_width_left = 2
		style.border_color = ACCENT
	if state == "focus":
		style.draw_center = false
		style.set_border_width_all(1)
		style.border_color = Color(0.75, 0.63, 0.48, 0.75)
	return style

static func primary_style(state: String = "normal") -> StyleBoxFlat:
	var style: StyleBoxFlat = action_style(state)
	if state == "focus": return style
	style.bg_color = Color("bfa17b") if state == "normal" else Color("d2b78f") if state == "hover" else Color("9e8565")
	if state == "disabled": style.bg_color = Color("363c3e")
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

static func quiet_style(state: String = "normal") -> StyleBoxFlat:
	var style: StyleBoxFlat = action_style(state)
	style.content_margin_left = 8
	style.content_margin_right = 8
	return style

static func tab_style(active: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = action_style("normal")
	style.border_width_bottom = 2 if active else 1
	style.border_color = ACCENT if active else LINE
	return style

static func keycap_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = surface(Color("232c30"), 5)
	style.set_corner_radius_all(3)
	style.border_width_bottom = 2
	style.border_color = Color("536064")
	return style

static func frame_style(padding: int = 24) -> StyleBoxFlat:
	var style: StyleBoxFlat = surface(INK, padding)
	style.set_border_width_all(1)
	style.border_color = LINE
	style.shadow_color = Color(0, 0, 0, 0.32)
	style.shadow_size = 24
	return style

static func make_theme() -> Theme:
	var result: Theme = Theme.new()
	result.default_font = body_font()
	result.default_font_size = 18
	for type_name: String in ["Label", "Button", "CheckBox", "RichTextLabel"]:
		result.set_color("font_color", type_name, TEXT)
	for type_name: String in ["Button", "CheckBox"]:
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			result.set_stylebox(state, type_name, action_style("normal" if type_name == "CheckBox" and state == "pressed" else state))
		result.set_color("font_hover_color", type_name, ACCENT)
		result.set_color("font_focus_color", type_name, ACCENT)
		result.set_color("font_pressed_color", type_name, TEXT)
		result.set_color("font_disabled_color", type_name, Color("696c63"))
	result.set_stylebox("panel", "PanelContainer", surface())
	result.set_icon("unchecked", "CheckBox", load("res://assets/ui/check_off.svg"))
	result.set_icon("checked", "CheckBox", load("res://assets/ui/check_on.svg"))
	for type_name: String in ["HSlider", "HScrollBar", "VScrollBar"]:
		result.set_stylebox("slider" if type_name == "HSlider" else "scroll", type_name, surface(Color("353930"), 2))
		result.set_stylebox("grabber_area" if type_name == "HSlider" else "grabber", type_name, surface(ACCENT, 3))
		result.set_stylebox("grabber_area_highlight" if type_name == "HSlider" else "grabber_highlight", type_name, surface(TEXT, 3))
	result.set_stylebox("background", "ProgressBar", surface(Color("383b32"), 0))
	result.set_stylebox("fill", "ProgressBar", surface(ACCENT, 0))
	result.set_color("font_color", "TooltipLabel", TEXT)
	result.set_stylebox("panel", "TooltipPanel", surface(INK, 10))
	return result

static func clean_text(value: String) -> String:
	var result: String = ""
	for index: int in value.length():
		var code: int = value.unicode_at(index)
		if code >= 0x1f000 or code in [0xfe0f, 0x200d, 0x25b6, 0x2714, 0x2328, 0x2699, 0x2139, 0x21ba]: continue
		result += value[index]
	return result.strip_edges()

static func restyle_tree(node: Node) -> void:
	if node is Control:
		var control: Control = node as Control
		for property: Dictionary in control.get_property_list():
			var key: String = property.name
			if key.begins_with("theme_override_styles/"): control.remove_theme_stylebox_override(key.get_slice("/", 1))
			elif key.begins_with("theme_override_colors/"): control.remove_theme_color_override(key.get_slice("/", 1))
		if node is Label:
			var label: Label = node as Label
			label.modulate = Color.WHITE
			label.text = clean_text(label.text)
			var old_size: int = label.get_theme_font_size("font_size")
			label.add_theme_font_size_override("font_size", maxi(16, old_size))
			if node.name == "Title":
				label.add_theme_font_override("font", title_font())
				label.add_theme_font_size_override("font_size", 30)
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		elif node is Button:
			var button: Button = node as Button
			button.text = clean_text(button.text)
			button.add_theme_font_size_override("font_size", 18)
			button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 42)
			button.modulate = Color.WHITE
	for child: Node in node.get_children(): restyle_tree(child)
