extends Node
var game: Node
var failed := false

func _ready() -> void:
	game = get_parent()
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("FAIL: "+message)
	else:
		print("PASS: "+message)

func click(point: Vector2, mouse_button: int) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = mouse_button
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)

func click_tile(c: Vector2i, mouse_button: int = MOUSE_BUTTON_LEFT) -> void:
	var point: Vector2 = game.camera.unproject_position(game.grid_pos(c)) + game.view_container.position
	await click(point,mouse_button)

func clear_crops() -> void:
	for c in game.crops.keys():
		while game.crops.has(c): game.hit_crop(c)

func screenshot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://"+file)

func run() -> void:
	await get_tree().create_timer(0.6).timeout
	await click_tile(Vector2i(4,4))
	await get_tree().create_timer(1.0).timeout
	check(game.cell == Vector2i(4,4),"Left mouse input moves bunny to selected tile")
	await click_tile(Vector2i(3,2),MOUSE_BUTTON_RIGHT)
	await get_tree().create_timer(1.2).timeout
	check(game.crops.size()<16 and not game.shot_active,"Right mouse input harvests and returns scythe")
	check(game.harvest.w == 16-game.crops.size() and game.harvest.c == 0,"Wheat harvest updates its separate inventory count")
	await click_tile(Vector2i(10,4))
	await get_tree().create_timer(1.6).timeout
	check(game.stage == 0,"Unharvested field blocks exit")
	clear_crops()
	# Step away and back onto the gate.
	await click_tile(Vector2i(9,4))
	await get_tree().create_timer(0.4).timeout
	await click_tile(Vector2i(10,4))
	await get_tree().create_timer(0.6).timeout
	check(game.stage == 1,"Walking onto cleared field edge changes screen")
	await click_tile(Vector2i(0,4))
	await get_tree().create_timer(0.8).timeout
	check(game.stage == 0 and game.crops.is_empty(),"West edge returns to persisted field")
	game.harvest = {"w":16,"c":16}
	game.load_stage(2)
	await get_tree().create_timer(0.3).timeout
	await screenshot("screenshot-greenhouse.png")
	await click(Vector2(550,627),MOUSE_BUTTON_LEFT)
	await get_tree().create_timer(0.2).timeout
	check(game.power == 2 and game.harvest.c == 8 and game.harvest.w == 16,"Power upgrade spends only carrots")
	await click(Vector2(900,627),MOUSE_BUTTON_LEFT)
	await get_tree().create_timer(0.2).timeout
	check(game.reach == 4 and game.harvest.w == 6 and game.harvest.c == 8,"Range upgrade spends only wheat")
	await click_tile(Vector2i(10,4))
	await get_tree().create_timer(2.5).timeout
	check(game.stage == 3,"Greenhouse gate remains clickable below shop UI")
	game.load_stage(7)
	await get_tree().create_timer(0.3).timeout
	await click_tile(Vector2i(2,4))
	await get_tree().create_timer(0.7).timeout
	check(game.bridge_open,"Walking onto switch opens bridge")
	await screenshot("screenshot-final-field.png")
	clear_crops()
	await click_tile(Vector2i(10,4))
	await get_tree().create_timer(2.5).timeout
	check(game.finished and is_instance_valid(game.overlay),"Final exit shows completion screen")
	game.restart()
	check(game.stage == 0 and game.harvest.w == 0 and game.harvest.c == 0 and game.power == 1 and game.reach == 3,"Replay resets run")
	await screenshot("screenshot.png")
	print("INPUT INTEGRATION "+("FAILED" if failed else "PASSED"))
	get_tree().quit(1 if failed else 0)
