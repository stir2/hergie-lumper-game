extends Node

const RENDER_SCALE := 2.0
const CHARGE_SECONDS := 0.9
const MIN_THROW_DISTANCE := 1.0
const BUNNY_ROTATION_OFFSET := -PI / 2.0
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
var floor_materials: Dictionary = {}
var tile_nodes: Dictionary = {}
var crop_nodes: Dictionary = {}
var path: Array[Vector2i] = []
var cell := Vector2i(0,4)
var world: Node3D
var board: Node3D
var background_ruins: Node3D
var floating_ruins: Array[Node3D] = []
var bunny: Node3D
var bunny_model: Node3D
var hand_anchor: Node3D
var camera: Camera3D
var view: SubViewport
var view_container: SubViewportContainer
var back_buffer_copy: BackBufferCopy
var post_process: ColorRect
var ui: Control
var hud: Control
var title_menu: Control
var title_active := false
var wheat_total: Label
var carrot_total: Label
var equipment: Label
var shop_panel: PanelContainer
var overlay: PanelContainer
var hover: MeshInstance3D
var aim_markers: Array[MeshInstance3D] = []
var gate: MeshInstance3D
var scythe: Node3D
var held: Node3D
var charging := false
var charge_time := 0.0
var charge_target := Vector3.ZERO
var shot_limit := 0.0
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
	show_title()
	build_post_process()
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

func floor_tile(c: Vector2i, kind: String) -> MeshInstance3D:
	if floor_materials.is_empty():
		for texture_name in ["DirtTile_lowdirt.png","lowdirtSandy.webp","lowdirtRocky.webp","lowdirtseedsnweeds.webp"]:
			var soil := material(Color.WHITE)
			soil.albedo_texture = load("res://Imported/PNG/Jefferson/"+texture_name)
			soil.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
			floor_materials[texture_name] = soil
	var texture_name := "DirtTile_lowdirt.png"
	if kind.to_lower() in ["w","c"]:
		texture_name = "lowdirtseedsnweeds.webp"
	elif kind == "#":
		texture_name = "lowdirtRocky.webp"
	elif (c.x*13+c.y*7+stage)%5 == 0:
		texture_name = "lowdirtSandy.webp"
	elif (c.x*7+c.y*3+stage)%7 == 0:
		texture_name = "lowdirtRocky.webp"
	var tile := box(board,grid_pos(c)-Vector3(0,0.19,0),Vector3(0.96,0.34,0.96),Color("302b24"))
	var surface := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.86,0.86)
	surface.mesh = plane
	surface.material_override = floor_materials[texture_name]
	surface.position.y = 0.176
	surface.rotation.y = float((c.x+c.y)%4)*PI/2
	tile.add_child(surface)
	return tile

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
	view_container.position = Vector2.ZERO
	view_container.size = Vector2(1280,800) * RENDER_SCALE
	view_container.scale = Vector2.ONE / RENDER_SCALE
	view_container.stretch = false
	view_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view_container)
	view = SubViewport.new()
	view.size = Vector2i(Vector2(1280,800) * RENDER_SCALE)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.msaa_3d = Viewport.MSAA_4X
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
	camera.size = 9.6
	camera.position = Vector3(11,15,16)
	camera.look_at(Vector3(0,0,0))
	board = Node3D.new()
	world.add_child(board)
	build_background_ruins()
	bunny = Node3D.new()
	world.add_child(bunny)
	bunny_model = Node3D.new()
	bunny.add_child(bunny_model)
	asset(bunny_model,"res://Meshes/Jefferson/BunnyFarmer.tres",Vector3.ZERO,1.02)
	# A little oxygen pack marks our space farmer.
	box(bunny_model,Vector3(0,0.40,0.27),Vector3(0.30,0.36,0.18),Color("74acac"))
	hand_anchor = Node3D.new()
	bunny_model.add_child(hand_anchor)
	# Hand attachment point for the held scythe. Adjust these values if needed
	# to fine-tune the grip position for BunnyFarmer.tres.
	hand_anchor.position = Vector3(.30,0.2,0.30)
	hand_anchor.rotation_degrees = Vector3(0,0,180)
	held = make_scythe(true)
	hand_anchor.add_child(held)
	held.position = Vector3.ZERO
	held.scale = Vector3.ONE*0.8
	scythe = make_scythe()
	world.add_child(scythe)
	scythe.visible = false
	hover = box(world,Vector3.ZERO,Vector3(0.82,0.025,0.82),MINT)
	var hover_material := hover.material_override as StandardMaterial3D
	hover_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hover_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hover_material.albedo_color = Color(0.65,0.90,0.78,0.5)
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

