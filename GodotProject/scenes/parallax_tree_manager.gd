@tool
extends Node3D
class_name ParallaxTreeManager

@export var player_reference: Node3D
@export var tree_layers: Array[Node3D] = []  # Changed from ParallaxTreeLayer to Node3D

var initial_player_position: Vector3

func _ready():
	if player_reference:
		initial_player_position = player_reference.global_position
	
	# Initialize tree layers if not set in editor
	if tree_layers.is_empty():
		for child in get_children():
			if child.has_method("update_parallax"):  # Check if it has the parallax method
				tree_layers.append(child)

func _process(_delta):
	if not player_reference:
		return
	
	var player_movement = player_reference.global_position - initial_player_position
	
	for layer in tree_layers:
		if layer:
			layer.update_parallax(player_movement)
