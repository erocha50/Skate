extends RigidBody3D

# Scoring signals
signal rail_grind_started
signal rail_grind_ended  
signal freeze_block_used
signal dash_performed
signal player_became_airborne
signal player_landed
signal qte_trick_completed(success: bool, score_bonus: int)

# Movement parameters
@export var max_speed: float = 15.0
@export var acceleration_force: float = 25.0
@export var deceleration_force: float = 15.0
@export var air_control_multiplier: float = 0.4
@export var rail_move_speed: float = 25.0
@export var jump_force: float = 10.0
@export var freeze_jump_force: float = 6.0
@export var ground_gravity: float = 9.8
@export var jump_gravity: float = 6.0
@export var max_fall_speed: float = 15.0
@export var rail_force: float = 100.0
@export var mesh_tilt_speed: float = 10.0

# Curved rail parameters
@export var skateboard_rotation_speed: float = 8.0  # How fast skateboard aligns to rail
@export var player_rotation_speed: float = 8.0  # How fast player aligns to rail
@export var player_lean_factor: float = 0.5  # Controls how much player rotates relative to skateboard (0.0 to 1.0)

# Dash parameters
@export var dash_force: float = 30.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 1.0
@export var dash_gravity_reduction: float = 0.3

# QTE parameters
@export var qte_cooldown: float = 2.0
@export var qte_manual_trigger_key: String = "qte_trigger"  # Add this for manual testing

# Spawn system parameters
@export var spawn_point: Vector3 = Vector3(0, 1, 0)
@export var fall_threshold: float = -40.0

# Ground check
@export var ground_check_distance: float = 0.1
@onready var ground_check: RayCast3D = $GroundCheck
@onready var player_mesh: MeshInstance3D = $MeshInstance3D
@onready var player_collision: CollisionShape3D = $PlayerCollision
@onready var player_model: Node3D = $male_casual
@onready var skateboard_collision: CollisionShape3D = $SkateboardCollision
@onready var skateboard_model: Node3D = $skateboardtest

var is_grounded: bool = false
var is_on_rail: bool = false
var ground_normal: Vector3 = Vector3.UP

# Rail normal tracking
var rail_normal: Vector3 = Vector3.UP
var skateboard_target_rotation: float = 0.0
var player_target_rotation: float = 0.0

# Dash variables
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: float = 0.0

# Freeze block variables
var is_frozen: bool = false
var has_double_jumped: bool = false

# QTE variables
var qte_system: Control = null
var is_qte_active: bool = false
var qte_cooldown_timer: float = 0.0

# Signal tracking variables
var was_grounded_last_frame: bool = false
var was_on_rail_last_frame: bool = false

func _ready():
	# Create and assign a PhysicsMaterial if none exists
	if not physics_material_override:
		physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 1.0
	physics_material_override.bounce = 0.0

	# Lock Z-axis position and all rotations for the main body
	axis_lock_linear_z = true
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	axis_lock_angular_z = true
	
	# Try to find QTE system automatically
	_find_qte_system()
	
	# Debug: Check if nodes exist
	if not skateboard_collision:
		print("ERROR: SkateboardCollision node not found! Please check node path.")
	else:
		print("SkateboardCollision node found: ", skateboard_collision.name)
		
	if not skateboard_model:
		print("ERROR: 'skateboard test' node not found! Please check node path.")
	else:
		print("Skateboard model node found: ", skateboard_model.name)
		
	if not player_collision:
		print("ERROR: PlayerCollision node not found! Please check node path.")
	else:
		print("PlayerCollision node found: ", player_collision.name)
		
	if not player_model:
		print("ERROR: 'male_casual' node not found! Please check node path.")
	else:
		print("Player model node found: ", player_model.name)