func build_post_process() -> void:
	# Explicitly copy the complete root viewport after the world and HUD
	# have been drawn. The shader reads this copy through hint_screen_texture.
	back_buffer_copy = BackBufferCopy.new()
	back_buffer_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(back_buffer_copy)

	# Draw the effect across the entire game window.
	post_process = ColorRect.new()
	post_process.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	post_process.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Transparent fallback: if the shader fails to load/compile, this node
	# will no longer cover the game with a solid white rectangle.
	post_process.color = Color(1.0, 1.0, 1.0, 0.0)

	var shader_material := ShaderMaterial.new()
	shader_material.shader = load("res://Shaders/dystopian_post.gdshader")
	post_process.material = shader_material

	add_child(post_process)


func make_scythe(pivot_at_handle: bool = false) -> Node3D:
	var root := Node3D.new()
	var packed: PackedScene = load("res://Imported/GLB/Jefferson/scythe.glb")
	var model := packed.instantiate() as Node3D
	root.add_child(model)
	model.scale = Vector3.ONE*0.75
	model.rotation_degrees = Vector3(0,0,90)
	# After the visual rotation, the lower handle end lies along local +X.
	# Offset the held mesh so its handle, rather than its imported center, is the pivot.
	if pivot_at_handle:
		model.position.x = -0.20
	for child in model.find_children("*", "MeshInstance3D"):
		child.material_override = material(Color("b9dfd0"),0.1)
	return root

func floating_ruin(file: String, pos: Vector3, target_size: float, orientation: Vector3, spin: Vector3, drift: Vector3, phase: float) -> void:
	var pivot := Node3D.new()
	background_ruins.add_child(pivot)
	pivot.position = pos
	pivot.rotation_degrees = orientation
	pivot.set_meta("base_position",pos)
	pivot.set_meta("spin",spin)
	pivot.set_meta("drift",drift)
	pivot.set_meta("phase",phase)
	asset(pivot,file,Vector3.ZERO,target_size)
	floating_ruins.append(pivot)

