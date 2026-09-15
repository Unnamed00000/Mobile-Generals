class_name Building
extends StaticBody3D

signal destroyed(building: Building)

@export var building_id := ""
@export var display_name := "Building"
@export var team_id := 1
@export var footprint := Vector2(5.0, 5.0)
@export var price := 0
@export var build_time := 5.0
@export var max_hp := 1000
@export var power_provided := 0
@export var power_required := 0
@export var produces: Array[String] = []

var is_preview := false
var is_complete := false
var construction_progress := 0.0
var production_queue: Array[String] = []
var current_production_id := ""
var production_progress := 0.0
var current_hp := 1000

var _body_mesh: MeshInstance3D
var _progress_label: Label3D
var _production_label: Label3D
var _health_label: Label3D
var _ready_material: StandardMaterial3D
var _valid_preview_material: StandardMaterial3D
var _invalid_preview_material: StandardMaterial3D
var _construction_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("buildings")
	add_to_group("combat_targets")
	if team_id == 1:
		add_to_group("player_buildings")
	else:
		add_to_group("enemy_buildings")
	_build_placeholder_model()

func configure(data: Dictionary, new_team_id: int) -> void:
	building_id = str(data.get("id", building_id))
	display_name = str(data.get("name", display_name))
	price = int(data.get("price", price))
	build_time = float(data.get("build_time", build_time))
	max_hp = int(data.get("hp", max_hp))
	current_hp = max_hp
	power_provided = int(data.get("power_provided", power_provided))
	power_required = int(data.get("power_required", power_required))
	produces.clear()
	for unit_id in data.get("produces", []):
		produces.append(str(unit_id))
	var footprint_value: Array = data.get("footprint", [footprint.x, footprint.y])
	if footprint_value.size() >= 2:
		footprint = Vector2(float(footprint_value[0]), float(footprint_value[1]))
	team_id = new_team_id

func set_preview_mode(valid: bool) -> void:
	is_preview = true
	is_complete = false
	collision_layer = 0
	collision_mask = 0
	if not is_inside_tree():
		await ready
	_body_mesh.material_override = _valid_preview_material if valid else _invalid_preview_material
	_progress_label.visible = false

func set_under_construction() -> void:
	is_preview = false
	is_complete = false
	collision_layer = 4
	collision_mask = 0
	if not is_inside_tree():
		await ready
	_body_mesh.material_override = _construction_material
	set_construction_progress(0.0)

func set_construction_progress(value: float) -> void:
	construction_progress = clampf(value, 0.0, 1.0)
	if not is_instance_valid(_progress_label):
		return
	_progress_label.visible = true
	_progress_label.text = "Construction %d%%" % int(round(construction_progress * 100.0))

func finish_construction() -> void:
	is_complete = true
	construction_progress = 1.0
	current_hp = max_hp
	if is_instance_valid(_body_mesh):
		_body_mesh.material_override = _ready_material
	if is_instance_valid(_progress_label):
		_progress_label.text = display_name
		_progress_label.visible = true
	_update_health_display()

func take_damage(amount: int, _source: Node = null) -> void:
	if is_preview or not is_complete:
		return
	current_hp = maxi(0, current_hp - maxi(1, amount))
	_update_health_display()
	if current_hp <= 0:
		destroyed.emit(self)
		queue_free()

func set_production_display(unit_name: String, progress: float, queued_count: int) -> void:
	current_production_id = unit_name
	production_progress = clampf(progress, 0.0, 1.0)
	if not is_instance_valid(_production_label):
		return
	if unit_name.is_empty():
		_production_label.visible = false
		return
	_production_label.visible = true
	_production_label.text = "Producing %s %d%% | Queue %d" % [unit_name, int(round(production_progress * 100.0)), queued_count]

func _build_placeholder_model() -> void:
	_ready_material = _make_material(_color_for_building(), 1.0)
	_valid_preview_material = _make_material(Color(0.12, 0.88, 0.28), 0.42)
	_invalid_preview_material = _make_material(Color(0.95, 0.12, 0.10), 0.42)
	_construction_material = _make_material(Color(0.58, 0.60, 0.58), 0.86)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(footprint.x, _height_for_building(), footprint.y)

	_body_mesh = MeshInstance3D.new()
	_body_mesh.name = "Body"
	_body_mesh.mesh = mesh
	_body_mesh.position.y = mesh.size.y * 0.5
	_body_mesh.material_override = _ready_material
	add_child(_body_mesh)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = mesh.size
	shape.shape = box
	shape.position = _body_mesh.position
	add_child(shape)

	_progress_label = Label3D.new()
	_progress_label.name = "ProgressLabel"
	_progress_label.text = display_name
	_progress_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_progress_label.position = Vector3(0.0, mesh.size.y + 0.9, 0.0)
	_progress_label.modulate = Color(1.0, 1.0, 1.0)
	_progress_label.outline_size = 8
	_progress_label.visible = false
	add_child(_progress_label)

	_production_label = Label3D.new()
	_production_label.name = "ProductionLabel"
	_production_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_production_label.position = Vector3(0.0, mesh.size.y + 1.55, 0.0)
	_production_label.modulate = Color(0.82, 0.95, 1.0)
	_production_label.outline_size = 8
	_production_label.visible = false
	add_child(_production_label)

	_health_label = Label3D.new()
	_health_label.name = "HealthLabel"
	_health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_label.position = Vector3(0.0, mesh.size.y + 2.15, 0.0)
	_health_label.modulate = Color(0.70, 1.0, 0.72)
	_health_label.outline_size = 8
	_health_label.visible = false
	add_child(_health_label)

func _make_material(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.roughness = 0.82
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func _height_for_building() -> float:
	match building_id:
		"power_plant":
			return 3.6
		"resource_center":
			return 2.8
		"barracks":
			return 2.3
		"war_factory":
			return 3.1
		"defense_turret":
			return 2.7
		_:
			return 2.5

func _color_for_building() -> Color:
	match building_id:
		"power_plant":
			return Color(0.18, 0.42, 0.86)
		"resource_center":
			return Color(0.22, 0.56, 0.66)
		"barracks":
			return Color(0.24, 0.37, 0.64)
		"war_factory":
			return Color(0.30, 0.33, 0.37)
		"defense_turret":
			return Color(0.44, 0.45, 0.42)
		"enemy_hq":
			return Color(0.56, 0.18, 0.16)
		_:
			return Color(0.35, 0.39, 0.44)

func _update_health_display() -> void:
	if not is_instance_valid(_health_label):
		return
	if current_hp >= max_hp:
		_health_label.visible = false
		return
	var percent := float(current_hp) / maxf(float(max_hp), 1.0)
	_health_label.visible = true
	_health_label.text = "HP %d/%d" % [current_hp, max_hp]
	if percent > 0.55:
		_health_label.modulate = Color(0.70, 1.0, 0.72)
	elif percent > 0.25:
		_health_label.modulate = Color(1.0, 0.88, 0.34)
	else:
		_health_label.modulate = Color(1.0, 0.32, 0.28)
