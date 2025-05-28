extends RigidBody3D

# Player states
enum State { AIRBORNE, GRINDING, GROUNDED }
var current_state = State.AIRBORNE

# Movement variables
@export var move_speed: float = 8.0
@export var jump_force: float = 1.0
@export var rail_attraction_force: float = 50.0
@export var rail_detection_distance: float = 2.0
@export var grind_speed_multiplier: float = 1.2

# Rail grinding variables
var is_on_rail: bool = false
var rail_surface_normal: Vector3
var rail_contact_point: Vector3
var current_rail: StaticBody3D

# Input variables
var move_input: float = 0.0
var jump_pressed: bool = false

# Camera follow
@onready var camera_pivot = get_node("../CameraPivot")
@onready var camera = get_node("../CameraPivot/Camera3D")

func _ready():
	# Set up rigidbody properties
	gravity_scale = 1.0
	mass = 1.0
	
	# Connect to physics
	contact_monitor = true
	max_contacts_reported = 10

func _input(event):
	# Handle input (2D side-scrolling style)
	move_input = Input.get_axis("ui_left", "ui_right")
	jump_pressed = Input.is_action_just_pressed("ui_accept")

func _physics_process(delta):
	handle_movement(delta)
	detect_rails()
	update_camera()
	update_state()

func handle_movement(delta):
	match current_state:
		State.AIRBORNE:
			handle_air_movement(delta)
		State.GRINDING:
			handle_rail_grinding(delta)
		State.GROUNDED:
			handle_ground_movement(delta)

func handle_air_movement(delta):
	# Air control (limited)
	var air_control_force = Vector3(move_input * 5.0, 0, 0)
	apply_central_force(air_control_force)
	
	# Rotation for tricks (simple version)
	if move_input != 0:
		apply_torque(Vector3(0, 0, -move_input * 10.0))

func handle_rail_grinding(delta):
	if not is_on_rail:
		return
	
	# Apply attraction force to stick to rail
	var attraction_direction = (rail_contact_point - global_position).normalized()
	var attraction = attraction_direction * rail_attraction_force
	apply_central_force(attraction)
	
	# Movement along rail (in 2D plane)
	var rail_forward = Vector3(1, 0, 0)  # Assuming rails go left-right
	var grind_force = rail_forward * move_input * move_speed * grind_speed_multiplier
	apply_central_force(grind_force)
	
	# Dampen unwanted movement
	var velocity_2d = Vector3(linear_velocity.x, 0, linear_velocity.z)
	if velocity_2d.length() > move_speed * 2:
		linear_velocity = Vector3(
			linear_velocity.x * 0.9,
			linear_velocity.y,
			linear_velocity.z * 0.1  # Heavily dampen Z movement
		)
	
	# Jump off rail
	if jump_pressed:
		leave_rail()
		apply_central_impulse(Vector3(0, jump_force, 0))

func handle_ground_movement(delta):
	# Basic ground movement
	var ground_force = Vector3(move_input * move_speed, 0, 0)
	apply_central_force(ground_force)
	
	# Jump
	if jump_pressed and is_on_floor():
		apply_central_impulse(Vector3(0, jump_force, 0))

func detect_rails():
	# Raycast downward to detect rails
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + Vector3(0, -rail_detection_distance, 0)
	)
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.get("collider")
		if collider and collider.is_in_group("rails"):
			attach_to_rail(collider, result.get("position"), result.get("normal"))
		else:
			leave_rail()
	else:
		leave_rail()

func attach_to_rail(rail: StaticBody3D, contact_point: Vector3, surface_normal: Vector3):
	if not is_on_rail:
		is_on_rail = true
		current_rail = rail
		current_state = State.GRINDING
		
		# Reduce gravity while grinding
		gravity_scale = 0.3
	
	rail_contact_point = contact_point
	rail_surface_normal = surface_normal

func leave_rail():
	if is_on_rail:
		is_on_rail = false
		current_rail = null
		current_state = State.AIRBORNE
		gravity_scale = 1.0

func update_state():
	if not is_on_rail and is_on_floor():
		current_state = State.GROUNDED
	elif not is_on_rail and not is_on_floor():
		current_state = State.AIRBORNE

func is_on_floor() -> bool:
	# Simple floor detection
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + Vector3(0, -1.1, 0)
	)
	var result = space_state.intersect_ray(query)
	return result != null

func update_camera():
	# Check if camera nodes exist before using them
	if not camera_pivot or not camera:
		return
	
	# Simple camera follow (side-view)
	var target_pos = global_position + Vector3(0, 2, 10)
	camera_pivot.global_position = camera_pivot.global_position.lerp(target_pos, 0.05)
	
	# Keep camera looking at player
	camera.look_at(global_position, Vector3.UP)
