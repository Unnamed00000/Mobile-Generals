class_name InfantryStageController
extends Node3D

const COMBAT_UNIT_SCENE := preload("res://scenes/units/combat_unit.tscn")
const WORKER_SCENE := preload("res://scenes/units/worker.tscn")
const RIFLEMAN_DATA_PATH := "res://data/units/rifleman.json"

@onready var prototype_map: PrototypeMap = $PrototypeMap
@onready var camera_controller: RtsCamera = $CameraRig
@onready var units_root: Node3D = $Units
@onready var hud: StageOneHud = $MatchHUD

var selected_units: Array[MobileUnit] = []

var _rifleman_data: Dictionary = {}
var _match_seconds := 0.0
var _select_mode := false
var _selection_start := Vector2.ZERO
var _selection_current := Vector2.ZERO
var _selection_dragging := false
var _primary_touch_start := Vector2.ZERO
var _primary_touch_dragged := false
var _match_over := false

func _ready() -> void:
	_rifleman_data = _load_json(RIFLEMAN_DATA_PATH)
	camera_controller.set_map_half_extents(prototype_map.get_half_extents())
	hud.select_mode_requested.connect(Callable(self, "_on_select_mode_requested"))
	_spawn_stage_units()
	_update_hud()

func _physics_process(delta: float) -> void:
	if _match_over:
		return
	_match_seconds += delta
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if _match_over:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _selection_dragging:
		_update_selection_drag(event.position)

func _spawn_stage_units() -> void:
	var player_positions: Array[Vector3] = [
		Vector3(-42.0, 0.45, 18.0),
		Vector3(-39.8, 0.45, 20.0),
		Vector3(-37.6, 0.45, 18.0),
		Vector3(-42.0, 0.45, 22.5),
		Vector3(-39.8, 0.45, 24.5),
		Vector3(-37.6, 0.45, 22.5)
	]
	var enemy_positions: Array[Vector3] = [
		Vector3(32.0, 0.45, -15.0),
		Vector3(35.0, 0.45, -17.0),
		Vector3(38.0, 0.45, -15.0),
		Vector3(41.0, 0.45, -17.0)
	]

	for index in player_positions.size():
		_spawn_rifleman(1, player_positions[index], "Rifleman%02d" % index)
	_spawn_worker(prototype_map.player_start + Vector3(-4.8, 0.0, 0.6))
	for index in enemy_positions.size():
		_spawn_rifleman(2, enemy_positions[index], "EnemyRifleman%02d" % index)

func _spawn_rifleman(team_id: int, world_position: Vector3, unit_name: String) -> CombatUnit:
	var unit := COMBAT_UNIT_SCENE.instantiate() as CombatUnit
	unit.name = unit_name
	unit.configure(_rifleman_data, team_id)
	unit.global_position = world_position
	unit.destroyed.connect(Callable(self, "_on_unit_destroyed"))
	units_root.add_child(unit)
	return unit

func _spawn_worker(world_position: Vector3) -> WorkerUnit:
	var worker := WORKER_SCENE.instantiate() as WorkerUnit
	worker.name = "PlayerWorker"
	worker.team_id = 1
	worker.global_position = world_position
	units_root.add_child(worker)
	return worker