func _physics_process(delta):
	# Skip all physics if frozen
	if is_frozen:
		return
	
	# Check for fall-off respawn
	if global_position.y < fall_threshold:
		_respawn_player()
		return
	
	# Update timers
	if qte_cooldown_timer > 0:
		qte_cooldown_timer -= delta
		
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false

	# Check ground and rail status
	var ground_info = _check_grounded()
	is_grounded = ground_info.is_grounded
	is_on_rail = ground_info.is_on_rail
	ground_normal = ground_info.ground_normal

	# Update rail normal when on rail
	if is_on_rail:
		rail_normal = ground_normal
		_calculate_rotation_angles()

	# Emit scoring signals
	if was_grounded_last_frame and not is_grounded:
		player_became_airborne.emit()

	elif not was_grounded_last_frame and is_grounded:
		player_landed.emit()

	
	if not was_on_rail_last_frame and is_on_rail:
		rail_grind_started.emit()

		
	elif was_on_rail_last_frame and not is_on_rail:
		rail_grind_ended.emit()

		# Reset rotations when leaving rail
		skateboard_target_rotation = 0.0
		player_target_rotation = 0.0
		# DON'T hide QTE when leaving rail - let it complete naturally
		# The QTE should continue running even after leaving the rail
	
	# Store states for next frame
	was_grounded_last_frame = is_grounded
	was_on_rail_last_frame = is_on_rail

	# Reset double jump when grounded
	if is_grounded:
		has_double_jumped = false

	# Prevent rotation of the main RigidBody3D
	angular_velocity = Vector3.ZERO

	# Apply gravity or rail force
	var gravity_multiplier = dash_gravity_reduction if is_dashing else 1.0
	
	if not is_grounded:
		var current_velocity = linear_velocity
		var new_y_velocity = max(current_velocity.y - ground_gravity * gravity_multiplier * delta, -max_fall_speed)
		apply_central_force(Vector3(0, (new_y_velocity - current_velocity.y) * mass / delta, 0))
		
	elif is_on_rail:
		apply_central_force(-ground_normal * rail_force * mass * gravity_multiplier)
	else:
		var current_velocity = linear_velocity
		var new_y_velocity = max(current_velocity.y - ground_gravity * gravity_multiplier * delta, -max_fall_speed)
		apply_central_force(Vector3(0, (new_y_velocity - current_velocity.y) * mass / delta, 0))

	# Handle inputs
	# Manual QTE trigger for testing (optional)
	if Input.is_action_just_pressed(qte_manual_trigger_key) and is_on_rail and not is_qte_active and qte_cooldown_timer <= 0:
		print("Manual QTE trigger activated!")
		_start_qte()
	
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0 and not is_dashing and not is_on_rail:
		_start_dash()

	if Input.is_action_just_pressed("jump"):
		if is_grounded:
			if is_on_rail:
				print("Jump pressed while on rail - triggering QTE!")
				# Trigger QTE when jumping from rail
				if not is_qte_active and qte_cooldown_timer <= 0:
					_start_qte()
				
				apply_central_impulse(Vector3.UP * jump_force)
				ground_check.enabled = false
				# Make sure we have a timer node or create one
				if has_node("Timer"):
					$Timer.start()
				else:
					var timer = Timer.new()
					timer.name = "Timer"
					timer.wait_time = 0.1
					timer.one_shot = true
					add_child(timer)
					timer.timeout.connect(_on_timer_timeout)
					timer.start()
			else:
				apply_central_impulse(Vector3(0, jump_force * mass, 0))

	if Input.is_action_just_pressed("reset"):
		_respawn_player()
		return

	# Handle movement
	_handle_movement(delta)

	# Handle rotations
	_handle_rotations(delta)

# Calculate both skateboard and player rotation angles
func _calculate_rotation_angles():
	
	# For a side-scrolling game, we want to rotate around Z based on the rail's tilt
	# If the rail slopes up/down, the normal will tilt in the X direction
	# We need to calculate the angle between the normal and straight up
	
	# Check if the rail is tilted (normal is not pointing straight up)
	var angle_from_up = acos(clamp(rail_normal.y, -1.0, 1.0))
	
	# Determine rotation direction based on normal's X component
	if abs(rail_normal.x) > 0.01:  # Rail is tilted
		# Use the X component to determine which way to rotate around Z
		var base_rotation = -sign(rail_normal.x) * angle_from_up
		skateboard_target_rotation = base_rotation
		# Player rotation is now a fraction of the skateboard's rotation based on player_lean_factor
		player_target_rotation = base_rotation * clamp(player_lean_factor, 0.0, 1.0)
	else:
		skateboard_target_rotation = 0.0
		player_target_rotation = 0.0