func build_background_ruins() -> void:
	background_ruins = Node3D.new()
	world.add_child(background_ruins)
	# Large nearby wrecks frame the farm; smaller silhouettes recede into the sky.
	floating_ruin("res://Meshes/Kevin/ConcreteBuilding1.tres",Vector3(-7.4,-1.0,-5.2),1.80,Vector3(11,-23,17),Vector3(0.05,0.12,-0.04),Vector3(0.45,0.20,-0.25),0.2)
	floating_ruin("res://Meshes/Kevin/BrickBuilding3.tres",Vector3(7.5,-1.6,-5.8),1.65,Vector3(-14,28,-10),Vector3(-0.04,-0.10,0.06),Vector3(-0.35,0.16,0.32),1.1)
	floating_ruin("res://Meshes/Kevin/ConcreteBuilding2.tres",Vector3(-2.0,-2.2,-8.8),1.05,Vector3(34,-12,23),Vector3(0.06,0.08,0.03),Vector3(0.18,-0.24,0.42),2.4)
	floating_ruin("res://Meshes/Kevin/BrickBuilding2.tres",Vector3(8.9,-2.4,-2.6),1.15,Vector3(-28,42,16),Vector3(-0.05,0.07,-0.04),Vector3(-0.40,0.23,-0.15),3.0)
	floating_ruin("res://Meshes/Kevin/ConcretePillar3.tres",Vector3(-8.8,-2.0,0.5),0.90,Vector3(66,18,-35),Vector3(0.09,-0.05,0.07),Vector3(0.26,0.31,0.12),3.8)
	floating_ruin("res://Meshes/Kevin/Railing1.tres",Vector3(7.8,-2.7,1.8),0.82,Vector3(31,-38,42),Vector3(-0.07,0.08,0.05),Vector3(-0.18,-0.20,0.36),4.6)
	floating_ruin("res://Meshes/Jefferson/ConcreteDebris.tres",Vector3(-5.6,-2.6,-7.4),0.78,Vector3(43,9,61),Vector3(0.10,0.06,-0.08),Vector3(0.35,-0.18,0.20),5.1)
	floating_ruin("res://Meshes/Jefferson/Debris2.tres",Vector3(4.6,-2.9,-8.0),0.62,Vector3(-22,48,31),Vector3(-0.08,0.11,0.04),Vector3(-0.28,0.25,-0.30),0.8)
	floating_ruin("res://Meshes/Jefferson/RockTitanium2.tres",Vector3(-9.5,-2.8,-3.4),0.72,Vector3(17,-31,29),Vector3(0.04,0.09,0.07),Vector3(0.20,0.12,-0.38),1.7)
	floating_ruin("res://Meshes/Jefferson/RockPlain3.tres",Vector3(10.2,-3.1,-4.4),0.54,Vector3(-31,24,-44),Vector3(-0.06,0.05,-0.09),Vector3(-0.32,-0.16,0.18),2.8)
	floating_ruin("res://Meshes/Kevin/ConcretePillar2.tres",Vector3(-10.4,-3.0,-6.9),0.92,Vector3(29,54,-17),Vector3(0.08,-0.06,0.10),Vector3(0.22,0.28,0.35),4.0)
	floating_ruin("res://Meshes/Kevin/BrickBuilding1.tres",Vector3(9.6,-3.2,-8.4),0.76,Vector3(-41,13,38),Vector3(-0.09,0.07,-0.06),Vector3(-0.38,0.17,-0.22),5.5)
	floating_ruin("res://Meshes/Kevin/ConcretePillar1.tres",Vector3(-6.8,-3.4,2.8),0.58,Vector3(73,-24,19),Vector3(0.11,0.04,-0.07),Vector3(0.16,-0.26,0.27),1.5)
	floating_ruin("res://Meshes/Kevin/BrickPillar1.tres",Vector3(10.8,-3.5,0.2),0.62,Vector3(-19,47,56),Vector3(-0.05,0.10,0.08),Vector3(-0.24,0.21,0.14),2.1)
	floating_ruin("res://Meshes/Jefferson/RockTitanium1.tres",Vector3(-3.8,-3.6,-10.6),0.50,Vector3(34,-48,-22),Vector3(0.07,-0.08,0.09),Vector3(0.30,0.14,-0.18),3.3)
	floating_ruin("res://Meshes/Jefferson/RockPlain2.tres",Vector3(5.5,-3.8,-10.2),0.42,Vector3(-62,21,44),Vector3(-0.10,0.05,-0.04),Vector3(-0.16,0.29,0.24),4.9)
	# Lower, farther pieces keep the void around the near edge from feeling empty.
	floating_ruin("res://Meshes/Kevin/ConcreteBuilding1.tres",Vector3(-10.8,-5.0,-3.4),1.08,Vector3(48,-37,29),Vector3(0.06,0.09,-0.05),Vector3(0.31,0.22,0.18),0.6)
	floating_ruin("res://Meshes/Kevin/BrickBuilding1.tres",Vector3(-6.8,-6.0,-3.0),0.84,Vector3(-33,26,51),Vector3(-0.08,0.04,0.10),Vector3(-0.26,0.30,-0.16),1.9)
	floating_ruin("res://Meshes/Kevin/ConcretePillar2.tres",Vector3(-9.8,-5.7,-0.3),0.62,Vector3(71,12,-39),Vector3(0.10,-0.07,0.06),Vector3(0.22,-0.18,0.29),2.7)
	floating_ruin("res://Meshes/Jefferson/Debris2.tres",Vector3(-5.1,-6.5,-6.5),0.72,Vector3(24,58,-36),Vector3(-0.06,0.11,-0.08),Vector3(-0.34,0.24,0.20),3.6)
	floating_ruin("res://Meshes/Jefferson/ConcreteDebris.tres",Vector3(-11.8,-5.8,1.8),0.56,Vector3(-47,19,63),Vector3(0.09,0.05,0.07),Vector3(0.17,0.27,-0.25),4.4)
	floating_ruin("res://Meshes/Jefferson/RockTitanium1.tres",Vector3(-7.2,-5.5,2.4),0.48,Vector3(39,-52,18),Vector3(-0.07,0.08,-0.09),Vector3(-0.21,0.16,0.33),5.2)
	floating_ruin("res://Meshes/Jefferson/RockPlain3.tres",Vector3(-2.4,-7.0,-8.3),0.52,Vector3(-56,34,27),Vector3(0.08,-0.06,0.05),Vector3(0.29,0.20,-0.17),1.3)
	floating_ruin("res://Meshes/Kevin/Railing1.tres",Vector3(2.8,-6.2,-8.6),0.50,Vector3(62,-29,45),Vector3(-0.10,0.07,0.04),Vector3(-0.18,0.32,0.21),2.4)

