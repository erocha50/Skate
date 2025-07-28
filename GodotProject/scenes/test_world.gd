extends Node3D

# Game system references
@onready var player = $Player
@onready var camera_controller = $CameraController  
@onready var qte_system = $QTESystem
@onready var score_ui = get_node("../../../ScoreUI")  # Navigate up to the UI layer

func _ready():
	print("Test World initializing...")
	
	# Setup player systems
	if player and qte_system:
		player.set_qte_system(qte_system)
		print("QTE system connected to player")
	else:
		if not player:
			print("ERROR: Player node not found!")
		if not qte_system:
			print("ERROR: QTE system node not found!")
	
	# Verify other connections
	if score_ui:
		print("Score UI found and should auto-connect to player")
	else:
		print("WARNING: Score UI not found at expected path")
	
	print("Test World initialization complete")

func _input(event):
	# Debug: Allow manual QTE trigger for testing
	if event.is_action_pressed("ui_accept") and qte_system:
		print("Manual QTE trigger (for testing)")
		qte_system.start_qte()
