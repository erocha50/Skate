extends Node3D

# Reference to the player
@export var target: Node3D  # Drag the player node here in the editor
@onready var camera = $Camera3D  # Assumes Camera3D is a child of CameraPivot

# Camera settings
@export var y_offset: float = 2.0
@export var z_distance: float = 10.0
@export var smooth_speed: float = 0.05

func _process(_delta):
	if not target or not camera:
		return
	
	# Target position (follow player's X and Y, fixed Z)
	var target_pos = Vector3(target.global_position.x, target.global_position.y + y_offset, z_distance)
	
	# Smoothly interpolate position
	global_position = global_position.lerp(target_pos, smooth_speed)
	
	# Set fixed rotation and look at player
	camera.global_rotation = Vector3(0, -PI / 2, 0)  # Side-scrolling view
	camera.look_at(target.global_position, Vector3.UP)
