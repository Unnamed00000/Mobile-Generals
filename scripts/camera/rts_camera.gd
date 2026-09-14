class_name RtsCamera
extends Node3D

@export var map_half_extents := Vector2(60.0, 40.0)
@export var pan_speed := 0.035
@export var mouse_pan_speed := 0.08
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
	var zoom_factor := camera.position.z / max_zoom
	var right := global_transform.basis.x
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	position += ((-right * pixel_delta.x) + (-forward * pixel_delta.y)) * speed * max(0.45, zoom_factor)
	_clamp_to_map()

func _zoom_by(amount: float) -> void:
	camera.position.z = clampf(camera.position.z + amount, min_zoom, max_zoom)

func _clamp_to_map() -> void:
	position.x = clampf(position.x, -map_half_extents.x, map_half_extents.x)
	position.z = clampf(position.z, -map_half_extents.y, map_half_extents.y)

