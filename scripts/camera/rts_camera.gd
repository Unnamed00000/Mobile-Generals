class_name RtsCamera
extends Node3D

@export var map_half_extents := Vector2(60.0, 40.0)
@export var pan_speed := 0.035
@export var mouse_pan_speed := 0.08
@export var edge_pan_speed := 30.0
@export var keyboard_pan_speed := 34.0
@export var edge_pan_margin := 28.0
@export var min_zoom := 18.0
@export var max_zoom := 48.0
@export var zoom_step := 2.5

@onready var camera: Camera3D = $Camera3D

var _touch_points: Dictionary = {}
var _last_pinch_distance := 0.0
var _middle_mouse_panning := false

func _ready() -> void:
	rotation_degrees = Vector3(-58.0, 0.0, 0.0)
	position = Vector3(-28.0, 0.0, 18.0)
	camera.position = Vector3(0.0, 0.0, 34.0)
	_clamp_to_map()

func _process(delta: float) -> void:
	var keyboard_direction: Vector2 = _keyboard_pan_direction()
	var edge_direction: Vector2 = _edge_pan_direction()
	if keyboard_direction.length_squared() > 0.0:
		_pan_by_screen_direction(keyboard_direction.normalized(), keyboard_pan_speed * delta)
	if edge_direction.length_squared() > 0.0:
		_pan_by_screen_direction(edge_direction.normalized(), edge_pan_speed * delta)

func get_camera() -> Camera3D:
	return camera

func set_map_half_extents(value: Vector2) -> void:
	map_half_extents = value
	_clamp_to_map()

func center_on(world_position: Vector3) -> void:
	position.x = world_position.x
	position.z = world_position.z
	_clamp_to_map()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _middle_mouse_panning:
		_pan_by_pixels(event.relative, mouse_pan_speed)

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touch_points[event.index] = event.position
	else:
		_touch_points.erase(event.index)
		_last_pinch_distance = 0.0

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	_touch_points[event.index] = event.position

	if _touch_points.size() == 1:
		_pan_by_pixels(event.relative, pan_speed)
	elif _touch_points.size() == 2:
		var points := _touch_points.values()
		var current_distance: float = points[0].distance_to(points[1])
		if _last_pinch_distance > 0.0:
			_zoom_by((_last_pinch_distance - current_distance) * 0.06)
		_last_pinch_distance = current_distance

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		_middle_mouse_panning = event.pressed
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_by(-zoom_step)
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_by(zoom_step)

func _pan_by_pixels(pixel_delta: Vector2, speed: float) -> void:
	var zoom_factor: float = camera.position.z / max_zoom
	_pan_world((-pixel_delta.x) * speed * maxf(0.45, zoom_factor), (-pixel_delta.y) * speed * maxf(0.45, zoom_factor))

func _pan_by_screen_direction(screen_direction: Vector2, distance: float) -> void:
	_pan_world(screen_direction.x * distance, screen_direction.y * distance)

func _pan_world(right_amount: float, forward_amount: float) -> void:
	var right: Vector3 = global_transform.basis.x
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	position += (right * right_amount) + (forward * forward_amount)
	_clamp_to_map()

func _zoom_by(amount: float) -> void:
	camera.position.z = clampf(camera.position.z + amount, min_zoom, max_zoom)

func _clamp_to_map() -> void:
	position.x = clampf(position.x, -map_half_extents.x, map_half_extents.x)
	position.z = clampf(position.z, -map_half_extents.y, map_half_extents.y)

func _keyboard_pan_direction() -> Vector2:
	var direction: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y -= 1.0
	return direction

func _edge_pan_direction() -> Vector2:
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var viewport_size: Vector2 = viewport_rect.size
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var direction: Vector2 = Vector2.ZERO

	if mouse_position.x <= edge_pan_margin:
		direction.x -= 1.0
	elif mouse_position.x >= viewport_size.x - edge_pan_margin:
		direction.x += 1.0

	if mouse_position.y <= edge_pan_margin:
		direction.y += 1.0
	elif mouse_position.y >= viewport_size.y - edge_pan_margin:
		direction.y -= 1.0

	return direction
