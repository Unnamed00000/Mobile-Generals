class_name CombatUnit
extends MobileUnit

@export var hp := 100
@export var armor := 0
@export var damage := 10
@export var attack_range := 8.0
@export var fire_rate := 1.0
@export var unit_cap_cost := 1

@onready var body_mesh: MeshInstance3D = $Body
@onready var accent_mesh: MeshInstance3D = $Accent
@onready var unit_label: Label3D = $UnitLabel

func configure(data: Dictionary, new_team_id: int) -> void:
	display_name = str(data.get("name", display_name))
	unit_type = str(data.get("id", unit_type))
	hp = int(data.get("hp", hp))
	armor = int(data.get("armor", armor))
	move_speed = float(data.get("speed", move_speed))
	damage = int(data.get("damage", damage))
	attack_range = float(data.get("range", attack_range))
	fire_rate = float(data.get("fire_rate", fire_rate))
	unit_cap_cost = int(data.get("unit_cap_cost", unit_cap_cost))
	team_id = new_team_id

func _ready() -> void:
	super()
	_apply_placeholder_visual()

func _apply_placeholder_visual() -> void:
	if is_instance_valid(unit_label):
		unit_label.text = display_name
		unit_label.visible = true

	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = _body_color()
	body_material.roughness = 0.78

	var accent_material := StandardMaterial3D.new()
	accent_material.albedo_color = _accent_color()
	accent_material.roughness = 0.72

	if is_instance_valid(body_mesh):
		body_mesh.material_override = body_material
		body_mesh.scale = _body_scale()

	if is_instance_valid(accent_mesh):
		accent_mesh.material_override = accent_material
		accent_mesh.scale = _accent_scale()
		accent_mesh.position = _accent_position()

func _body_color() -> Color:
	match unit_type:
		"rifleman":
			return Color(0.16, 0.34, 0.66)
		"rpg_soldier":
			return Color(0.18, 0.45, 0.38)
		"main_battle_tank":
			return Color(0.22, 0.25, 0.28)
		_:
			return Color(0.22, 0.35, 0.55)

func _accent_color() -> Color:
	match unit_type:
		"rpg_soldier":
			return Color(0.74, 0.72, 0.48)
		"main_battle_tank":
			return Color(0.40, 0.42, 0.40)
		_:
			return Color(0.70, 0.76, 0.82)

func _body_scale() -> Vector3:
	match unit_type:
		"main_battle_tank":
			return Vector3(1.9, 0.75, 2.35)
		_:
			return Vector3(0.75, 1.2, 0.75)

func _accent_scale() -> Vector3:
	match unit_type:
		"main_battle_tank":
			return Vector3(1.0, 0.45, 1.0)
		"rpg_soldier":
			return Vector3(0.25, 0.25, 1.2)
		_:
			return Vector3(0.2, 0.2, 0.75)

func _accent_position() -> Vector3:
	match unit_type:
		"main_battle_tank":
			return Vector3(0.0, 0.78, -0.25)
		"rpg_soldier":
			return Vector3(0.0, 1.15, -0.2)
		_:
			return Vector3(0.0, 1.0, -0.25)

