@tool
extends Node3D
class_name ParallaxTreeLayer

@export_group("Parallax Settings")
@export var parallax_factor: float = 0.5  # How much this layer moves (0.0 = no movement, 1.0 = same as player)
@export var background_position: Vector3 = Vector3.ZERO  # Base position of this layer
@export var layer_depth: float = -10.0  # How far back this layer is

@export_group("Tree Settings") 
@export var tree_count: int = 10
@export var tree_spacing: float = 5.0
@export var tree_mesh: Mesh  # Drag your tree mesh here
@export var tree_material: Material

var initial_position: Vector3
var tree_instances: Array[MeshInstance3D] = []

func _ready():
	initial_position = global_position + background_position
	global_position.z = layer_depth
	
	if tree_instances.is_empty():
		generate_trees()

func generate_trees():
	# Clear existing trees
	for tree in tree_instances:
		if is_instance_valid(tree):
			tree.queue_free()
	tree_instances.clear()
	
	# Generate new trees
	for i in range(tree_count):
		var tree = MeshInstance3D.new()
		add_child(tree)
		
		# Set mesh and material
		if tree_mesh:
			tree.mesh = tree_mesh
		else:
			# Create a simple tree mesh if none provided
			tree.mesh = create_simple_tree_mesh()
		
		if tree_material:
			tree.material_override = tree_material
		
		# Position the tree
		var x_pos = i * tree_spacing - (tree_count * tree_spacing * 0.5)
		tree.position = Vector3(x_pos, 0, 0)
		
		# Add some random variation
		tree.position.y += randf_range(-1.0, 1.0)
		tree.scale *= randf_range(0.8, 1.2)
		tree.rotation.y = randf() * TAU
		
		tree_instances.append(tree)

func create_simple_tree_mesh() -> ArrayMesh:
	var array_mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	# Simple tree trunk (cylinder)
	var trunk_height = 2.0
	var trunk_radius = 0.2
	var segments = 8
	
	# Trunk vertices
	for i in range(segments + 1):
		var angle = i * TAU / segments
		var x = cos(angle) * trunk_radius
		var z = sin(angle) * trunk_radius
		
		# Bottom vertex
		vertices.append(Vector3(x, 0, z))
		normals.append(Vector3(x, 0, z).normalized())
		uvs.append(Vector2(float(i) / segments, 0))
		
		# Top vertex
		vertices.append(Vector3(x, trunk_height, z))
		normals.append(Vector3(x, 0, z).normalized())
		uvs.append(Vector2(float(i) / segments, 1))
	
	# Trunk indices
	for i in range(segments):
		var bottom1 = i * 2
		var top1 = i * 2 + 1
		var bottom2 = ((i + 1) % segments) * 2
		var top2 = ((i + 1) % segments) * 2 + 1
		
		# Two triangles per segment
		indices.append_array([bottom1, top1, bottom2])
		indices.append_array([top1, top2, bottom2])
	
	# Simple canopy (tetrahedron)
	var canopy_base_y = trunk_height
	var canopy_top_y = trunk_height + 2.0
	var canopy_radius = 1.0
	
	var base_center = vertices.size()
	vertices.append(Vector3(0, canopy_base_y, 0))
	normals.append(Vector3(0, 1, 0))
	uvs.append(Vector2(0.5, 0.5))
	
	var top_vertex = vertices.size()
	vertices.append(Vector3(0, canopy_top_y, 0))
	normals.append(Vector3(0, 1, 0))
	uvs.append(Vector2(0.5, 0))
	
	# Canopy base vertices
	var canopy_segments = 6
	for i in range(canopy_segments):
		var angle = i * TAU / canopy_segments
		var x = cos(angle) * canopy_radius
		var z = sin(angle) * canopy_radius
		vertices.append(Vector3(x, canopy_base_y, z))
		normals.append(Vector3(x, -0.5, z).normalized())
		uvs.append(Vector2(cos(angle) * 0.5 + 0.5, sin(angle) * 0.5 + 0.5))
	
	# Canopy indices
	for i in range(canopy_segments):
		var current = base_center + 2 + i
		var next = base_center + 2 + ((i + 1) % canopy_segments)
		
		# Base triangle
		indices.append_array([base_center, next, current])
		
		# Side triangle
		indices.append_array([top_vertex, current, next])
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return array_mesh

func update_parallax(player_movement: Vector3):
	var parallax_offset = player_movement * parallax_factor
	global_position = initial_position - parallax_offset

# Editor tools
func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray()
	
	if not tree_mesh:
		warnings.append("No tree mesh assigned. Will use procedural mesh.")
	
	if parallax_factor < 0.0 or parallax_factor > 1.0:
		warnings.append("Parallax factor should typically be between 0.0 and 1.0")
	
	return warnings

# Function to regenerate trees in editor
func regenerate_trees():
	generate_trees()
