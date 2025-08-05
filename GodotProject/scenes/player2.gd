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
@export var natural_deceleration_force: float = 3.0  # Much slower deceleration when no input
@export var air_control_multiplier: float = 0.4
@export var rail_move_speed: float = 25.0
@export var jump_force: float = 10.0
@export var freeze_jump_force: float = 6.0
@export var ground_gravity: float = 9.8
@export var max_fall_speed: float = 15.0
@export var rail_force: float = 100.0

# Curved rail parameters
@export var skateboard_rotation_speed: float = 8.0
@export var player_rotation_speed: float = 8.0
@export var player_lean_factor: float = 0.5

# Dash/QTE/Spawn parameters
@export var dash_force: float = 30.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 1.0
@export var dash_gravity_reduction: float = 0.3
@export var qte_cooldown: float = 2.0
@export var qte_manual_trigger_key: String = "qte_trigger"
@export var spawn_point: Vector3 = Vector3(0, 1, 0)
@export var fall_threshold: float = -40.0
@export var ground_check_distance: float = 0.1

# Node references
@onready var ground_check: RayCast3D = $GroundCheck
@onready var player_mesh: MeshInstance3D = $MeshInstance3D
@onready var player_collision: CollisionShape3D = $PlayerCollision
@onready var player_model: Node3D = $male_casual
@onready var skateboard_collision: CollisionShape3D = $SkateboardCollision
@onready var skateboard_model: Node3D = $skateboardtest

# State variables
var is_grounded: bool = false
var is_on_rail: bool = false
var ground_normal: Vector3 = Vector3.UP
var rail_normal: Vector3 = Vector3.UP
var skateboard_target_rotation: float = 0.0
var player_target_rotation: float = 0.0
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: float = 0.0
var is_frozen: bool = false
var has_double_jumped: bool = false
var qte_system: Control = null
var is_qte_active: bool = false
var qte_cooldown_timer: float = 0.0
var was_grounded_last_frame: bool = false
var was_on_rail_last_frame: bool = false

# New direction memory variables
var last_direction: float = 1.0  # Remember last pressed direction (1 = right, -1 = left)
var current_input_direction: float = 0.0  # Current frame input

func _ready():
	# Setup physics
	if not physics_material_override: physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 1.0
	physics_material_override.bounce = 0.0
	
	# Lock axes for 2.5D movement
	axis_lock_linear_z = true
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	axis_lock_angular_z = true
	
	_find_qte_system()
	_debug_nodes()

func _debug_nodes():
	var nodes = [skateboard_collision, skateboard_model, player_collision, player_model]
	var names = ["SkateboardCollision", "skateboard test", "PlayerCollision", "male_casual"]
	for i in range(nodes.size()):
		print("ERROR: %s node not found!" % names[i] if not nodes[i] else "%s node found: %s" % [names[i], nodes[i].name])

func _physics_process(delta):
	if is_frozen: return
	if global_position.y < fall_threshold: _respawn_player(); return
	
	# Update timers
	qte_cooldown_timer = max(0, qte_cooldown_timer - delta)
	dash_cooldown_timer = max(0, dash_cooldown_timer - delta)
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0: is_dashing = false
	
	# Check ground/rail status
	var ground_info = _check_grounded()
	is_grounded = ground_info.is_grounded
	is_on_rail = ground_info.is_on_rail
	ground_normal = ground_info.ground_normal
	
	if is_on_rail:
		rail_normal = ground_normal
		_calculate_rotation_angles()
	
	# Emit signals
	_emit_state_signals()
	
	# Reset states
	if is_grounded: has_double_jumped = false
	angular_velocity = Vector3.ZERO
	
	# Apply forces
	_apply_gravity_and_forces(delta)
	
	# Handle input
	_handle_input()
	
	# Handle movement and rotations
	_handle_movement(delta)
	_handle_rotations(delta)

func _emit_state_signals():
	if was_grounded_last_frame != is_grounded:
		if was_grounded_last_frame:
			player_became_airborne.emit()
		else:
			player_landed.emit()
	
	if was_on_rail_last_frame != is_on_rail:
		if is_on_rail:
			rail_grind_started.emit()
		else:
			rail_grind_ended.emit()
			skateboard_target_rotation = 0.0
			player_target_rotation = 0.0
	
	was_grounded_last_frame = is_grounded
	was_on_rail_last_frame = is_on_rail

func _apply_gravity_and_forces(delta):
	var gravity_mult = dash_gravity_reduction if is_dashing else 1.0
	var current_vel = linear_velocity
	
	if is_on_rail:
		apply_central_force(-ground_normal * rail_force * mass * gravity_mult)
	elif not is_grounded:
		var new_y = max(current_vel.y - ground_gravity * gravity_mult * delta, -max_fall_speed)
		apply_central_force(Vector3(0, (new_y - current_vel.y) * mass / delta, 0))
	else:
		var new_y = max(current_vel.y - ground_gravity * gravity_mult * delta, -max_fall_speed)
		apply_central_force(Vector3(0, (new_y - current_vel.y) * mass / delta, 0))