func update_background_ruins(dt: float) -> void:
	for ruin in floating_ruins:
		if not is_instance_valid(ruin): continue
		var spin: Vector3 = ruin.get_meta("spin")
		var base_position: Vector3 = ruin.get_meta("base_position")
		var drift: Vector3 = ruin.get_meta("drift")
		var phase: float = ruin.get_meta("phase")
		ruin.rotation += spin*dt
		ruin.position = base_position+drift*sin(time*0.42+phase)

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

	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)

	crop_icon("wheat",Vector2(982,32),Vector2(42,52),hud)
	wheat_total = label_at("0",Vector2(1040,40),26,GOLD,hud)
	crop_icon("carrot",Vector2(1110,32),Vector2(48,52),hud)
	carrot_total = label_at("0",Vector2(1174,40),26,GOLD,hud)
	label_at("YOUR SCYTHE",Vector2(34,587),11,MUTED,hud)
	equipment = label_at("",Vector2(34,611),16,MINT,hud)
	label_at("DEEP SPACE AGRICULTURE  /  EST. 2086",Vector2(930,751),10,MUTED,hud)

func crop_icon(crop: String, pos: Vector2, dimensions: Vector2, parent: Node) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load("res://assets/icons/"+crop+".png")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = pos
	icon.size = dimensions
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon

