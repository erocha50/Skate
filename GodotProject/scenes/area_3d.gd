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
	
	# Set up materials
	_setup_materials()

func _setup_materials():
	# Original material - glowing blue
	var original_mat = StandardMaterial3D.new()
	original_mat.albedo_color = Color(0.2, 0.5, 1.0, 0.8)  # Semi-transparent blue
	original_mat.emission_enabled = true
	original_mat.emission = Color(0.1, 0.3, 0.8)
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
	# Handle reset timer
	if is_activated and reset_timer > 0:
		reset_timer -= delta
		if reset_timer <= 0:
			_reset_block()
	
	# Add a subtle floating animation
	if not is_activated:
		var time = Time.get_time_dict_from_system()
		var float_offset = sin(time.second + time.minute * 60 + randf() * 10) * 0.1
		position.y += float_offset * delta

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
				_activate_block()
				player.trigger_freeze_jump()
			else:
				print("FreezeBlock: Player must be in midair to activate")

func _activate_block():
	print("FreezeBlock activated!")
	is_activated = true
	reset_timer = reset_duration
	
	# Visual feedback - flash white
	mesh_instance.material_override = activated_material
	
	# Optional: Add scale animation for extra effect
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.2, 0.1)
	tween.tween_property(self, "scale", Vector3.ONE, 0.1)

func _reset_block():
	print("FreezeBlock reset - ready for use")
	is_activated = false
	
	# Return to original material
	mesh_instance.material_override = original_material
	
	# Reset scale just in case
	scale = Vector3.ONE