func _handle_input():
	# Update current input direction and remember last pressed direction
	current_input_direction = Input.get_axis("steer_left", "steer_right")
	if abs(current_input_direction) > 0.1:
		last_direction = sign(current_input_direction)
	
	if Input.is_action_just_pressed(qte_manual_trigger_key) and is_on_rail and not is_qte_active and qte_cooldown_timer <= 0:
		_start_qte()
	
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0 and not is_dashing and not is_on_rail:
		_start_dash()
	
	if Input.is_action_just_pressed("jump"):
		if is_grounded:
			if is_on_rail:
				if not is_qte_active and qte_cooldown_timer <= 0: _start_qte()
				apply_central_impulse(Vector3.UP * jump_force)
				ground_check.enabled = false
				_create_timer(0.1, _on_timer_timeout)
			else:
				apply_central_impulse(Vector3(0, jump_force * mass, 0))
	
	if Input.is_action_just_pressed("reset"): _respawn_player()

func _create_timer(wait_time: float, callback: Callable):
	var timer = get_node_or_null("Timer")
	if not timer:
		timer = Timer.new()
		timer.name = "Timer"
		add_child(timer)
	timer.wait_time = wait_time
	timer.one_shot = true
	if not timer.timeout.is_connected(callback): timer.timeout.connect(callback)
	timer.start()

func _calculate_rotation_angles():
	var angle_from_up = acos(clamp(rail_normal.y, -1.0, 1.0))
	if abs(rail_normal.x) > 0.01:
		var base_rotation = -sign(rail_normal.x) * angle_from_up
		skateboard_target_rotation = base_rotation
		player_target_rotation = base_rotation * clamp(player_lean_factor, 0.0, 1.0)
	else:
		skateboard_target_rotation = 0.0
		player_target_rotation = 0.0

func _handle_rotations(delta):
	var nodes = [skateboard_collision, skateboard_model, player_collision, player_model, player_mesh]
	var targets = [skateboard_target_rotation, skateboard_target_rotation, player_target_rotation, player_target_rotation, player_target_rotation]
	var speeds = [skateboard_rotation_speed, skateboard_rotation_speed, player_rotation_speed, player_rotation_speed, player_rotation_speed]
	
	for i in range(nodes.size()):
		if nodes[i]:
			var current_rot = nodes[i].rotation
			var target = targets[i] if is_on_rail else ((-dash_direction * 0.2) if is_dashing and i >= 3 else 0.0)
			var new_z = lerp_angle(current_rot.z, target, speeds[i] * delta)
			nodes[i].rotation = Vector3(current_rot.x, current_rot.y, new_z)

func _start_qte():
	if is_qte_active or not qte_system: return
	is_qte_active = true
	qte_cooldown_timer = qte_cooldown
	if qte_system.has_method("start_qte"): qte_system.start_qte()

func _on_qte_completed(success: bool, score_bonus: int):
	qte_trick_completed.emit(success, score_bonus)
	is_qte_active = false

func _start_dash():
	var input_dir = current_input_direction if abs(current_input_direction) > 0.1 else last_direction
	dash_direction = input_dir
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
	return result

