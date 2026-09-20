extends Node

@export var instruction_font: Font = preload("res://assets/fonts/Futurot.ttf")

const RENDER_SCALE := 2.0
const CHARGE_SECONDS := 0.9
const MIN_THROW_DISTANCE := 1.0
const BASE_THROW_DISTANCE := 4.0
const JUMP_DURATION := 0.34
const SCYTHE_OUTBOUND_MAX_SPEED := 12.0
const SCYTHE_OUTBOUND_MIN_SPEED := 5.0
const SCYTHE_RETURN_MAX_SPEED := 22.0
const SCYTHE_MODEL_SCALE := 0.675
const SCYTHE_HITBOX_VERTICAL_PADDING := 0.315
const BUNNY_ROTATION_OFFSET := -PI / 2.0
const MUSIC_GAMEPLAY_VOLUME_DB := -14.0
const MUSIC_MENU_VOLUME_DB := -18.0
const HARVEST_ICON_SIZE := Vector2(34,34)
const HUD_INVENTORY_TARGETS := {"w": Vector2(1003,58), "c": Vector2(1134,58), "t": Vector2(1134,116)}
const RESOURCE_ICON_NAMES := {"w":"wheat", "c":"carrot", "t":"titanium"}
const SHOP_BASE := "res://Imported/PNG/Jefferson/Shop-ShopBase.webp"
const SHOP_BUTTON_SIZE := Vector2(370,108)
const SHOP_BUTTON_PATH := "res://Imported/PNG/Jefferson/Shop-"
const W := 11
const H := 9
const MINT := Color("a6e6c7")
const GOLD := Color("efd594")
const WHITE := Color("edf1df")
const MUTED := Color("95abae")
const LEVELS := [
	preload("res://scenes/levels/00_first_light.tscn"),
	preload("res://scenes/levels/01_across_the_blue.tscn"),
	preload("res://scenes/levels/02_little_greenhouse.tscn"),
	preload("res://scenes/levels/03_roots_and_routes.tscn"),
	preload("res://scenes/levels/04_bridge_of_stars.tscn"),
	preload("res://scenes/levels/05_wandering_nursery.tscn"),
	preload("res://scenes/levels/06_lunar_labyrinth.tscn"),
	preload("res://scenes/levels/08_empty_field_01.tscn"),
	preload("res://scenes/levels/09_empty_field_02.tscn"),
	preload("res://scenes/levels/10_empty_field_03.tscn"),
	preload("res://scenes/levels/11_empty_field_04.tscn"),
	preload("res://scenes/levels/12_empty_field_05.tscn"),
	preload("res://scenes/levels/13_empty_field_06.tscn"),
	preload("res://scenes/levels/14_empty_field_07.tscn"),
	preload("res://scenes/levels/15_empty_field_08.tscn"),
	preload("res://scenes/levels/16_empty_field_09.tscn"),
	preload("res://scenes/levels/17_empty_field_10.tscn"),
	preload("res://scenes/levels/07_last_constellation.tscn")
]

