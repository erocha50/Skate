extends RigidBody3D
@export var barrel_scene: PackedScene
@export var spawn_height: float = 10.0
var has_spawned_barrel: bool = false

func _ready():
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
	
	# Check if a barrel touched this rigidbody
	if body.is_in_group("barrel"):
		unlock_rigidbody()

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

func unlock_rigidbody():
	# Unlock all axes
	axis_lock_linear_x = false
	axis_lock_linear_y = false
	axis_lock_linear_z = false
	axis_lock_angular_x = false
	axis_lock_angular_y = false
	axis_lock_angular_z = false
	print("RigidBody unlocked and ready to fall!")

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
