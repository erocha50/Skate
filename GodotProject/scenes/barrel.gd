extends RigidBody3D

# Simple cleanup script for barrels that fall off the world
# This is the ONLY code the barrel needs!

func _ready():
	# Set up basic physics properties
	mass = 3.0  # Make it heavy for good impact
	
	# Add physics material for realistic bouncing
	var physics_material = PhysicsMaterial.new()
	physics_material.bounce = 0.4
	physics_material.friction = 0.7
	set_physics_material_override(physics_material)
	
	# Add to barrel group so platform can identify it
	add_to_group("barrel")
	
	print("Simple barrel created!")

# Clean up if barrel falls too far down
func _integrate_forces(state):
	if global_position.y < -50:
		print("Barrel fell too far - cleaning up")
		queue_free()
