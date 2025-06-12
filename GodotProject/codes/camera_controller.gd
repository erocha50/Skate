extends Node3D
class_name CameraController

@export var target: Node3D
@export var follow_speed: float = 8.0
@export var rotation_speed: float = 5.0
@export var side_distance: float = 12.0              # How far to the side of the character
@export var height_offset: float = 3.0               # Height above character
@export var look_ahead_distance: float = 4.0         # How far ahead to look based on movement
@export var speed_zoom_factor: float = 0.3

# Vertical following parameters
@export var vertical_follow_threshold: float = 3.0   # Height difference before camera starts following
@export var vertical_follow_speed: float = 6.0      # Base speed of vertical following
@export var fast_follow_speed: float = 15.0         # Speed when player is moving fast vertically
@export var speed_threshold: float = 8.0            # Player speed that triggers fast following
@export var follow_hysteresis: float = 1.0          # Prevents oscillation

@onready var camera: Camera3D = $Camera3D

var base_fov: float = 70.0
var desired_camera_y: float
var is_following_vertically: bool = false
var previous_target_y: float = 0.0
var player_facing_direction: float = 1.0  # 1 for right, -1 for left

func _ready():
	if not target:
		target = get_tree().get_first_node_in_group("player")
	
	base_fov = camera.fov
	
	if target:
		desired_camera_y = target.global_position.y + height_offset
		previous_target_y = target.global_position.y
		
		# Set initial camera position for side view (positioned on Z axis)
		global_position = Vector3(
			target.global_position.x,
			desired_camera_y,
			target.global_position.z + side_distance
		)
		
		# Look at the character initially
		look_at(target.global_position, Vector3.UP)

func _process(delta):
	if not target:
		return
	
	var target_pos = target.global_position
	
	# Detect player facing direction (optional - you can remove this if not needed)
	# This assumes your character has a way to determine facing direction
	if target.has_method("get_facing_direction"):
		player_facing_direction = target.get_facing_direction()
	
	# Calculate player's vertical speed
	var player_vertical_speed = abs(target_pos.y - previous_target_y) / delta
	previous_target_y = target_pos.y
	
	# Calculate ideal camera Y position
	var ideal_camera_y = target_pos.y + height_offset
	var height_difference = abs(ideal_camera_y - desired_camera_y)
	
	# Hysteresis for vertical following
	var follow_threshold = vertical_follow_threshold
	var stop_threshold = vertical_follow_threshold - follow_hysteresis
	
	# Determine vertical following state
	if !is_following_vertically and height_difference > follow_threshold:
		is_following_vertically = true
	elif is_following_vertically and height_difference < stop_threshold:
		is_following_vertically = false
	
	# Update desired camera Y position
	if is_following_vertically:
		var follow_speed_to_use = vertical_follow_speed
		if player_vertical_speed > speed_threshold:
			follow_speed_to_use = fast_follow_speed
		desired_camera_y = lerp(desired_camera_y, ideal_camera_y, follow_speed_to_use * delta)
	else:
		# Gentle drift toward ideal when not actively following
		var drift_speed = vertical_follow_speed * 0.3
		desired_camera_y = lerp(desired_camera_y, ideal_camera_y, drift_speed * delta)
	
	# Calculate look-ahead based on player movement (optional)
	var look_ahead_offset = 0.0
	if target.has_method("get_velocity"):
		var velocity = target.get_velocity()
		if abs(velocity.x) > 1.0:  # Only look ahead if moving horizontally
			look_ahead_offset = sign(velocity.x) * look_ahead_distance
	
	# Calculate target camera position for 2.5D side view
	var camera_target_pos = Vector3(
		target_pos.x + look_ahead_offset,                  # Follow X position with optional look-ahead
		desired_camera_y,                                  # Calculated Y position
		target_pos.z + side_distance                       # Side position on Z axis
	)
	
	# Smooth camera movement
	global_position = global_position.lerp(camera_target_pos, follow_speed * delta)
	
	# For 2.5D side view, camera looks at character from the side
	# Create a target point to look at
	var look_target = Vector3(
		target_pos.x + look_ahead_offset * 0.3,  # Slight look-ahead in movement direction
		target_pos.y + height_offset * 0.5,      # Look at character's upper body/head area
		target_pos.z                             # Same Z as character
	)
	
	# Smooth rotation toward target
	var target_transform = global_transform.looking_at(look_target, Vector3.UP)
	global_transform = global_transform.interpolate_with(target_transform, rotation_speed * delta)