var stage := 0
var current_level
var harvest := {"w":0,"c":0,"t":0}
var displayed_harvest := {"w":0,"c":0,"t":0}
var rock_break_level := 0
var reach_level := 0
var jump_unlocked := false
var total_harvest := 0
var states: Dictionary = {}
var crops: Dictionary = {}
var tiles: Dictionary = {}
var rocks: Dictionary = {}
var rock_nodes: Dictionary = {}
var collected_titanium_rocks: Dictionary = {}
var scenery_blockers: Dictionary = {}
var floor_materials: Dictionary = {}
var tile_nodes: Dictionary = {}
var crop_nodes: Dictionary = {}
var shop_tiles: Dictionary = {}
var shop_marker_materials: Dictionary = {}
var current_shop_number := 0
var path: Array[Vector2i] = []
var cell := Vector2i(0,4)
var hop_active := false
var hop_progress := 0.0
var hop_start := Vector3.ZERO
var hop_target := Vector3.ZERO
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
var first_level_instructions: Control
var title_menu: Control
var title_active := false
var wheat_total: Label
var carrot_total: Label
var titanium_icon: TextureRect
var titanium_total: Label
var shop_panel: Control
var shop_closed_for_visit := false
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
var shot_speed := 0.0
var shot_return_start_distance := 0.0
var shot_hits: Dictionary = {}
var harvest_icon_sequence := 0
var harvest_icon_release_time := 0.0
var harvest_icon_batches: Dictionary = {}
var time := 0.0
var bridge_open := false
var muted := false
var music_paused := false
var finished := false
var cut_audio: AudioStreamPlayer
var throw_audio: AudioStreamPlayer
var inventory_audio: AudioStreamPlayer
var background_music: AudioStreamPlayer
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
			harvest = {"w":16,"c":16,"t":16}
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
	var wheat_mesh := "Wheat" in file
	if wheat_mesh:
		n.material_override = material(Color("d7b354"))
	var bounds := n.mesh.get_aabb()
	var factor := target_size / maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
	n.scale = Vector3.ONE * factor
	if wheat_mesh: n.rotation.y = -PI/2
	parent.add_child(n)
	n.position = pos - n.basis*Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
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
	inventory_audio = AudioStreamPlayer.new()
	inventory_audio.stream = load("res://Sounds/crop_landing_into_inventory.wav")
	inventory_audio.volume_db = -12
	add_child(inventory_audio)
	background_music = AudioStreamPlayer.new()
	background_music.stream = load("res://Sounds/Music/f_sonata.mp3")
	background_music.volume_db = MUSIC_GAMEPLAY_VOLUME_DB
	background_music.finished.connect(background_music.play)
	add_child(background_music)
	background_music.play()

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
	model.scale = Vector3.ONE*SCYTHE_MODEL_SCALE
	model.rotation_degrees = Vector3(0,0,90)
	# After the visual rotation, the lower handle end lies along local +X.
	# Offset the held mesh so its handle, rather than its imported center, is the pivot.
	if pivot_at_handle:
		model.position.x = -0.20
	var scythe_material := load("res://Materials/Atlas1.tres") as StandardMaterial3D
	if model is MeshInstance3D:
		(model as MeshInstance3D).material_override = scythe_material
	for child in model.find_children("*", "MeshInstance3D",true,false):
		child.material_override = scythe_material
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
	floating_ruin("res://Meshes/Jefferson/RockTitanium3.tres",Vector3(-3.8,-3.6,-10.6),0.50,Vector3(34,-48,-22),Vector3(0.07,-0.08,0.09),Vector3(0.30,0.14,-0.18),3.3)
	floating_ruin("res://Meshes/Jefferson/RockPlain2.tres",Vector3(5.5,-3.8,-10.2),0.42,Vector3(-62,21,44),Vector3(-0.10,0.05,-0.04),Vector3(-0.16,0.29,0.24),4.9)
	# Lower, farther pieces keep the void around the near edge from feeling empty.
	floating_ruin("res://Meshes/Kevin/ConcreteBuilding1.tres",Vector3(-10.8,-5.0,-3.4),1.08,Vector3(48,-37,29),Vector3(0.06,0.09,-0.05),Vector3(0.31,0.22,0.18),0.6)
	floating_ruin("res://Meshes/Kevin/BrickBuilding1.tres",Vector3(-6.8,-6.0,-3.0),0.84,Vector3(-33,26,51),Vector3(-0.08,0.04,0.10),Vector3(-0.26,0.30,-0.16),1.9)
	floating_ruin("res://Meshes/Kevin/ConcretePillar2.tres",Vector3(-9.8,-5.7,-0.3),0.62,Vector3(71,12,-39),Vector3(0.10,-0.07,0.06),Vector3(0.22,-0.18,0.29),2.7)
	floating_ruin("res://Meshes/Jefferson/Debris2.tres",Vector3(-5.1,-6.5,-6.5),0.72,Vector3(24,58,-36),Vector3(-0.06,0.11,-0.08),Vector3(-0.34,0.24,0.20),3.6)
	floating_ruin("res://Meshes/Jefferson/ConcreteDebris.tres",Vector3(-11.8,-5.8,1.8),0.56,Vector3(-47,19,63),Vector3(0.09,0.05,0.07),Vector3(0.17,0.27,-0.25),4.4)
	floating_ruin("res://Meshes/Jefferson/RockTitanium3.tres",Vector3(-7.2,-5.5,2.4),0.48,Vector3(39,-52,18),Vector3(-0.07,0.08,-0.09),Vector3(-0.21,0.16,0.33),5.2)
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
	titanium_icon = crop_icon("titanium",Vector2(1110,90),Vector2(48,52),hud)
	titanium_total = label_at("0",Vector2(1174,98),26,GOLD,hud)
	titanium_icon.visible = false
	titanium_total.visible = false

	first_level_instructions = Control.new()
	first_level_instructions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(first_level_instructions)
	instruction_label("Left click a tile to move",Vector2(32,32))
	instruction_label("Hold & release right click to throw",Vector2(32,66))

func instruction_label(text: String, pos: Vector2) -> Label:
	var instruction := label_at(text,pos,18,WHITE,first_level_instructions)
	if instruction_font:
		instruction.add_theme_font_override("font",instruction_font)
	return instruction

func crop_icon(crop: String, pos: Vector2, dimensions: Vector2, parent: Node) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load("res://assets/icons/"+crop+".png")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = pos
	icon.size = dimensions
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.self_modulate = Color.WHITE
	var icon_material := CanvasItemMaterial.new()
	icon_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	icon.material = icon_material
	parent.add_child(icon)
	return icon

func crop_icon_world_position(c: Vector2i) -> Vector2:
	return view_container.get_global_transform() * camera.unproject_position(grid_pos(c)+Vector3(0,1.35,0))

