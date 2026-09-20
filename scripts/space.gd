extends SubViewportContainer

# Render the panorama as a sky behind the transparent orthographic game view.
# This keeps the sky continuous behind the HUD and across the whole window.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	size = get_viewport_rect().size
	var sky_view := SubViewport.new()
	sky_view.size = Vector2i(size)
	sky_view.world_3d = World3D.new()
	sky_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sky_view)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_SKY
	environment.environment.sky = load("res://Materials/SpaceSky.tres")
	sky_view.add_child(environment)
	var sky_camera := Camera3D.new()
	sky_camera.fov = 100.0
	sky_camera.rotation_degrees.y = 65.0
	sky_view.add_child(sky_camera)
	get_viewport().size_changed.connect(func(): size = get_viewport_rect().size)
