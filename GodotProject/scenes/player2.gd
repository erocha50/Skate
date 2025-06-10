extends RigidBody3D

# Scoring signals
signal rail_grind_started
signal rail_grind_ended  
signal freeze_block_used
signal dash_performed
signal player_became_airborne
signal player_landed

# Movement parameters
@export var move_speed: float = 15.0  # Standard speed for Sonic-like movement
@export var rail_move_speed: float = 25.0  # Higher speed when on rails
@export var jump_force: float = 10.0  # Higher for Mario-like jump height
@export var freeze_jump_force: float = 6.0  # Weaker jump from freeze block
@export var ground_gravity: float = 9.8
@export var jump_gravity: float = 6.0  # Lower gravity for floaty Mario-like jumps
@export var max_fall_speed: float = 15.0  # Cap falling speed
@export var acceleration: float = 20.0  # Snappier acceleration
@export var friction: float = 2.0  # Ground friction for stopping
@export var air_friction: float = 2.0  # Lower friction in air for momentum
@export var rail_force: float = 100.0  # Downward force when on rails
@export var mesh_tilt_speed: float = 10.0  # Speed of mesh tilt interpolation

# Dash parameters
@export var dash_force: float = 30.0  # Force applied during dash
@export var dash_duration: float = 0.2  # How long the dash lasts
@export var dash_cooldown: float = 1.0  # Cooldown between dashes
@export var dash_gravity_reduction: float = 0.3  # Reduce gravity during dash (0-1)

# Ground check
@export var ground_check_distance: float = 0.1
@onready var ground_check: RayCast3D = $GroundCheck
@onready var player_mesh: MeshInstance3D = $PlayerMesh
var is_grounded: bool = false
var is_on_rail: bool = false
var ground_normal: Vector3 = Vector3.UP
var move_input: float = 0.0

# Dash variables
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: float = 0.0

# Freeze block variables
var is_frozen: bool = false
var has_double_jumped: bool = false

# Signal tracking variables
var was_grounded_last_frame: bool = false
var was_on_rail_last_frame: bool = false

func _ready():
	# Create and assign a PhysicsMaterial if none exists
	if not physics_material_override:
		physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 1.0
	physics_material_override.bounce = 0.0

	# Lock Z-axis position and all rotations
	axis_lock_linear_z = true
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	axis_lock_angular_z = true

func _physics_process(delta):
	# Skip all physics if frozen
	if is_frozen:
		return
		
	# Update dash timers
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false

	# Check if grounded and on rail
	var ground_info = _check_grounded()
	is_grounded = ground_info.is_grounded
	is_on_rail = ground_info.is_on_rail
	ground_normal = ground_info.ground_normal

	# Emit scoring signals
	if was_grounded_last_frame and not is_grounded:
		player_became_airborne.emit()
		print("emitting player became airborne")
	elif not was_grounded_last_frame and is_grounded:
		player_landed.emit()
		print("emitting player landed")
	
	if not was_on_rail_last_frame and is_on_rail:
		rail_grind_started.emit()
		print("emitting  rail grind started")
		
	elif was_on_rail_last_frame and not is_on_rail:
		rail_grind_ended.emit()
		print("emitting rail grind ended")
	
	# Store states for next frame
	was_grounded_last_frame = is_grounded
	was_on_rail_last_frame = is_on_rail

	# Reset double jump when grounded
	if is_grounded:
		has_double_jumped = false

	# Prevent rotation of the RigidBody3D
	angular_velocity = Vector3.ZERO

	# Apply gravity or rail force (reduced during dash)
	var gravity_multiplier = dash_gravity_reduction if is_dashing else 1.0
	
	if not is_grounded:
		# In air - check if player is giving input for momentum control
		var air_input = Input.get_axis("move_left", "move_right")
		var current_velocity = linear_velocity
		
		# Apply gravity
		var new_y_velocity = max(current_velocity.y - ground_gravity * gravity_multiplier * delta, -max_fall_speed)
		apply_central_force(Vector3(0, (new_y_velocity - current_velocity.y) * mass / delta, 0))
		
		# Apply air control only if player is giving input
		if abs(air_input) > 0.1:
			var air_control_force = air_input * acceleration * 0.3 * mass  # Reduced air control
			apply_central_force(Vector3(air_control_force, 0, 0))
		
	elif is_on_rail:
		# Apply downward force along the rail's normal
		apply_central_force(-ground_normal * rail_force * mass * gravity_multiplier)
	else:
		# Apply regular gravity when grounded but not on rail
		var current_velocity = linear_velocity
		var new_y_velocity = max(current_velocity.y - ground_gravity * gravity_multiplier * delta, -max_fall_speed)
		apply_central_force(Vector3(0, (new_y_velocity - current_velocity.y) * mass / delta, 0))

	# Handle dash input
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0 and not is_dashing and not is_on_rail:
		_start_dash()

	# Handle jump
	if Input.is_action_just_pressed("jump") and is_grounded:
		if is_on_rail:
			# Only allow jump at ledge
			if is_at_rail_ledge():
				# Rail jump: dash forward with stronger force
				#print("Rail jump - powerful dash forward at ledge")
				apply_central_impulse(Vector3.UP * jump_force )
				ground_check.enabled = false
				$Timer.start()
			else:
				print("Jump blocked - not at rail ledge")
		else:
			# Normal jump
			#print("Normal jump")
			apply_central_impulse(Vector3(0, jump_force * mass, 0))

	# Handle movement
	_handle_movement(delta)

	# Handle mesh tilt
	_handle_mesh_tilt(delta)

