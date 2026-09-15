class_name ResourceHarvester
extends MobileUnit

signal resources_delivered(amount: int)

enum HarvestState {
	TO_RESOURCE,
	LOADING,
	TO_CENTER,
	UNLOADING
}

@export var delivery_amount := 500
@export var load_time := 1.2
@export var unload_time := 0.8

var resource_center: Building
var resource_point: Node3D
var harvest_state := HarvestState.TO_RESOURCE
var state_timer := 0.0
var _status_label: Label3D
var _allow_economy_move := false

func setup(center: Building, point: Node3D, new_team_id: int) -> void:
	resource_center = center
	resource_point = point
	team_id = new_team_id

func _ready() -> void:
	display_name = "Resource Truck"
	unit_type = "resource_harvester"
	move_speed = 7.5
	super()
	_build_status_label()
	_route_to_resource()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(resource_center) or not is_instance_valid(resource_point):
		stop()
		_set_status("Idle")
		return

	super(delta)

	match harvest_state:
		HarvestState.TO_RESOURCE:
			_set_status("To resource")
			if not has_move_order:
				_enter_loading()
		HarvestState.LOADING:
			_tick_loading(delta)
		HarvestState.TO_CENTER:
			_set_status("Returning")
			if not has_move_order:
				_enter_unloading()
		HarvestState.UNLOADING:
			_tick_unloading(delta)

func _route_to_resource() -> void:
	if not is_instance_valid(resource_point):
		return
	harvest_state = HarvestState.TO_RESOURCE
	_economy_move_to(_resource_pickup_position())

func move_to(world_position: Vector3) -> void:
	if _allow_economy_move:
		super.move_to(world_position)

func _enter_loading() -> void:
	harvest_state = HarvestState.LOADING
	state_timer = load_time
	stop()
	_set_status("Loading")

func _tick_loading(delta: float) -> void:
	state_timer -= delta
	_set_status("Loading")
	if state_timer <= 0.0:
		harvest_state = HarvestState.TO_CENTER
		_economy_move_to(_center_dropoff_position())

func _enter_unloading() -> void:
	harvest_state = HarvestState.UNLOADING
	state_timer = unload_time
	stop()
	_set_status("Unloading")

func _tick_unloading(delta: float) -> void:
	state_timer -= delta
	_set_status("Unloading")
	if state_timer <= 0.0:
		resources_delivered.emit(delivery_amount)
		_route_to_resource()

func _resource_pickup_position() -> Vector3:
	var offset := global_position - resource_point.global_position
	offset.y = 0.0
	if offset.length_squared() < 0.01:
		offset = Vector3(1.0, 0.0, 0.0)
	return resource_point.global_position + offset.normalized() * 4.2

func _center_dropoff_position() -> Vector3:
	var offset := global_position - resource_center.global_position
	offset.y = 0.0
	if offset.length_squared() < 0.01:
		offset = Vector3(0.0, 0.0, 1.0)
	var distance := maxf(resource_center.footprint.x, resource_center.footprint.y) * 0.5 + 1.5
	return resource_center.global_position + offset.normalized() * distance

func _build_status_label() -> void:
	_status_label = Label3D.new()
	_status_label.name = "StatusLabel"
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label.position = Vector3(0.0, 1.65, 0.0)
	_status_label.outline_size = 6
	_status_label.visible = false
	add_child(_status_label)

func _set_status(text: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = text
		_status_label.visible = true

func _economy_move_to(world_position: Vector3) -> void:
	_allow_economy_move = true
	move_to(world_position)
	_allow_economy_move = false
