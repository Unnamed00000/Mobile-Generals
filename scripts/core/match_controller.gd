class_name MatchController
extends Node3D

const BUILDER_SCENE := preload("res://scenes/units/builder.tscn")

@onready var prototype_map: PrototypeMap = $PrototypeMap
@onready var camera_controller: RtsCamera = $CameraRig
@onready var units_root: Node3D = $Units
@onready var hud: MatchHud = $MatchHUD

var selected_units: Array[MobileUnit] = []
var _primary_touch_start := Vector2.ZERO
var _primary_touch_dragged := false
var _last_mouse_position := Vector2.ZERO
var _command_marker: MeshInstance3D

func _ready() -> void:
	camera_controller.set_map_half_extents(prototype_map.get_half_extents())
	_spawn_builder()
	_create_command_marker()
	_update_hud_selection()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag and event.index == 0:
		if event.position.distance_to(_primary_touch_start) > 18.0:
			_primary_touch_dragged = true
	elif event is InputEventMouseMotion:
		_last_mouse_position = event.position
	elif event is InputEventMouseButton and event.pressed:
		_handle_mouse_button(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if hud.is_screen_position_over_ui(event.position):
		return

	if event.pressed and event.index == 0:
		_primary_touch_start = event.position
		_primary_touch_dragged = false
	elif not event.pressed and event.index == 0 and not _primary_touch_dragged:
		_process_primary_tap(event.position)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if hud.is_screen_position_over_ui(event.position):
		return

	if event.button_index == MOUSE_BUTTON_LEFT:
		_process_primary_tap(event.position)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_issue_move_command(event.position)

func _process_primary_tap(screen_position: Vector2) -> void:
	var hit := _raycast_from_screen(screen_position)
	if hit.is_empty():
		return

	var selectable := _selectable_from_collider(hit.get("collider"))
	if selectable != null and selectable.team_id == 1:
		_select_single(selectable)
		return

	if not selected_units.is_empty() and _is_ground_hit(hit):
		_move_selected_to(hit.position)
	else:
		_clear_selection()

func _issue_move_command(screen_position: Vector2) -> void:
	if selected_units.is_empty():
		return

	var hit := _raycast_from_screen(screen_position)
	if not hit.is_empty() and _is_ground_hit(hit):
		_move_selected_to(hit.position)

func _raycast_from_screen(screen_position: Vector2) -> Dictionary:
	var camera := camera_controller.get_camera()
	var origin := camera.project_ray_origin(screen_position)
	var end := origin + camera.project_ray_normal(screen_position) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = 7
	query.collide_with_areas = true
	query.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func _selectable_from_collider(collider: Object) -> MobileUnit:
	var node := collider as Node
	while node != null:
		if node is MobileUnit:
			return node as MobileUnit
		node = node.get_parent()
	return null

func _is_ground_hit(hit: Dictionary) -> bool:
	var collider := hit.get("collider") as Node
	return collider != null and collider.is_in_group("command_ground")

func _select_single(unit: MobileUnit) -> void:
	_clear_selection()
	selected_units.append(unit)
	unit.set_selected(true)
	_update_hud_selection()

func _clear_selection() -> void:
	for unit in selected_units:
		if is_instance_valid(unit):
			unit.set_selected(false)
	selected_units.clear()
	_update_hud_selection()

func _move_selected_to(world_position: Vector3) -> void:
	var offsets := _formation_offsets(selected_units.size())
	for i in selected_units.size():
		var unit := selected_units[i]
		if is_instance_valid(unit):
			unit.move_to(world_position + offsets[i])
	_show_command_marker(world_position)

func _formation_offsets(count: int) -> Array[Vector3]:
	var offsets: Array[Vector3] = []
	if count <= 1:
		offsets.append(Vector3.ZERO)
		return offsets

	var columns := ceili(sqrt(float(count)))
	var spacing := 1.8
	for index in count:
		var row := index / columns
		var col := index % columns
		var centered_x := (float(col) - float(columns - 1) * 0.5) * spacing
		var centered_z := float(row) * spacing
		offsets.append(Vector3(centered_x, 0.0, centered_z))
	return offsets

func _spawn_builder() -> void:
	var builder := BUILDER_SCENE.instantiate() as BuilderUnit
	builder.name = "PlayerBuilder"
	builder.team_id = 1
	builder.global_position = prototype_map.player_start
	units_root.add_child(builder)

func _create_command_marker() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.2
	mesh.bottom_radius = 1.2
	mesh.height = 0.05
	mesh.radial_segments = 28

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.18, 0.72, 0.34, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_command_marker = MeshInstance3D.new()
	_command_marker.name = "MoveCommandMarker"
	_command_marker.mesh = mesh
	_command_marker.material_override = material
	_command_marker.visible = false
	add_child(_command_marker)

func _show_command_marker(world_position: Vector3) -> void:
	if not is_instance_valid(_command_marker):
		return
	_command_marker.global_position = Vector3(world_position.x, 0.08, world_position.z)
	_command_marker.visible = true
	var tween := create_tween()
	_command_marker.scale = Vector3.ONE
	tween.tween_property(_command_marker, "scale", Vector3(1.65, 1.0, 1.65), 0.18)
	tween.tween_interval(0.15)
	tween.tween_callback(Callable(self, "_hide_command_marker"))

func _hide_command_marker() -> void:
	if is_instance_valid(_command_marker):
		_command_marker.visible = false

func _update_hud_selection() -> void:
	if selected_units.is_empty():
		hud.update_selection(0, "None")
	elif selected_units.size() == 1 and is_instance_valid(selected_units[0]):
		hud.update_selection(1, selected_units[0].display_name)
	else:
		hud.update_selection(selected_units.size(), "Units")
