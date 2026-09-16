class_name InfantryStageController
extends Node3D

const COMBAT_UNIT_SCENE := preload("res://scenes/units/combat_unit.tscn")
const WORKER_SCENE := preload("res://scenes/units/worker.tscn")
const RIFLEMAN_DATA_PATH := "res://data/units/rifleman.json"
const BUILDING_DATA := {
	"hq": {
		"id": "hq",
		"name": "HQ",
		"price": 0,
		"hp": 2600,
		"build_time": 0.0,
		"footprint": [8.0, 8.0],
		"produces": ["worker"]
	},
	"resource_center": {
		"id": "resource_center",
		"name": "Resource Center",
		"price": 1200,
		"hp": 1400,
		"build_time": 7.0,
		"footprint": [6.5, 6.5],
		"produces": []
	},
	"power_plant": {
		"id": "power_plant",
		"name": "Power Plant",
		"price": 700,
		"hp": 1000,
		"build_time": 5.0,
		"footprint": [4.5, 4.5],
		"produces": []
	},
	"barracks": {
		"id": "barracks",
		"name": "Barracks",
		"price": 1000,
		"hp": 1200,
		"build_time": 6.0,
		"footprint": [6.0, 5.0],
		"produces": []
	},
	"defense_post": {
		"id": "defense_post",
		"name": "Defense Post",
		"price": 900,
		"hp": 900,
		"build_time": 6.0,
		"footprint": [4.0, 4.0],
		"produces": []
	}
}

@onready var prototype_map: PrototypeMap = $PrototypeMap
@onready var camera_controller: RtsCamera = $CameraRig
@onready var units_root: Node3D = $Units
@onready var buildings_root: Node3D = $Buildings
@onready var hud: StageOneHud = $MatchHUD

var selected_units: Array[MobileUnit] = []
var selected_building: Building
var money := 10000

var _rifleman_data: Dictionary = {}
var _active_builds: Array[Dictionary] = []
var _active_productions: Array[Dictionary] = []
var _resource_income_timer := 0.0
var _placement_preview: Building
var _placement_building_id := ""
var _placement_worker: WorkerUnit
var _placement_position := Vector3.ZERO
var _placement_valid := false
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
	hud.worker_build_requested.connect(Callable(self, "_on_worker_build_requested"))
	hud.hq_worker_requested.connect(Callable(self, "_on_hq_worker_requested"))
	hud.placement_cancel_requested.connect(Callable(self, "_cancel_placement"))
	_spawn_starting_hq()
	_spawn_stage_units()
	_update_hud()

func _physics_process(delta: float) -> void:
	if _match_over:
		return
	_match_seconds += delta
	_update_active_builds(delta)
	_update_active_productions(delta)
	_update_resource_income(delta)
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
	elif event is InputEventMouseMotion:
		if _selection_dragging:
			_update_selection_drag(event.position)
		elif _is_placing_building():
			_update_placement_from_screen(event.position)

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

func _spawn_starting_hq() -> void:
	var hq := Building.new()
	hq.name = "PlayerHQ"
	hq.configure(BUILDING_DATA["hq"], 1)
	hq.global_position = prototype_map.player_start + Vector3(-8.5, -0.45, -3.5)
	buildings_root.add_child(hq)
	hq.finish_construction()

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
	if _is_placing_building():
		_update_placement_from_screen(event.position)
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

	if _is_placing_building():
		if _is_ground_hit(hit):
			_update_placement(hit.position)
			_confirm_placement()
		return

	var unit := _selectable_from_collider(hit.get("collider"))
	if unit != null:
		if unit.team_id == 1:
			var single_selection: Array[MobileUnit] = [unit]
			_select_units(single_selection)
		elif not selected_units.is_empty() and unit is CombatUnit:
			_attack_selected(unit as CombatUnit)
		return

	var building := _building_from_collider(hit.get("collider"))
	if building != null and building.team_id == 1:
		_select_building(building)
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
	selected_building = null
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
		hud.show_default_context()
	elif selected_units.size() == 1:
		var selected := selected_units[0]
		if selected is WorkerUnit:
			hud.set_hint("Worker selected. Tap ground to move.")
			hud.show_worker_context()
		else:
			hud.set_hint("Rifleman selected. Tap ground to move or enemy to attack.")
			hud.show_default_context()
	else:
		hud.set_hint("%d units selected." % selected_units.size())
		hud.show_default_context()