# Handle all rotations including player
func _handle_rotations(delta):
	if is_on_rail:
		# Skateboard collision and model follow the rail normal on Z axis
		if skateboard_collision:
			var current_rotation = skateboard_collision.rotation
			var new_z_rotation = lerp_angle(current_rotation.z, skateboard_target_rotation, skateboard_rotation_speed * delta)
			skateboard_collision.rotation = Vector3(current_rotation.x, current_rotation.y, new_z_rotation)
			
		
		if skateboard_model:
			var current_rotation = skateboard_model.rotation
			var new_z_rotation = lerp_angle(current_rotation.z, skateboard_target_rotation, skateboard_rotation_speed * delta)
			skateboard_model.rotation = Vector3(current_rotation.x, current_rotation.y, new_z_rotation)
			
		
		# Rotate player collision
		if player_collision:
			var current_rotation = player_collision.rotation
			var new_z_rotation = lerp_angle(current_rotation.z, player_target_rotation, player_rotation_speed * delta)
			player_collision.rotation = Vector3(current_rotation.x, current_rotation.y, new_z_rotation)
			
		
		# Rotate player model
		if player_model:
			var current_rotation = player_model.rotation
			var new_z_rotation = lerp_angle(current_rotation.z, player_target_rotation, player_rotation_speed * delta)
			player_model.rotation = Vector3(current_rotation.x, current_rotation.y, new_z_rotation)
			
		
		# Keep existing mesh rotation if you still have it
		if player_mesh:
			var current_rotation = player_mesh.rotation
			var new_z_rotation = lerp_angle(current_rotation.z, player_target_rotation, mesh_tilt_speed * delta)
			player_mesh.rotation = Vector3(current_rotation.x, current_rotation.y, new_z_rotation)
	else:
		# Return to neutral when not on rail
		if skateboard_collision and abs(skateboard_collision.rotation.z) > 0.01:
			var current_rotation = skateboard_collision.rotation
			var new_z_rotation = lerp_angle(current_rotation.z, 0.0, skateboard_rotation_speed * delta)
			skateboard_collision.rotation = Vector3(current_rotation.x, current_rotation.y, new_z_rotation)
		
		if skateboard_model and abs(skateboard_model.rotation.z) > 0.01:
			var current_rotation = skateboard_model.rotation
			var new_z_rotation = lerp_angle(current_rotation.z, 0.0, skateboard_rotation_speed * delta)
			skateboard_model.rotation = Vector3(current_rotation.x, current_rotation.y, new_z_rotation)
		
		# Return player collision to neutral
		if player_collision and abs(player_collision.rotation.z) > 0.01:
			var current_rotation = player_collision.rotation
			var new_z_rotation = lerp_angle(current_rotation.z, 0.0, player_rotation_speed * delta)
			player_collision.rotation = Vector3(current_rotation.x, current_rotation.y, new_z_rotation)
		
		# Return player model to neutral (or dash tilt)
		if player_model:
			var current_rotation = player_model.rotation
			var target_z_rotation = 0.0
			if is_dashing:
				target_z_rotation = -dash_direction * 0.2
			var new_z_rotation = lerp_angle(current_rotation.z, target_z_rotation, player_rotation_speed * delta)
			player_model.rotation = Vector3(current_rotation.x, current_rotation.y, new_z_rotation)
		
		# Keep existing mesh handling
		if player_mesh:
			var current_rotation = player_mesh.rotation
			var target_z_rotation = 0.0
			if is_dashing:
				target_z_rotation = -dash_direction * 0.2
			var new_z_rotation = lerp_angle(current_rotation.z, target_z_rotation, mesh_tilt_speed * delta)
			player_mesh.rotation = Vector3(current_rotation.x, current_rotation.y, new_z_rotation)

func _start_qte():
	if is_qte_active or not qte_system:
		print("QTE start failed - is_qte_active: ", is_qte_active, ", qte_system exists: ", qte_system != null)
		return
	
	print("Starting QTE system!")
	is_qte_active = true
	qte_cooldown_timer = qte_cooldown
	
	if qte_system and qte_system.has_method("start_qte"):
		qte_system.start_qte()
	else:
		print("ERROR: QTE system doesn't have start_qte method or is null!")

func _on_qte_completed(success: bool, score_bonus: int):
	print("QTE completed with success: ", success, ", score bonus: ", score_bonus)
	qte_trick_completed.emit(success, score_bonus)
	is_qte_active = false
	
	# The QTE system will hide itself after showing feedback

func _start_dash():
	# For dash, we still want to use A/D input or current velocity direction
	var input_dir = 0.0
	if Input.is_action_pressed("steer_left"):
		input_dir = -1.0
	elif Input.is_action_pressed("steer_right"):
		input_dir = 1.0
	
	if abs(input_dir) > 0.1:
		dash_direction = input_dir
	else:
		dash_direction = 1.0 if linear_velocity.x >= 0 else -1.0
	
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	
	apply_central_impulse(Vector3(dash_direction * dash_force * mass, 0, 0))
	dash_performed.emit()

