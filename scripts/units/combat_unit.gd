class_name CombatUnit
extends MobileUnit

signal destroyed(unit: CombatUnit)

@export var hp := 100
@export var armor := 0
@export var damage := 10
@export var attack_range := 8.0
@export var fire_rate := 1.0
@export var unit_cap_cost := 1

@onready var body_mesh: MeshInstance3D = $Body
@onready var accent_mesh: MeshInstance3D = $Accent
@onready var unit_label: Label3D = $UnitLabel
@onready var health_label: Label3D = $HealthLabel

var current_hp := 100
var attack_target: Node3D
var _fire_cooldown := 0.0
var _scan_timer := 0.0

func configure(data: Dictionary, new_team_id: int) -> void:
	display_name = str(data.get("name", display_name))
	unit_type = str(data.get("id", unit_type))
	hp = int(data.get("hp", hp))
	current_hp = hp
	armor = int(data.get("armor", armor))
	move_speed = float(data.get("speed", move_speed))
	damage = int(data.get("damage", damage))
	attack_range = float(data.get("range", attack_range))
	fire_rate = float(data.get("fire_rate", fire_rate))
	unit_cap_cost = int(data.get("unit_cap_cost", unit_cap_cost))
	unit_tags.clear()
	for tag in data.get("tags", []):
		unit_tags.append(str(tag))
	team_id = new_team_id

func _ready() -> void:
	super()
	add_to_group("combat_targets")
	_apply_placeholder_visual()
	_update_health_display()

func _physics_process(delta: float) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_scan_timer = maxf(0.0, _scan_timer - delta)

	if not _is_attack_target_valid():
		attack_target = null

	if attack_target == null and _should_auto_acquire() and _scan_timer <= 0.0:
		attack_target = _find_nearest_enemy_target()
		_scan_timer = 0.45

	if attack_target != null:
		_update_attack_order(delta)
		return

	super(delta)

func set_attack_target(target: Node3D) -> void:
	if not _is_enemy_target(target):
		return
	attack_target = target
	command_mode = "attack"

func attack_move_to(world_position: Vector3) -> void:
	attack_target = null
	super.attack_move_to(world_position)

func move_to(world_position: Vector3) -> void:
	attack_target = null
	super.move_to(world_position)

func stop() -> void:
	attack_target = null
	super.stop()

func take_damage(amount: int, _source: Node = null) -> void:
	var final_damage: int = maxi(1, amount - armor)
	current_hp = maxi(0, current_hp - final_damage)
	_update_health_display()
	if current_hp <= 0:
		destroyed.emit(self)
		queue_free()

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
	if team_id != 1:
		return Color(0.66, 0.18, 0.16)
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

func _update_attack_order(_delta: float) -> void:
	var target_position := attack_target.global_position
	var distance := global_position.distance_to(target_position)
	if distance > attack_range:
		destination = target_position
		destination.y = global_position.y
		has_move_order = true
		command_mode = "attack"
		_follow_attack_target()
		return

	has_move_order = false
	velocity = Vector3.ZERO
	move_and_slide()
	var direction := target_position - global_position
	direction.y = 0.0
	_look_towards(direction.normalized())
	if _fire_cooldown <= 0.0:
		_apply_damage_to_target()
		_fire_cooldown = 1.0 / maxf(fire_rate, 0.05)

func _follow_attack_target() -> void:
	var offset := destination - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance <= stopping_distance:
		has_move_order = false
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var direction := offset.normalized()
	velocity = direction * move_speed
	move_and_slide()
	_look_towards(direction)

func _apply_damage_to_target() -> void:
	if attack_target == null:
		return
	if attack_target.has_method("take_damage"):
		attack_target.call("take_damage", damage, self)
	_flash_attack()

func _flash_attack() -> void:
	if not is_instance_valid(accent_mesh):
		return
	var tween := create_tween()
	accent_mesh.scale = _accent_scale() * 1.25
	tween.tween_property(accent_mesh, "scale", _accent_scale(), 0.12)

func _find_nearest_enemy_target() -> Node3D:
	var nearest: Node3D = null
	var nearest_distance: float = INF
	for node in get_tree().get_nodes_in_group("combat_targets"):
		var target := node as Node3D
		if not _is_enemy_target(target):
			continue
		var distance := global_position.distance_to(target.global_position)
		if distance <= attack_range and distance < nearest_distance:
			nearest = target
			nearest_distance = distance
	return nearest

func _is_attack_target_valid() -> bool:
	return is_instance_valid(attack_target) and _is_enemy_target(attack_target)

func _is_enemy_target(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target is CombatUnit:
		return (target as CombatUnit).team_id != team_id and (target as CombatUnit).current_hp > 0
	if target is Building:
		var building := target as Building
		return building.team_id != team_id and building.is_complete and building.current_hp > 0
	return false

func _should_auto_acquire() -> bool:
	return command_mode == "attack_move" or command_mode == "idle" or command_mode == "move"

func _update_health_display() -> void:
	if not is_instance_valid(health_label):
		return
	if current_hp >= hp:
		health_label.visible = false
		return
	var percent := float(current_hp) / maxf(float(hp), 1.0)
	health_label.visible = true
	health_label.text = "HP %d/%d" % [current_hp, hp]
	if percent > 0.55:
		health_label.modulate = Color(0.70, 1.0, 0.72)
	elif percent > 0.25:
		health_label.modulate = Color(1.0, 0.88, 0.34)
	else:
		health_label.modulate = Color(1.0, 0.32, 0.28)