func queue_harvest_icon(c: Vector2i, resource: String) -> void:
	harvest_icon_sequence += 1
	var key := str(harvest_icon_sequence)
	var crop_name: String = RESOURCE_ICON_NAMES[resource]
	var icon := crop_icon(crop_name,Vector2.ZERO,HARVEST_ICON_SIZE,ui)
	icon.position = crop_icon_world_position(c)-icon.size*0.5
	icon.pivot_offset = icon.size*0.5
	var start_delay := 0.14
	if time < harvest_icon_release_time:
		start_delay = harvest_icon_release_time-time
	harvest_icon_release_time = time+start_delay+0.06
	harvest_icon_batches[key] = {"resource":resource,"icon":icon,"start_delay":start_delay}
	animate_harvest_icon(key)

func animate_harvest_icon(key: String) -> void:
	if not harvest_icon_batches.has(key): return
	var flight: Dictionary = harvest_icon_batches[key]
	await get_tree().create_timer(flight.start_delay).timeout
	if not harvest_icon_batches.has(key): return
	flight = harvest_icon_batches[key]
	var icon := flight.icon as TextureRect
	if not is_instance_valid(icon):
		harvest_icon_batches.erase(key)
		return
	var target: Vector2 = HUD_INVENTORY_TARGETS[flight.resource]
	var flight_duration := clampf(icon.position.distance_to(target)/1100.0,0.28,0.58)
	var flight_tween := create_tween().set_parallel(true)
	flight_tween.tween_property(icon,"position",target-icon.size*0.5,flight_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flight_tween.tween_property(icon,"scale",Vector2.ONE*0.42,flight_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await flight_tween.finished
	if not harvest_icon_batches.has(key): return
	if is_instance_valid(icon): icon.queue_free()
	harvest_icon_batches.erase(key)
	displayed_harvest[flight.resource] += 1
	refresh_inventory_totals()
	if not muted:
		play_inventory_sound()

func clear_harvest_icon_batches() -> void:
	for flight in harvest_icon_batches.values():
		var icon := flight.icon as TextureRect
		if is_instance_valid(icon): icon.queue_free()
	harvest_icon_batches.clear()
	harvest_icon_release_time = time

func play_inventory_sound() -> void:
	var sound := AudioStreamPlayer.new()
	sound.stream = inventory_audio.stream
	sound.volume_db = inventory_audio.volume_db
	add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()

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

func shop_button(
	asset_name: String,
	pos: Vector2,
	cost: int,
	sold_out: bool,
	callback: Callable,
	parent: Control,
	title_override: String = ""
) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = load(SHOP_BUTTON_PATH+asset_name+".webp")
	b.texture_hover = load(SHOP_BUTTON_PATH+asset_name+"Click.webp")
	b.texture_pressed = load(SHOP_BUTTON_PATH+asset_name+"Click.webp")
	b.texture_disabled = load(SHOP_BUTTON_PATH+asset_name+"Sold.webp")
	b.position = pos
	b.size = SHOP_BUTTON_SIZE
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.disabled = sold_out
	b.pressed.connect(callback)
	parent.add_child(b)
	if not sold_out:
		var price := label_at(str(cost),pos+Vector2(265,36),20,WHITE,parent)
		price.size = Vector2(42,32)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.add_theme_color_override("font_outline_color",Color("172025"))
		price.add_theme_constant_override("outline_size",4)
		if instruction_font:
			price.add_theme_font_override("font",instruction_font)
	if not title_override.is_empty():
		var title_backing := ColorRect.new()
		title_backing.color = Color("202427")
		title_backing.position = pos+Vector2(11,21)
		title_backing.size = Vector2(226,65)
		title_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(title_backing)
		var title := label_at(title_override,pos+Vector2(18,35),27,WHITE,parent)
		title.add_theme_color_override("font_outline_color",Color("0a0b0c"))
		title.add_theme_constant_override("outline_size",5)
		if instruction_font:
			title.add_theme_font_override("font",instruction_font)
	return b

func shop_close_button(parent: Control) -> TextureButton:
	var close := TextureButton.new()
	close.texture_normal = load(SHOP_BUTTON_PATH+"ExitButton.webp")
	close.texture_hover = load(SHOP_BUTTON_PATH+"ExitButtonClicked.webp")
	close.texture_pressed = load(SHOP_BUTTON_PATH+"ExitButtonClicked.webp")
	close.position = Vector2(821,12)
	close.size = Vector2(128,128)
	close.ignore_texture_size = true
	close.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close.pressed.connect(dismiss_shop)
	parent.add_child(close)
	return close

func show_title() -> void:
	cancel_charge()
	cancel_hop()
	path.clear()
	title_active = true
	update_music_volume()
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
	var menu_button_size := Vector2(350,108)
	var start_row := CenterContainer.new()
	title_menu.add_child(start_row)
	start_row.position = Vector2(0,432)
	start_row.size = Vector2(1280,108)
	var start_button := menu_button("res://Imported/PNG/Jefferson/Menu-Start.webp","res://Imported/PNG/Jefferson/Menu-StartHover.webp","res://Imported/PNG/Jefferson/Menu-StartClick.webp",Vector2.ZERO,menu_button_size,begin_game,start_row)
	start_button.custom_minimum_size = menu_button_size
	var exit_row := CenterContainer.new()
	title_menu.add_child(exit_row)
	exit_row.position = Vector2(0,552)
	exit_row.size = Vector2(1280,108)
	var exit_button := menu_button("res://Imported/PNG/Jefferson/Menu-Exit.webp","res://Imported/PNG/Jefferson/Menu-ExitHover.webp","res://Imported/PNG/Jefferson/Menu-ExitClick.webp",Vector2.ZERO,menu_button_size,quit_game,exit_row)
	exit_button.custom_minimum_size = menu_button_size

func begin_game() -> void:
	title_active = false
	update_music_volume()
	hud.visible = true
	if is_instance_valid(title_menu):
		title_menu.queue_free()
		title_menu = null

func quit_game() -> void:
	get_tree().quit()

func update_music_volume() -> void:
	if is_instance_valid(background_music):
		background_music.volume_db = MUSIC_MENU_VOLUME_DB if title_active else MUSIC_GAMEPLAY_VOLUME_DB

func grid_pos(c: Vector2i) -> Vector3:
	return Vector3(c.x-5,0,c.y-4)

func nearest_cell(pos: Vector3) -> Vector2i:
	return Vector2i(clampi(roundi(pos.x)+5,0,W-1),clampi(roundi(pos.z)+4,0,H-1))

func is_shop() -> bool:
	return shop_tiles.has(cell)

func has_shop() -> bool:
	return not shop_tiles.is_empty()

func shop_number() -> int:
	return current_shop_number

func update_shop_number() -> void:
	current_shop_number = 0
	for index in range(stage+1):
		var level := LEVELS[index].instantiate() as LevelScene
		if level.shop: current_shop_number += 1
		level.free()

func can_afford_any_upgrade() -> bool:
	match shop_number():
		1:
			return (rock_break_level < 1 and harvest.c >= 8) or (reach_level < 1 and harvest.w >= 10)
		2:
			return (rock_break_level < 2 and harvest.c >= 16) or (reach_level < 2 and harvest.w >= 20)
		3:
			return not jump_unlocked and harvest.t >= 50
	return false

func make_shop_marker(c: Vector2i) -> void:
	var overlay := MeshInstance3D.new()
	overlay.name = "ShopOverlay"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(0.84,0.84)
	overlay.mesh = mesh
	var overlay_material := material(MINT,0.0)
	overlay_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay_material.render_priority = 1
	overlay.material_override = overlay_material
	overlay.position = grid_pos(c)+Vector3(0,0.025,0)
	board.add_child(overlay)
	shop_marker_materials[c] = overlay_material

func update_shop_markers() -> void:
	var affordable := can_afford_any_upgrade()
	var pulse := 0.5 + 0.5 * sin(time*4.0)
	for marker_material in shop_marker_materials.values():
		var m := marker_material as StandardMaterial3D
		var overlay_color := MINT
		overlay_color.a = pulse if affordable else 0.0
		m.albedo_color = overlay_color

func close_shop() -> void:
	if is_instance_valid(shop_panel):
		shop_panel.free()
		shop_panel = null

func dismiss_shop() -> void:
	shop_closed_for_visit = true
	close_shop()

func save_stage() -> void:
	states[stage] = {"crops":crops.duplicate(true),"bridge":bridge_open,"rocks":rocks.duplicate(true)}

func load_stage(index: int, from_right: bool = false) -> void:
	cancel_charge()
	cancel_hop()
	clear_harvest_icon_batches()
	stage = index
	for n in board.get_children():
		n.free()
	crops.clear()
	tiles.clear()
	rocks.clear()
	rock_nodes.clear()
	collected_titanium_rocks.clear()
	scenery_blockers.clear()
	tile_nodes.clear()
	crop_nodes.clear()
	shop_tiles.clear()
	shop_marker_materials.clear()
	shop_closed_for_visit = false
	path.clear()
	shot_active = false
	scythe.visible = false
	held.visible = true
	throw_audio.stop()
	bridge_open = false
	close_shop()
	current_level = LEVELS[stage].instantiate()
	update_shop_number()
	board.add_child(current_level)
	for z in H:
		for x in W:
			var c := Vector2i(x,z)
			var kind: String = current_level.tile_kind_at(c)
			if kind == "~" or kind == "b": continue
			tiles[c] = kind
			tile_nodes[c] = floor_tile(c,kind)
			box(board,grid_pos(c)-Vector3(0,0.44,0),Vector3(0.85,0.18,0.85),Color("213943"))
			if kind in ["#", "t"]:
				rocks[c] = "titanium" if kind == "t" else "normal"
				rock_nodes[c] = asset(board,"res://Meshes/Jefferson/RockTitanium3.tres" if kind == "t" else "res://Meshes/Jefferson/RockPlain2.tres",grid_pos(c),0.94)
			if kind.to_lower() in ["w","c"]:
				crops[c] = {"kind":kind,"hp":(2 if kind == "W" else (3 if kind == "C" else 1))}
			if kind == "s":
				box(board,grid_pos(c)+Vector3(0,0.02,0),Vector3(0.65,0.05,0.65),GOLD,0.5)
	if states.has(stage):
		crops = states[stage].crops.duplicate(true)
		if states[stage].has("rocks"):
			var saved_rocks: Dictionary = states[stage].rocks
			for rock_cell in rock_nodes.keys():
				if not saved_rocks.has(rock_cell):
					(rock_nodes[rock_cell] as Node3D).queue_free()
					rock_nodes.erase(rock_cell)
			rocks = saved_rocks.duplicate(true)
		if states[stage].bridge: open_bridge()
	for decoration in current_level.decorations():
		asset(board,decoration.asset,grid_pos(decoration.cell),decoration.size)
		if decoration.blocks: scenery_blockers[decoration.cell] = true
	for shop_cell in current_level.shop_cells():
		shop_tiles[shop_cell] = true
		make_shop_marker(shop_cell)
	for c in crops:
		var crop_kind: String = crops[c].kind
		var file := "WheatFull" if crop_kind.to_lower() == "w" else "Carrot3"
		var n := asset(board,"res://Meshes/Jefferson/"+file+".tres",grid_pos(c),0.81)
		crop_nodes[c] = n
		if crop_kind == crop_kind.to_upper():
			box(n,Vector3(0,0.05,0),Vector3(0.13,0.035,0.13),GOLD,0.3)
	gate = box(board,grid_pos(Vector2i(10,4))+Vector3(0,0.02,0),Vector3(0.83,0.06,0.83),MINT,0.5)
	if stage > 0:
		box(board,grid_pos(Vector2i(0,4))+Vector3(0,0.02,0),Vector3(0.83,0.06,0.83),Color("7e9ba7"),0.25)
	cell = Vector2i(9,4) if from_right else Vector2i(1,4)
	bunny.position = grid_pos(cell)
	bunny_model.rotation = Vector3(0, BUNNY_ROTATION_OFFSET, 0)
	transition_lock = 0.6
	if has_shop() and current_level.shop:
		asset(board,"res://Meshes/Kevin/Greenhouse.tres",Vector3(0,0,-2),3.7)
		for x in range(4,7):
			for z in range(1,4):
				scenery_blockers[Vector2i(x,z)] = true
	first_level_instructions.visible = stage == 0
	update_ui()

func update_ui() -> void:
	displayed_harvest = harvest.duplicate()
	refresh_inventory_totals()
	gate.material_override = material(MINT,0.5)
	update_shop_markers()

func refresh_inventory_totals() -> void:
	wheat_total.text = str(displayed_harvest.w)
	carrot_total.text = str(displayed_harvest.c)
	titanium_total.text = str(displayed_harvest.t)
	var titanium_unlocked := rock_break_level >= 2
	titanium_icon.visible = titanium_unlocked
	titanium_total.visible = titanium_unlocked

func walkable(c: Vector2i) -> bool:
	return tiles.has(c) and not rocks.has(c) and not crops.has(c) and not scenery_blockers.has(c)

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
			elif jump_unlocked and not tiles.has(next):
				var landing: Vector2i = cur+dir*2
				if walkable(landing) and not previous.has(landing):
					previous[landing] = cur
					queue.append(landing)
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
	return lerpf(MIN_THROW_DISTANCE,max_throw_distance(),charge_progress())

func charge_progress() -> float:
	return sqrt(clampf(charge_time/CHARGE_SECONDS,0.0,1.0))

func max_throw_distance() -> float:
	return BASE_THROW_DISTANCE+reach_level

func start_charge(target: Vector3) -> void:
	if shot_active or charging or is_shop() or finished or is_instance_valid(overlay): return
	cancel_hop()
	path.clear()
	cell = nearest_cell(bunny.position)
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

func cancel_hop() -> void:
	hop_active = false
	hop_progress = 0.0
	if is_instance_valid(bunny): bunny.position.y = 0.0

func is_hop_between(from: Vector2i, to: Vector2i) -> bool:
	var delta: Vector2i = to-from
	if absi(delta.x)+absi(delta.y) != 2: return false
	var midpoint: Vector2i = from+Vector2i(signi(delta.x),signi(delta.y))
	return jump_unlocked and not tiles.has(midpoint)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if finished: return
			if is_instance_valid(overlay): close_overlay()
			else: show_title()
			return
		if event.keycode == KEY_M:
			music_paused = not music_paused
			background_music.stream_paused = music_paused
			return
		if title_active: return
		if event.keycode == KEY_6 and stage > 0:
			finished = false
			save_stage()
			load_stage(stage-1,true)
			return
		if event.keycode == KEY_7 and stage < LEVELS.size()-1:
			finished = false
			save_stage()
			load_stage(stage+1)
			return
		if event.keycode == KEY_8:
			harvest = {"w":99,"c":99,"t":99}
			update_ui()
			if is_shop(): show_shop()
			return
		if event.keycode == KEY_R and not is_instance_valid(overlay) and not is_shop(): reset_field()
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
	cancel_hop()
	path.clear()
	bunny.position = grid_pos(cell)
	var direction := target-bunny.position
	direction.y = 0
	if direction.length() < 0.1: return
	shot_limit = max_throw_distance() if distance < 0.0 else clampf(distance,MIN_THROW_DISTANCE,max_throw_distance())
	shot_dir = direction.normalized()
	shot_origin = bunny.position+Vector3(0,0.45,0)
	shot_distance = 0
	shot_speed = SCYTHE_OUTBOUND_MAX_SPEED
	shot_return_start_distance = 0
	shot_return = false
	shot_active = true
	shot_hits.clear()
	scythe.position = shot_origin
	scythe.visible = true
	held.visible = false
	bunny_model.rotation.y = atan2(shot_dir.x,shot_dir.z) + BUNNY_ROTATION_OFFSET
	if not muted:
		throw_audio.pitch_scale = 1.0
		throw_audio.play()

func can_break_rock(c: Vector2i) -> bool:
	if not rocks.has(c): return false
	return rock_break_level >= (2 if rocks[c] == "titanium" else 1)

func break_rock(c: Vector2i) -> void:
	if not can_break_rock(c): return
	var rock_kind: String = rocks[c]
	rocks.erase(c)
	var n := rock_nodes.get(c) as Node3D
	rock_nodes.erase(c)
	if n != null:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(n,"scale",Vector3.ZERO,0.16)
		tween.tween_property(n,"position:y",n.position.y+0.18,0.16)
		tween.chain().tween_callback(n.queue_free)
	if rock_kind == "titanium":
		collected_titanium_rocks[c] = true
		harvest.t += 1
		queue_harvest_icon(c,"t")

func hit_crop(c: Vector2i) -> void:
	if not crops.has(c): return
	crops[c].hp -= 1
	var n: Node3D = crop_nodes[c]
	if crops[c].hp > 0:
		var tween := create_tween()
		tween.tween_property(n,"rotation:z",0.22,0.08)
		tween.tween_property(n,"rotation:z",0.0,0.12)
		return
	var kind: String = crops[c].kind
	harvest[kind.to_lower()] += 1
	total_harvest += 1
	queue_harvest_icon(c,kind.to_lower())
	crops.erase(c)
	crop_nodes.erase(c)
	var remnant_file := "WheatChopped" if kind.to_lower() == "w" else "CarrotDugOut3"
	asset(board,"res://Meshes/Jefferson/"+remnant_file+".tres",grid_pos(c),0.81)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(n,"position:y",n.position.y+0.5,0.2)
	tween.tween_property(n,"scale",Vector3.ZERO,0.25)
	tween.chain().tween_callback(n.queue_free)
	if not muted:
		cut_audio.pitch_scale = randf_range(0.9,1.2)
		cut_audio.play()
	if crops.is_empty():
		save_stage()

func _process(dt: float) -> void:
	time += dt
	update_background_ruins(dt)
	update_shop_markers()
	if title_active: return
	if is_instance_valid(overlay): return
	transition_lock = maxf(0,transition_lock-dt)
	if charging:
		charge_time = minf(CHARGE_SECONDS,charge_time+dt)
		held.rotation.y = PI*0.5*charge_progress()
	if not path.is_empty():
		var next_cell: Vector2i = path[0]
		var target := grid_pos(next_cell)
		var delta := target-bunny.position
		bunny_model.rotation.y = lerp_angle(bunny_model.rotation.y,atan2(delta.x,delta.z) + BUNNY_ROTATION_OFFSET,dt*14)
		if is_hop_between(cell,next_cell):
			if not hop_active:
				hop_active = true
				hop_progress = 0.0
				hop_start = bunny.position
				hop_start.y = 0.0
				hop_target = target
			hop_progress = minf(1.0,hop_progress+dt/JUMP_DURATION)
			bunny.position = hop_start.lerp(hop_target,hop_progress)
			bunny.position.y += sin(hop_progress*PI)*0.62
			bunny_model.position.y = sin(hop_progress*PI)*0.08
			bunny_model.rotation.z = -sin(hop_progress*PI)*0.14
			if hop_progress >= 1.0:
				bunny.position = hop_target
				hop_active = false
				cell = path.pop_front()
				if tiles.get(cell,"") == "s": open_bridge()
		else:
			hop_active = false
			bunny.position = bunny.position.move_toward(target,dt*4.5)
			bunny_model.position.y = absf(sin(time*17))*0.11
			bunny_model.rotation.z = sin(time*17)*0.045
			if bunny.position.distance_to(target)<0.015:
				cell = path.pop_front()
				if tiles.get(cell,"") == "s": open_bridge()
	else:
		if hop_active: cancel_hop()
		bunny_model.position.y = sin(time*2)*0.018
		bunny_model.rotation.z = 0
		if not shot_active and not charging:
			var mouse_target = mouse_world()
			if mouse_target != null:
				var look_direction: Vector3 = mouse_target-bunny.position
				look_direction.y = 0
				if look_direction.length_squared() > 0.01:
					bunny_model.rotation.y = lerp_angle(bunny_model.rotation.y,atan2(look_direction.x,look_direction.z) + BUNNY_ROTATION_OFFSET,dt*14)
	if is_shop():
		if not shop_closed_for_visit and not is_instance_valid(shop_panel): show_shop()
	else:
		shop_closed_for_visit = false
		if is_instance_valid(shop_panel): close_shop()
	if transition_lock == 0 and path.is_empty() and not shot_active and not charging:
		if cell == Vector2i(10,4):
			next_stage()
		elif cell == Vector2i(0,4) and stage > 0:
			save_stage()
			load_stage(stage-1,true)
	if shot_active: update_shot(dt)
	update_aim()

func update_shot(dt: float) -> void:
	if shot_return:
		var return_target := bunny.position+Vector3(0,0.45,0)
		var distance_left := scythe.position.distance_to(return_target)
		var return_progress := 1.0-distance_left/maxf(shot_return_start_distance,0.001)
		shot_speed = lerpf(SCYTHE_OUTBOUND_MIN_SPEED,SCYTHE_RETURN_MAX_SPEED,clampf(return_progress,0.0,1.0))
		var return_pitch_progress := inverse_lerp(SCYTHE_OUTBOUND_MIN_SPEED,SCYTHE_RETURN_MAX_SPEED,shot_speed)
		throw_audio.pitch_scale = lerpf(0.72,1.28,return_pitch_progress)
		scythe.rotation.y += dt*(8.0+shot_speed*1.35)
		scythe.position = scythe.position.move_toward(return_target,dt*shot_speed)
		if scythe.position.distance_to(return_target)<0.1:
			shot_active = false
			scythe.visible = false
			held.visible = true
			throw_audio.stop()
		return
	# Short substeps prevent a fast blade skipping a crop or a rock.
	var outbound_progress := shot_distance/maxf(shot_limit,0.001)
	shot_speed = lerpf(SCYTHE_OUTBOUND_MAX_SPEED,SCYTHE_OUTBOUND_MIN_SPEED,outbound_progress)
	var distance := minf(dt*shot_speed,shot_limit-shot_distance)
	var steps := maxi(1,ceili(distance/0.1))
	for i in steps:
		shot_distance += distance/steps
		scythe.position = shot_origin+shot_dir*shot_distance
		var c := Vector2i(roundi(scythe.position.x)+5,roundi(scythe.position.z)+4)
		if rocks.has(c):
			if can_break_rock(c):
				break_rock(c)
			else:
				shot_return = true
				shot_return_start_distance = scythe.position.distance_to(bunny.position+Vector3(0,0.45,0))
				break
		hit_crops_in_scythe_hitbox()
	if shot_distance >= shot_limit-0.001:
		shot_return = true
		shot_return_start_distance = scythe.position.distance_to(bunny.position+Vector3(0,0.45,0))
	var pitch_progress := inverse_lerp(SCYTHE_OUTBOUND_MIN_SPEED,SCYTHE_RETURN_MAX_SPEED,shot_speed)
	throw_audio.pitch_scale = lerpf(0.72,1.28,pitch_progress)
	scythe.rotation.y += dt*(8.0+shot_speed*1.35)

func scythe_hitbox() -> AABB:
	var has_bounds := false
	var bounds := AABB()
	for child in scythe.find_children("*", "MeshInstance3D",true,false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null: continue
		var mesh_bounds := mesh_instance.global_transform*mesh_instance.get_aabb()
		bounds = mesh_bounds if not has_bounds else bounds.merge(mesh_bounds)
		has_bounds = true
	bounds.position.y -= SCYTHE_HITBOX_VERTICAL_PADDING
	bounds.size.y += SCYTHE_HITBOX_VERTICAL_PADDING*2.0
	return bounds

func hit_crops_in_scythe_hitbox() -> void:
	var blade_bounds := scythe_hitbox()
	for crop_cell in crops.keys():
		if shot_hits.has(crop_cell): continue
		var crop_mesh := crop_nodes[crop_cell] as MeshInstance3D
		if crop_mesh != null and blade_bounds.intersects(crop_mesh.global_transform*crop_mesh.get_aabb()):
			shot_hits[crop_cell] = true
			hit_crop(crop_cell)

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
			var hover_color: Color = MINT if walkable(c) else GOLD
			hover_color.a = 0.5
			var hover_material := hover.material_override as StandardMaterial3D
			hover_material.albedo_color = hover_color
	if not charging or shot_active: return
	var direction := charge_target-bunny.position
	direction.y = 0
	if direction.length_squared()<0.01: return
	direction = direction.normalized()
	bunny_model.rotation.y = atan2(direction.x,direction.z) + BUNNY_ROTATION_OFFSET
	var distance := charged_distance()
	for i in aim_markers.size():
		var offset := float(i+1)*max_throw_distance()/aim_markers.size()
		if offset>distance: break
		var p := bunny.position + direction*offset
		var tc := Vector2i(roundi(p.x)+5,roundi(p.z)+4)
		if rocks.has(tc) and not can_break_rock(tc): break
		aim_markers[i].position = p+Vector3(0,0.15,0)
		aim_markers[i].visible = true

func open_bridge() -> void:
	if bridge_open: return
	bridge_open = true
	for c in current_level.cells_in(4):
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
	for c in current_level.crop_cells():
		var kind: String = current_level.crop_kind_at(c)
		if not crops.has(c):
			harvest[kind.to_lower()] -= 1
			total_harvest -= 1
	for c in collected_titanium_rocks:
		harvest.t -= 1
	load_stage(stage)

func show_shop() -> void:
	if not is_shop(): return
	if is_instance_valid(shop_panel): shop_panel.free()
	shop_panel = Control.new()
	shop_panel.position = Vector2(158,72)
	shop_panel.size = Vector2(963,656)
	ui.add_child(shop_panel)
	var base := menu_image(SHOP_BASE,Vector2.ZERO,shop_panel.size,shop_panel)
	base.stretch_mode = TextureRect.STRETCH_SCALE
	var content := Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	shop_panel.add_child(content)
	shop_close_button(content)
	match shop_number():
		1:
			shop_button("BreakTitanium",Vector2(520,184),8,rock_break_level >= 1 or harvest.c < 8,func(): buy_break_upgrade(1),content)
			shop_button("ScytheReach",Vector2(520,364),10,reach_level >= 1 or harvest.w < 10,func(): buy_reach_upgrade(1),content)
		2:
			shop_button("BreakTitanium",Vector2(520,184),16,rock_break_level >= 2 or harvest.c < 16,func(): buy_break_upgrade(2),content)
			shop_button("ScytheReach",Vector2(520,364),20,reach_level >= 2 or harvest.w < 20,func(): buy_reach_upgrade(2),content)
		3:
			shop_button("Jump",Vector2(520,274),50,jump_unlocked or harvest.t < 50,buy_jump_upgrade,content)

func buy_break_upgrade(level: int) -> void:
	var cost := 8*level
	if level != rock_break_level+1 or harvest.c < cost: return
	harvest.c -= cost
	rock_break_level = level
	update_ui()
	show_shop()

func buy_reach_upgrade(level: int) -> void:
	var cost := 10*level
	if level != reach_level+1 or harvest.w < cost: return
	harvest.w -= cost
	reach_level = level
	update_ui()
	show_shop()

func buy_jump_upgrade() -> void:
	if jump_unlocked or harvest.t < 50: return
	harvest.t -= 50
	jump_unlocked = true
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
	var content := modal("A universe in bloom.","Every field harvested. Every little root brought home.\n\nYou gathered %d crops across six space gardens.\nYour scythe: break %d / 2 · reach +%d · jump %s.\n\nThanks for tending this corner of the universe." % [total_harvest,rock_break_level,reach_level,"online" if jump_unlocked else "offline"])
	button("Plant a new beginning",Vector2(30,282),Vector2(490,40),restart,content)

func restart() -> void:
	close_overlay()
	states.clear()
	harvest = {"w":0,"c":0,"t":0}
	rock_break_level = 0
	reach_level = 0
	jump_unlocked = false
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
	buy_break_upgrade(1)
	buy_reach_upgrade(1)
	buy_jump_upgrade()
	assert(rock_break_level == 0 and reach_level == 0 and not jump_unlocked and harvest.w == 0 and harvest.c == 0,"Unaffordable purchases preserve inventory")
	for index in LEVELS.size():
		load_stage(index)
		if has_shop():
			cell = shop_tiles.keys()[0]
			bunny.position = grid_pos(cell)
			show_shop()
			assert(is_instance_valid(shop_panel),"Shop opens only after reaching a shop tile")
			harvest = {"w":1000,"c":1000,"t":1000}
			var before := rock_break_level
			if rock_break_level < 2:
				buy_break_upgrade(rock_break_level+1)
				assert(rock_break_level == before+1,"Rock-breaking purchase")
			if reach_level < 2:
				buy_reach_upgrade(reach_level+1)
			if shop_number() == 3 and not jump_unlocked:
				buy_jump_upgrade()
			continue
		if index in [4,17]:
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
