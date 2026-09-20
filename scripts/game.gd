extends Node

const W := 11
const H := 9
const MINT := Color("a6e6c7")
const GOLD := Color("efd594")
const WHITE := Color("edf1df")
const MUTED := Color("95abae")
const LEVELS := [
	{"name":"First light", "region":"THE SEEDLING BELT", "map":["...........","..ww...cc..","..ww...cc..","...........","...........","...##......","..ww...cc..","..ww...cc..","..........."]},
	{"name":"Across the blue", "region":"THE SEEDLING BELT", "map":["...........",".ww.~..cc..",".ww.~..cc..","....~......","...........","....~..##..",".cc.~..ww..",".cc.~..ww..","..........."]},
	{"name":"The little greenhouse", "region":"WAYSTATION 01", "shop":true},
	{"name":"Roots & routes", "region":"THE AMBER REACH", "map":["...........",".WW..#..cc.",".WW..#..cc.",".....#.....","...........","...#.......",".cc#..WW...",".cc...WW...","..........."]},
	{"name":"A bridge of stars", "region":"THE AMBER REACH", "map":[".....~.....",".ww..~.cc..",".ww..~.cc..",".....~.....","..s..b.....",".....~.....",".cc..~.WW..",".cc..~.WW..",".....~....."]},
	{"name":"The wandering nursery", "region":"WAYSTATION 02", "shop":true},
	{"name":"Lunar labyrinth", "region":"THE MOONFLOWER DRIFT", "map":["...........",".WW#..CC...",".WW#..CC...","...#.......","...#...#...",".......#...",".CC...#WW..",".CC....WW..","..........."]},
	{"name":"The last constellation", "region":"THE MOONFLOWER DRIFT", "map":[".....~.....",".WW..~.CC..",".WW..~.CC..","..#..~..#..","..s..b.....","..#..~..#..",".CC..~.WW..",".CC..~.WW..",".....~....."]}
]

var stage := 0
var harvest := {"w":0,"c":0}
var power := 1
var reach := 3
var total_harvest := 0
var states: Dictionary = {}
var crops: Dictionary = {}
var tiles: Dictionary = {}
var rocks: Dictionary = {}
var tile_nodes: Dictionary = {}
var crop_nodes: Dictionary = {}
var path: Array[Vector2i] = []
var cell := Vector2i(0,4)
var world: Node3D
var board: Node3D
var bunny: Node3D
var bunny_model: Node3D
var camera: Camera3D
var view: SubViewport
var view_container: SubViewportContainer
var ui: Control
var wheat_total: Label
var carrot_total: Label
var counts: Label
var equipment: Label
var shop_panel: PanelContainer
var overlay: PanelContainer
var hover: MeshInstance3D
var aim_markers: Array[MeshInstance3D] = []
var gate: MeshInstance3D
var scythe: Node3D
var held: Node3D
var shot_active := false
var shot_return := false
var shot_origin := Vector3.ZERO
var shot_dir := Vector3.RIGHT
var shot_distance := 0.0
var shot_hits: Dictionary = {}
var time := 0.0
var bridge_open := false
var muted := false
var finished := false
var cut_audio: AudioStreamPlayer
var throw_audio: AudioStreamPlayer
var transition_lock := 0.0

func _ready() -> void:
	build_world()
	build_ui()
	load_stage(0)
	if "--input-check" in OS.get_cmdline_user_args():
		var checker := Node.new()
		checker.set_script(load("res://tests/input_check.gd"))
		add_child(checker)
	if "--smoke" in OS.get_cmdline_user_args():
		call_deferred("smoke_test")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			harvest = {"w":16,"c":16}
			load_stage(clampi(arg.trim_prefix("--stage=").to_int(),0,7))
	if "--capture" in OS.get_cmdline_user_args():
		capture_later()

func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if glow > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = material(color,glow)
	parent.add_child(n)
	n.position = pos
	return n

