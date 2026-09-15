class_name MatchController
extends Node3D

const BUILDER_SCENE := preload("res://scenes/units/builder.tscn")
const RESOURCE_HARVESTER_SCENE := preload("res://scenes/units/resource_harvester.tscn")
const BUILDING_DATA_PATHS := {
	"power_plant": "res://data/buildings/power_plant.json",
	"resource_center": "res://data/buildings/resource_center.json",
	"barracks": "res://data/buildings/barracks.json",
	"war_factory": "res://data/buildings/war_factory.json",
	"defense_turret": "res://data/buildings/defense_turret.json"
}

@onready var prototype_map: PrototypeMap = $PrototypeMap
@onready var camera_controller: RtsCamera = $CameraRig
@onready var units_root: Node3D = $Units
@onready var buildings_root: Node3D = $Buildings
@onready var hud: MatchHud = $MatchHUD

var selected_units: Array[MobileUnit] = []
var money := 10000
var power_current := 0
var power_max := 0
var unit_count := 1
var unit_cap := 60

var building_data: Dictionary = {}
var active_builds: Array[Dictionary] = []

var _primary_touch_start := Vector2.ZERO
var _primary_touch_dragged := false
var _last_mouse_position := Vector2.ZERO
var _command_marker: MeshInstance3D
var _placement_preview: Building
var _placement_building_id := ""
var _placement_position := Vector3.ZERO
var _placement_valid := false

func _ready() -> void:
	_load_building_data()
	hud.build_requested.connect(Callable(self, "_on_build_requested"))
	hud.placement_confirmed.connect(Callable(self, "_on_placement_confirmed"))
	hud.placement_cancelled.connect(Callable(self, "_cancel_placement"))
	camera_controller.set_map_half_extents(prototype_map.get_half_extents())
	_spawn_builder()
	_create_command_marker()
	_update_match_stats()
	_update_hud_selection()

func _physics_process(delta: float) -> void:
	_update_active_builds(delta)

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
		hud.show_builder_controls(false)
	elif selected_units.size() == 1 and is_instance_valid(selected_units[0]):
		hud.update_selection(1, selected_units[0].display_name)
		hud.show_builder_controls(selected_units[0] is BuilderUnit and not _is_placing_building())
	else:
		hud.update_selection(selected_units.size(), "Units")
		hud.show_builder_controls(false)

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
