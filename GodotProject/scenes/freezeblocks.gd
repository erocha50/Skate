extends Node3D
class_name FreezeBlocks

@onready var area_3d: Area3D = $Area3D
@onready var collision_shape: CollisionShape3D = $Area3D/CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var billboard_sprite: Sprite3D = $BillboardSprite

# State tracking
var is_activated: bool = false
var reset_timer: float = 0.0
var reset_duration: float = 1.0  # Time before block can be used again

# Animation variables
var initial_y_position: float
var time_passed: float = 0.0

# Billboard animation variables
var billboard_pulse_speed: float = 2.0
var billboard_pulse_intensity: float = 0.1

# Texture swapping for white effect (billboard only)
@export var original_billboard_texture: Texture2D
@export var white_billboard_texture: Texture2D

func _ready():
	# Set up the groups
	add_to_group("FreezeBlock")
	
	# Store initial position for potential future animations
	initial_y_position = position.y
	
	# Create Area3D if it doesn't exist
	if not area_3d:
		area_3d = Area3D.new()
		area_3d.name = "Area3D"
		add_child(area_3d)
	
	# Connect the body entered signal
	area_3d.body_entered.connect(_on_body_entered)
	
	# Create collision shape if it doesn't exist
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		area_3d.add_child(collision_shape)
	
	# Set up collision shape
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1.0, 1.0, 1.0)
	collision_shape.shape = box_shape
	
	# Create billboard sprite if it doesn't exist
	setup_billboard_sprite()
	
	# Setup initial textures
	setup_initial_textures()

func setup_billboard_sprite():
	if not billboard_sprite:
		billboard_sprite = Sprite3D.new()
		billboard_sprite.name = "BillboardSprite"
		add_child(billboard_sprite)
	
	# Configure the billboard settings
	billboard_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	billboard_sprite.transparent = true
	billboard_sprite.no_depth_test = true
	billboard_sprite.fixed_size = true
	
	# Scale it to be slightly larger than the pizza
	billboard_sprite.pixel_size = 0.01  # Adjust this to control size
	
	# Position it slightly behind the pizza so it acts as an outline
	billboard_sprite.position = Vector3(0, 0, 0.1)
	
	# Load your outline texture here
	# Replace "res://path/to/your/outline_texture.png" with your actual texture path
	# billboard_sprite.texture = load("res://path/to/your/outline_texture.png")
	
	# For now, create a simple colored material as placeholder
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.8, 1.0, 0.7)  # Light blue with transparency
	material.flags_transparent = true
	material.flags_unshaded = true
	billboard_sprite.material_override = material
	
	# Set initial billboard texture if provided
	if original_billboard_texture:
		billboard_sprite.texture = original_billboard_texture

func setup_initial_textures():
	# Set initial billboard texture if provided through the exported variables
	if billboard_sprite and original_billboard_texture:
		billboard_sprite.texture = original_billboard_texture

func apply_white_effect():
	# Switch to white billboard texture only
	if billboard_sprite and white_billboard_texture:
		billboard_sprite.texture = white_billboard_texture

func remove_white_effect():
	# Switch back to original billboard texture only
	if billboard_sprite and original_billboard_texture:
		billboard_sprite.texture = original_billboard_texture

func _physics_process(delta):
	time_passed += delta
	
	# Handle reset timer
	if is_activated and reset_timer > 0:
		reset_timer -= delta
		if reset_timer <= 0:
			reset_block()
	
	# Animate billboard sprite with subtle pulsing effect
	animate_billboard(delta)

func animate_billboard(delta):
	if billboard_sprite and not is_activated:
		# Create a gentle pulsing effect
		var pulse = sin(time_passed * billboard_pulse_speed) * billboard_pulse_intensity
		var base_scale = 1.2  # Base scale relative to the pizza
		billboard_sprite.scale = Vector3.ONE * (base_scale + pulse)
		
		# Optional: Add slight rotation for more dynamic effect
		billboard_sprite.rotation.z = sin(time_passed * 0.5) * 0.05

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
	
	# Apply white effect to billboard only
	apply_white_effect()
	
	# Stop rotation and reset position when activated
	if mesh_instance:
		mesh_instance.rotation.y = 0
	
	# Reset to initial position
	position.y = initial_y_position
	
	# Animate the billboard sprite on activation
	animate_activation_effect()
	
	# Optional: Add scale animation for effect (to entire Node3D)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.2, 0.1)
	tween.tween_property(self, "scale", Vector3.ONE, 0.1)

func animate_activation_effect():
	if billboard_sprite:
		var tween = create_tween()
		tween.parallel().tween_property(billboard_sprite, "scale", Vector3.ONE * 2.0, 0.2)
		tween.parallel().tween_property(billboard_sprite, "modulate:a", 0.2, 0.2)
		tween.tween_property(billboard_sprite, "scale", Vector3.ONE * 1.2, 0.3)
		tween.parallel().tween_property(billboard_sprite, "modulate:a", 0.7, 0.3)

func reset_block():
	print("FreezeBlock reset - ready for use")
	is_activated = false
	
	# Remove white effect and restore original texture
	remove_white_effect()
	
	# Reset scale just in case
	scale = Vector3.ONE
	
	# Reset billboard sprite
	if billboard_sprite:
		billboard_sprite.scale = Vector3.ONE * 1.2
		billboard_sprite.modulate.a = 0.7