func menu_image(file: String, pos: Vector2, dimensions: Vector2, parent: Node) -> TextureRect:
	var image := TextureRect.new()
	image.texture = load(file)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.position = pos
	image.size = dimensions
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func menu_button(
	normal_file: String,
	hover_file: String,
	pressed_file: String,
	pos: Vector2,
	dimensions: Vector2,
	callback: Callable,
	parent: Node
) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = load(normal_file)
	b.texture_hover = load(hover_file)
	b.texture_pressed = load(pressed_file)
	b.position = pos
	b.size = dimensions
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func show_title() -> void:
	cancel_charge()
	path.clear()
	title_active = true
	hud.visible = false
	if is_instance_valid(title_menu): title_menu.queue_free()
	title_menu = Control.new()
	ui.add_child(title_menu)
	title_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.03,0.075,0.11,0.68)
	shade.position = Vector2.ZERO
	shade.size = Vector2(1280,800)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_menu.add_child(shade)
	menu_image("res://Imported/PNG/Jefferson/Menu-HergieLogoFinal.webp",Vector2(300,74),Vector2(680,306),title_menu)
	var tagline := label_at("A SPACE-FARMING JOURNEY",Vector2(488,374),16,MINT,title_menu)
	tagline.size = Vector2(304,28)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_button("res://Imported/PNG/Jefferson/Menu-Start.webp","res://Imported/PNG/Jefferson/Menu-StartHover.webp","res://Imported/PNG/Jefferson/Menu-StartClick.webp",Vector2(465,432),Vector2(350,108),begin_game,title_menu)
	menu_button("res://Imported/PNG/Jefferson/Menu-Exit.webp","res://Imported/PNG/Jefferson/Menu-ExitHover.webp","res://Imported/PNG/Jefferson/Menu-ExitClick.webp",Vector2(465,552),Vector2(350,108),quit_game,title_menu)
	var hint := label_at("ESC opens the garden menu during play",Vector2(420,702),13,MUTED,title_menu)
	hint.size = Vector2(440,24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func begin_game() -> void:
	title_active = false
	hud.visible = true
	if is_instance_valid(title_menu):
		title_menu.queue_free()
		title_menu = null

func quit_game() -> void:
	get_tree().quit()

func grid_pos(c: Vector2i) -> Vector3:
	return Vector3(c.x-5,0,c.y-4)

func is_shop(index: int = stage) -> bool:
	return LEVELS[index].get("shop",false)

func save_stage() -> void:
	states[stage] = {"crops":crops.duplicate(true),"bridge":bridge_open}

func load_stage(index: int, from_right: bool = false) -> void:
	cancel_charge()
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
			tile_nodes[c] = floor_tile(c,kind)
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
	bunny_model.rotation = Vector3(0, BUNNY_ROTATION_OFFSET, 0)
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
	var mouse := view_container.get_local_mouse_position() if screen_position == Vector2.INF else view_container.get_global_transform().affine_inverse() * screen_position
	if not Rect2(Vector2.ZERO,view_container.size).has_point(mouse): return null
	return Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(mouse),camera.project_ray_normal(mouse))

func _input(event: InputEvent) -> void:
	if not charging: return
	if event is InputEventMouseMotion:
		var point = mouse_world(event.position)
		if point != null: charge_target = point
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		# Handle release before UI controls can consume it, including outside the board.
		var point = mouse_world(event.position)
		var distance := charged_distance()
		cancel_charge()
		if point != null and not is_instance_valid(overlay) and not finished:
			throw_scythe(point,distance)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_charge()

func charged_distance() -> float:
	return lerpf(MIN_THROW_DISTANCE,float(reach),clampf(charge_time/CHARGE_SECONDS,0.0,1.0))

func start_charge(target: Vector3) -> void:
	if shot_active or charging or is_shop() or finished or is_instance_valid(overlay): return
	path.clear()
	bunny.position = grid_pos(cell)
	charging = true
	charge_time = 0.0
	charge_target = target
	update_aim()

func cancel_charge() -> void:
	charging = false
	charge_time = 0.0
	for dot in aim_markers: dot.visible = false
	if is_instance_valid(held): held.rotation.y = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if finished: return
			if is_instance_valid(overlay): close_overlay()
			else: show_title()
			return
		if title_active: return
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
			if shot_active or charging:
				return
			if crops.has(target):
				return
			path = find_path(cell,target)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			start_charge(point)

