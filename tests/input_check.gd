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

func mouse_button(point: Vector2, button_index: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = get_viewport().get_final_transform() * point
	event.global_position = event.position
	event.button_index = button_index
	event.pressed = pressed
	Input.parse_input_event(event)

func click(point: Vector2, button_index: int) -> void:
	mouse_button(point,button_index,true)
	await get_tree().process_frame
	mouse_button(point,button_index,false)

func tile_screen(c: Vector2i) -> Vector2:
	return game.view_container.get_global_transform() * game.camera.unproject_position(game.grid_pos(c))

func click_tile(c: Vector2i, button_index: int = MOUSE_BUTTON_LEFT) -> void:
	await click(tile_screen(c),button_index)

func visible_dots() -> int:
	var count := 0
	for dot in game.aim_markers:
		if dot.visible: count += 1
	return count

func clear_crops() -> void:
	for c in game.crops.keys():
		while game.crops.has(c): game.hit_crop(c)

func screenshot(file: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png("res://"+file)

func run() -> void:
	await get_tree().create_timer(0.6).timeout
	await click_tile(Vector2i(4,4))
	await get_tree().create_timer(1.0).timeout
	check(game.cell == Vector2i(4,4),"Left mouse input moves bunny to selected tile")
	check(visible_dots() == 0,"Charge line is hidden while idle")
	var target := tile_screen(Vector2i(3,2))
	mouse_button(target,MOUSE_BUTTON_RIGHT,true)
	await get_tree().create_timer(0.25).timeout
	var short_line := visible_dots()
	check(game.charging and not game.shot_active and short_line>0 and game.crops.size()==16,"Holding begins charge without throwing")
	await get_tree().create_timer(0.8).timeout
	check(visible_dots()>short_line and is_equal_approx(game.charged_distance(),float(game.reach)),"Charge line grows to full upgraded range")
	await screenshot("screenshot-charge.png")
	mouse_button(target,MOUSE_BUTTON_RIGHT,false)
	await get_tree().create_timer(0.05).timeout
	check(game.shot_active and not game.charging and visible_dots()==0,"Release throws and hides charge line")
	check(is_equal_approx(game.shot_limit,float(game.reach)),"Full charge sets actual projectile range")
	await get_tree().create_timer(1.2).timeout
	check(game.crops.size()<16 and not game.shot_active,"Charged throw harvests and returns scythe")
	await click_tile(Vector2i(8,4),MOUSE_BUTTON_RIGHT)
	await get_tree().create_timer(0.05).timeout
	check(game.shot_limit<game.reach,"Quick tap gives a shorter throw")
	await get_tree().create_timer(0.8).timeout
	mouse_button(target,MOUSE_BUTTON_RIGHT,true)
	await get_tree().create_timer(0.15).timeout
	mouse_button(Vector2(10,10),MOUSE_BUTTON_RIGHT,false)
	await get_tree().create_timer(0.05).timeout
	check(not game.charging and not game.shot_active and visible_dots()==0,"Release outside view cancels charge")
	mouse_button(target,MOUSE_BUTTON_RIGHT,true)
	await get_tree().create_timer(0.15).timeout
	game.show_pause()
	mouse_button(target,MOUSE_BUTTON_RIGHT,false)
	check(not game.charging and not game.shot_active and visible_dots()==0,"Pausing cancels charge without a stray throw")
	game.close_overlay()
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