func _check_grounded() -> Dictionary:
	var result = {"is_grounded": false, "is_on_rail": false, "ground_normal": Vector3.UP}
	if ground_check and ground_check.is_colliding():
		result.is_grounded = true
		var collider = ground_check.get_collider()
		if collider:
			result.is_on_rail = collider.is_in_group("Rail")
			result.ground_normal = ground_check.get_collision_normal()
			# Debug print
			if result.is_on_rail:
				print("Ground check: On rail detected")
	return result

func _handle_movement(delta):
	# Get input from WASD keys
	var accelerate_input = Input.is_action_pressed("accelerate")  # W key
	var brake_input = Input.is_action_pressed("brake")  # S key
	var left_input = Input.is_action_pressed("steer_left")  # A key
	var right_input = Input.is_action_pressed("steer_right")  # D key
	
	# Calculate desired direction from A/D input
	var direction_input = 0.0
	if right_input:
		direction_input += 1.0
	if left_input:
		direction_input -= 1.0
	
	var current_velocity = linear_velocity
	
	# Special handling for rail movement (keep original rail behavior)
	if is_on_rail:
		var current_direction = sign(current_velocity.x) if abs(current_velocity.x) > 0.1 else 1.0
		var target_velocity_x = current_direction * rail_move_speed
		
		if abs(current_velocity.x) < rail_move_speed * 0.9:
			var force_needed = (target_velocity_x - current_velocity.x) * mass * 10.0
			apply_central_force(Vector3(force_needed, 0, 0))
		return
	
	# Skip movement handling if dashing (let dash control movement)
	if is_dashing:
		return
	
	# Determine control multiplier based on ground state
	var control_multiplier = 1.0
	if not is_grounded:
		control_multiplier = air_control_multiplier
	
	# Handle acceleration/deceleration based on input
	var target_velocity_x = current_velocity.x
	var force_to_apply = 0.0
	
	if accelerate_input and abs(direction_input) > 0.1:
		# Accelerate in the direction of A/D input
		target_velocity_x = direction_input * max_speed
		var velocity_diff = target_velocity_x - current_velocity.x
		force_to_apply = sign(velocity_diff) * acceleration_force * control_multiplier
		
		# Limit force if we're close to target velocity
		if abs(velocity_diff) < abs(force_to_apply * delta / mass):
			force_to_apply = velocity_diff * mass / delta
	
	elif brake_input:
		# Active deceleration (S key) - brake harder
		force_to_apply = -sign(current_velocity.x) * deceleration_force * 1.5 * control_multiplier
		
		# Stop if we're going slow enough
		if abs(current_velocity.x) < 1.0:
			force_to_apply = -current_velocity.x * mass / delta
	
	elif abs(direction_input) > 0.1:
		# Just directional input without acceleration - gentle steering
		target_velocity_x = direction_input * max_speed * 0.7  # Reduced speed for steering without W
		var velocity_diff = target_velocity_x - current_velocity.x
		force_to_apply = sign(velocity_diff) * acceleration_force * 0.5 * control_multiplier
		
		# Limit force if we're close to target velocity
		if abs(velocity_diff) < abs(force_to_apply * delta / mass):
			force_to_apply = velocity_diff * mass / delta
	
	else:
		# No input - natural deceleration (momentum)
		if abs(current_velocity.x) > 0.1:
			var natural_decel = deceleration_force * 0.3 * control_multiplier  # Gentle natural slowdown
			force_to_apply = -sign(current_velocity.x) * natural_decel
			
			# Stop if we're going very slow
			if abs(current_velocity.x) < 0.5:
				force_to_apply = -current_velocity.x * mass / delta
	
	# Apply the calculated force
	if abs(force_to_apply) > 0.01:
		apply_central_force(Vector3(force_to_apply * mass, 0, 0))

func _on_timer_timeout() -> void:
	ground_check.enabled = true