func _handle_movement(delta):
	var inputs = {
		"accel": Input.is_action_pressed("accelerate"),
		"brake": Input.is_action_pressed("brake"),
		"dir": current_input_direction
	}
	
	var current_vel = linear_velocity
	
	# Rail movement
	if is_on_rail:
		var current_dir = sign(current_vel.x) if abs(current_vel.x) > 0.1 else 1.0
		var target_vel_x = current_dir * rail_move_speed
		if abs(current_vel.x) < rail_move_speed * 0.9:
			apply_central_force(Vector3((target_vel_x - current_vel.x) * mass * 10.0, 0, 0))
		return
	
	if is_dashing: return
	
	var control_mult = air_control_multiplier if not is_grounded else 1.0
	var force = 0.0
	
	# Check if player is actively giving directional input
	var has_directional_input = abs(inputs.dir) > 0.1
	
	if inputs.accel:
		# Accelerate in the last remembered direction (or current input direction if actively steering)
		var accel_direction = inputs.dir if has_directional_input else last_direction
		var target_vel = accel_direction * max_speed
		var vel_diff = target_vel - current_vel.x
		force = sign(vel_diff) * acceleration_force * control_mult
		if abs(vel_diff) < abs(force * delta / mass): force = vel_diff * mass / delta
	elif inputs.brake:
		# Brake regardless of direction
		force = -sign(current_vel.x) * deceleration_force * 1.5 * control_mult
		if abs(current_vel.x) < 1.0: force = -current_vel.x * mass / delta
	elif has_directional_input:
		# Move in the direction being pressed (without accelerate)
		var target_vel = inputs.dir * max_speed * 0.7
		var vel_diff = target_vel - current_vel.x
		force = sign(vel_diff) * acceleration_force * 0.5 * control_mult
		if abs(vel_diff) < abs(force * delta / mass): force = vel_diff * mass / delta
	else:
		# No input - use natural deceleration (much slower)
		if abs(current_vel.x) > 0.1:
			# Continue in last direction but slowly decelerate
			var target_vel = last_direction * max_speed * 0.8  # Continue at 80% max speed
			var vel_diff = target_vel - current_vel.x
			
			# If we're going faster than our target, slow down
			if (last_direction > 0 and current_vel.x > target_vel) or (last_direction < 0 and current_vel.x < target_vel):
				force = -sign(current_vel.x) * natural_deceleration_force * control_mult
			# If we're going slower or opposite direction, gently accelerate toward target
			elif sign(current_vel.x) != last_direction or abs(current_vel.x) < abs(target_vel):
				force = sign(vel_diff) * natural_deceleration_force * 2.0 * control_mult
			
			# Prevent oscillation around target velocity
			if abs(vel_diff) < abs(force * delta / mass): 
				force = vel_diff * mass / delta
			
			# Stop very slow movement
			if abs(current_vel.x) < 0.5: 
				force = -current_vel.x * mass / delta
	
	if abs(force) > 0.01: apply_central_force(Vector3(force * mass, 0, 0))

func _on_timer_timeout(): ground_check.enabled = true

func is_at_rail_ledge() -> bool:
	if not is_on_rail: return false
	
	var forward_dist = 1.0
	var vel_sign = sign(linear_velocity.x)
	var checks = [forward_dist, forward_dist * 1.5]
	var hits = []
	
	for dist in checks:
		var raycast = RayCast3D.new()
		raycast.position = global_position + Vector3(vel_sign * dist, 0, 0)
		raycast.target_position = Vector3(0, -ground_check_distance, 0)
		add_child(raycast)
		raycast.force_raycast_update()
		hits.append(raycast.is_colliding() and raycast.get_collider() and raycast.get_collider().is_in_group("Rail"))
		raycast.queue_free()
	
	var is_curve = abs(ground_normal.dot(Vector3.UP) - 1.0) > 0.1
	return (!hits[0] or (!hits[0] and !hits[1])) and not is_curve

func trigger_freeze_jump():
	if not is_grounded and not has_double_jumped:
		has_double_jumped = true
		freeze_block_used.emit()
		is_frozen = true
		# Use a different approach - create an unpaused timer
		var timer = Timer.new()
		timer.process_mode = Node.PROCESS_MODE_ALWAYS  # This makes it work even when paused
		timer.wait_time = 0.4
		timer.one_shot = true
		add_child(timer)
		timer.timeout.connect(_on_freeze_timeout)
		get_tree().paused = true
		timer.start()

func _on_freeze_timeout():
	get_tree().paused = false
	is_frozen = false
	apply_central_impulse(Vector3(0, freeze_jump_force * mass, 0))
	# Clean up the timer
	for child in get_children():
		if child is Timer and child.process_mode == Node.PROCESS_MODE_ALWAYS:
			child.queue_free()

func _respawn_player():
	global_position = spawn_point
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	skateboard_target_rotation = 0.0
	player_target_rotation = 0.0
	last_direction = 1.0  # Reset to right
	current_input_direction = 0.0
	
	var nodes = [skateboard_collision, skateboard_model, player_collision, player_model, player_mesh]
	for node in nodes:
		if node: node.rotation = Vector3.ZERO
	
	is_grounded = false
	is_on_rail = false
	has_double_jumped = false
	is_dashing = false
	dash_timer = 0.0
	
	if is_qte_active and qte_system:
		qte_system.force_stop_qte()
		is_qte_active = false
	
	if ground_check: ground_check.enabled = true

func set_spawn_point(new_spawn_point: Vector3): spawn_point = new_spawn_point

func _find_qte_system():
	qte_system = get_node_or_null("QTESystem")
	if not qte_system and get_parent():
		qte_system = get_parent().get_node_or_null("QTESystem")
	if not qte_system and get_tree().current_scene:
		qte_system = _find_node_recursive(get_tree().current_scene, "QTESystem")
	if qte_system: _connect_qte_system()

func _find_node_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name: return node
	for child in node.get_children():
		var result = _find_node_recursive(child, target_name)
		if result: return result
	return null

func _connect_qte_system():
	if qte_system and qte_system.has_signal("qte_completed") and not qte_system.qte_completed.is_connected(_on_qte_completed):
		qte_system.qte_completed.connect(_on_qte_completed)

func set_qte_system(qte: Control):
	qte_system = qte
	if qte_system: _connect_qte_system()
