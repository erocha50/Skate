extends RigidBody3D

# Movement parameters
@export var move_speed: float = 15.0  # Standard speed for Sonic-like movement
@export var rail_move_speed: float = 25.0  # Higher speed when on rails
@export var jump_force: float = 10.0  # Higher for Mario-like jump height
@export var ground_gravity: float = 9.8
@export var jump_gravity: float = 6.0  # Lower gravity for floaty Mario-like jumps
@export var max_fall_speed: float = 15.0  # Cap falling speed
@export var acceleration: float = 20.0  # Snappier acceleration
@export var friction: float = 2.0  # Ground friction for stopping
@export var air_friction: float = 2.0  # Lower friction in air for momentum
@export var rail_force: float = 100.0  # Downward force when on rails
@export var mesh_tilt_speed: float = 10.0  # Speed of mesh tilt interpolation

# Ground check
@export var ground_check_distance: float = 0.1
@onready var ground_check: RayCast3D = $GroundCheck
@onready var player_mesh: MeshInstance3D = $PlayerMesh
var is_grounded: bool = false
var is_on_rail: bool = false
var ground_normal: Vector3 = Vector3.UP
var move_input : float  = 0.0
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
	# Check if grounded and on rail
	var ground_info = _check_grounded()
	is_grounded = ground_info.is_grounded
	is_on_rail = ground_info.is_on_rail
	ground_normal = ground_info.ground_normal

	# Prevent rotation of the RigidBody3D
	angular_velocity = Vector3.ZERO

	# Apply gravity or rail force
	if not is_grounded:
		var current_velocity = linear_velocity
		var new_y_velocity = max(current_velocity.y - ground_gravity * delta, -max_fall_speed)
		apply_central_force(Vector3(0, (new_y_velocity - current_velocity.y) * mass / delta, 0))
	elif is_on_rail:
		# Apply downward force along the rail's normal
		apply_central_force(-ground_normal * rail_force * mass)
	else:
		# Apply regular gravity when grounded but not on rail
		var current_velocity = linear_velocity
		var new_y_velocity = max(current_velocity.y - ground_gravity * delta, -max_fall_speed)
		apply_central_force(Vector3(0, (new_y_velocity - current_velocity.y) * mass / delta, 0))

	# Handle movement
	_handle_movement(delta)

	# Handle jump
	if Input.is_action_just_pressed("jump") and (is_grounded or is_on_rail):
		print("jump")
		apply_central_impulse(Vector3(0, jump_force * mass, 0))
		if is_on_rail:
			ground_check.enabled = false
			$Timer.start()

	# Handle mesh tilt
	_handle_mesh_tilt(delta)

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
	# Get input
	if is_grounded and not is_on_rail:
		print("checking input")
		move_input = Input.get_axis("move_left", "move_right")

	# Calculate desired velocity, using rail_move_speed when on rail
	var target_speed = rail_move_speed if is_on_rail else move_speed
	var target_velocity = Vector3(move_input * target_speed, linear_velocity.y, 0)

	# Apply acceleration or friction
	var current_velocity = linear_velocity
	var velocity_diff = target_velocity.x - current_velocity.x
	var accel = acceleration if abs(move_input) > 0.1 else (friction if is_grounded else air_friction)
	var force = current_velocity.x
	if not is_on_rail:
		force = velocity_diff * accel * mass


	# Apply force for smooth sliding
	apply_central_force(Vector3(force, 0, 0))

func _handle_mesh_tilt(delta):
	if player_mesh:
		var target_rotation: Vector3
		if is_on_rail:

			target_rotation = Vector3(0,0.1,0)#basis.get_euler()
		else:
			# Revert to upright rotation
			target_rotation = Vector3.ZERO

		# Smoothly interpolate the mesh rotation
		var current_rotation = player_mesh.rotation
		player_mesh.rotation = Vector3(
			0,0,lerp_angle(current_rotation.z, target_rotation.y, mesh_tilt_speed * delta))
		#)


func _on_timer_timeout() -> void:
	ground_check.enabled = true
