extends Node3D

@onready var disc_container = $DiscContainer
@onready var camera_controller = $CameraController
@onready var song_title = $UI/SongInfo/SongTitle
@onready var artist_name = $UI/SongInfo/ArtistName
@onready var play_button = $UI/PlayButton
@onready var audio_manager = $AudioManager

var is_dragging = false
var drag_start_position = Vector2.ZERO
var container_start_position = Vector3.ZERO
var current_disc_index = 0
var total_discs = 0
var disc_spacing = 3.0
var scroll_sensitivity = 0.01
var target_position = Vector3.ZERO
var scroll_speed = 5.0

# Infinite scrolling variables
var visible_discs = []  # Array to track visible disc nodes
var center_disc_offset = 0.0  # Tracks the logical position for infinite scroll

# Music data - add your own tracks here
var music_tracks = [
	{
		"title": "Neon Dreams",
		"artist": "Synthwave Studio",
		"audio_path": "res://audio/track1.ogg",
		"album_art": "res://textures/album1.png"
	},
	{
		"title": "Digital Horizon",
		"artist": "Cyber Collective", 
		"audio_path": "res://audio/track2.ogg",
		"album_art": "res://textures/album2.png"
	},
	{
		"title": "Electric Pulse",
		"artist": "Future Beats",
		"audio_path": "res://audio/track3.ogg",
		"album_art": "res://textures/album3.png"
	},
	{
		"title": "Cosmic Journey",
		"artist": "Space Sounds",
		"audio_path": "res://audio/track4.ogg",
		"album_art": "res://textures/album4.png"
	},
	{
		"title": "Retro Wave",
		"artist": "80s Revival",
		"audio_path": "res://audio/track5.ogg",
		"album_art": "res://textures/album5.png"
	}
]

func _ready():
	setup_discs()
	update_ui()
	
	# Connect play button if it exists
	if play_button:
		play_button.pressed.connect(_on_play_button_pressed)

func setup_discs():
	total_discs = music_tracks.size()
	
	# Use only existing disc nodes in the scene - don't create new ones
	var existing_discs = disc_container.get_child_count()
	var disc_pool_size = existing_discs  # Use whatever discs you have
	var center_index = disc_pool_size / 2  # Middle disc index
	
	# Setup existing disc nodes
	for i in range(existing_discs):
		var disc = disc_container.get_child(i)
		visible_discs.append(disc)
		
		# Position discs in a line
		disc.position.x = (i - center_index) * disc_spacing
		
		# Setup initial disc data (wrap around music tracks)
		var track_index = (i - center_index + current_disc_index) % total_discs
		if track_index < 0:
			track_index += total_discs
		
		# Check if disc has setup_disc method before calling it
		if disc.has_method("setup_disc"):
			disc.setup_disc(music_tracks[track_index], track_index)
			if not disc.disc_selected.is_connected(_on_disc_selected):
				disc.disc_selected.connect(_on_disc_selected)
			if not disc.disc_hovered.is_connected(_on_disc_hovered):
				disc.disc_hovered.connect(_on_disc_hovered)
		else:
			# Fallback: manually set basic properties
			setup_disc_fallback(disc, music_tracks[track_index], track_index)
	
	target_position = disc_container.position

func setup_disc_fallback(disc: Node3D, track_data: Dictionary, track_index: int):
	# Fallback method to setup disc without the script
	var label = disc.get_node_or_null("DiscLabel")
	if label and label is Label3D:
		label.text = track_data.title

func create_disc_node() -> Node3D:
	# Create a new disc node with the same structure as existing ones
	var disc = Node3D.new()
	disc.name = "MusicDisc"
	
	# Add DiscMesh
	var disc_mesh = MeshInstance3D.new()
	disc_mesh.name = "DiscMesh"
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 0.1
	disc_mesh.mesh = cylinder
	disc.add_child(disc_mesh)
	
	# Add collision
	var collision_body = StaticBody3D.new()
	collision_body.name = "DiscCollision"
	var collision_shape = CollisionShape3D.new()
	var cylinder_shape = CylinderShape3D.new()
	cylinder_shape.height = 0.1
	cylinder_shape.radius = 1.0
	collision_shape.shape = cylinder_shape
	collision_body.add_child(collision_shape)
	disc_mesh.add_child(collision_body)
	
	# Add album art
	var album_art = MeshInstance3D.new()
	album_art.name = "AlbumArt"
	var quad = QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	album_art.mesh = quad
	album_art.position.y = 0.06
	disc.add_child(album_art)
	
	# Add label
	var label = Label3D.new()
	label.name = "DiscLabel"
	label.position.y = -0.5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	disc.add_child(label)
	
	# Try to attach script - but don't fail if it doesn't work
	var script_path = "res://music_disc_1.gd"
	if ResourceLoader.exists(script_path):
		var script = load(script_path)
		if script:
			disc.set_script(script)
	else:
		print("Warning: Could not find script at ", script_path, " - disc will have basic functionality only")
	
	return disc
	
	target_position = disc_container.position

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_dragging(event.position)
			else:
				stop_dragging()
	
	elif event is InputEventMouseMotion and is_dragging:
		handle_drag(event.position)
	
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_LEFT:
			navigate_disc(-1)
		elif event.keycode == KEY_RIGHT:
			navigate_disc(1)

