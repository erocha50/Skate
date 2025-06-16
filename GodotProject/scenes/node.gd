extends Node

@onready var pause_menu = get_node_or_null("PauseMenuUI")
@onready var resume_button = get_node_or_null("PauseMenuUI/VBoxContainer/ResumeButton")
@onready var menu_button = get_node_or_null("PauseMenuUI/VBoxContainer/MenuButton")
@onready var quit_button = get_node_or_null("PauseMenuUI/VBoxContainer/QuitButton")

var is_paused = false

func _ready():
	# Check if all nodes exist before proceeding
	if pause_menu == null:
		print("Error: PauseMenuUI node not found! Check node path.")
		return
	
	if resume_button == null or menu_button == null or quit_button == null:
		print("Error: One or more button nodes not found! Check node paths.")
		return
	
	# Hide pause menu initially
	pause_menu.visible = false
	
	# Make sure the pause menu can process while paused
	pause_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Connect pause menu buttons
	resume_button.pressed.connect(_on_resume_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _input(event):
	# Handle pause input (ESC key) - only for key/button events
	if event is InputEventKey or event is InputEventJoypadButton:
		if event.is_action_just_pressed("ui_cancel"):
			_toggle_pause()

func _toggle_pause():
	if pause_menu == null:
		return
		
	is_paused = !is_paused
	
	if is_paused:
		_pause_game()
	else:
		_resume_game()

func _pause_game():
	if pause_menu == null:
		return
		
	get_tree().paused = true
	pause_menu.visible = true

func _resume_game():
	if pause_menu == null:
		return
		
	get_tree().paused = false
	pause_menu.visible = false
	is_paused = false

func _on_resume_pressed():
	_resume_game()

func _on_menu_pressed():
	_resume_game()  # Unpause first
	# Return to main menu
	get_tree().change_scene_to_file("res://scenes/Menu3D.tscn")

func _on_quit_pressed():
	get_tree().quit()
