extends Node3D

@onready var disc_mesh = $DiscMesh
@onready var album_art = $AlbumArt
@onready var disc_label = $DiscLabel
@onready var collision_body = $DiscMesh/DiscCollision

signal disc_selected(disc_index: int)
signal disc_hovered(disc_index: int)

var disc_index = 0
var is_selected = false
var is_hovered = false
var base_scale = Vector3.ONE
var hover_scale = Vector3(1.1, 1.1, 1.1)
var selected_scale = Vector3(1.2, 1.2, 1.2)
var rotation_speed = 1.0
var hover_rotation_speed = 2.0
var selected_rotation_speed = 3.0

var track_data = {}

func _ready():
	# Setup materials
	setup_disc_material()
	
	# Connect collision signals
	collision_body.input_event.connect(_on_input_event)
	collision_body.mouse_entered.connect(_on_mouse_entered)
	collision_body.mouse_exited.connect(_on_mouse_exited)

func setup_disc_material():
	# Create disc material
	var disc_material = StandardMaterial3D.new()
	disc_material.albedo_color = Color(0.1, 0.1, 0.1)
	disc_material.metallic = 0.8
	disc_material.roughness = 0.2
	disc_mesh.material_override = disc_material
	
	# Create album art material
	var art_material = StandardMaterial3D.new()
	art_material.flags_unshaded = true
	album_art.material_override = art_material

func setup_disc(data: Dictionary, index: int):
	disc_index = index
	track_data = data
	
	# Set label text
	disc_label.text = data.title
	
	# Load album art texture
	if ResourceLoader.exists(data.album_art):
		var texture = load(data.album_art)
		var material = album_art.material_override as StandardMaterial3D
		material.albedo_texture = texture
	else:
		# Create default texture with track info
		create_default_album_art()

func create_default_album_art():
	# Create a simple colored texture as fallback
	var image = Image.create(512, 512, false, Image.FORMAT_RGB8)
	var colors = [
		Color.CYAN,
		Color.MAGENTA, 
		Color.YELLOW,
		Color.GREEN,
		Color.RED
	]
	var color = colors[disc_index % colors.size()]
	image.fill(color)
	
	var texture = ImageTexture.new()
	texture.create_from_image(image)
	
	var material = album_art.material_override as StandardMaterial3D
	material.albedo_texture = texture

func _process(delta):
	# Rotate disc based on state
	var current_rotation_speed = rotation_speed
	if is_selected:
		current_rotation_speed = selected_rotation_speed
	elif is_hovered:
		current_rotation_speed = hover_rotation_speed
	
	disc_mesh.rotate_y(current_rotation_speed * delta)
	
	# Handle scaling animation
	var target_scale = base_scale
	if is_selected:
		target_scale = selected_scale
	elif is_hovered:
		target_scale = hover_scale
	
	scale = scale.lerp(target_scale, 5.0 * delta)

func _on_input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			disc_selected.emit(disc_index)

func _on_mouse_entered():
	is_hovered = true
	disc_hovered.emit(disc_index)
	
	# Add glow effect
	add_glow_effect()

func _on_mouse_exited():
	is_hovered = false
	remove_glow_effect()

func set_selected(selected: bool):
	is_selected = selected
	
	if selected:
		add_selection_effect()
	else:
		remove_selection_effect()

func add_glow_effect():
	# Create emission for hover effect
	var material = disc_mesh.material_override as StandardMaterial3D
	material.emission_enabled = true
	material.emission = Color(0.2, 0.4, 1.0) * 0.3

func remove_glow_effect():
	if not is_selected:
		var material = disc_mesh.material_override as StandardMaterial3D
		material.emission_enabled = false

func add_selection_effect():
	# Create stronger emission for selection
	var material = disc_mesh.material_override as StandardMaterial3D
	material.emission_enabled = true
	material.emission = Color(1.0, 0.6, 0.2) * 0.5
	
	# Make label more prominent
	disc_label.modulate = Color.YELLOW

func remove_selection_effect():
	if not is_hovered:
		var material = disc_mesh.material_override as StandardMaterial3D
		material.emission_enabled = false
	
	# Reset label color
	disc_label.modulate = Color.WHITE
