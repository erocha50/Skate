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
var disc_spacing = 3.0
var scroll_sensitivity = 0.01
var target_position = Vector3.ZERO
var scroll_speed = 5.0

# Fixed music data - each disc gets one specific track
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
	}
]

var disc_nodes = []  # Array to hold our 3 disc nodes

func _ready():
	setup_discs()
	update_ui()
	
	# Connect play button if it exists
	if play_button:
		play_button.pressed.connect(_on_play_button_pressed)

func setup_discs():
	# Let the disc container handle positioning
	disc_container.setup_disc_positions()
	
	# Get all disc nodes from the container
	for i in range(disc_container.get_child_count()):
		var disc = disc_container.get_child(i)
		if disc.name.begins_with("MusicDisc"):
			disc_nodes.append(disc)
	
	# Ensure we have exactly 3 discs
	if disc_nodes.size() != 3:
		print("Warning: Expected 3 discs, found ", disc_nodes.size())
		return
	
	# Setup each disc with its specific track
	for i in range(disc_nodes.size()):
		var disc = disc_nodes[i]
		
		# Each disc gets its own specific track (no rotation/changing)
		if disc.has_method("setup_disc"):
			disc.setup_disc(music_tracks[i], i)
			# Connect signals
			if not disc.disc_selected.is_connected(_on_disc_selected):
				disc.disc_selected.connect(_on_disc_selected)
			if not disc.disc_hovered.is_connected(_on_disc_hovered):
				disc.disc_hovered.connect(_on_disc_hovered)
		else:
			setup_disc_fallback(disc, music_tracks[i], i)
	
	# Start with middle disc selected
	current_disc_index = 1
	disc_container.center_disc(current_disc_index)
	update_disc_selection()

func setup_disc_fallback(disc: Node3D, track_data: Dictionary, track_index: int):
	# Fallback method to setup disc without the script
	var label = disc.get_node_or_null("DiscLabel")
	if label and label is Label3D:
		label.text = track_data.title

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
	var new_position = container_start_position + Vector3(delta.x, 0, 0)
	disc_container.set_immediate_position(new_position)

func navigate_disc(direction: int):
	var new_index = current_disc_index + direction
	
	# Clamp to valid range (0-2 for 3 discs)
	new_index = clamp(new_index, 0, disc_nodes.size() - 1)
	
	if new_index != current_disc_index:
		current_disc_index = new_index
		
		# Use disc container's method to center the disc
		disc_container.center_disc(current_disc_index)
		
		update_ui()
		update_disc_selection()

func snap_to_nearest_disc():
	# Use disc container's snap method
	current_disc_index = disc_container.snap_to_nearest_disc()
	
	update_ui()
	update_disc_selection()

func _process(delta):
	# The disc container handles its own smooth movement now
	pass

func _on_disc_selected(disc_index: int):
	# Find which disc was clicked and center it
	for i in range(disc_nodes.size()):
		var disc = disc_nodes[i]
		if disc.has_method("get_current_track_index"):
			if disc.get_current_track_index() == disc_index:
				current_disc_index = i
				break
		elif i == disc_index:  # Fallback
			current_disc_index = i
			break
	
	# Use disc container's method to center the disc
	disc_container.center_disc(current_disc_index)
	
	update_ui()
	update_disc_selection()
	play_current_track()

func _on_disc_hovered(disc_index: int):
	# Optional: Show preview info or highlight effect
	pass

func update_disc_selection():
	# Update which disc is selected (only one at a time)
	for i in range(disc_nodes.size()):
		var disc = disc_nodes[i]
		if disc.has_method("set_selected"):
			disc.set_selected(i == current_disc_index)

func update_ui():
	if current_disc_index >= 0 and current_disc_index < music_tracks.size():
		var track = music_tracks[current_disc_index]
		
		# Check if UI nodes exist before updating them
		if song_title:
			song_title.text = track.title
		if artist_name:
			artist_name.text = track.artist
		
		update_disc_selection()

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
			# For testing, you can comment out the above and uncomment below
			# print("Would play: ", track.title, " by ", track.artist)

func _on_audio_finished():
	if play_button:
		play_button.text = "Play"
