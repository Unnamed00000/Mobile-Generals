class_name MinimapPanel
extends Control

signal map_pressed(world_position: Vector3)

@export var map_size := Vector2(120.0, 80.0)

var _blips: Array[Dictionary] = []
var _camera_center: Vector3 = Vector3.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(240.0, 160.0)

func set_map_size(value: Vector2) -> void:
	map_size = value
	queue_redraw()

func set_blips(blips: Array[Dictionary], camera_center: Vector3) -> void:
	_blips = blips
	_camera_center = camera_center
	queue_redraw()

func _draw() -> void:
	var panel_rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(panel_rect, Color(0.035, 0.052, 0.058, 0.84), true)
	draw_rect(panel_rect, Color(0.40, 0.54, 0.58, 0.96), false, 2.0)
	_draw_map_guides()
	_draw_blips()
	_draw_camera_frame()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		map_pressed.emit(_minimap_to_world(event.position))
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		map_pressed.emit(_minimap_to_world(event.position))
		accept_event()

func _draw_map_guides() -> void:
	var center: Vector2 = size * 0.5
	draw_line(Vector2(0.0, center.y), Vector2(size.x, center.y), Color(0.18, 0.22, 0.21, 0.9), 2.0)
	draw_line(Vector2(center.x, 0.0), Vector2(center.x, size.y), Color(0.16, 0.20, 0.20, 0.8), 1.5)
	var resource_position: Vector2 = _world_to_minimap(Vector3(-32.0, 0.0, -12.0))
	draw_circle(resource_position, 8.0, Color(0.62, 0.82, 0.95, 0.42))

func _draw_blips() -> void:
	for blip in _blips:
		var world_position: Vector3 = blip["position"]
		var color: Color = blip["color"]
		var radius: float = float(blip.get("radius", 3.0))
		draw_circle(_world_to_minimap(world_position), radius, color)

func _draw_camera_frame() -> void:
	var camera_point: Vector2 = _world_to_minimap(_camera_center)
	var frame_size: Vector2 = Vector2(44.0, 28.0)
	var camera_rect: Rect2 = Rect2(camera_point - frame_size * 0.5, frame_size)
	camera_rect.position.x = clampf(camera_rect.position.x, 1.0, maxf(1.0, size.x - camera_rect.size.x - 1.0))
	camera_rect.position.y = clampf(camera_rect.position.y, 1.0, maxf(1.0, size.y - camera_rect.size.y - 1.0))
	draw_rect(camera_rect, Color(1.0, 1.0, 1.0, 0.86), false, 2.0)

func _world_to_minimap(world_position: Vector3) -> Vector2:
	var x_ratio: float = inverse_lerp(-map_size.x * 0.5, map_size.x * 0.5, world_position.x)
	var y_ratio: float = inverse_lerp(map_size.y * 0.5, -map_size.y * 0.5, world_position.z)
	return Vector2(clampf(x_ratio, 0.0, 1.0) * size.x, clampf(y_ratio, 0.0, 1.0) * size.y)

func _minimap_to_world(panel_position: Vector2) -> Vector3:
	var x_ratio: float = clampf(panel_position.x / maxf(size.x, 1.0), 0.0, 1.0)
	var y_ratio: float = clampf(panel_position.y / maxf(size.y, 1.0), 0.0, 1.0)
	var world_x: float = lerpf(-map_size.x * 0.5, map_size.x * 0.5, x_ratio)
	var world_z: float = lerpf(map_size.y * 0.5, -map_size.y * 0.5, y_ratio)
	return Vector3(world_x, 0.45, world_z)
