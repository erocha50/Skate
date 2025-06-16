extends Node

# Camera references - use get_node_or_null for safety
@onready var menu_camera = get_node_or_null("MenuCamera")  # Update path as needed
@onready var game_camera_controller = get_node_or_null("GameCameraController")  # Update path as needed
@onready var player = get_node_or_null("Player")  # Update path as needed

# Menu camera positions
var menu_camera_position: Vector3
var menu_camera_rotation: Vector3

func _ready():
	# Check if essential nodes exist
	if menu_camera == null:
		print("Error: MenuCamera node not found! Check node path.")
		return
	
	if game_camera_controller == null:
		print("Error: GameCameraController node not found! Check node path.")
		return
	
	if player == null:
		print("Error: Player node not found! Check node path.")
		return
	
	# Set up menu camera positions
	menu_camera_position = Vector3(0, 8, 8)  # High up, looking at menu focus
	menu_camera_rotation = Vector3(-30, 0, 0)  # Looking down at an angle
	
	# Position menu camera
	menu_camera.position = menu_camera_position
	menu_camera.rotation_degrees = menu_camera_rotation
	menu_camera.look_at(menu_camera.global_position, Vector3.UP)
	
	# Disable game camera initially
	game_camera_controller.set_process(false)
	game_camera_controller.get_node("Camera3D").current = false
	menu_camera.current = true
	
	# Disable player physics initially
	player.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	player.freeze = true

func _on_play_pressed():
	_start_camera_transition()

func _on_settings_pressed():
	# Handle settings logic here
	pass

func _on_quit_pressed():
	get_tree().quit()

func _on_back_pressed():
	# Handle back button logic here
	pass

func _start_camera_transition():
	if menu_camera == null or game_camera_controller == null:
		print("Error: Camera nodes not available for transition")
		return
	
	# Enable game camera and disable menu camera
	menu_camera.current = false
	game_camera_controller.get_node("Camera3D").current = true
	game_camera_controller.set_process(true)
	
	# Enable player physics
	if player != null:
		player.freeze = false

func _update_camera_position():
	if menu_camera == null:
		return
	
	# Update menu camera position logic here
	pass

func _update_camera_rotation():
	if menu_camera == null:
		return
	
	# Update menu camera rotation logic here
	pass
