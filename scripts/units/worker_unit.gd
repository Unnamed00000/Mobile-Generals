class_name WorkerUnit
extends MobileUnit

func _ready() -> void:
	display_name = "Worker"
	unit_type = "worker"
	move_speed = 6.2
	unit_tags.clear()
	unit_tags.append("worker")
	super()