func _start_dash():
	# Determine dash direction
	var input_dir = Input.get_axis("move_left", "move_right")
	if abs(input_dir) > 0.1:
		dash_direction = input_dir
	else:
		dash_direction = 1.0 if linear_velocity.x >= 0 else -1.0
	
	# Start dash
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	
	# Apply dash force
	apply_central_impulse(Vector3(dash_direction * dash_force * mass, 0, 0))
	
	# Emit dash signal for scoring
	dash_performed.emit()
	
	#print("Dash started! Direction: ", dash_direction)

func _check_grounded() -> Dictionary:
	var result = {"is_grounded": false, "is_on_rail": false, "ground_normal": Vector3.UP}
	if ground_check and ground_check.is_colliding():
		result.is_grounded = true
		var collider = ground_check.get_collider()
		if collider:
			result.is_on_rail = collider.is_in_group("Rail")
			result.ground_normal = ground_check.get_collision_normal()
	return result

func _handle_movement(delta):
	# Get input (don't override movement during dash)
	if is_grounded and not is_on_rail and not is_dashing:
		#print("checking input")
		move_input = Input.get_axis("move_left", "move_right")
	elif is_dashing:
		# During dash, reduce player control
		move_input = 0.0

	# Calculate desired velocity, using rail_move_speed when on rail
	var target_speed = rail_move_speed if is_on_rail else move_speed
	var current_velocity = linear_velocity
	
	if is_on_rail:
		# On rails: maintain constant speed in current direction
		var current_direction = sign(current_velocity.x) if abs(current_velocity.x) > 0.1 else 1.0
		var target_velocity_x = current_direction * rail_move_speed
		
		# Only apply force if we're significantly below target speed
		if abs(current_velocity.x) < rail_move_speed * 0.9:
			var force_needed = (target_velocity_x - current_velocity.x) * mass * 10.0
			apply_central_force(Vector3(force_needed, 0, 0))
	else:
		# Normal ground/air movement
		var target_velocity = Vector3(move_input * target_speed, linear_velocity.y, 0)
		var velocity_diff = target_velocity.x - current_velocity.x
		var accel = acceleration if abs(move_input) > 0.1 else (friction if is_grounded else air_friction)
		
		# Reduce movement forces during dash to let dash momentum carry
		if is_dashing:
			accel *= 0.2
		
		var force = velocity_diff * accel * mass
		apply_central_force(Vector3(force, 0, 0))

func _handle_mesh_tilt(delta):
	if player_mesh:
		var target_rotation: Vector3
		if is_on_rail:
			target_rotation = Vector3(0, 0.1, 0)
		elif is_dashing:
			# Add slight tilt during dash for visual feedback
			target_rotation = Vector3(0, 0, -dash_direction * 0.2)
		else:
			# Revert to upright rotation
			target_rotation = Vector3.ZERO

		# Smoothly interpolate the mesh rotation
		var current_rotation = player_mesh.rotation
		player_mesh.rotation = Vector3(
			0, 0, lerp_angle(current_rotation.z, target_rotation.z, mesh_tilt_speed * delta))

func _on_timer_timeout() -> void:
	ground_check.enabled = true

func is_at_rail_ledge() -> bool:
	# Enhanced ledge detection to avoid false positives at curves
	var forward_distance = 1.0
	var downward_offset = ground_check_distance

	# Primary forward raycast (in direction of movement)
	var forward_check = RayCast3D.new()
	forward_check.position = global_position + Vector3(sign(linear_velocity.x) * forward_distance, 0, 0)
	forward_check.target_position = Vector3(0, -downward_offset, 0)
	add_child(forward_check)
	forward_check.force_raycast_update()
	var forward_hit = forward_check.is_colliding() and forward_check.get_collider().is_in_group("Rail")
	forward_check.queue_free()

	# Secondary raycast slightly further to confirm rail end
	var far_check = RayCast3D.new()
	far_check.position = global_position + Vector3(sign(linear_velocity.x) * forward_distance * 1.5, 0, 0)
	far_check.target_position = Vector3(0, -downward_offset, 0)
	add_child(far_check)
	far_check.force_raycast_update()
	var far_hit = far_check.is_colliding() and far_check.get_collider().is_in_group("Rail")
	far_check.queue_free()

	# Check ground normal to detect sharp curves (curves have non-vertical normals)
	var is_curve = abs(ground_normal.dot(Vector3.UP) - 1.0) > 0.1

	# Ledge is detected if primary raycast misses rail or both miss, and it's not a curve
	var at_ledge = (!forward_hit || (!forward_hit && !far_hit)) && !is_curve
	
	if at_ledge:
		print("Ledge detected")
	else:
		print("Not at ledge, possibly on curve: forward_hit=", forward_hit, ", far_hit=", far_hit, ", is_curve=", is_curve)
	
	return at_ledge

# Called by FreezeBlock when touched in midair
func trigger_freeze_jump():
	if not is_grounded and not has_double_jumped:
		print("Freeze block triggered!")
		has_double_jumped = true
		
		# Emit freeze block signal for scoring
		freeze_block_used.emit()
		
		# Freeze the entire game
		is_frozen = true
		get_tree().paused = true
		
		# Create a timer for the freeze duration
		var freeze_timer = Timer.new()
		freeze_timer.wait_time = 0.5
		freeze_timer.one_shot = true
		freeze_timer.process_mode = Node.PROCESS_MODE_ALWAYS  # Continue during pause
		add_child(freeze_timer)
		freeze_timer.timeout.connect(_on_freeze_timeout)
		freeze_timer.start()

func _on_freeze_timeout():
	# Unfreeze and apply the weaker jump
	get_tree().paused = false
	is_frozen = false
	
	# Apply weaker jump force
	apply_central_impulse(Vector3(0, freeze_jump_force * mass, 0))
	print("Freeze jump executed!")
	
	# Clean up the timer
	if has_node("Timer2"):
		$Timer2.queue_free()
