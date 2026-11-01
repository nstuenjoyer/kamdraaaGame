extends Control

var paper: bool = false
var notebook: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var edge: Color = Color("a99c85") if paper else Color("5b554b")
	edge.a = 0.35
	draw_rect(Rect2(Vector2(-20,-20),size+Vector2(40,40)),edge,false,1)
	if paper:
		for y: int in range(12,int(size.y)-8,4):
			draw_line(Vector2(7,y),Vector2(size.x-7,y),Color(0.28,0.22,0.14,0.012),1)
	else:
		for x: int in range(3,int(size.x),5):
			draw_line(Vector2(x,3),Vector2(x,size.y-3),Color(0.5,0.47,0.4,0.012),1)
	var length_value: float = 16
	for corner: Vector2 in [Vector2(-12,-12),Vector2(size.x+12,-12),Vector2(-12,size.y+12),size+Vector2(12,12)]:
		var direction: Vector2 = Vector2(1 if corner.x < size.x*0.5 else -1,1 if corner.y < size.y*0.5 else -1)
		draw_line(corner,corner+Vector2(direction.x*length_value,0),edge,1)
		draw_line(corner,corner+Vector2(0,direction.y*length_value),edge,1)
