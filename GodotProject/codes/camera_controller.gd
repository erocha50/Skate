extends Node3D
class_name CameraController

@export var target: Node3D
@export var follow_speed: float = 8.0
@export var rotation_speed: float = 5.0
@export var side_offset: Vector3 = Vector3(12, 3, 0) # Side-view positioning
@export var look_ahead_distance: float = 4.0
@export var speed_zoom_factor: float = 0.3

# New parameters for vertical following
@export var vertical_follow_threshold: float = 3.0   # Height difference before camera starts following
@export var vertical_follow_speed: float = 6.0      # Base speed of vertical following
@export var fast_follow_speed: float = 15.0         # Speed when player is moving fast vertically
@export var speed_threshold: float = 8.0            # Player speed that triggers fast following
@export var max_look_angle: float = 25.0            # Maximum angle camera can look up/down (in degrees)
@export var ground_level: float = 0.0               # What you consider "ground level" for the player
@export var camera_eye_level_offset: float = 3.0    # How high above the player's position the camera should be

@onready var camera: Camera3D = $Camera3D

var base_fov: float = 70.0
var target_position: Vector3
var current_look_ahead: Vector3
var desired_camera_y: float  # The Y position the camera wants to be at
var is_following_vertically: bool = false
var previous_target_y: float = 0.0  # To track player's vertical speed

func _ready():
	if not target:
		target = get_tree().get_first_node_in_group("player")
	
	base_fov = camera.fov
	# Set initial camera height to eye level relative to player
	if target:
		desired_camera_y = target.global_position.y + camera_eye_level_offset
		previous_target_y = target.global_position.y
	else:
		desired_camera_y = ground_level + camera_eye_level_offset
	global_position.y = desired_camera_y

func _process(delta):
	if not target:
		return
	
	var target_pos = target.global_position
	
	# Calculate player's vertical speed
	var player_vertical_speed = abs(target_pos.y - previous_target_y) / delta
	previous_target_y = target_pos.y
	
	# Calculate where the camera should be relative to player
	var ideal_camera_y = target_pos.y + camera_eye_level_offset
	var height_difference = abs(ideal_camera_y - global_position.y)  # Use actual camera position, not desired
	
	# Determine if we should follow vertically or just look
	var should_follow_vertically = height_difference > vertical_follow_threshold
	
	# Handle vertical following logic
	if should_follow_vertically:
		# Player is too high/low, follow them vertically maintaining the same relative height
		is_following_vertically = true
		# Keep the same offset relative to the player as we have on ground level
		var target_camera_height = target_pos.y + camera_eye_level_offset
		
		# Use faster follow speed if player is moving fast vertically
		var follow_speed_to_use = vertical_follow_speed
		if player_vertical_speed > speed_threshold:
			follow_speed_to_use = fast_follow_speed
		
		desired_camera_y = lerp(desired_camera_y, target_camera_height, follow_speed_to_use * delta)
	else:
		# Player is close enough, gradually return to proper eye level relative to player if we were following
		if is_following_vertically:
			var proper_eye_level_y = target_pos.y + camera_eye_level_offset
			desired_camera_y = lerp(desired_camera_y, proper_eye_level_y, vertical_follow_speed * 0.5 * delta)
			
			# Stop following when we're close to proper eye level
			if abs(desired_camera_y - proper_eye_level_y) < 0.5:
				is_following_vertically = false
	
	# Calculate target camera position
	var camera_target_pos = Vector3(
		target_pos.x,  # Always follow horizontally
		desired_camera_y,  # Use our calculated vertical position
		global_position.z  # Keep same Z (side-view distance)
	)
	
	# Smooth camera movement
	global_position = global_position.lerp(camera_target_pos, follow_speed * delta)
	
	# Handle rotation - look at player level when following, allow up/down look when stationary
	if is_following_vertically:
		# When following vertically, look straight at player's level (no up/down angle)
		var level_target = Vector3(target_pos.x, global_position.y, target_pos.z)
		look_at_target_constrained(level_target, delta)
	else:
		# When not following vertically, allow looking up/down at the player
		look_at_target_constrained(target_pos, delta)

func look_at_target_constrained(target_pos: Vector3, delta: float):
	# Calculate the direction to the target
	var direction = (target_pos - global_position).normalized()
	
	# Calculate the angle of looking up/down
	var look_angle = rad_to_deg(asin(direction.y))
	
	# Clamp the angle to prevent extreme looking up/down
	look_angle = clamp(look_angle, -max_look_angle, max_look_angle)
	
	# Convert back to direction vector with constrained angle
	var constrained_direction = Vector3(
		direction.x,
		sin(deg_to_rad(look_angle)),
		direction.z
	).normalized()
	
	# Apply the look direction with smooth rotation
	var target_transform = global_transform.looking_at(
		global_position + constrained_direction,
		Vector3.UP
	)
	
	# Smooth rotation
	global_transform = global_transform.interpolate_with(target_transform, rotation_speed * delta)
