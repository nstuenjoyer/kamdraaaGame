extends CanvasLayer

# HUD: Монитор биоритмов и шкала паранойи (Heart Rate & Paranoia System)
# Отображает неонуарный кардиомонитор, динамический BPM, живую ЭКГ-волну,
# уровень стресса и пульсирующую виньетку паники на весь экран.

@onready var hud_panel: PanelContainer = $HUDContainer/Panel
@onready var heart_icon: Label = $HUDContainer/Panel/MarginContainer/VBoxContainer/TopRow/HeartIcon
@onready var bpm_label: Label = $HUDContainer/Panel/MarginContainer/VBoxContainer/TopRow/BPMLabel
@onready var status_badge: Label = $HUDContainer/Panel/MarginContainer/VBoxContainer/TopRow/StatusBadge
@onready var ecg_wave: Control = $HUDContainer/Panel/MarginContainer/VBoxContainer/ECGContainer/ECGWave
@onready var paranoia_bar: ProgressBar = $HUDContainer/Panel/MarginContainer/VBoxContainer/BottomRow/ParanoiaBar
@onready var paranoia_percent_label: Label = $HUDContainer/Panel/MarginContainer/VBoxContainer/BottomRow/ParanoiaPercent
@onready var vignette_rect: ColorRect = $PanicVignette

var _heart_tween: Tween
var _bpm_tween: Tween
var _vignette_tween: Tween

# Параметры ЭКГ волны
var _wave_points: PackedVector2Array = PackedVector2Array()
var _wave_phase: float = 0.0
var _qrs_spike: float = 0.0
var _pulse_intensity: float = 0.2

func _ready() -> void:
	layer = 10 # Отображается поверх игрового мира, но под модальными окнами паузы
	
	# Подключаемся к менеджеру паранойи
	var paranoia_mgr: Node = get_node_or_null("/root/ParanoiaManager")
	if paranoia_mgr:
		if paranoia_mgr.has_signal("heartbeat_pulsed"):
			paranoia_mgr.heartbeat_pulsed.connect(_on_heartbeat_pulsed)
		if paranoia_mgr.has_signal("paranoia_changed"):
			paranoia_mgr.paranoia_changed.connect(_on_paranoia_changed)
		if paranoia_mgr.has_signal("panic_state_changed"):
			paranoia_mgr.panic_state_changed.connect(_on_panic_state_changed)
			
		_update_display(paranoia_mgr.get_paranoia(), paranoia_mgr.get_bpm())

	if vignette_rect:
		vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vignette_rect.modulate.a = 0.0

	if ecg_wave:
		ecg_wave.draw.connect(_on_ecg_draw)

func _process(delta: float) -> void:
	# Анимация бегущей волны кардиограммы
	var paranoia_mgr: Node = get_node_or_null("/root/ParanoiaManager")
	var speed_multiplier: float = 1.0
	if paranoia_mgr:
		speed_multiplier = float(paranoia_mgr.get_bpm()) / 70.0

	_wave_phase += delta * 140.0 * speed_multiplier
	_qrs_spike = move_toward(_qrs_spike, 0.0, delta * 8.0)

	if ecg_wave and ecg_wave.visible:
		ecg_wave.queue_redraw()

