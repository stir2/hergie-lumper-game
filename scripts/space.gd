extends SubViewportContainer

const RENDER_SCALE := 2.0
const DRIFT_DEGREES_PER_SECOND := 0.5
const PITCH_DEGREES_PER_SECOND := 0.22
var sky_camera: Camera3D

# Render the panorama as a sky behind the transparent orthographic game view.
# This keeps the sky continuous behind the HUD and across the whole window.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	scale = Vector2.ONE / RENDER_SCALE
	size = get_viewport_rect().size * RENDER_SCALE
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
	sky_camera = Camera3D.new()
	sky_camera.fov = 100.0
	sky_camera.rotation_degrees.y = 65.0
	sky_view.add_child(sky_camera)
	get_viewport().size_changed.connect(func(): size = get_viewport_rect().size * RENDER_SCALE)

func _process(delta: float) -> void:
	sky_camera.rotation.y = wrapf(sky_camera.rotation.y + deg_to_rad(DRIFT_DEGREES_PER_SECOND) * delta, 0.0, TAU)
	sky_camera.rotation.x = wrapf(sky_camera.rotation.x + deg_to_rad(PITCH_DEGREES_PER_SECOND) * delta, 0.0, TAU)
