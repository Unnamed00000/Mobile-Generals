class_name PrototypeMap
extends Node3D

@export var map_size := Vector2(120.0, 80.0)

var player_start := Vector3(-42.0, 0.45, 24.0)
var enemy_start := Vector3(42.0, 0.45, -24.0)

func _ready() -> void:
	_build_ground()
	_build_roads()
	_build_terrain_details()
	_build_start_markers()

func get_half_extents() -> Vector2:
	return map_size * 0.5

func _build_ground() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = map_size

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.54, 0.46, 0.33)
	material.roughness = 0.95

	var terrain := MeshInstance3D.new()
	terrain.name = "DryTerrain"
	terrain.mesh = mesh
	terrain.material_override = material
	add_child(terrain)

	var body := StaticBody3D.new()
	body.name = "GroundCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("command_ground")
	add_child(body)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(map_size.x, 0.25, map_size.y)
	shape.shape = box
	shape.position.y = -0.14
	body.add_child(shape)

func _build_roads() -> void:
	_add_flat_box("MainRoad", Vector3.ZERO, Vector3(112.0, 0.03, 6.0), Color(0.24, 0.23, 0.21), 8.0)
	_add_flat_box("CrossRoad", Vector3(10.0, 0.02, 0.0), Vector3(6.0, 0.03, 70.0), Color(0.25, 0.24, 0.22), -12.0)

func _build_terrain_details() -> void:
	var rocks := [
		Vector3(-17.0, 0.4, 4.0),
		Vector3(-9.0, 0.4, 9.5),
		Vector3(19.0, 0.4, -7.5),
		Vector3(27.0, 0.4, -14.0),
		Vector3(5.0, 0.4, 24.0)
	]
	for i in rocks.size():
		_add_obstacle("Rock%02d" % i, rocks[i], Vector3(3.2, 1.2, 2.5), Color(0.36, 0.34, 0.31))

	var wrecks := [
		Vector3(-2.0, 0.3, -18.0),
		Vector3(33.0, 0.3, 11.0)
	]
	for i in wrecks.size():
		_add_flat_box("Wreck%02d" % i, wrecks[i], Vector3(7.0, 0.6, 3.0), Color(0.22, 0.24, 0.23), 23.0 + i * 19.0)

	var resource_marker := _make_cylinder("ResourceField", 5.5, 0.35, Color(0.72, 0.80, 0.88))
	resource_marker.position = Vector3(-32.0, 0.18, -12.0)
	resource_marker.add_to_group("resource_points")
	add_child(resource_marker)

	for i in 9:
		var angle := float(i) * TAU / 9.0
		var pos := resource_marker.position + Vector3(cos(angle) * 4.1, 0.3, sin(angle) * 2.6)
		_add_flat_box("ResourceCrate%02d" % i, pos, Vector3(1.2, 0.55, 0.9), Color(0.70, 0.77, 0.83), rad_to_deg(angle))

func _build_start_markers() -> void:
	_add_start_pad("PlayerStartPad", player_start, Color(0.12, 0.38, 0.85))
	_add_start_pad("EnemyStartPad", enemy_start, Color(0.75, 0.16, 0.14))

func _add_start_pad(label: String, at: Vector3, color: Color) -> void:
	var pad := _make_cylinder(label, 4.0, 0.08, color)
	pad.position = Vector3(at.x, 0.04, at.z)
	add_child(pad)

func _add_obstacle(label: String, at: Vector3, size: Vector3, color: Color) -> void:
	var mesh_instance := _make_box(label, size, color)
	mesh_instance.position = at
	mesh_instance.rotation_degrees.y = randf_range(-25.0, 25.0)
	add_child(mesh_instance)

	var body := StaticBody3D.new()
	body.name = "%sCollision" % label
	body.position = at
	body.collision_layer = 4
	body.collision_mask = 0
	add_child(body)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

func _add_flat_box(label: String, at: Vector3, size: Vector3, color: Color, yaw_degrees: float) -> void:
	var mesh_instance := _make_box(label, size, color)
	mesh_instance.position = at
	mesh_instance.rotation_degrees.y = yaw_degrees
	add_child(mesh_instance)

func _make_box(label: String, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	return mesh_instance

func _make_cylinder(label: String, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	return mesh_instance
