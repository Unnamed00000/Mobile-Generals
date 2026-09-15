class_name MatchController
extends Node3D

const BUILDER_SCENE := preload("res://scenes/units/builder.tscn")
const RESOURCE_HARVESTER_SCENE := preload("res://scenes/units/resource_harvester.tscn")
const COMBAT_UNIT_SCENE := preload("res://scenes/units/combat_unit.tscn")
const BUILDING_DATA_PATHS := {
	"power_plant": "res://data/buildings/power_plant.json",
	"resource_center": "res://data/buildings/resource_center.json",
	"barracks": "res://data/buildings/barracks.json",
	"war_factory": "res://data/buildings/war_factory.json",
	"defense_turret": "res://data/buildings/defense_turret.json"
}
const UNIT_DATA_PATHS := {
	"builder": "res://data/units/builder.json",
	"resource_harvester": "res://data/units/resource_harvester.json",
	"rifleman": "res://data/units/rifleman.json",
	"rpg_soldier": "res://data/units/rpg_soldier.json",
	"main_battle_tank": "res://data/units/main_battle_tank.json"
}

@onready var prototype_map: PrototypeMap = $PrototypeMap
@onready var camera_controller: RtsCamera = $CameraRig
@onready var units_root: Node3D = $Units
@onready var buildings_root: Node3D = $Buildings
@onready var hud: MatchHud = $MatchHUD

var selected_units: Array[MobileUnit] = []
var selected_building: Building
var money := 10000
var power_current := 0
var power_max := 0
var unit_count := 1
var unit_cap := 60

var building_data: Dictionary = {}
var unit_data: Dictionary = {}
var active_builds: Array[Dictionary] = []
var active_productions: Array[Dictionary] = []
var army_groups := {
	1: [],
	2: [],
	3: [],
	4: []
}

var _primary_touch_start := Vector2.ZERO
var _primary_touch_dragged := false
var _last_mouse_position := Vector2.ZERO
var _command_marker: MeshInstance3D
var _placement_preview: Building
var _placement_building_id := ""
var _placement_position := Vector3.ZERO
var _placement_valid := false
var _pending_army_command := ""

func _ready() -> void:
	_load_building_data()
	_load_unit_data()
	hud.build_requested.connect(Callable(self, "_on_build_requested"))
	hud.placement_confirmed.connect(Callable(self, "_on_placement_confirmed"))
	hud.placement_cancelled.connect(Callable(self, "_cancel_placement"))
	hud.production_requested.connect(Callable(self, "_on_production_requested"))
	hud.production_cancel_requested.connect(Callable(self, "_on_production_cancel_requested"))
	hud.army_filter_requested.connect(Callable(self, "_on_army_filter_requested"))
	hud.army_command_requested.connect(Callable(self, "_on_army_command_requested"))
	hud.group_selected.connect(Callable(self, "_on_group_selected"))
	hud.group_saved.connect(Callable(self, "_on_group_saved"))
	camera_controller.set_map_half_extents(prototype_map.get_half_extents())
	_spawn_builder()
	_create_command_marker()
	_update_match_stats()
	_update_hud_selection()

