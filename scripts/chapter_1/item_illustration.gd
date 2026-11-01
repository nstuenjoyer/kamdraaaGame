class_name ItemIllustration
extends Control

var item_id: String = ""
var ink: Color = Color("b7aa91")
var highlighted: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func line(points: Array[Vector2], width: float = 2.0, tint: Color = Color(-1,-1,-1,-1)) -> void:
	draw_polyline(PackedVector2Array(points), ink if tint.a < 0 else tint, width, true)

func _draw() -> void:
	var factor: float = minf(size.x / 120.0, size.y / 100.0)
	draw_set_transform((size - Vector2(120, 100) * factor) * 0.5, 0.0, Vector2.ONE * factor)
	var dark: Color = Color(ink, 0.14)
	match item_id:
		"pills":
			draw_style_box(_outline(), Rect2(30, 10, 60, 80))
			for x: int in [46, 74]:
				for y: int in [27, 49, 71]:
					draw_circle(Vector2(x,y), 7, dark)
					draw_arc(Vector2(x,y), 7, 0, TAU, 24, ink, 1.4, true)
			line([Vector2(26,18), Vector2(26,84)], 1, Color(ink, 0.3))
		"flashlight":
			draw_colored_polygon(PackedVector2Array([Vector2(33,71),Vector2(46,84),Vector2(80,50),Vector2(67,37)]), dark)
			line([Vector2(33,71),Vector2(46,84),Vector2(80,50),Vector2(67,37),Vector2(33,71)])
			line([Vector2(67,37),Vector2(65,26),Vector2(79,12),Vector2(105,38),Vector2(91,52),Vector2(80,50)])
			line([Vector2(65,26),Vector2(91,52)])
			draw_line(Vector2(86,14),Vector2(102,30), ink, 3, true)
			line([Vector2(44,66),Vector2(53,75)], 4)
		"phone":
			draw_style_box(_outline(), Rect2(35, 6, 50, 88))
			draw_rect(Rect2(41,19,38,58), dark)
			line([Vector2(52,13),Vector2(68,13)], 1)
			draw_circle(Vector2(60,85),3,ink)
		"front_key", "cabinet_key":
			draw_arc(Vector2(41,30),18,0,TAU,32,ink,3,true)
			draw_arc(Vector2(41,30),9,0,TAU,24,ink,1,true)
			line([Vector2(52,44),Vector2(91,83),Vector2(100,74),Vector2(92,66),Vector2(85,73),Vector2(78,66),Vector2(85,59)], 3)
		"screwdriver":
			line([Vector2(30,84),Vector2(70,44)],4)
			line([Vector2(25,88),Vector2(33,76)],5)
			draw_colored_polygon(PackedVector2Array([Vector2(62,34),Vector2(80,16),Vector2(100,36),Vector2(82,54)]), dark)
			line([Vector2(62,34),Vector2(80,16),Vector2(100,36),Vector2(82,54),Vector2(62,34)])
			line([Vector2(74,36),Vector2(84,26)],2)
		"fuse":
			line([Vector2(29,65),Vector2(78,16),Vector2(98,36),Vector2(49,85),Vector2(29,65)])
			line([Vector2(39,55),Vector2(59,75)],3)
			line([Vector2(69,25),Vector2(89,45)],3)
			line([Vector2(48,56),Vector2(64,40),Vector2(65,54),Vector2(80,39)],1.5)
		"pepper":
			draw_style_box(_outline(),Rect2(40,30,40,60))
			draw_rect(Rect2(46,17,28,13),dark)
			line([Vector2(46,30),Vector2(46,17),Vector2(74,17),Vector2(74,30)])
			line([Vector2(50,17),Vector2(50,10),Vector2(78,10),Vector2(78,18)])
			draw_line(Vector2(46,64),Vector2(74,64),ink,1)
			draw_line(Vector2(46,70),Vector2(68,70),ink,1)
		"throwable":
			line([Vector2(43,11),Vector2(77,11),Vector2(70,24),Vector2(70,35),Vector2(87,56),Vector2(90,70),Vector2(81,88),Vector2(39,88),Vector2(30,70),Vector2(33,56),Vector2(50,35),Vector2(50,24),Vector2(43,11)])
			draw_arc(Vector2(60,63),21,0.3,2.6,24,Color(ink,0.4),1,true)
		"rope":
			for i: int in 4:
				draw_arc(Vector2(58+i*3,46+i*5),26,0,TAU,40,ink,1.5,true)
			line([Vector2(85,70),Vector2(94,79),Vector2(105,74)],2)
		"heavy":
			draw_arc(Vector2(52,40),27,0,TAU,40,ink,3,true)
			draw_circle(Vector2(52,40),20,dark)
			line([Vector2(69,61),Vector2(94,90),Vector2(102,82),Vector2(77,55)],5)
		_:
			line([Vector2(38,10),Vector2(78,10),Vector2(88,21),Vector2(88,90),Vector2(32,90),Vector2(32,10),Vector2(38,10)])
			for y: int in [35,45,55,65]: draw_line(Vector2(43,y),Vector2(76,y),ink,1,true)

func _outline() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(ink,0.07)
	style.border_color = ink
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	return style
