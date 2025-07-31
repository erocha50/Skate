extends Node3D

var smooth_movement = true
var movement_speed = 8.0
var target_position = Vector3.ZERO

func _ready():
	target_position = position

func _process(delta):
	if smooth_movement:
		position = position.lerp(target_position, movement_speed * delta)

func move_to_position(new_position: Vector3):
	target_position = new_position

func set_immediate_position(new_position: Vector3):
	position = new_position
	target_position = new_position
