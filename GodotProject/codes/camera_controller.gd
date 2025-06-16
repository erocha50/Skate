extends Node3D
class_name CameraController

@export var target: Node3D
@export var follow_speed: float = 8.0
@export var rotation_speed: float = 5.0
@export var camera_distance_x: float = 12.0  # Horizontal distance from player (side distance)
@export var camera_distance_y: float = 3.0   # Vertical offset from player's eye level
@export var camera_distance_z: float = 0.0   # Forward/back distance from player
@export var look_ahead_distance: float = 4.0
@export var speed_zoom_factor: float = 0.3

# New parameters for vertical following
@export var vertical_follow_threshold: float = 1.5   # Height difference before camera starts following (reduced further)
@export var vertical_follow_speed: float = 12.0     # Base speed of vertical following (increased more)
@export var fast_follow_speed: float = 35.0         # Speed when player is moving fast vertically (increased more)
@export var speed_threshold: float = 3.0            # Player speed that triggers fast following (reduced more)
@export var max_look_angle: float = 25.0            # Maximum angle camera can look up/down (in degrees)
@export var ground_level: float = 0.0               # What you consider "ground level" for the player
@export var camera_eye_level_offset: float = 3.0    # How high above the player's position the camera should be

# New parameters to fix the issues
@export var follow_state_hysteresis: float = 0.3    # Prevents flickering between states (reduced more)
@export var rotation_smoothing: float = 0.1         # Smoother rotation transitions
@export var instant_follow_threshold: float = 8.0   # Speed at which camera follows instantly (reduced)

@onready var camera: Camera3D = $Camera3D

var base_fov: float = 70.0
var target_position: Vector3
var current_look_ahead: Vector3
var desired_camera_y: float  # The Y position the camera wants to be at
var is_following_vertically: bool = false
var previous_target_y: float = 0.0  # To track player's vertical speed
var follow_state_timer: float = 0.0  # Prevents rapid state changes

func _ready():
	if not target:
		target = get_tree().get_first_node_in_group("player")
	
	base_fov = camera.fov
	# Set initial camera height to eye level relative to player
	if target:
		desired_camera_y = target.global_position.y + camera_eye_level_offset + camera_distance_y
		previous_target_y = target.global_position.y
		# Set initial position with proper distance
		global_position = Vector3(
			target.global_position.x + camera_distance_x,
			target.global_position.y + camera_eye_level_offset + camera_distance_y,
			target.global_position.z + camera_distance_z
		)
	else:
		desired_camera_y = ground_level + camera_eye_level_offset + camera_distance_y
		global_position = Vector3(camera_distance_x, ground_level + camera_eye_level_offset + camera_distance_y, camera_distance_z)

func _process(delta):
	if not target:
		return
	
	var target_pos = target.global_position
	
	# Calculate player's vertical speed
	var player_vertical_speed = abs(target_pos.y - previous_target_y) / delta
	previous_target_y = target_pos.y
	
	# Calculate where the camera should be relative to player
	var ideal_camera_y = target_pos.y + camera_eye_level_offset + camera_distance_y
	var height_difference = abs(ideal_camera_y - desired_camera_y)
	
	# For very fast movement (like sliding down rails), follow immediately
	if player_vertical_speed > instant_follow_threshold:
		is_following_vertically = true
		# Instantly set the camera to the correct position for fast movement
		desired_camera_y = ideal_camera_y
		follow_state_timer = 0.0
	# Also trigger immediate following if the height difference is too large
	elif height_difference > (vertical_follow_threshold * 3.0):
		is_following_vertically = true
		desired_camera_y = ideal_camera_y
		follow_state_timer = 0.0
	else:
		# Add hysteresis to prevent flickering between states
		var threshold_to_use = vertical_follow_threshold
		if is_following_vertically:
			threshold_to_use = vertical_follow_threshold - follow_state_hysteresis
		else:
			threshold_to_use = vertical_follow_threshold + follow_state_hysteresis
		
		# Update follow state timer
		follow_state_timer += delta
		
		# Determine if we should follow vertically (with hysteresis and timer to prevent rapid changes)
		var should_follow_vertically = height_difference > threshold_to_use and follow_state_timer > 0.1
		
		# Handle vertical following logic
		if should_follow_vertically and not is_following_vertically:
			is_following_vertically = true
			follow_state_timer = 0.0
		elif not should_follow_vertically and is_following_vertically and height_difference < (threshold_to_use * 0.3):
			is_following_vertically = false
			follow_state_timer = 0.0
		
		if is_following_vertically:
			# Player is too high/low, follow them vertically maintaining the same relative height
			var target_camera_height = target_pos.y + camera_eye_level_offset + camera_distance_y
			
			# Use different follow speeds based on player's vertical speed
			var follow_speed_to_use = vertical_follow_speed
			if player_vertical_speed > speed_threshold:
				follow_speed_to_use = fast_follow_speed
			
			# For downward movement, use even faster following to prevent lag
			var vertical_direction = target_pos.y - previous_target_y
			if vertical_direction < 0 and player_vertical_speed > speed_threshold:
				follow_speed_to_use *= 2.0  # Double speed for downward movement
			
			# If the difference is still large, lerp faster
			if height_difference > vertical_follow_threshold * 2:
				follow_speed_to_use *= 1.5
			
			desired_camera_y = lerp(desired_camera_y, target_camera_height, min(follow_speed_to_use * delta, 1.0))
		else:
			# Gradually adjust to proper eye level relative to player
			var proper_eye_level_y = target_pos.y + camera_eye_level_offset + camera_distance_y
			desired_camera_y = lerp(desired_camera_y, proper_eye_level_y, vertical_follow_speed * 1.5 * delta)
	
	# Calculate target camera position - maintain proper side distance
	var camera_target_pos = Vector3(
		target_pos.x + camera_distance_x,  # Side distance (left/right of player)
		desired_camera_y,  # Use the calculated desired Y position (already includes eye level offset)
		target_pos.z + camera_distance_z   # Forward/back distance from player
	)
	
	# Smooth camera movement
	global_position = global_position.lerp(camera_target_pos, follow_speed * delta)
	
	# Handle rotation - keep camera looking in the gameplay direction (2.5D sidescroller style)
	maintain_sidescroller_view(delta)

func maintain_sidescroller_view(delta: float):
	# For a 2.5D sidescroller, the camera should look straight ahead in the direction of gameplay
	# The camera is positioned to the side of the player but looks in the direction the game flows
	
	# Determine the direction the camera should look based on your game's layout
	# For most 2.5D games, this is along the Z-axis (into the scene)
	var camera_look_direction = Vector3.FORWARD  # Change this to match your scene layout
	
	# Alternative directions you might need:
	# Vector3.BACK     # If looking towards negative Z
	# Vector3.RIGHT    # If gameplay flows along X-axis
	# Vector3.LEFT     # If gameplay flows along negative X-axis
	
	# Create the target look position
	var look_target = global_position + camera_look_direction
	
	# Create target transform
	var target_transform = global_transform.looking_at(
		look_target,
		Vector3.UP
	)
	
	# Smooth rotation transition
	var current_basis = global_transform.basis
	var target_basis = target_transform.basis
	
	# Use slerp for smoother rotation interpolation
	var new_basis = current_basis.slerp(target_basis, rotation_speed * delta)
	
	# Apply the new rotation
	global_transform.basis = new_basis