func _on_heartbeat_pulsed(bpm: int, intensity: float) -> void:
	_pulse_intensity = intensity
	_qrs_spike = 1.0 # Запускаем спайк на кардиограмме

	var paranoia_mgr: Node = get_node_or_null("/root/ParanoiaManager")
	var status_col: Color = paranoia_mgr.get_status_color() if paranoia_mgr else Color(0.35, 0.88, 0.95)

	# 1. Анимация удара значка сердца (деликатный микро-толчок)
	if heart_icon:
		if _heart_tween and _heart_tween.is_valid():
			_heart_tween.kill()
		_heart_tween = create_tween()
		heart_icon.pivot_offset = heart_icon.size * 0.5
		var punch_scale: float = lerpf(1.08, 1.22, intensity)
		_heart_tween.tween_property(heart_icon, "scale", Vector2(punch_scale, punch_scale), 0.06)
		_heart_tween.tween_property(heart_icon, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE)

	# 2. Вспышка значения BPM
	if bpm_label:
		bpm_label.text = "%d BPM" % bpm
		bpm_label.add_theme_color_override("font_color", status_col.lightened(0.2))
		if _bpm_tween and _bpm_tween.is_valid():
			_bpm_tween.kill()
		_bpm_tween = create_tween()
		_bpm_tween.tween_property(bpm_label, "theme_override_colors/font_color", status_col, 0.22)

	# 3. Пульсация виньетки краев экрана только при высокой тревоге (> 45%)
	if vignette_rect and intensity > 0.45:
		var target_alpha: float = lerpf(0.04, 0.22, (intensity - 0.45) / 0.55)
		if _vignette_tween and _vignette_tween.is_valid():
			_vignette_tween.kill()
		_vignette_tween = create_tween()
		_vignette_tween.tween_property(vignette_rect, "modulate:a", target_alpha, 0.08)
		_vignette_tween.tween_property(vignette_rect, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 4. Сотрясение камеры только при крайней панической атаке (> 88%)
	if intensity >= 0.88:
		var tree: SceneTree = get_tree()
		if tree and tree.current_scene:
			var player: Node = tree.current_scene.find_child("Player", true, false)
			if player and player.has_method("apply_shake"):
				player.apply_shake(1.0)

func _on_paranoia_changed(new_level: float, _delta: float, _reason: String) -> void:
	var paranoia_mgr: Node = get_node_or_null("/root/ParanoiaManager")
	var current_bpm: int = paranoia_mgr.get_bpm() if paranoia_mgr else 74
	_update_display(new_level, current_bpm)

func _on_panic_state_changed(is_panic: bool) -> void:
	if is_panic:
		# Микро-вспышка при переходе в панику
		if hud_panel:
			var flash: Tween = create_tween()
			flash.tween_property(hud_panel, "modulate", Color(1.3, 0.7, 0.7, 1.0), 0.1)
			flash.tween_property(hud_panel, "modulate", Color.WHITE, 0.4)

func _update_display(level: float, bpm: int) -> void:
	var paranoia_mgr: Node = get_node_or_null("/root/ParanoiaManager")
	var status_text: String = paranoia_mgr.get_status_text() if paranoia_mgr else "СПОКОЙСТВИЕ"
	var status_col: Color = paranoia_mgr.get_status_color() if paranoia_mgr else Color(0.35, 0.88, 0.95)

	if bpm_label:
		bpm_label.text = "%d BPM" % bpm
		bpm_label.add_theme_color_override("font_color", status_col)

	if status_badge:
		status_badge.text = "[ %s ]" % status_text
		status_badge.add_theme_color_override("font_color", status_col)

	if paranoia_bar:
		paranoia_bar.value = level
		# Настройка цвета полосы
		var style: StyleBoxFlat = paranoia_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if style:
			style.bg_color = status_col

	if paranoia_percent_label:
		paranoia_percent_label.text = "%d%%" % roundi(level)
		paranoia_percent_label.add_theme_color_override("font_color", status_col.lerp(Color.WHITE, 0.3))

func _on_ecg_draw() -> void:
	if not ecg_wave:
		return

	var size: Vector2 = ecg_wave.size
	var mid_y: float = size.y * 0.5
	var width: float = size.x

	var paranoia_mgr: Node = get_node_or_null("/root/ParanoiaManager")
	var col: Color = paranoia_mgr.get_status_color() if paranoia_mgr else Color(0.35, 0.88, 0.95)
	var glow_col: Color = Color(col.r, col.g, col.b, 0.25)

	# Отрисовка фоновой координатной сетки кардиомонитора
	var grid_col: Color = Color(0.18, 0.24, 0.32, 0.35)
	draw_line_grid(ecg_wave, size, grid_col)

	# Вычисляем форму волны ЭКГ
	var points: PackedVector2Array = PackedVector2Array()
	var step_px: float = 2.0
	var num_points: int = int(width / step_px) + 1

	for i in range(num_points):
		var x: float = float(i) * step_px
		var sample_phase: float = (_wave_phase - (width - x))
		var norm_phase: float = fposmod(sample_phase, 120.0)

		# Моделирование медицинского P-Q-R-S-T комплекса
		var y_offset: float = 0.0
		if norm_phase < 15.0:
			# P-волна (предсердный зубец)
			y_offset = -sin((norm_phase / 15.0) * PI) * (2.2 + _pulse_intensity * 1.5)
		elif norm_phase >= 20.0 and norm_phase < 24.0:
			# Q-зубец (небольшой прогиб вниз)
			y_offset = ((norm_phase - 20.0) / 4.0) * 2.5
		elif norm_phase >= 24.0 and norm_phase < 32.0:
			# R-зубец (высокий острый пик вверх)
			var r_prog: float = (norm_phase - 24.0) / 8.0
			var spike_amp: float = 8.5 + _pulse_intensity * 4.5
			y_offset = -sin(r_prog * PI) * spike_amp
		elif norm_phase >= 32.0 and norm_phase < 36.0:
			# S-зубец (глубокий прогиб вниз)
			var s_prog: float = (norm_phase - 32.0) / 4.0
			y_offset = sin(s_prog * PI) * (3.5 + _pulse_intensity * 2.0)
		elif norm_phase >= 44.0 and norm_phase < 62.0:
			# T-волна (реполяризация желудочков)
			var t_prog: float = (norm_phase - 44.0) / 18.0
			y_offset = -sin(t_prog * PI) * (3.0 + _pulse_intensity * 1.5)
		else:
			# Изолиния с микро-шумом
			y_offset = sin(sample_phase * 0.4) * 0.5

		var y: float = clampf(mid_y + y_offset, 2.0, size.y - 2.0)
		points.append(Vector2(x, y))

	# Отрисовка деликатного свечения и основной линии
	if points.size() > 1:
		ecg_wave.draw_polyline(points, glow_col, 2.2, true)
		ecg_wave.draw_polyline(points, col, 1.1, true)

		# Светящаяся ведущая точка сканирования
		var last_pt: Vector2 = points[points.size() - 1]
		ecg_wave.draw_circle(last_pt, 1.6, Color.WHITE)
		ecg_wave.draw_circle(last_pt, 3.2, glow_col)

func draw_line_grid(target: Control, size: Vector2, grid_color: Color) -> void:
	# Тонкая сетка 15x15 px
	var x: float = 0.0
	while x < size.x:
		target.draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color, 1.0)
		x += 16.0
	var y: float = 0.0
	while y < size.y:
		target.draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1.0)
		y += 12.0
