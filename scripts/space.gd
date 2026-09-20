extends Control
var clock := 0.0
var stars: Array[Vector3] = []
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 91742
	for i in 180:
		stars.append(Vector3(rng.randf_range(0,1280),rng.randf_range(0,800),rng.randf_range(0.4,1.8)))
func _process(dt: float) -> void:
	clock += dt
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(0,0,1280,800),Color("0b1423"))
	for i in 14:
		draw_circle(Vector2(900,360),440-i*22,Color(0.08,0.18,0.24,0.027))
	for s in stars:
		draw_circle(Vector2(s.x,s.y),s.z,Color(0.65,0.83,0.83,0.22+0.17*sin(clock*0.6+s.x)))
	draw_arc(Vector2(1070,220),160,0,TAU,100,Color("243546"),1,true)
	draw_arc(Vector2(1070,220),168,0,TAU,100,Color(0.2,0.34,0.4,0.25),1,true)
	draw_circle(Vector2(1070,220),111,Color("14293a"))
	draw_arc(Vector2(1070,220),112,3.4,5.4,50,Color("355765"),2,true)
	draw_line(Vector2(32,108),Vector2(1248,108),Color("2b3a46"),1)
	draw_line(Vector2(32,718),Vector2(1248,718),Color("2b3a46"),1)