func asset(parent: Node3D, file: String, pos: Vector3, target_size: float) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = load(file)
	if "Wheat" in file:
		n.material_override = material(Color("d7b354"))
	if "Greenhouse.tres" in file:
		var colors := [Color("397b75"),Color("b9c596"),Color("80c9bd"),Color("63976c")]
		for surface in n.mesh.get_surface_count():
			var mat := material(colors[surface % colors.size()])
			if surface == 2:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color.a = 0.55
				mat.roughness = 0.2
			n.set_surface_override_material(surface,mat)
	var bounds := n.mesh.get_aabb()
	var factor := target_size / maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
	n.scale = Vector3.ONE * factor
	parent.add_child(n)
	n.position = pos - Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*factor
	return n

func build_world() -> void:
	var bg := SubViewportContainer.new()
	bg.set_script(load("res://scripts/space.gd"))
	add_child(bg)
	view_container = SubViewportContainer.new()
	view_container.position = Vector2(280,126)
	view_container.size = Vector2(970,578)
	view_container.stretch = true
	view_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view_container)
	view = SubViewport.new()
	view.size = Vector2i(970,578)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.msaa_3d = Viewport.MSAA_2X
	view_container.add_child(view)
	world = Node3D.new()
	view.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.sky = load("res://Materials/SpaceSky.tres")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("b6d4d6")
	env.environment.ambient_light_energy = 0.7
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-35,0)
	sun.light_color = Color("fff0ce")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	world.add_child(sun)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.5
	camera.position = Vector3(11,15,16)
	camera.look_at(Vector3(0,0,0))
	board = Node3D.new()
	world.add_child(board)
	bunny = Node3D.new()
	world.add_child(bunny)
	bunny_model = Node3D.new()
	bunny.add_child(bunny_model)
	asset(bunny_model,"res://Meshes/Jefferson/BunnyFarmer.tres",Vector3.ZERO,1.02)
	# A little oxygen pack marks our space farmer.
	box(bunny_model,Vector3(0,0.40,0.27),Vector3(0.30,0.36,0.18),Color("74acac"))
	held = make_scythe()
	bunny.add_child(held)
	held.position = Vector3(0.4,0.55,0)
	held.scale = Vector3.ONE*0.8
	scythe = make_scythe()
	world.add_child(scythe)
	scythe.visible = false
	hover = box(world,Vector3.ZERO,Vector3(0.94,0.025,0.94),MINT)
	hover.visible = false
	for i in 18:
		var dot := box(world,Vector3.ZERO,Vector3(0.055,0.045,0.055),GOLD,0.6)
		dot.visible = false
		aim_markers.append(dot)
	cut_audio = AudioStreamPlayer.new()
	cut_audio.stream = load("res://Sounds/Scythe/scythe_cut1.wav")
	cut_audio.volume_db = -17
	add_child(cut_audio)
	throw_audio = AudioStreamPlayer.new()
	throw_audio.stream = load("res://Sounds/Scythe/boomerang_loop.wav")
	throw_audio.volume_db = -24
	add_child(throw_audio)

func make_scythe() -> Node3D:
	var root := Node3D.new()
	var packed: PackedScene = load("res://Imported/GLB/Jefferson/scythe.glb")
	var model := packed.instantiate() as Node3D
	root.add_child(model)
	model.scale = Vector3.ONE*0.75
	model.rotation_degrees = Vector3(0,0,90)
	for child in model.find_children("*", "MeshInstance3D"):
		child.material_override = material(Color("b9dfd0"),0.1)
	return root

func panel(pos: Vector2, dimensions: Vector2, parent: Node = ui) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.size = dimensions
	var style := StyleBoxFlat.new()
	style.bg_color = Color("122330")
	style.border_color = Color("334b52")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	p.add_theme_stylebox_override("panel",style)
	parent.add_child(p)
	return p

