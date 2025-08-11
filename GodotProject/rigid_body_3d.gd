extends RigidBody3D

@export var barrel_scene: PackedScene
@export var spawn_height: float = 10.0
@export var shake_intensity: float = 0.5
@export var shake_duration: float = 1.0
@export var fall_delay: float = 0.5

var has_spawned_barrel: bool = false
var original_position: Vector3
var is_shaking: bool = false
var has_fallen: bool = false

func _ready():
	# Store original position for shake effect
	original_position = global_position
	
	# Start locked on all axes
	axis_lock_linear_x = true
	axis_lock_linear_y = true
	axis_lock_linear_z = true
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	axis_lock_angular_z = true
	
	# Connect collision signals
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Check if a player touched this rigidbody and we haven't spawned a barrel yet
	if body.is_in_group("player") and not has_spawned_barrel:
		spawn_barrel()
	
	# Check if a barrel touched this rigidbody and we haven't fallen yet
	if body.is_in_group("barrel") and not has_fallen:
		start_cartoon_sequence()

func spawn_barrel():
	if barrel_scene == null:
		print("Warning: No barrel scene assigned!")
		return
	
	# Instantiate the barrel
	var barrel_instance = barrel_scene.instantiate()
	
	# Position it above this rigidbody
	var spawn_position = global_position + Vector3(0, spawn_height, 0)
	barrel_instance.global_position = spawn_position
	
	# Add the barrel to the scene
	get_tree().current_scene.add_child(barrel_instance)
	
	# Make sure the barrel is in the "barrel" group
	if not barrel_instance.is_in_group("barrel"):
		barrel_instance.add_to_group("barrel")
	
	has_spawned_barrel = true
	print("Barrel spawned at position: ", spawn_position)

func start_cartoon_sequence():
	if is_shaking or has_fallen:
		return
	
	print("Platform hit! Starting cartoon sequence...")
	start_shake_effect()
	
	# Wait for shake to finish, then fall
	await get_tree().create_timer(shake_duration + fall_delay).timeout
	start_fall_sequence()

func start_shake_effect():
	if is_shaking:
		return
	
	is_shaking = true
	var shake_tween = create_tween()
	
	# Create rapid back-and-forth shaking
	var shake_count = int(shake_duration * 20)  # 20 shakes per second
	var shake_time = shake_duration / shake_count
	
	for i in range(shake_count):
		var random_offset = Vector3(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity * 0.3, shake_intensity * 0.3),  # Less vertical shake
			randf_range(-shake_intensity, shake_intensity)
		)
		
		shake_tween.tween_property(self, "global_position", original_position + random_offset, shake_time)
	
	# Return to original position at the end
	shake_tween.tween_property(self, "global_position", original_position, shake_time)
	
	# Stop shaking after duration
	get_tree().create_timer(shake_duration).timeout.connect(_stop_shaking)

func _stop_shaking():
	is_shaking = false
	global_position = original_position

func start_fall_sequence():
	if has_fallen:
		return
	
	has_fallen = true
	print("Platform falling!")
	
	# Disable collision with other objects (except world/static bodies)
	set_collision_layer_value(1, false)  # Disable main collision layer
	
	# Unlock all axes for realistic falling
	unlock_rigidbody()
	
	# Add some dramatic cartoon-style initial velocity
	var cartoon_impulse = Vector3(
		randf_range(-2.0, 2.0),  # Random sideways motion
		-1.0,                    # Slight downward push
		randf_range(-2.0, 2.0)   # Random forward/backward motion
	)
	apply_central_impulse(cartoon_impulse)
	
	# Add some spin for cartoon effect
	var spin_impulse = Vector3(
		randf_range(-5.0, 5.0),
		randf_range(-3.0, 3.0),
		randf_range(-5.0, 5.0)
	)
	apply_torque_impulse(spin_impulse)
	
	# Optional: Remove the platform after it falls off screen
	get_tree().create_timer(10.0).timeout.connect(_cleanup_platform)

func _cleanup_platform():
	# Check if platform has fallen far enough to be removed
	if global_position.y < original_position.y - 50:
		queue_free()

func unlock_rigidbody():
	# Unlock all axes
	axis_lock_linear_x = false
	axis_lock_linear_y = false
	axis_lock_linear_z = false
	axis_lock_angular_x = false
	axis_lock_angular_y = false
	axis_lock_angular_z = false

# Optional: Reset function if you want to reuse the trigger
func reset_trigger():
	# Lock all axes again
	axis_lock_linear_x = true
	axis_lock_linear_y = true
	axis_lock_linear_z = true
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	axis_lock_angular_z = true
	
	has_spawned_barrel = false
	is_shaking = false
	has_fallen = false
	global_position = original_position
	
	# Re-enable collision
	set_collision_layer_value(1, true)
