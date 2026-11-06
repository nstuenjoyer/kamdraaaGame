extends RefCounted

var host: Node
var revision: int = 0
var silhouette: Node3D

func setup(controller: Node) -> void:
	host = controller
	# Cover world construction and navigation baking from the first drawn frame.
	var curtain: CanvasLayer = CanvasLayer.new()
	curtain.name = "BootCurtain"
	curtain.layer = 99
	host.add_child(curtain)
	var black: ColorRect = ColorRect.new()
	black.color = Color("080d13")
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.add_child(black)
	var corner: Vector3 = ApartmentLayout3D.center("bedroom") + Vector3(-2.4, 0, -1.5)
	var chair: Node3D = Node3D.new()
	chair.name = "OpeningChair"
	host.world.rooms.bedroom.add_child(chair)
	var wood: Material = host.world.material("wood", Color("332d29"))
	var cloth: Material = host.world.material("fabric", Color("22272d"))
	host.world.box(chair, "Seat", corner + Vector3(0,.45,0), Vector3(.55,.1,.5), wood)
	host.world.box(chair, "CoatOnBack", corner + Vector3(0,.89,.16), Vector3(.54,.85,.18), cloth)
	for x: float in [-.22,.22]:
		for z: float in [-.18,.18]: host.world.box(chair, "Leg", corner + Vector3(x,.22,z), Vector3(.06,.44,.06), wood)
	silhouette = Node3D.new()
	silhouette.name = "OpeningIllusion"
	host.world.rooms.bedroom.add_child(silhouette)
	host.world.box(silhouette, "Body", corner + Vector3(0,1.12,0), Vector3(.47,.95,.27), cloth)
	host.world.box(silhouette, "Head", corner + Vector3(0,1.72,0), Vector3(.24,.29,.23), cloth)
	silhouette.visible = false

func shot(target: Vector3, offset: Vector3) -> void:
	# Authored cuts within the bedroom; no camera flight through walls.
	host.camera.position = target + offset
	host.camera.look_at(target)

func play() -> void:
	revision += 1
	var token: int = revision
	host.state.mark("intro")
	host.intro_active = true
	host.player.set_control_locked(true)
	host.get_node("/root/ParanoiaManager").set_paranoia(38.0)
	var center: Vector3 = ApartmentLayout3D.center("bedroom")
	shot(center + Vector3(0,1.4,-3.3), Vector3(2,1.2,4))
	await host.ui.opening_fade()
	if token != revision: return
	if not host.intro_skip_requested:
		host.ui.cinematic_caption("Накануне вечером в квартире погас свет.")
		await host._intro_wait(4.5)
	if token != revision: return
	if not host.intro_skip_requested:
		shot(host.world.interactables.phone.global_position, Vector3(1.6,1.5,2.2))
		host.ui.cinematic_caption("Телефон разрядился. Последние часы словно выпали из памяти.")
		await host._intro_wait(5.0)
	if token != revision: return
	if not host.intro_skip_requested:
		shot(host.player.position + Vector3.UP * 1.1, Vector3(2.2,1.8,3.0))
		host.ui.cinematic_caption("Даша просыпается от холода. За стеной слышен шорох.")
		await host._intro_wait(4.5)
	if token != revision: return
	end_visuals()
	if host.intro_skip_requested:
		finish()
		return
	host.ui.message("Тёмная квартира · Даша", "Я проснулась от холода. В квартире темно, за окном дождь. Последнее, что помню, — вчерашний вечер. Почему дверь на галерею открыта?", func() -> void:
		if token != revision: return
		host.ui.message("Даша", "Телефон разрядился. Свет опять выбило… Нужно понять, что произошло, и найти свои ключи.", func() -> void:
			if token != revision: return
			silhouette.visible = true
			host.get_node("/root/ParanoiaManager").set_paranoia(100.0)
			host.ui.message("В углу кто-то стоит", "Не двигайся…", func() -> void:
				if token != revision: return
				silhouette.visible = false
				host.ui.message("Даша", "Нет. Это куртка на стуле. От тревоги знакомые вещи кажутся чужими. Такие приступы уже были — таблетки должны лежать у кровати.", func() -> void:
					if token == revision: finish()
				)
			)
		)
	)

func end_visuals() -> void:
	host.intro_active = false
	host.ui.cinematic_caption("")
	host.ui.hide_intro_skip()
	host._update_camera(true)
	if host.has_node("BootCurtain"): host.get_node("BootCurtain").queue_free()

func finish() -> void:
	silhouette.visible = false
	host.state.mark("opening_done")
	host.get_node("/root/ParanoiaManager").set_paranoia(100.0)
	host.ui.hud.visible = true
	host.player.set_control_locked(false)
	host.ui.notify("Обыщите кровать, возьмите блистер и примите таблетку через сумку. Запас ограничен.", 7.0)

func cancel() -> void:
	revision += 1
	host.intro_skip_requested = true
	silhouette.visible = false
	end_visuals()
	host.ui.hud.visible = true