func label_at(text: String, pos: Vector2, font_size: int, color: Color = WHITE, parent: Node = ui) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func button(text: String, pos: Vector2, dimensions: Vector2, callback: Callable, parent: Node = ui) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = dimensions
	b.add_theme_font_size_override("font_size",16)
	for state in ["normal","hover","pressed","disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color("24443f") if state == "normal" else Color("38665a")
		if state == "disabled": s.bg_color = Color("26313a")
		s.set_corner_radius_all(7)
		s.set_border_width_all(1)
		s.border_color = Color("527d6e")
		b.add_theme_stylebox_override(state,s)
	b.add_theme_color_override("font_color",WHITE)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func build_ui() -> void:
	ui = Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	label_at("✦",Vector2(34,25),43,MINT)
	label_at("ORBIT & HARVEST",Vector2(90,27),30,WHITE)
	label_at("A LITTLE GARDEN IN A VERY BIG UNIVERSE",Vector2(92,70),11,MUTED)
	crop_icon("wheat",Vector2(982,32),Vector2(42,52),ui)
	wheat_total = label_at("0",Vector2(1040,40),26,GOLD)
	crop_icon("carrot",Vector2(1110,32),Vector2(48,52),ui)
	carrot_total = label_at("0",Vector2(1174,40),26,GOLD)
	counts = label_at("",Vector2(34,352),18,GOLD)
	label_at("YOUR SCYTHE",Vector2(34,587),11,MUTED)
	equipment = label_at("",Vector2(34,611),16,MINT)
	label_at("DEEP SPACE AGRICULTURE  /  EST. 2086",Vector2(930,751),10,MUTED)

func crop_icon(crop: String, pos: Vector2, dimensions: Vector2, parent: Node) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load("res://assets/icons/"+crop+".jpg")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = pos
	icon.size = dimensions
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon

func grid_pos(c: Vector2i) -> Vector3:
	return Vector3(c.x-5,0,c.y-4)

func is_shop(index: int = stage) -> bool:
	return LEVELS[index].get("shop",false)

func save_stage() -> void:
	states[stage] = {"crops":crops.duplicate(true),"bridge":bridge_open}

func load_stage(index: int, from_right: bool = false) -> void:
	stage = index
	for n in board.get_children():
		n.free()
	crops.clear()
	tiles.clear()
	rocks.clear()
	tile_nodes.clear()
	crop_nodes.clear()
	path.clear()
	shot_active = false
	scythe.visible = false
	held.visible = true
	throw_audio.stop()
	bridge_open = false
	if is_instance_valid(shop_panel): shop_panel.queue_free()
	var rows: Array = LEVELS[stage].get("map",[])
	if is_shop():
		rows = ["...........","...........","...........","...........","...........","...........","...........","...........","..........."]
	for z in H:
		for x in W:
			var c := Vector2i(x,z)
			var kind: String = rows[z][x]
			if kind == "~" or kind == "b": continue
			tiles[c] = kind
			var ground_color := Color("456363") if (x+z)%2 == 0 else Color("3e595b")
			if kind.to_lower() in ["w","c"]: ground_color = Color("6a5f44")
			tile_nodes[c] = box(board,grid_pos(c)-Vector3(0,0.19,0),Vector3(0.96,0.34,0.96),ground_color)
			box(board,grid_pos(c)-Vector3(0,0.44,0),Vector3(0.85,0.18,0.85),Color("213943"))
			if kind == "#":
				rocks[c] = true
				asset(board,"res://Meshes/Jefferson/RockPlain2.tres",grid_pos(c),0.94)
			if kind.to_lower() in ["w","c"]:
				crops[c] = {"kind":kind,"hp":(2 if kind == "W" else (3 if kind == "C" else 1))}
			if kind == "s":
				box(board,grid_pos(c)+Vector3(0,0.02,0),Vector3(0.65,0.05,0.65),GOLD,0.5)
	if states.has(stage):
		crops = states[stage].crops.duplicate(true)
		if states[stage].bridge: open_bridge()
	for c in crops:
		var crop_kind: String = crops[c].kind
		var file := "WheatFull" if crop_kind.to_lower() == "w" else "Carrot3"
		var n := asset(board,"res://Meshes/Jefferson/"+file+".tres",grid_pos(c),0.81)
		crop_nodes[c] = n
		if crop_kind == crop_kind.to_upper():
			box(n,Vector3(0,0.05,0),Vector3(0.13,0.035,0.13),GOLD,0.3)
	gate = box(board,grid_pos(Vector2i(10,4))+Vector3(0,0.02,0),Vector3(0.83,0.06,0.83),MINT,0.5)
	for x in [-5.42,5.42]:
		for z in [-3.75,3.75]:
			box(board,Vector3(x,0.15,z),Vector3(0.10,0.60,0.10),Color("91cabc"),0.5)
	if stage > 0:
		box(board,grid_pos(Vector2i(0,4))+Vector3(0,0.02,0),Vector3(0.83,0.06,0.83),Color("7e9ba7"),0.25)
	var arrow := Label3D.new()
	arrow.text = "→"
	arrow.font_size = 80
	arrow.pixel_size = 0.009
	arrow.position = grid_pos(Vector2i(10,4))+Vector3(0,0.65,0)
	arrow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	arrow.modulate = MINT
	board.add_child(arrow)
	cell = Vector2i(9,4) if from_right else Vector2i(1,4)
	bunny.position = grid_pos(cell)
	bunny_model.rotation = Vector3.ZERO
	transition_lock = 0.6
	if is_shop():
		asset(board,"res://Meshes/Kevin/Greenhouse.tres",Vector3(0,0,-2),3.7)
		for x in range(3,8):
			for z in [0,7]:
				asset(board,"res://Meshes/Jefferson/WheatFull.tres",grid_pos(Vector2i(x,z)),0.72)
		for x in range(4,7):
			for z in range(1,4): rocks[Vector2i(x,z)] = true
		show_shop()
	update_ui()

func update_ui() -> void:
	wheat_total.text = str(harvest.w)
	carrot_total.text = str(harvest.c)
	var wheat := 0
	var carrots := 0
	for c in crops:
		if crops[c].kind.to_lower() == "w": wheat += 1
		else: carrots += 1
	counts.text = "%02d wheat  /  %02d carrots" % [wheat,carrots] if not is_shop() else ""
	equipment.text = "Power  %d     /     Reach  %d" % [power,reach]
	gate.material_override = material(MINT if crops.is_empty() else Color("b98860"),0.5)

func walkable(c: Vector2i) -> bool:
	return tiles.has(c) and not rocks.has(c) and not crops.has(c)

func find_path(start: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not walkable(target): return result
	var queue: Array[Vector2i] = [start]
	var previous := {start:start}
	var at := 0
	while at < queue.size():
		var cur := queue[at]
		at += 1
		if cur == target: break
		for dir in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = cur+dir
			if walkable(next) and not previous.has(next):
				previous[next] = cur
				queue.append(next)
	if not previous.has(target): return result
	var step := target
	while step != start:
		result.push_front(step)
		step = previous[step]
	return result

func mouse_world(screen_position: Vector2 = Vector2.INF) -> Variant:
	var mouse := view_container.get_local_mouse_position() if screen_position == Vector2.INF else screen_position-view_container.position
	if not Rect2(Vector2.ZERO,view_container.size).has_point(mouse): return null
	return Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(mouse),camera.project_ray_normal(mouse))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if finished: return
			if is_instance_valid(overlay): close_overlay()
			else: show_pause()
		if event.keycode == KEY_R and not is_instance_valid(overlay) and not is_shop(): reset_field()
		if event.keycode == KEY_M:
			muted = not muted
			AudioServer.set_bus_mute(0,muted)
		if event.keycode == KEY_F11:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if is_instance_valid(overlay) or finished: return
	if event is InputEventMouseButton and event.pressed:
		var point = mouse_world(event.position)
		if point == null: return
		var target := Vector2i(roundi(point.x)+5,roundi(point.z)+4)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if shot_active:
				return
			if crops.has(target):
				return
			path = find_path(cell,target)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			throw_scythe(point)

func throw_scythe(target: Vector3) -> void:
	if shot_active or is_shop(): return
	path.clear()
	bunny.position = grid_pos(cell)
	var direction := target-bunny.position
	direction.y = 0
	if direction.length() < 0.1: return
	shot_dir = direction.normalized()
	shot_origin = bunny.position+Vector3(0,0.45,0)
	shot_distance = 0
	shot_return = false
	shot_active = true
	shot_hits.clear()
	scythe.position = shot_origin
	scythe.visible = true
	held.visible = false
	bunny_model.rotation.y = atan2(shot_dir.x,shot_dir.z)
	if not muted: throw_audio.play()

func hit_crop(c: Vector2i) -> void:
	if not crops.has(c): return
	crops[c].hp -= power
	var n: Node3D = crop_nodes[c]
	if crops[c].hp > 0:
		var tween := create_tween()
		tween.tween_property(n,"rotation:z",0.22,0.08)
		tween.tween_property(n,"rotation:z",0.0,0.12)
		return
	var kind: String = crops[c].kind
	harvest[kind.to_lower()] += 1
	total_harvest += 1
	crops.erase(c)
	crop_nodes.erase(c)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(n,"position:y",n.position.y+0.5,0.2)
	tween.tween_property(n,"scale",Vector3.ZERO,0.25)
	tween.chain().tween_callback(n.queue_free)
	if not muted:
		cut_audio.pitch_scale = randf_range(0.9,1.2)
		cut_audio.play()
	update_ui()
	if crops.is_empty():
		save_stage()

func _process(dt: float) -> void:
	time += dt
	if is_instance_valid(overlay): return
	transition_lock = maxf(0,transition_lock-dt)
	if not path.is_empty():
		var target := grid_pos(path[0])
		var delta := target-bunny.position
		bunny.position = bunny.position.move_toward(target,dt*4.5)
		bunny_model.rotation.y = lerp_angle(bunny_model.rotation.y,atan2(delta.x,delta.z),dt*14)
		bunny_model.position.y = absf(sin(time*17))*0.11
		bunny_model.rotation.z = sin(time*17)*0.045
		if bunny.position.distance_to(target)<0.015:
			cell = path.pop_front()
			if tiles.get(cell,"") == "s": open_bridge()
	else:
		bunny_model.position.y = sin(time*2)*0.018
		bunny_model.rotation.z = 0
	if transition_lock == 0 and path.is_empty() and not shot_active:
		if cell == Vector2i(10,4) and crops.is_empty():
			next_stage()
		elif cell == Vector2i(0,4) and stage > 0:
			save_stage()
			load_stage(stage-1,true)
	if shot_active: update_shot(dt)
	update_aim()

func update_shot(dt: float) -> void:
	scythe.rotation.y += dt*19
	if shot_return:
		scythe.position = scythe.position.move_toward(bunny.position+Vector3(0,0.45,0),dt*12)
		if scythe.position.distance_to(bunny.position+Vector3(0,0.45,0))<0.1:
			shot_active = false
			scythe.visible = false
			held.visible = true
			throw_audio.stop()
		return
	# Short substeps prevent a fast blade skipping a crop or a rock.
	var distance := minf(dt*8,reach-shot_distance)
	var steps := maxi(1,ceili(distance/0.1))
	for i in steps:
		shot_distance += distance/steps
		scythe.position = shot_origin+shot_dir*shot_distance
		var c := Vector2i(roundi(scythe.position.x)+5,roundi(scythe.position.z)+4)
		if rocks.has(c):
			shot_return = true
			break
		if crops.has(c) and not shot_hits.has(c):
			shot_hits[c] = true
			hit_crop(c)
	if shot_distance >= reach-0.001: shot_return = true

func update_aim() -> void:
	var point = mouse_world()
	for dot in aim_markers: dot.visible = false
	hover.visible = false
	if point == null or is_shop(): return
	var c := Vector2i(roundi(point.x)+5,roundi(point.z)+4)
	if tiles.has(c):
		hover.visible = true
		hover.position = grid_pos(c)+Vector3(0,0.015,0)
		hover.material_override = material(MINT if walkable(c) else GOLD)
	if shot_active: return
	var direction: Vector3 = (point-bunny.position).normalized()
	direction.y = 0
	direction = direction.normalized()
	for i in aim_markers.size():
		var p := bunny.position + direction*(i+1)*float(reach)/aim_markers.size()
		var tc := Vector2i(roundi(p.x)+5,roundi(p.z)+4)
		if rocks.has(tc): break
		aim_markers[i].position = p+Vector3(0,0.15,0)
		aim_markers[i].visible = true

func open_bridge() -> void:
	if bridge_open: return
	bridge_open = true
	var c := Vector2i(5,4)
	tiles[c] = "."
	tile_nodes[c] = box(board,grid_pos(c)-Vector3(0,0.17,0),Vector3(0.97,0.32,0.97),MINT,0.2)

func next_stage() -> void:
	save_stage()
	if stage == LEVELS.size()-1:
		finished = true
		show_ending()
	else: load_stage(stage+1)

func reset_field() -> void:
	# Refunding the field's harvest prevents reset farming and keeps purchases valid.
	# A field can only reset before leaving it; persisted cleared fields stay cleared.
	if states.has(stage):
		return
	var rows: Array = LEVELS[stage].map
	for z in H:
		for x in W:
			var kind: String = rows[z][x]
			if kind.to_lower() in ["w","c"] and not crops.has(Vector2i(x,z)):
				harvest[kind.to_lower()] -= 1
				total_harvest -= 1
	load_stage(stage)

func show_shop() -> void:
	if is_instance_valid(shop_panel): shop_panel.queue_free()
	shop_panel = panel(Vector2(430,520),Vector2(690,140))
	var content := Control.new()
	content.custom_minimum_size = Vector2(690,140)
	shop_panel.add_child(content)
	label_at("THE GREENHOUSE EXCHANGE",Vector2(20,14),12,MINT,content)
	var power_cost := 8*power
	var range_cost := 10*(reach-2)
	label_at("Forged moonsteel",Vector2(20,40),20,WHITE,content)
	label_at("+1 power",Vector2(20,69),13,MUTED,content)
	var p := button("%d   /   Upgrade" % power_cost if power<3 else "Power fully upgraded",Vector2(20,91),Vector2(306,36),func(): buy_upgrade(true),content)
	p.icon = load("res://assets/icons/carrot.jpg")
	p.expand_icon = true
	p.add_theme_constant_override("icon_max_width",24)
	p.disabled = harvest.c<power_cost or power>=3
	label_at("Orbital tether",Vector2(359,40),20,WHITE,content)
	label_at("+1 tile of throwing distance",Vector2(359,69),13,MUTED,content)
	var r := button("%d   /   Upgrade" % range_cost if reach<6 else "Reach fully upgraded",Vector2(359,91),Vector2(306,36),func(): buy_upgrade(false),content)
	r.icon = load("res://assets/icons/wheat.jpg")
	r.expand_icon = true
	r.add_theme_constant_override("icon_max_width",24)
	r.disabled = harvest.w<range_cost or reach>=6

func buy_upgrade(strength: bool) -> void:
	var resource := "c" if strength else "w"
	var cost := 8*power if strength else 10*(reach-2)
	if harvest[resource]<cost or (strength and power>=3) or (not strength and reach>=6): return
	harvest[resource] -= cost
	if strength: power += 1
	else: reach += 1
	update_ui()
	show_shop()

func modal(title: String, body: String) -> Control:
	if is_instance_valid(overlay): overlay.free()
	overlay = panel(Vector2(365,225),Vector2(550,340))
	var content := Control.new()
	content.custom_minimum_size = Vector2(550,340)
	overlay.add_child(content)
	label_at(title,Vector2(30,25),29,MINT,content)
	var l := label_at(body,Vector2(30,80),17,WHITE,content)
	l.size = Vector2(490,200)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return content

func close_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.free()
		overlay = null

func show_pause() -> void:
	var content := modal("A moment among the stars","Paused")
	button("Back to the garden",Vector2(30,282),Vector2(490,40),close_overlay,content)

func show_ending() -> void:
	var content := modal("A universe in bloom.","Every field harvested. Every little root brought home.\n\nYou gathered %d crops across six space gardens.\nYour scythe: power %d · reach %d.\n\nThanks for tending this corner of the universe." % [total_harvest,power,reach])
	button("Plant a new beginning",Vector2(30,282),Vector2(490,40),restart,content)

func restart() -> void:
	close_overlay()
	states.clear()
	harvest = {"w":0,"c":0}
	power = 1
	reach = 3
	total_harvest = 0
	finished = false
	load_stage(0)

func capture_later() -> void:
	await get_tree().create_timer(3).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshot.png")

func smoke_test() -> void:
	muted = true
	assert(crops.size() == 16,"Opening crop count")
	assert(find_path(cell,Vector2i(9,4)).size() > 0,"Click path to exit")
	assert(find_path(cell,Vector2i(2,1)).is_empty(),"Crops block walking")
	throw_scythe(grid_pos(Vector2i(2,1)))
	for i in 120:
		if shot_active: update_shot(0.016)
	assert(not shot_active,"Scythe returns")
	assert(crops.size()<16,"Throw harvests a crop")
	assert(harvest.w == 16-crops.size() and harvest.c == 0,"Separate crop inventory")
	reset_field()
	assert(crops.size() == 16 and harvest.w == 0 and harvest.c == 0 and total_harvest == 0,"Reset refunds only this field's crops")
	buy_upgrade(true)
	buy_upgrade(false)
	assert(power == 1 and reach == 3 and harvest.w == 0 and harvest.c == 0,"Unaffordable purchases preserve inventory")
	for index in LEVELS.size():
		load_stage(index)
		if is_shop():
			harvest = {"w":1000,"c":1000}
			var before := power
			if power<3:
				buy_upgrade(true)
				assert(power == before+1,"Strength purchase")
			buy_upgrade(false)
			continue
		if index in [4,7]:
			assert(not tiles.has(Vector2i(5,4)),"Bridge starts closed")
			assert(not find_path(cell,Vector2i(2,4)).is_empty(),"Switch reachable")
			open_bridge()
			assert(tiles.has(Vector2i(5,4)),"Switch opens bridge")
		# Solve by choosing reachable firing positions; prove every crop can be reached at base range.
		var remaining := crops.size()
		while not crops.is_empty():
			var harvested := false
			for c in crops.keys():
				for origin in tiles:
					if not walkable(origin): continue
					if origin != cell and find_path(cell,origin).is_empty(): continue
					var delta: Vector3 = grid_pos(c)-grid_pos(origin)
					if delta.length()>3.0: continue
					var blocked := false
					for step in range(1,31):
						var point := grid_pos(origin)+delta*step/30.0
						if rocks.has(Vector2i(roundi(point.x)+5,roundi(point.z)+4)): blocked = true
					if blocked: continue
					while crops.has(c): hit_crop(c)
					harvested = true
					break
			assert(harvested,"All crops solvable at base range: %d" % index)
			assert(crops.size()<remaining,"Solver makes progress")
			remaining = crops.size()
		save_stage()
		load_stage(index)
		assert(crops.is_empty(),"Screen harvest persists")
	print("PASS: movement, crop collisions, actual throw/return, all six puzzles at base range, bridges, upgrades, screen persistence.")
	await get_tree().create_timer(0.4).timeout
	get_tree().quit()
