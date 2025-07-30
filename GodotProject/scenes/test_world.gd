extends Node3D

# Game system references
@onready var player = $Player
@onready var camera_controller = $CameraController  
@onready var qte_system = $QTESystem
@onready var score_ui = get_node("../../../ScoreUI")  # Navigate up to the UI layer