func throw_scythe(target: Vector3, distance: float = -1.0) -> void:
	if shot_active or is_shop(): return
	path.clear()
	bunny.position = grid_pos(cell)
	var direction := target-bunny.position
	direction.y = 0
	if direction.length() < 0.1: return
	shot_limit = float(reach) if distance < 0.0 else clampf(distance,MIN_THROW_DISTANCE,float(reach))
	shot_dir = direction.normalized()
	shot_origin = bunny.position+Vector3(0,0.45,0)
	shot_distance = 0
	shot_return = false
	shot_active = true
	shot_hits.clear()
	scythe.position = shot_origin
	scythe.visible = true
	held.visible = false
	bunny_model.rotation.y = atan2(shot_dir.x,shot_dir.z) + BUNNY_ROTATION_OFFSET
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
	update_background_ruins(dt)
	if title_active: return
	if is_instance_valid(overlay): return
	transition_lock = maxf(0,transition_lock-dt)
	if charging:
		charge_time = minf(CHARGE_SECONDS,charge_time+dt)
		held.rotation.y = PI*0.5*(charge_time/CHARGE_SECONDS)
	if not path.is_empty():
		var target := grid_pos(path[0])
		var delta := target-bunny.position
		bunny.position = bunny.position.move_toward(target,dt*4.5)
		bunny_model.rotation.y = lerp_angle(bunny_model.rotation.y,atan2(delta.x,delta.z) + BUNNY_ROTATION_OFFSET,dt*14)
		bunny_model.position.y = absf(sin(time*17))*0.11
		bunny_model.rotation.z = sin(time*17)*0.045
		if bunny.position.distance_to(target)<0.015:
			cell = path.pop_front()
			if tiles.get(cell,"") == "s": open_bridge()
	else:
		bunny_model.position.y = sin(time*2)*0.018
		bunny_model.rotation.z = 0
		if not shot_active and not charging:
			var mouse_target = mouse_world()
			if mouse_target != null:
				var look_direction: Vector3 = mouse_target-bunny.position
				look_direction.y = 0
				if look_direction.length_squared() > 0.01:
					bunny_model.rotation.y = lerp_angle(bunny_model.rotation.y,atan2(look_direction.x,look_direction.z) + BUNNY_ROTATION_OFFSET,dt*14)
	if transition_lock == 0 and path.is_empty() and not shot_active and not charging:
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
	var distance := minf(dt*8,shot_limit-shot_distance)
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
	if shot_distance >= shot_limit-0.001: shot_return = true

func update_aim() -> void:
	for dot in aim_markers: dot.visible = false
	hover.visible = false
	if is_shop() or is_instance_valid(overlay): return
	var point = mouse_world()
	if point != null and not charging:
		var c := Vector2i(roundi(point.x)+5,roundi(point.z)+4)
		if tiles.has(c):
			hover.visible = true
			hover.position = grid_pos(c)+Vector3(0,0.015,0)
			hover.material_override = material(MINT if walkable(c) else GOLD)
	if not charging or shot_active: return
	var direction := charge_target-bunny.position
	direction.y = 0
	if direction.length_squared()<0.01: return
	direction = direction.normalized()
	bunny_model.rotation.y = atan2(direction.x,direction.z) + BUNNY_ROTATION_OFFSET
	var distance := charged_distance()
	for i in aim_markers.size():
		var offset := float(i+1)*float(reach)/aim_markers.size()
		if offset>distance: break
		var p := bunny.position + direction*offset
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
	cancel_charge()
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
	p.icon = load("res://assets/icons/carrot.png")
	p.expand_icon = true
	p.add_theme_constant_override("icon_max_width",24)
	p.disabled = harvest.c<power_cost or power>=3
	label_at("Orbital tether",Vector2(359,40),20,WHITE,content)
	label_at("+1 tile of throwing distance",Vector2(359,69),13,MUTED,content)
	var r := button("%d   /   Upgrade" % range_cost if reach<6 else "Reach fully upgraded",Vector2(359,91),Vector2(306,36),func(): buy_upgrade(false),content)
	r.icon = load("res://assets/icons/wheat.png")
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
	cancel_charge()
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