func _select_building(building: Building) -> void:
	for unit in selected_units:
		if is_instance_valid(unit):
			unit.set_selected(false)
	selected_units.clear()
	selected_building = building
	hud.update_selection_summary(0)
	if building.building_id == "hq":
		hud.show_hq_context()
		hud.set_hint("HQ selected. Train workers here.")
	else:
		hud.show_building_context(building.display_name)

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

func _building_from_collider(collider: Object) -> Building:
	var node := collider as Node
	while node != null:
		if node is Building:
			return node as Building
		node = node.get_parent()
	return null

func _is_selectable_alive(unit: MobileUnit) -> bool:
	if unit is CombatUnit:
		return (unit as CombatUnit).current_hp > 0
	return true

func _is_ground_hit(hit: Dictionary) -> bool:
	var collider := hit.get("collider") as Node
	return collider != null and collider.is_in_group("command_ground")

func _on_worker_build_requested(building_id: String) -> void:
	if not BUILDING_DATA.has(building_id):
		hud.set_hint("Unknown building.")
		return
	var worker := _selected_worker()
	if worker == null:
		hud.set_hint("Select one worker first.")
		return
	var data: Dictionary = BUILDING_DATA[building_id]
	var price := int(data.get("price", 0))
	if money < price:
		hud.set_hint("Not enough money for %s." % str(data.get("name", building_id)))
		return
	_start_placement(building_id, worker)

func _start_placement(building_id: String, worker: WorkerUnit) -> void:
	_cancel_placement()
	_placement_building_id = building_id
	_placement_worker = worker
	_placement_preview = Building.new()
	_placement_preview.configure(BUILDING_DATA[building_id], 1)
	_placement_preview.name = "Preview%s" % str(BUILDING_DATA[building_id].get("name", building_id)).replace(" ", "")
	buildings_root.add_child(_placement_preview)
	_placement_preview.set_preview_mode(false)
	hud.show_placement_context(_placement_preview.display_name, false)

func _update_placement_from_screen(screen_position: Vector2) -> void:
	var hit := _raycast_from_screen(screen_position)
	if hit.is_empty() or not _is_ground_hit(hit):
		return
	_update_placement(hit.position)

func _update_placement(world_position: Vector3) -> void:
	if not _is_placing_building():
		return
	_placement_position = world_position
	_placement_position.y = -0.45
	_placement_preview.global_position = _placement_position
	_placement_valid = _can_place_building(_placement_preview, _placement_position)
	_placement_preview.set_preview_mode(_placement_valid)
	hud.show_placement_context(_placement_preview.display_name, _placement_valid)

func _confirm_placement() -> void:
	if not _is_placing_building():
		return
	if not _placement_valid:
		hud.set_hint("Cannot build there.")
		return
	if not is_instance_valid(_placement_worker):
		_cancel_placement()
		return

	var data: Dictionary = BUILDING_DATA[_placement_building_id]
	var price := int(data.get("price", 0))
	if money < price:
		hud.set_hint("Not enough money.")
		return

	money -= price
	var building := _placement_preview
	_placement_preview = null
	building.name = str(data.get("name", _placement_building_id)).replace(" ", "")
	building.set_under_construction()
	_active_builds.append({
		"building": building,
		"worker": _placement_worker,
		"elapsed": 0.0
	})
	_placement_worker.move_to(_nearest_worker_position(building.global_position, building.footprint))
	hud.set_hint("Building %s." % building.display_name)
	_placement_building_id = ""
	_placement_worker = null
	_placement_valid = false
	hud.show_worker_context()
	_update_hud()

func _cancel_placement() -> void:
	if is_instance_valid(_placement_preview):
		_placement_preview.queue_free()
	_placement_preview = null
	_placement_building_id = ""
	_placement_worker = null
	_placement_valid = false
	if _selected_worker() != null:
		hud.show_worker_context()
	else:
		hud.show_default_context()

func _is_placing_building() -> bool:
	return is_instance_valid(_placement_preview) and not _placement_building_id.is_empty()

