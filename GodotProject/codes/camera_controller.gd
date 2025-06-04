extends Node3D
class_name CameraController

@export var target: Node3D
@export var follow_speed: float = 8.0
@export var rotation_speed: float = 5.0
@export var side_offset: Vector3 = Vector3(12, 3, 0)  # Side-view positioning
@export var look_ahead_distance: float = 4.0
@export var speed_zoom_factor: float = 0.3

@onready var camera: Camera3D = $Camera3D

var base_fov: float = 70.0
var target_position: Vector3
var current_look_ahead: Vector3

func _ready():
	if not target:
		target = get_tree().get_first_node_in_group("player")
	
	base_fov = camera.fov

func _process(delta):
	look_at(target.global_position)
	global_position.x = target.global_position.x