func is_at_rail_ledge() -> bool:
	# First, double-check that we're actually on a rail
	if not is_on_rail:
		print("is_at_rail_ledge: Not on rail, returning false")
		return false
	
	var forward_distance = 1.0
	var downward_offset = ground_check_distance

	var forward_check = RayCast3D.new()
	forward_check.position = global_position + Vector3(sign(linear_velocity.x) * forward_distance, 0, 0)
	forward_check.target_position = Vector3(0, -downward_offset, 0)
	add_child(forward_check)
	forward_check.force_raycast_update()
	var forward_hit = forward_check.is_colliding() and forward_check.get_collider() and forward_check.get_collider().is_in_group("Rail")
	forward_check.queue_free()

	var far_check = RayCast3D.new()
	far_check.position = global_position + Vector3(sign(linear_velocity.x) * forward_distance * 1.5, 0, 0)
	far_check.target_position = Vector3(0, -downward_offset, 0)
	add_child(far_check)
	far_check.force_raycast_update()
	var far_hit = far_check.is_colliding() and far_check.get_collider() and far_check.get_collider().is_in_group("Rail")
	far_check.queue_free()

	var is_curve = abs(ground_normal.dot(Vector3.UP) - 1.0) > 0.1
	var at_ledge = (!forward_hit || (!forward_hit and !far_hit)) && !is_curve
	
	print("is_at_rail_ledge debug:")
	print("  - is_on_rail: ", is_on_rail)
	print("  - forward_hit: ", forward_hit)
	print("  - far_hit: ", far_hit)
	print("  - is_curve: ", is_curve)
	print("  - at_ledge result: ", at_ledge)
	
	if at_ledge:
		print("Ledge detected")
	else:
		print("Not at ledge")
	
	return at_ledge

func trigger_freeze_jump():
	if not is_grounded and not has_double_jumped:
		print("Freeze block triggered!")
		has_double_jumped = true
		freeze_block_used.emit()
		
		is_frozen = true
		get_tree().paused = true
		
		var freeze_timer = Timer.new()
		freeze_timer.wait_time = 0.5
		freeze_timer.one_shot = true
		freeze_timer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(freeze_timer)
		freeze_timer.timeout.connect(_on_freeze_timeout)
		freeze_timer.start()

func _on_freeze_timeout():
	get_tree().paused = false
	is_frozen = false
	apply_central_impulse(Vector3(0, freeze_jump_force * mass, 0))
	print("Freeze jump executed!")

func _respawn_player():
	print("Player fell below threshold, respawning at spawn point")
	
	global_position = spawn_point
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	# Reset rotations
	skateboard_target_rotation = 0.0
	player_target_rotation = 0.0
	
	# Reset all rotations
	if skateboard_collision:
		skateboard_collision.rotation = Vector3.ZERO
	if skateboard_model:
		skateboard_model.rotation = Vector3.ZERO
	if player_collision:
		player_collision.rotation = Vector3.ZERO
	if player_model:
		player_model.rotation = Vector3.ZERO
	if player_mesh:
		player_mesh.rotation = Vector3.ZERO
	
	is_grounded = false
	is_on_rail = false
	has_double_jumped = false
	is_dashing = false
	dash_timer = 0.0
	
	if is_qte_active and qte_system:
		qte_system.force_stop_qte()
		is_qte_active = false
	
	if ground_check:
		ground_check.enabled = true

func set_spawn_point(new_spawn_point: Vector3):
	spawn_point = new_spawn_point
	print("Spawn point updated to: ", spawn_point)

# Function to automatically find QTE system
func _find_qte_system():
	# First, try to find it as a child of this node
	qte_system = get_node_or_null("QTESystem")
	if qte_system:
		print("Found QTE system as child of player")
		_connect_qte_system()
		return
	
	# Try to find it as a sibling (same parent)
	if get_parent():
		qte_system = get_parent().get_node_or_null("QTESystem")
		if qte_system:
			print("Found QTE system as sibling of player")
			_connect_qte_system()
			return
	
	# Try to find it in the scene tree by searching recursively
	var root = get_tree().current_scene
	if root:
		qte_system = _find_node_recursive(root, "QTESystem")
		if qte_system:
			print("Found QTE system in scene tree: ", qte_system.name)
			_connect_qte_system()
			return
	
	print("WARNING: QTE system not found! Please make sure it's added to the scene.")
	print("Looking for a node named 'QTESystem' - you can also manually connect it using set_qte_system()")

# Recursive function to find a node by name
func _find_node_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	
	for child in node.get_children():
		var result = _find_node_recursive(child, target_name)
		if result:
			return result
	
	return null

# Helper function to connect the QTE system
func _connect_qte_system():
	if qte_system and qte_system.has_signal("qte_completed"):
		if not qte_system.qte_completed.is_connected(_on_qte_completed):
			qte_system.qte_completed.connect(_on_qte_completed)
		print("QTE system connected successfully!")
	else:
		print("ERROR: QTE system found but doesn't have qte_completed signal!")

func set_qte_system(qte: Control):
	qte_system = qte
	if qte_system:
		_connect_qte_system()
	else:
		print("ERROR: Attempted to set null QTE system")