func _can_place_building(building: Building, at: Vector3) -> bool:
	var half_extents := prototype_map.get_half_extents()
	var half_footprint := building.footprint * 0.5
	if at.x - half_footprint.x < -half_extents.x or at.x + half_footprint.x > half_extents.x:
		return false
	if at.z - half_footprint.y < -half_extents.y or at.z + half_footprint.y > half_extents.y:
		return false
	if prototype_map.is_area_blocked(at, building.footprint):
		return false
	if building.building_id == "resource_center" and not _is_near_resource_point(at):
		return false
	for node in get_tree().get_nodes_in_group("buildings"):
		var existing := node as Building
		if existing == null or existing == building or existing.is_preview:
			continue
		var min_distance := maxf(existing.footprint.length(), building.footprint.length()) * 0.42
		if existing.global_position.distance_to(at) < min_distance:
			return false
	return true

func _is_near_resource_point(at: Vector3) -> bool:
	for node in get_tree().get_nodes_in_group("resource_points"):
		var resource := node as Node3D
		if resource != null and resource.global_position.distance_to(at) <= 18.0:
			return true
	return false

func _nearest_worker_position(center: Vector3, footprint: Vector2) -> Vector3:
	var offset := Vector3(footprint.x * 0.5 + 1.5, 0.9, footprint.y * 0.5 + 1.5)
	return center + offset

func _update_active_builds(delta: float) -> void:
	for index in range(_active_builds.size() - 1, -1, -1):
		var order: Dictionary = _active_builds[index]
		var building := order.get("building") as Building
		if building == null or not is_instance_valid(building):
			_active_builds.remove_at(index)
			continue
		order["elapsed"] = float(order.get("elapsed", 0.0)) + delta
		var progress := float(order["elapsed"]) / maxf(building.build_time, 0.1)
		building.set_construction_progress(progress)
		if progress >= 1.0:
			building.finish_construction()
			_active_builds.remove_at(index)
			hud.set_hint("%s complete." % building.display_name)

func _on_hq_worker_requested() -> void:
	if selected_building == null or not is_instance_valid(selected_building) or selected_building.building_id != "hq":
		hud.set_hint("Select HQ first.")
		return
	if _is_building_producing(selected_building):
		hud.set_hint("HQ is already training a worker.")
		return
	if money < 500:
		hud.set_hint("Not enough money for Worker.")
		return
	if _count_live_player_units() >= 40:
		hud.set_hint("Unit limit reached.")
		return
	money -= 500
	_active_productions.append({
		"building": selected_building,
		"unit_id": "worker",
		"elapsed": 0.0,
		"time": 5.0
	})
	selected_building.set_production_display("Worker", 0.0, 0)
	hud.set_hint("Training Worker.")
	_update_hud()

func _update_active_productions(delta: float) -> void:
	for index in range(_active_productions.size() - 1, -1, -1):
		var order: Dictionary = _active_productions[index]
		var building := order.get("building") as Building
		if building == null or not is_instance_valid(building):
			_active_productions.remove_at(index)
			continue
		order["elapsed"] = float(order.get("elapsed", 0.0)) + delta
		var progress := float(order["elapsed"]) / maxf(float(order.get("time", 1.0)), 0.1)
		building.set_production_display("Worker", progress, 0)
		if progress >= 1.0:
			_active_productions.remove_at(index)
			building.set_production_display("", 0.0, 0)
			_spawn_worker(_building_spawn_position(building))
			hud.set_hint("Worker ready.")

func _is_building_producing(building: Building) -> bool:
	for order in _active_productions:
		if order.get("building") == building:
			return true
	return false

func _building_spawn_position(building: Building) -> Vector3:
	return building.global_position + Vector3(building.footprint.x * 0.5 + 2.0, 0.9, 0.0)

func _update_resource_income(delta: float) -> void:
	var center_count := _complete_resource_center_count()
	if center_count <= 0:
		_resource_income_timer = 0.0
		return
	_resource_income_timer += delta
	if _resource_income_timer < 6.0:
		return
	_resource_income_timer = 0.0
	money += 300 * center_count
	hud.set_hint("Resource delivery +$%d." % (300 * center_count))

func _complete_resource_center_count() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("player_buildings"):
		var building := node as Building
		if building != null and is_instance_valid(building) and building.building_id == "resource_center" and building.is_complete:
			count += 1
	return count

func _selected_worker() -> WorkerUnit:
	if selected_units.size() != 1:
		return null
	var worker := selected_units[0] as WorkerUnit
	if worker != null and is_instance_valid(worker):
		return worker
	return null

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
	hud.update_status(money, _count_live_player_units(), 40, int(_match_seconds))

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