func _physics_process(delta: float) -> void:
	_update_active_builds(delta)
	_update_active_productions(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag and event.index == 0:
		if event.position.distance_to(_primary_touch_start) > 18.0:
			_primary_touch_dragged = true
		if _is_placing_building():
			_update_placement_from_screen(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_last_mouse_position = event.position
		if _is_placing_building():
			_update_placement_from_screen(event.position)
	elif event is InputEventMouseButton and event.pressed:
		_handle_mouse_button(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key_press(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if hud.is_screen_position_over_ui(event.position):
		return

	if event.pressed and event.index == 0:
		_primary_touch_start = event.position
		_primary_touch_dragged = false
		if _is_placing_building():
			_update_placement_from_screen(event.position)
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

	if _is_placing_building():
		if _is_ground_hit(hit):
			_update_placement_from_screen(screen_position)
		return

	var selectable := _selectable_from_collider(hit.get("collider"))
	if selectable != null and selectable.team_id == 1:
		_select_single(selectable)
		return

	if _has_army_selection() and not _pending_army_command.is_empty():
		_process_pending_army_command(hit)
		return

	var building := _building_from_collider(hit.get("collider"))
	if building != null and building.team_id == 1:
		_select_building(building)
		return

	if not selected_units.is_empty() and _is_ground_hit(hit):
		_move_selected_to(hit.position)
	else:
		_clear_selection()

func _issue_move_command(screen_position: Vector2) -> void:
	if _is_placing_building():
		_cancel_placement()
		return

	if selected_units.is_empty():
		return

	var hit := _raycast_from_screen(screen_position)
	if not hit.is_empty() and _is_ground_hit(hit):
		_move_selected_to(hit.position)

func _handle_key_press(event: InputEventKey) -> void:
	if event.keycode >= KEY_1 and event.keycode <= KEY_4:
		var group_id := int(event.keycode - KEY_0)
		if event.ctrl_pressed:
			_on_group_saved(group_id)
		else:
			_on_group_selected(group_id)

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

func _is_ground_hit(hit: Dictionary) -> bool:
	var collider := hit.get("collider") as Node
	return collider != null and collider.is_in_group("command_ground")

func _select_single(unit: MobileUnit) -> void:
	_clear_selection()
	selected_building = null
	selected_units.append(unit)
	unit.set_selected(true)
	_update_hud_selection()

func _select_units(units: Array[MobileUnit]) -> void:
	_clear_selection()
	selected_building = null
	for unit in units:
		if is_instance_valid(unit) and unit.team_id == 1:
			selected_units.append(unit)
			unit.set_selected(true)
	_update_hud_selection()

func _select_building(building: Building) -> void:
	_clear_selection()
	selected_building = building
	hud.update_selection(1, building.display_name)
	if not building.is_complete:
		hud.show_builder_controls(false)
		hud.set_hint("%s is still under construction." % building.display_name)
	elif building.produces.is_empty():
		hud.show_builder_controls(false)
		hud.set_hint("%s is ready." % building.display_name)
	else:
		_update_hud_production()

func _clear_selection() -> void:
	for unit in selected_units:
		if is_instance_valid(unit):
			unit.set_selected(false)
	selected_units.clear()
	selected_building = null
	_update_hud_selection()

func _move_selected_to(world_position: Vector3) -> void:
	var offsets := _formation_offsets(selected_units.size())
	for i in selected_units.size():
		var unit := selected_units[i]
		if is_instance_valid(unit):
			unit.move_to(world_position + offsets[i])
	_show_command_marker(world_position)
	_pending_army_command = ""

func _attack_move_selected_to(world_position: Vector3) -> void:
	var offsets := _formation_offsets(selected_units.size())
	for i in selected_units.size():
		var unit := selected_units[i]
		if is_instance_valid(unit):
			unit.attack_move_to(world_position + offsets[i])
	_show_command_marker(world_position)
	_pending_army_command = ""
	hud.set_hint("Attack Move issued. Auto-targeting comes with combat in Milestone 6.")

func _stop_selected_units() -> void:
	for unit in selected_units:
		if is_instance_valid(unit):
			unit.stop()
	_pending_army_command = ""
	hud.set_hint("Selected units stopped.")

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
		hud.show_army_controls(0)
	elif selected_units.size() == 1 and is_instance_valid(selected_units[0]):
		hud.update_selection(1, selected_units[0].display_name)
		if selected_units[0] is BuilderUnit:
			hud.show_builder_controls(not _is_placing_building())
		elif selected_units[0] is CombatUnit:
			hud.show_army_controls(1)
		else:
			hud.show_builder_controls(false)
	else:
		hud.update_selection(selected_units.size(), "Units")
		hud.show_army_controls(_combat_selection_count())

func _load_building_data() -> void:
	for building_id in BUILDING_DATA_PATHS.keys():
		var path: String = BUILDING_DATA_PATHS[building_id]
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_warning("Missing building data: %s" % path)
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			building_data[building_id] = parsed
		else:
			push_warning("Invalid building data: %s" % path)

func _load_unit_data() -> void:
	for unit_id in UNIT_DATA_PATHS.keys():
		var path: String = UNIT_DATA_PATHS[unit_id]
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_warning("Missing unit data: %s" % path)
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			unit_data[unit_id] = parsed
		else:
			push_warning("Invalid unit data: %s" % path)

func _on_build_requested(building_id: String) -> void:
	if not building_data.has(building_id):
		hud.set_hint("Building data is missing: %s" % building_id)
		return
	if _get_selected_builder() == null:
		hud.set_hint("Select the Builder before placing a building.")
		return

	var data: Dictionary = building_data[building_id]
	var price := int(data.get("price", 0))
	if money < price:
		hud.set_hint("Not enough money for %s." % str(data.get("name", building_id)))
		return

	_start_placement(building_id)

func _start_placement(building_id: String) -> void:
	_cancel_placement()
	_placement_building_id = building_id
	var data: Dictionary = building_data[building_id]
	_placement_preview = Building.new()
	_placement_preview.configure(data, 1)
	_placement_preview.name = "Preview%s" % str(data.get("name", building_id)).replace(" ", "")
	buildings_root.add_child(_placement_preview)
	_update_placement_from_screen(_last_mouse_position)

func _update_placement_from_screen(screen_position: Vector2) -> void:
	if not _is_placing_building():
		return
	var hit := _raycast_from_screen(screen_position)
	if hit.is_empty() or not _is_ground_hit(hit):
		_placement_valid = false
		_placement_preview.set_preview_mode(false)
		hud.show_placement_controls(_placement_preview.display_name, false)
		return

	_placement_position = hit.position
	_placement_position.y = 0.0
	_placement_preview.global_position = _placement_position
	_placement_valid = _can_place_building(_placement_preview, _placement_position)
	_placement_preview.set_preview_mode(_placement_valid)
	hud.show_placement_controls(_placement_preview.display_name, _placement_valid)

func _on_placement_confirmed() -> void:
	if not _is_placing_building():
		return
	if not _placement_valid:
		hud.set_hint("Cannot build there.")
		return

	var builder := _get_selected_builder()
	if builder == null:
		_cancel_placement()
		return

	var data: Dictionary = building_data[_placement_building_id]
	var price := int(data.get("price", 0))
	if money < price:
		hud.set_hint("Not enough money for %s." % _placement_preview.display_name)
		return

	money -= price
	_update_match_stats()

	var building := _placement_preview
	_placement_preview = null
	_placement_building_id = ""
	building.name = "%sConstruction" % building.display_name.replace(" ", "")
	building.set_under_construction()

	var build_spot := _nearest_builder_position(building.global_position, building.footprint)
	builder.move_to(build_spot)
	active_builds.append({
		"builder": builder,
		"building": building,
		"build_spot": build_spot,
		"elapsed": 0.0,
		"started": false
	})

	hud.show_builder_controls(true)
	hud.set_hint("Builder moving to construct %s." % building.display_name)

func _cancel_placement() -> void:
	if is_instance_valid(_placement_preview):
		_placement_preview.queue_free()
	_placement_preview = null
	_placement_building_id = ""
	_placement_valid = false
	if _get_selected_builder() != null:
		hud.show_builder_controls(true)
	else:
		hud.show_builder_controls(false)

func _update_active_builds(delta: float) -> void:
	for index in range(active_builds.size() - 1, -1, -1):
		var order := active_builds[index]
		var builder := order.get("builder") as BuilderUnit
		var building := order.get("building") as Building
		if not is_instance_valid(builder) or not is_instance_valid(building):
			active_builds.remove_at(index)
			continue
		var build_spot := order.get("build_spot", building.global_position) as Vector3

		var started := bool(order.get("started", false))
		if not started:
			if builder.global_position.distance_to(build_spot) > 1.25:
				continue
			order["started"] = true
			builder.stop()
			hud.set_hint("Constructing %s." % building.display_name)

		order["elapsed"] = float(order.get("elapsed", 0.0)) + delta
		var progress := float(order["elapsed"]) / maxf(building.build_time, 0.1)
		building.set_construction_progress(progress)

		if progress >= 1.0:
			building.finish_construction()
			_apply_completed_building_stats(building)
			active_builds.remove_at(index)
			if building.building_id != "resource_center":
				hud.set_hint("%s complete." % building.display_name)

func _apply_completed_building_stats(building: Building) -> void:
	power_max += building.power_provided
	power_current += building.power_required
	if building.building_id == "resource_center":
		_spawn_resource_harvester(building)
	if selected_building == building:
		_update_hud_production()
	_update_match_stats()

func _can_place_building(building: Building, at: Vector3) -> bool:
	var half_map := prototype_map.get_half_extents()
	var half_footprint := building.footprint * 0.5
	if at.x - half_footprint.x < -half_map.x or at.x + half_footprint.x > half_map.x:
		return false
	if at.z - half_footprint.y < -half_map.y or at.z + half_footprint.y > half_map.y:
		return false
	if prototype_map.is_area_blocked(at, building.footprint):
		return false

	for existing in get_tree().get_nodes_in_group("buildings"):
		var existing_building := existing as Building
		if existing_building == null or existing_building == building or existing_building.is_preview:
			continue
		var min_distance := maxf(existing_building.footprint.length(), building.footprint.length()) * 0.38
		if existing_building.global_position.distance_to(at) < min_distance:
			return false
	return true

func _nearest_builder_position(center: Vector3, footprint: Vector2) -> Vector3:
	var builder := _get_selected_builder()
	var direction := Vector3(0.0, 0.0, 1.0)
	if builder != null:
		direction = builder.global_position - center
		direction.y = 0.0
		if direction.length_squared() < 0.01:
			direction = Vector3(0.0, 0.0, 1.0)
		direction = direction.normalized()
	var distance := maxf(footprint.x, footprint.y) * 0.5 + 1.6
	var target := center + direction * distance
	var half_map := prototype_map.get_half_extents()
	target.x = clampf(target.x, -half_map.x, half_map.x)
	target.z = clampf(target.z, -half_map.y, half_map.y)
	target.y = 0.45
	return target

func _get_selected_builder() -> BuilderUnit:
	if selected_units.size() == 1 and is_instance_valid(selected_units[0]) and selected_units[0] is BuilderUnit:
		return selected_units[0] as BuilderUnit
	return null

func _is_placing_building() -> bool:
	return is_instance_valid(_placement_preview)

func _update_match_stats() -> void:
	hud.update_match_stats(money, power_current, power_max, unit_count, unit_cap)
	for building_id in building_data.keys():
		hud.set_build_button_enabled(building_id, money >= int(building_data[building_id].get("price", 0)))
	for unit_id in unit_data.keys():
		hud.set_unit_button_enabled(unit_id, _can_afford_and_fit_unit(unit_id))

func _spawn_resource_harvester(resource_center: Building) -> void:
	if unit_count >= unit_cap:
		hud.set_hint("Resource Center complete, but unit cap is full.")
		return

	var resource_point := _get_nearest_resource_point(resource_center.global_position)
	if resource_point == null:
		hud.set_hint("Resource Center complete, but no resource field was found.")
		return

	var harvester := RESOURCE_HARVESTER_SCENE.instantiate() as ResourceHarvester
	harvester.name = "ResourceTruck"
	harvester.setup(resource_center, resource_point, resource_center.team_id)
	harvester.global_position = _harvester_spawn_position(resource_center)
	harvester.resources_delivered.connect(Callable(self, "_on_resources_delivered"))
	units_root.add_child(harvester)
	unit_count += 1
	_update_match_stats()
	hud.set_hint("Resource Truck deployed. It will harvest automatically.")

func _on_resources_delivered(amount: int) -> void:
	money += amount
	_update_match_stats()
	hud.set_hint("Resource delivery +$%d." % amount)

func _get_nearest_resource_point(from_position: Vector3) -> Node3D:
	var nearest: Node3D = null
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("resource_points"):
		var point := node as Node3D
		if point == null:
			continue
		var distance := from_position.distance_to(point.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = point
	return nearest

func _harvester_spawn_position(resource_center: Building) -> Vector3:
	var target := resource_center.global_position + Vector3(resource_center.footprint.x * 0.5 + 1.8, 0.45, 0.0)
	var half_map := prototype_map.get_half_extents()
	target.x = clampf(target.x, -half_map.x, half_map.x)
	target.z = clampf(target.z, -half_map.y, half_map.y)
	return target

func _on_production_requested(unit_id: String) -> void:
	if selected_building == null or not is_instance_valid(selected_building):
		hud.set_hint("Select Barracks or War Factory first.")
		return
	if not selected_building.is_complete:
		hud.set_hint("%s is not ready yet." % selected_building.display_name)
		return
	if not selected_building.produces.has(unit_id):
		hud.set_hint("%s cannot produce that unit." % selected_building.display_name)
		return
	if not unit_data.has(unit_id):
		hud.set_hint("Missing unit data: %s" % unit_id)
		return
	if not _can_afford_and_fit_unit(unit_id):
		hud.set_hint("Not enough money or unit cap for %s." % str(unit_data[unit_id].get("name", unit_id)))
		return

	var data: Dictionary = unit_data[unit_id]
	money -= int(data.get("price", 0))
	unit_count += int(data.get("unit_cap_cost", 1))
	selected_building.production_queue.append(unit_id)
	_start_next_production_if_idle(selected_building)
	_update_match_stats()
	_update_hud_production()

func _on_production_cancel_requested() -> void:
	if selected_building == null or not is_instance_valid(selected_building):
		return

	var cancelled_unit_id := ""
	if not selected_building.production_queue.is_empty():
		cancelled_unit_id = selected_building.production_queue.pop_back()
	else:
		for index in range(active_productions.size() - 1, -1, -1):
			var order := active_productions[index]
			if order.get("building") == selected_building:
				cancelled_unit_id = str(order.get("unit_id", ""))
				active_productions.remove_at(index)
				selected_building.set_production_display("", 0.0, 0)
				break

	if cancelled_unit_id.is_empty() or not unit_data.has(cancelled_unit_id):
		hud.set_hint("Production queue is empty.")
		return

	var data: Dictionary = unit_data[cancelled_unit_id]
	money += int(data.get("price", 0))
	unit_count = max(0, unit_count - int(data.get("unit_cap_cost", 1)))
	hud.set_hint("Cancelled %s." % str(data.get("name", cancelled_unit_id)))
	_start_next_production_if_idle(selected_building)
	_update_match_stats()
	_update_hud_production()

func _update_active_productions(delta: float) -> void:
	for index in range(active_productions.size() - 1, -1, -1):
		var order := active_productions[index]
		var building := order.get("building") as Building
		if not is_instance_valid(building):
			active_productions.remove_at(index)
			continue

		var unit_id := str(order.get("unit_id", ""))
		if not unit_data.has(unit_id):
			active_productions.remove_at(index)
			continue

		var data: Dictionary = unit_data[unit_id]
		order["elapsed"] = float(order.get("elapsed", 0.0)) + delta
		var progress := float(order["elapsed"]) / maxf(float(data.get("production_time", 1.0)), 0.1)
		building.set_production_display(str(data.get("name", unit_id)), progress, building.production_queue.size())

		if progress >= 1.0:
			active_productions.remove_at(index)
			_spawn_produced_unit(unit_id, building)
			building.set_production_display("", 0.0, building.production_queue.size())
			_start_next_production_if_idle(building)
			if selected_building == building:
				_update_hud_production()

	if selected_building != null and is_instance_valid(selected_building) and selected_building.produces.size() > 0:
		_update_hud_production()

func _start_next_production_if_idle(building: Building) -> void:
	if _is_building_producing(building) or building.production_queue.is_empty():
		return
	var unit_id := building.production_queue.pop_front()
	active_productions.append({
		"building": building,
		"unit_id": unit_id,
		"elapsed": 0.0
	})

func _is_building_producing(building: Building) -> bool:
	for order in active_productions:
		if order.get("building") == building:
			return true
	return false

func _spawn_produced_unit(unit_id: String, building: Building) -> void:
	var data: Dictionary = unit_data[unit_id]
	var unit := COMBAT_UNIT_SCENE.instantiate() as CombatUnit
	unit.name = str(data.get("name", unit_id)).replace(" ", "")
	unit.configure(data, building.team_id)
	unit.global_position = _unit_spawn_position(building)
	units_root.add_child(unit)
	hud.set_hint("%s ready." % unit.display_name)
	_update_group_counts()

func _unit_spawn_position(building: Building) -> Vector3:
	var offset := Vector3(building.footprint.x * 0.5 + 2.6, 0.45, building.production_queue.size() * 1.2)
	var target := building.global_position + offset
	var half_map := prototype_map.get_half_extents()
	target.x = clampf(target.x, -half_map.x, half_map.x)
	target.z = clampf(target.z, -half_map.y, half_map.y)
	return target

func _can_afford_and_fit_unit(unit_id: String) -> bool:
	if not unit_data.has(unit_id):
		return false
	var data: Dictionary = unit_data[unit_id]
	return money >= int(data.get("price", 0)) and unit_count + int(data.get("unit_cap_cost", 1)) <= unit_cap

func _update_hud_production() -> void:
	if selected_building == null or not is_instance_valid(selected_building) or selected_building.produces.is_empty():
		return

	var available_units: Array = []
	for unit_id in selected_building.produces:
		if unit_data.has(unit_id):
			available_units.append(unit_data[unit_id])

	var queue_names: Array[String] = []
	var progress := 0.0
	for order in active_productions:
		if order.get("building") == selected_building:
			var active_unit_id := str(order.get("unit_id", ""))
			if unit_data.has(active_unit_id):
				queue_names.append(str(unit_data[active_unit_id].get("name", active_unit_id)))
				var data: Dictionary = unit_data[active_unit_id]
				progress = float(order.get("elapsed", 0.0)) / maxf(float(data.get("production_time", 1.0)), 0.1)
			break
	for queued_unit_id in selected_building.production_queue:
		if unit_data.has(queued_unit_id):
			queue_names.append(str(unit_data[queued_unit_id].get("name", queued_unit_id)))

	hud.show_production_controls(selected_building.display_name, available_units, queue_names, progress)

func _on_army_filter_requested(filter_id: String, visible_only: bool) -> void:
	var matching_units: Array[MobileUnit] = []
	for node in get_tree().get_nodes_in_group("player_units"):
		var unit := node as MobileUnit
		if unit == null or not is_instance_valid(unit) or not (unit is CombatUnit):
			continue
		if visible_only and not camera_controller.get_camera().is_position_in_frustum(unit.global_position):
			continue
		if _unit_matches_filter(unit, filter_id):
			matching_units.append(unit)
	_select_units(matching_units)
	hud.set_hint("Selected %d unit(s) for %s." % [matching_units.size(), filter_id])

func _on_army_command_requested(command_id: String) -> void:
	if command_id == "stop":
		_stop_selected_units()
		return
	if not _has_army_selection():
		hud.set_hint("Select combat units first.")
		return
	_pending_army_command = command_id
	match command_id:
		"move":
			hud.set_hint("MOVE: tap terrain.")
		"attack_move":
			hud.set_hint("ATTACK MOVE: tap destination.")
		"attack":
			hud.set_hint("ATTACK: tap an enemy target after Milestone 6 adds enemies.")

func _on_group_saved(group_id: int) -> void:
	if not army_groups.has(group_id):
		return
	var saved: Array[MobileUnit] = []
	for unit in selected_units:
		if is_instance_valid(unit) and unit.team_id == 1 and unit is CombatUnit:
			saved.append(unit)
	army_groups[group_id] = saved
	_update_group_counts()
	hud.set_hint("Group %d saved with %d unit(s)." % [group_id, saved.size()])

func _on_group_selected(group_id: int) -> void:
	if not army_groups.has(group_id):
		return
	var live_units: Array[MobileUnit] = []
	for unit in army_groups[group_id]:
		if is_instance_valid(unit):
			live_units.append(unit)
	army_groups[group_id] = live_units
	_select_units(live_units)
	hud.set_hint("Group %d selected: %d unit(s)." % [group_id, live_units.size()])

func _process_pending_army_command(hit: Dictionary) -> void:
	if _pending_army_command == "move" and _is_ground_hit(hit):
		_move_selected_to(hit.position)
	elif _pending_army_command == "attack_move" and _is_ground_hit(hit):
		_attack_move_selected_to(hit.position)
	elif _pending_army_command == "attack":
		hud.set_hint("Attack target handling comes with combat in Milestone 6.")
		_pending_army_command = ""

func _unit_matches_filter(unit: MobileUnit, filter_id: String) -> bool:
	match filter_id:
		"all":
			return true
		"infantry":
			return unit.has_tag("infantry")
		"rpg":
			return unit.unit_type == "rpg_soldier" or unit.has_tag("rpg")
		"tanks":
			return unit.has_tag("tank")
		_:
			return false

func _has_army_selection() -> bool:
	for unit in selected_units:
		if is_instance_valid(unit) and unit is CombatUnit:
			return true
	return false

func _combat_selection_count() -> int:
	var count := 0
	for unit in selected_units:
		if is_instance_valid(unit) and unit is CombatUnit:
			count += 1
	return count

func _update_group_counts() -> void:
	for group_id in army_groups.keys():
		var live_units: Array[MobileUnit] = []
		for unit in army_groups[group_id]:
			if is_instance_valid(unit):
				live_units.append(unit)
		army_groups[group_id] = live_units
		hud.set_group_count(group_id, live_units.size())
