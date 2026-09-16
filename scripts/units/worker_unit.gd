class_name WorkerUnit
extends MobileUnit

func _ready() -> void:
	display_name = "Worker"
	unit_type = "worker"
	move_speed = 6.2
	unit_tags.clear()
	unit_tags.append("worker")
	super()
	_apply_worker_visual()

func _apply_worker_visual() -> void:
	var old_body := get_node_or_null("Body") as MeshInstance3D
	if old_body != null:
		old_body.visible = false
	var old_pack := get_node_or_null("Pack") as MeshInstance3D
	if old_pack != null:
		old_pack.visible = false

	var uniform_material := _make_material(Color(0.16, 0.42, 0.50))
	var vest_material := _make_material(Color(0.86, 0.68, 0.22))
	var skin_material := _make_material(Color(0.68, 0.52, 0.40))
	var boot_material := _make_material(Color(0.08, 0.08, 0.07))
	var tool_material := _make_material(Color(0.12, 0.13, 0.14))

	_add_part("WorkerBody", _make_capsule_mesh(0.27, 1.08), uniform_material, Vector3(0.0, 0.60, 0.0))
	_add_part("SafetyVest", _make_box_mesh(Vector3(0.42, 0.58, 0.10)), vest_material, Vector3(0.0, 0.78, -0.23))
	_add_part("Head", _make_sphere_mesh(0.20), skin_material, Vector3(0.0, 1.32, 0.0))
	_add_part("HardHat", _make_cylinder_mesh(0.23, 0.13), vest_material, Vector3(0.0, 1.51, 0.0))
	_add_part("ToolPack", _make_box_mesh(Vector3(0.42, 0.42, 0.22)), tool_material, Vector3(0.0, 0.72, 0.34))
	_add_part("LeftArm", _make_cylinder_mesh(0.055, 0.55), uniform_material, Vector3(-0.33, 0.78, -0.03), Vector3(20.0, 0.0, -18.0))
	_add_part("RightArm", _make_cylinder_mesh(0.055, 0.55), uniform_material, Vector3(0.33, 0.78, -0.03), Vector3(24.0, 0.0, 18.0))
	_add_part("ToolHandle", _make_cylinder_mesh(0.035, 0.70), tool_material, Vector3(0.48, 0.76, -0.08), Vector3(38.0, 0.0, 24.0))
	_add_part("LeftLeg", _make_cylinder_mesh(0.06, 0.56), boot_material, Vector3(-0.13, 0.10, 0.0))
	_add_part("RightLeg", _make_cylinder_mesh(0.06, 0.56), boot_material, Vector3(0.13, 0.10, 0.0))

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.84
	return material

func _make_capsule_mesh(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 3
	return mesh

func _make_sphere_mesh(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return mesh

func _make_cylinder_mesh(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	return mesh

func _make_box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

func _add_part(label: String, mesh: Mesh, material: Material, local_position: Vector3, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	part.material_override = material
	part.position = local_position
	part.rotation_degrees = rotation
	add_child(part)
	return part
