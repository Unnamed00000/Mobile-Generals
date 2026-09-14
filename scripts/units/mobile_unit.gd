class_name MobileUnit
extends CharacterBody3D

signal command_completed(unit: MobileUnit)

@export var display_name := "Unit"
@export var unit_type := "unit"
@export var team_id := 1
@export var move_speed := 7.0
@export var stopping_distance := 0.45

@onready var selection_ring: MeshInstance3D = $SelectionRing

var is_selected := false
var destination: Vector3
var has_move_order := false

func _ready() -> void:
	add_to_group("selectable")
	if team_id == 1:
		add_to_group("player_units")
	else:
		add_to_group("enemy_units")
	destination = global_position
	set_selected(false)

func _physics_process(_delta: float) -> void:
	if not has_move_order:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var offset := destination - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance <= stopping_distance:
		has_move_order = false
		velocity = Vector3.ZERO
		move_and_slide()
		command_completed.emit(self)
		return

	var direction := offset.normalized()
	velocity = direction * move_speed
	move_and_slide()
	_look_towards(direction)

func set_selected(value: bool) -> void:
	is_selected = value
	if is_instance_valid(selection_ring):
		selection_ring.visible = value

func move_to(world_position: Vector3) -> void:
	destination = world_position
	destination.y = global_position.y
	has_move_order = true

func stop() -> void:
	has_move_order = false
	velocity = Vector3.ZERO

func _look_towards(direction: Vector3) -> void:
	if direction.length_squared() <= 0.001:
		return
	var target_basis := Basis.looking_at(direction, Vector3.UP)
	basis = basis.slerp(target_basis, 0.22)

