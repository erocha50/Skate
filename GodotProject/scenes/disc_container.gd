extends Node3D

@export var smooth_movement: bool = true
@export var movement_speed: float = 8.0
@export var disc_spacing: float = 3.0

var target_position: Vector3 = Vector3.ZERO
var disc_nodes: Array[Node3D] = []

func _ready() -> void:
	target_position = position
	setup_disc_positions()

func _process(delta: float) -> void:
	if smooth_movement:
		position = position.lerp(target_position, movement_speed * delta)

func setup_disc_positions() -> void:
	# Get all child disc nodes
	disc_nodes.clear()
	for child in get_children():
		if child.name.begins_with("MusicDisc") and child is Node3D:
			disc_nodes.append(child as Node3D)
	
	# Position discs in a line: far left (-6), left (-3), center (0), right (+3), far right (+6)
	# For 5 discs: positions are -6, -3, 0, +3, +6
	for i in range(disc_nodes.size()):
		var disc = disc_nodes[i]
		# Calculate position: (i - 2) * disc_spacing gives us -6, -3, 0, +3, +6
		disc.position.x = (i - 2) * disc_spacing
		disc.position.y = 0
		disc.position.z = 0
		
		print("Positioned ", disc.name, " at x=", disc.position.x)

func move_to_position(new_position: Vector3) -> void:
	target_position = new_position

func set_immediate_position(new_position: Vector3) -> void:
	position = new_position
	target_position = new_position

# Method to center a specific disc by moving the container
func center_disc(disc_index: int) -> void:
	if disc_index >= 0 and disc_index < disc_nodes.size():
		# Calculate offset needed to center the disc
		# For 5 discs: disc 0 needs +6, disc 1 needs +3, disc 2 needs 0, disc 3 needs -3, disc 4 needs -6
		var offset = (2 - disc_index) * disc_spacing
		target_position.x = offset
		print("Centering disc ", disc_index, " with container offset: ", offset)

# Get the currently centered disc index based on container position
func get_centered_disc_index() -> int:
	var offset = target_position.x
	var disc_index = 2 - round(offset / disc_spacing)
	return clamp(disc_index, 0, disc_nodes.size() - 1)

# Snap to the nearest valid position (centers one of the discs)
func snap_to_nearest_disc() -> int:
	var current_offset = position.x
	var disc_index = 2 - round(current_offset / disc_spacing)
	disc_index = clamp(disc_index, 0, disc_nodes.size() - 1)
	center_disc(disc_index)
	return disc_index
