extends Area3D
class_name FreezeBlocks
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
# Visual feedback
var original_material: Material
var activated_material: StandardMaterial3D
var is_activated: bool = false
var reset_timer: float = 0.0
var reset_duration: float = 1.0  # Time before block can be used again

# Animation variables
var bob_speed: float = 2.0
var bob_height: float = 0.3
var rotation_speed: float = 1.0
var initial_mesh_y_position: float
var initial_collision_y_position: float
var time_passed: float = 0.0

func _ready():
	# Set up the groups
	add_to_group("FreezeBlock")
	
	# Connect the body entered signal
	body_entered.connect(_on_body_entered)
	
	# Create the block mesh if it doesn't exist
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		add_child(mesh_instance)
	
	# Create a simple cube mesh
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1.0, 1.0, 1.0)
	mesh_instance.mesh = box_mesh
	
	# Create collision shape if it doesn't exist
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		add_child(collision_shape)
	
	# Set up collision shape
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1.0, 1.0, 1.0)
	collision_shape.shape = box_shape
	
	# Store initial positions for bobbing animation AFTER creating the nodes
	initial_mesh_y_position = mesh_instance.position.y
	initial_collision_y_position = collision_shape.position.y
	
	# Set up materials
	setup_materials()

func setup_materials():
	# Original material - less blue, more transparent
	var original_mat = StandardMaterial3D.new()
	original_mat.albedo_color = Color(0.4, 0.7, 1.0, 0.4)  # Lighter blue with more transparency
	original_mat.emission_enabled = true
	original_mat.emission = Color(0.05, 0.15, 0.4)  # Reduced emission intensity
	original_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	original_material = original_mat
	
	# Activated material - bright white flash
	activated_material = StandardMaterial3D.new()
	activated_material.albedo_color = Color.WHITE
	activated_material.emission_enabled = true
	activated_material.emission = Color.WHITE
	activated_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Apply original material
	mesh_instance.material_override = original_material

func _physics_process(delta):
	time_passed += delta
	
	# Handle reset timer
	if is_activated and reset_timer > 0:
		reset_timer -= delta
		if reset_timer <= 0:
			reset_block()
	
	# Only animate when not activated
	if not is_activated:
		# Bobbing animation - apply to both mesh and collision shape
		var bob_offset = sin(time_passed * bob_speed) * bob_height
		mesh_instance.position.y = initial_mesh_y_position + bob_offset
		collision_shape.position.y = initial_collision_y_position + bob_offset
		
		# Rotation animation - apply only to mesh
		mesh_instance.rotation.y = time_passed * rotation_speed

func _on_body_entered(body):
	# Check if it's the player and they're in midair
	if body.name == "Player" and not is_activated:  # Assuming your player node is named "Player"
		var player = body as RigidBody3D
		
		# Check if player is in midair (not grounded)
		if player.has_method("trigger_freeze_jump"):
			var is_grounded = false
			
			# Try to get the grounded state from the player
			if "is_grounded" in player:
				is_grounded = player.is_grounded
			
			# Only trigger if player is not grounded (in midair)
			if not is_grounded:
				activate_block()
				player.trigger_freeze_jump()
			else:
				print("FreezeBlock: Player must be in midair to activate")

func activate_block():
	print("FreezeBlock activated!")
	is_activated = true
	reset_timer = reset_duration
	
	# Visual feedback - flash white
	mesh_instance.material_override = activated_material
	
	# Stop rotation when activated
	mesh_instance.rotation.y = 0
	
	# Optional: Add scale animation for extra effect (only to mesh)
	var tween = create_tween()
	tween.tween_property(mesh_instance, "scale", Vector3.ONE * 1.2, 0.1)
	tween.tween_property(mesh_instance, "scale", Vector3.ONE, 0.1)

func reset_block():
	print("FreezeBlock reset - ready for use")
	is_activated = false
	
	# Return to original material
	mesh_instance.material_override = original_material
	
	# Reset mesh scale just in case
	mesh_instance.scale = Vector3.ONE