func start_dragging(mouse_pos: Vector2):
	is_dragging = true
	drag_start_position = mouse_pos
	container_start_position = disc_container.position

func stop_dragging():
	is_dragging = false
	snap_to_nearest_disc()

func handle_drag(mouse_pos: Vector2):
	var delta = (mouse_pos - drag_start_position) * scroll_sensitivity
	center_disc_offset += delta.x
	target_position = container_start_position + Vector3(delta.x, 0, 0)
	
	# Update disc content based on scroll position
	update_disc_content()

func navigate_disc(direction: int):
	current_disc_index = (current_disc_index + direction) % total_discs
	if current_disc_index < 0:
		current_disc_index += total_discs
	
	center_disc_offset += direction * disc_spacing
	target_position.x += direction * disc_spacing
	
	update_disc_content()
	update_ui()

func snap_to_nearest_disc():
	# Find which disc should be in center based on scroll amount
	var scroll_offset = center_disc_offset / disc_spacing
	var nearest_disc = round(scroll_offset)
	
	# Update current disc index
	current_disc_index = int(nearest_disc) % total_discs
	if current_disc_index < 0:
		current_disc_index += total_discs
	
	# Snap to exact position
	center_disc_offset = nearest_disc * disc_spacing
	target_position.x = container_start_position.x + center_disc_offset
	
	update_disc_content()
	update_ui()

func _process(delta):
	# Smooth movement
	disc_container.position = disc_container.position.lerp(target_position, scroll_speed * delta)
	
	# Continuous content update during dragging
	if is_dragging:
		update_disc_content()
	
	# Update current disc based on position when not dragging
	if not is_dragging:
		var position_offset = disc_container.position.x - container_start_position.x
		var disc_offset = position_offset / disc_spacing
		var new_index = int(round(-disc_offset)) % total_discs
		if new_index < 0:
			new_index += total_discs
		
		if new_index != current_disc_index:
			current_disc_index = new_index
			update_ui()

func _on_disc_selected(disc_index: int):
	# Find which visible disc was clicked and update accordingly
	for i in range(visible_discs.size()):
		var disc = visible_discs[i]
		if disc.has_method("get_current_track_index") and disc.get_current_track_index() == disc_index:
			# Calculate how far to scroll to center this disc
			var disc_pool_size = visible_discs.size()
			var center_index = disc_pool_size / 2
			var scroll_amount = (i - center_index) * disc_spacing
			
			center_disc_offset += scroll_amount
			target_position.x += scroll_amount
			current_disc_index = disc_index
			
			update_ui()
			play_current_track()
			break

func _on_disc_hovered(disc_index: int):
	# Optional: Show preview info or highlight effect
	pass

func update_disc_content():
	# Update which music track each visible disc shows based on scroll position
	var disc_pool_size = visible_discs.size()
	var center_index = disc_pool_size / 2
	var scroll_offset = center_disc_offset / disc_spacing
	
	for i in range(visible_discs.size()):
		var disc = visible_discs[i]
		var disc_logical_index = int(scroll_offset) + (i - center_index)
		var track_index = disc_logical_index % total_discs
		if track_index < 0:
			track_index += total_discs
		
		# Only update if the track changed and disc has the method
		if disc.has_method("setup_disc"):
			if disc.has_method("get_current_track_index"):
				if disc.get_current_track_index() != track_index:
					disc.setup_disc(music_tracks[track_index], track_index)
			else:
				disc.setup_disc(music_tracks[track_index], track_index)
		else:
			# Fallback for discs without script
			setup_disc_fallback(disc, music_tracks[track_index], track_index)

func update_ui():
	if current_disc_index >= 0 and current_disc_index < music_tracks.size():
		var track = music_tracks[current_disc_index]
		
		# Check if UI nodes exist before updating them
		if song_title:
			song_title.text = track.title
		if artist_name:
			artist_name.text = track.artist
		
		# Update disc highlights - center disc is always selected
		var disc_pool_size = visible_discs.size()
		var center_index = disc_pool_size / 2
		for i in range(visible_discs.size()):
			var disc = visible_discs[i]
			if disc.has_method("set_selected"):
				disc.set_selected(i == center_index)

func _on_play_button_pressed():
	play_current_track()

func play_current_track():
	if current_disc_index >= 0 and current_disc_index < music_tracks.size():
		var track = music_tracks[current_disc_index]
		
		# Check if audio file exists before loading
		if ResourceLoader.exists(track.audio_path):
			var audio_stream = load(track.audio_path)
			if audio_stream and audio_manager:
				audio_manager.stream = audio_stream
				audio_manager.play()
				if play_button:
					play_button.text = "♪ Playing"
		else:
			print("Could not find audio file: ", track.audio_path)

func _on_audio_finished():
	play_button.text = "Play"
