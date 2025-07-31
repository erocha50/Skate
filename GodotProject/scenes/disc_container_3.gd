extends Node3D

var smooth_movement = true
var movement_speed = 8.0
var target_position = Vector3.ZERO

# Variables for managing disc positions
var disc_spacing = 3.0
var disc_nodes = []

func _ready():
	target_position = position
	setup_disc_positions()

func _process(delta):
	if smooth_movement:
		position = position.lerp(target_position, movement_speed * delta)

func setup_disc_positions():
	# Get all child disc nodes
	disc_nodes.clear()
	for child in get_children():
		if child.name.begins_with("MusicDisc"):
			disc_nodes.append(child)
	
	# Position discs in a line: left (-3), center (0), right (+3)
	for i in range(disc_nodes.size()):
		var disc = disc_nodes[i]
		disc.position.x = (i - 1) * disc_spacing
		disc.position.y = 0
		disc.position.z = 0
		
		print("Positioned ", disc.name, " at x=", disc.position.x)

func move_to_position(new_position: Vector3):
	target_position = new_position

func set_immediate_position(new_position: Vector3):
	position = new_position
	target_position = new_position

# Method to center a specific disc by moving the container
func center_disc(disc_index: int):
	if disc_index >= 0 and disc_index < disc_nodes.size():
		# Calculate offset needed to center the disc
		# Disc 0 (left): container moves +3, Disc 1 (center): +0, Disc 2 (right): -3
		var offset = (1 - disc_index) * disc_spacing
		target_position.x = offset
		print("Centering disc ", disc_index, " with container offset: ", offset)

# Get the currently centered disc index based on container position
func get_centered_disc_index() -> int:
	var offset = target_position.x
	var disc_index = 1 - round(offset / disc_spacing)
	return clamp(disc_index, 0, disc_nodes.size() - 1)

# Snap to the nearest valid position (centers one of the discs)
func snap_to_nearest_disc():
	var current_offset = position.x
	var disc_index = 1 - round(current_offset / disc_spacing)
	disc_index = clamp(disc_index, 0, disc_nodes.size() - 1)
	center_disc(disc_index)
	return disc_index