func _handle_touch(event: InputEventScreenTouch) -> void:
	if hud.is_screen_position_over_ui(event.position):
		return

	if _select_mode:
		if event.pressed and event.index == 0:
			_begin_selection_drag(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == 0 and _selection_dragging:
			_finish_selection_drag(event.position)
			get_viewport().set_input_as_handled()
		return

	if event.index != 0:
		return
	if event.pressed:
		_primary_touch_start = event.position
		_primary_touch_dragged = false
	else:
		if not _primary_touch_dragged:
			_process_tap(event.position)

func _handle_drag(event: InputEventScreenDrag) -> void:
	if _select_mode and _selection_dragging:
		_update_selection_drag(event.position)
		get_viewport().set_input_as_handled()
		return
	if event.index == 0 and event.position.distance_to(_primary_touch_start) > 18.0:
		_primary_touch_dragged = true

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if hud.is_screen_position_over_ui(event.position):
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if _select_mode:
		if event.pressed:
			_begin_selection_drag(event.position)
		elif _selection_dragging:
			_finish_selection_drag(event.position)
		get_viewport().set_input_as_handled()
	elif event.pressed:
		_process_tap(event.position)

func _process_tap(screen_position: Vector2) -> void:
	var hit := _raycast_from_screen(screen_position)
	if hit.is_empty():
		return

	var unit := _selectable_from_collider(hit.get("collider"))
	if unit != null:
		if unit.team_id == 1:
			var single_selection: Array[MobileUnit] = [unit]
			_select_units(single_selection)
		elif not selected_units.is_empty() and unit is CombatUnit:
			_attack_selected(unit as CombatUnit)
		return

	if _is_ground_hit(hit) and not selected_units.is_empty():
		_move_selected_to(hit.position)

func _begin_selection_drag(screen_position: Vector2) -> void:
	_selection_start = screen_position
	_selection_current = screen_position
	_selection_dragging = true
	hud.show_selection_rect(_selection_start, _selection_current)

func _update_selection_drag(screen_position: Vector2) -> void:
	_selection_current = screen_position
	hud.show_selection_rect(_selection_start, _selection_current)

func _finish_selection_drag(screen_position: Vector2) -> void:
	_selection_current = screen_position
	_selection_dragging = false
	hud.hide_selection_rect()
	var selection_rect := Rect2(_selection_start, _selection_current - _selection_start).abs()
	_select_units(_units_in_screen_rect(selection_rect))
	_select_mode = false
	hud.set_select_mode(false)

func _units_in_screen_rect(selection_rect: Rect2) -> Array[MobileUnit]:
	var camera := camera_controller.get_camera()
	var units: Array[MobileUnit] = []
	for node in get_tree().get_nodes_in_group("player_units"):
		var unit := node as MobileUnit
		if unit == null or not is_instance_valid(unit):
			continue
		if unit is CombatUnit and (unit as CombatUnit).current_hp <= 0:
			continue
		var screen_position := camera.unproject_position(unit.global_position)
		if selection_rect.has_point(screen_position):
			units.append(unit)
	return units

func _select_units(units: Array[MobileUnit]) -> void:
	for unit in selected_units:
		if is_instance_valid(unit):
			unit.set_selected(false)
	selected_units.clear()
	for unit in units:
		if is_instance_valid(unit) and unit.team_id == 1 and _is_selectable_alive(unit):
			selected_units.append(unit)
			unit.set_selected(true)
	hud.update_selection_summary(selected_units.size())
	if selected_units.is_empty():
		hud.set_hint("No soldiers selected.")
	elif selected_units.size() == 1:
		var selected := selected_units[0]
		if selected is WorkerUnit:
			hud.set_hint("Worker selected. Tap ground to move.")
		else:
			hud.set_hint("Rifleman selected. Tap ground to move or enemy to attack.")
	else:
		hud.set_hint("%d units selected." % selected_units.size())

func _move_selected_to(world_position: Vector3) -> void:
	var offsets := _formation_offsets(selected_units.size())
	for index in selected_units.size():
		var unit := selected_units[index]
		if is_instance_valid(unit):
			unit.move_to(world_position + offsets[index])
	hud.set_hint("Move order issued.")

func _attack_selected(target: CombatUnit) -> void:
	var issued := 0
	for unit in selected_units:
		if is_instance_valid(unit) and unit is CombatUnit and (unit as CombatUnit).current_hp > 0:
			(unit as CombatUnit).set_attack_target(target)
			issued += 1
	if issued > 0:
		hud.set_hint("Attack order issued.")
	else:
		hud.set_hint("Workers cannot attack.")

func _formation_offsets(count: int) -> Array[Vector3]:
	var offsets: Array[Vector3] = []
	if count <= 1:
		offsets.append(Vector3.ZERO)
		return offsets

	var columns: int = ceili(sqrt(float(count)))
	var spacing := 1.65
	for index in count:
		var row: int = int(index / columns)
		var col: int = index % columns
		var centered_x := (float(col) - float(columns - 1) * 0.5) * spacing
		var centered_z := float(row) * spacing
		offsets.append(Vector3(centered_x, 0.0, centered_z))
	return offsets

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

func _is_selectable_alive(unit: MobileUnit) -> bool:
	if unit is CombatUnit:
		return (unit as CombatUnit).current_hp > 0
	return true

func _is_ground_hit(hit: Dictionary) -> bool:
	var collider := hit.get("collider") as Node
	return collider != null and collider.is_in_group("command_ground")

func _on_select_mode_requested() -> void:
	_select_mode = not _select_mode
	hud.set_select_mode(_select_mode)

func _on_unit_destroyed(unit: CombatUnit) -> void:
	selected_units.erase(unit)
	hud.update_selection_summary(selected_units.size())
	_check_match_result()

func _check_match_result() -> void:
	if _match_over:
		return
	if _count_live_units(2) == 0:
		_match_over = true
		hud.set_hint("VICTORY - enemy squad eliminated.")
	elif _count_live_units(1) == 0:
		_match_over = true
		hud.set_hint("DEFEAT - your squad was eliminated.")

func _count_live_units(team_id: int) -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("combat_targets"):
		var unit := node as CombatUnit
		if unit != null and is_instance_valid(unit) and unit.team_id == team_id and unit.current_hp > 0:
			count += 1
	return count

func _update_hud() -> void:
	hud.update_status(10000, _count_live_player_units(), 40, int(_match_seconds))

func _count_live_player_units() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("player_units"):
		var unit := node as MobileUnit
		if unit != null and is_instance_valid(unit) and _is_selectable_alive(unit):
			count += 1
	return count

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Missing data file: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}
