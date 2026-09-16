class_name RtsCamera
extends Node3D

@export var map_half_extents := Vector2(60.0, 40.0)
@export var pinch_zoom_speed := 0.065
@export var mouse_pan_speed := 0.08
@export var edge_pan_speed := 30.0
@export var keyboard_pan_speed := 34.0
@export var edge_pan_margin := 28.0
@export var enable_desktop_test_controls := true
@export var min_zoom := 18.0
@export var max_zoom := 48.0
@export var zoom_step := 2.5

@onready var camera: Camera3D = $Camera3D

var _touch_points: Dictionary = {}
var _last_pinch_distance := 0.0
var _last_pinch_center := Vector2.ZERO
var _single_touch_anchor_world := Vector3.ZERO
var _single_touch_has_anchor := false
var _pinch_anchor_world := Vector3.ZERO
var _pinch_has_anchor := false
var _middle_mouse_panning := false

func _ready() -> void:
	rotation_degrees = Vector3(-58.0, 0.0, 0.0)
	position = Vector3(-28.0, 0.0, 18.0)
	camera.position = Vector3(0.0, 0.0, 34.0)
	_clamp_to_map()

func _process(delta: float) -> void:
	if not enable_desktop_test_controls:
		return
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
	elif enable_desktop_test_controls and event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif enable_desktop_test_controls and event is InputEventMouseMotion and _middle_mouse_panning:
		_pan_by_pixels(event.relative, mouse_pan_speed)

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touch_points[event.index] = event.position
		if _touch_points.size() == 1:
			var anchor: Variant = _screen_to_ground(event.position)
			_single_touch_has_anchor = anchor != null
			if _single_touch_has_anchor:
				_single_touch_anchor_world = anchor as Vector3
			_pinch_has_anchor = false
		elif _touch_points.size() == 2:
			_prepare_pinch_anchor()
	else:
		_touch_points.erase(event.index)
		_last_pinch_distance = 0.0
		_last_pinch_center = Vector2.ZERO
		_single_touch_has_anchor = false
		_pinch_has_anchor = false
		if _touch_points.size() == 1:
			var remaining_points: Array = _touch_points.values()
			var anchor: Variant = _screen_to_ground(remaining_points[0])
			_single_touch_has_anchor = anchor != null
			if _single_touch_has_anchor:
				_single_touch_anchor_world = anchor as Vector3

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	_touch_points[event.index] = event.position

	if _touch_points.size() == 1:
		if not _single_touch_has_anchor:
			var anchor: Variant = _screen_to_ground(event.position)
			_single_touch_has_anchor = anchor != null
			if _single_touch_has_anchor:
				_single_touch_anchor_world = anchor as Vector3
		if not _single_touch_has_anchor:
			return
		_pan_to_keep_screen_anchor(event.position, _single_touch_anchor_world)
	elif _touch_points.size() == 2:
		var points: Array = _touch_points.values()
		var first_point: Vector2 = points[0]
		var second_point: Vector2 = points[1]
		var current_distance: float = first_point.distance_to(second_point)
		var current_center: Vector2 = (first_point + second_point) * 0.5
		if not _pinch_has_anchor:
			var anchor: Variant = _screen_to_ground(current_center)
			_pinch_has_anchor = anchor != null
			if _pinch_has_anchor:
				_pinch_anchor_world = anchor as Vector3
		if _last_pinch_distance > 0.0:
			_zoom_by((_last_pinch_distance - current_distance) * pinch_zoom_speed)
		if _pinch_has_anchor:
			_pan_to_keep_screen_anchor(current_center, _pinch_anchor_world)
		_last_pinch_distance = current_distance
		_last_pinch_center = current_center

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

func _pan_to_keep_screen_anchor(screen_position: Vector2, anchor_world: Vector3) -> void:
	var current_world: Variant = _screen_to_ground(screen_position)
	if current_world == null:
		return
	var delta := anchor_world - (current_world as Vector3)
	position.x += delta.x
	position.z += delta.z
	_clamp_to_map()

func _prepare_pinch_anchor() -> void:
	var points: Array = _touch_points.values()
	if points.size() < 2:
		return
	_last_pinch_distance = (points[0] as Vector2).distance_to(points[1] as Vector2)
	_last_pinch_center = ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5
	var anchor: Variant = _screen_to_ground(_last_pinch_center)
	_pinch_has_anchor = anchor != null
	if _pinch_has_anchor:
		_pinch_anchor_world = anchor as Vector3

func _screen_to_ground(screen_position: Vector2) -> Variant:
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	if absf(ray_direction.y) <= 0.001:
		return null
	var distance := -ray_origin.y / ray_direction.y
	if distance < 0.0:
		return null
	var hit := ray_origin + ray_direction * distance
	return Vector3(hit.x, 0.0, hit.z)

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
