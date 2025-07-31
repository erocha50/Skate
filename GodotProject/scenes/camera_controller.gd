extends Node3D

@onready var camera = $Camera3D

var camera_positions = {
	"default": Vector3(0, 3, 8),
	"close": Vector3(0, 2, 5),
	"overview": Vector3(0, 5, 12)
}

var camera_rotations = {
	"default": Vector3(-20, 0, 0),
	"close": Vector3(-15, 0, 0), 
	"overview": Vector3(-25, 0, 0)
}

var current_view = "default"
var transition_speed = 3.0
var target_position = Vector3.ZERO
var target_rotation = Vector3.ZERO

func _ready():
	set_camera_view("default")

func _process(delta):
	# Smooth camera transitions
	position = position.lerp(target_position, transition_speed * delta)
	rotation_degrees = rotation_degrees.lerp(target_rotation, transition_speed * delta)

func set_camera_view(view_name: String):
	if view_name in camera_positions:
		current_view = view_name
		target_position = camera_positions[view_name]
		target_rotation = camera_rotations[view_name]

func focus_on_disc(disc_position: Vector3):
	# Optional: Focus camera on specific disc
	var focus_pos = camera_positions[current_view]
	focus_pos.x = disc_position.x * 0.2  # Slight camera follow
	target_position = focus_pos
