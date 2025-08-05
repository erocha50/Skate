extends Area3D
class_name TextBubbleTrigger

@export var bubble_text: String = "Hello World!"
@export var bubble_color: Color = Color.WHITE
@export var text_color: Color = Color.BLACK
@export var bubble_size: Vector2 = Vector2(200, 80)
@export var arc_radius: float = 100.0
@export var arc_angle: float = 0.0  # Angle in degrees around the player
@export var bubble_offset_y: float = 50.0  # Height offset above player

var active_bubble = null
var player_ref = null
var canvas_layer = null

func _ready():
	# Connect collision signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Create or find canvas layer for UI
	setup_canvas_layer()

func _on_body_entered(body):
	if body.has_method("get_camera") or body.is_in_group("player"):
		player_ref = body
		show_text_bubble()

func _on_body_exited(body):
	if body == player_ref:
		hide_text_bubble()
		player_ref = null

func setup_canvas_layer():
	# Look for existing CanvasLayer in the scene
	canvas_layer = find_canvas_layer()
	
	# If no CanvasLayer exists, create one
	if canvas_layer == null:
		canvas_layer = CanvasLayer.new()
		canvas_layer.name = "UI_Layer"
		get_tree().current_scene.add_child(canvas_layer)

func find_canvas_layer() -> CanvasLayer:
	# Look for existing CanvasLayer in the scene
	var scene_root = get_tree().current_scene
	for child in scene_root.get_children():
		if child is CanvasLayer:
			return child
	
	# Also check if there's a UI node that might contain a CanvasLayer
	var ui_node = scene_root.get_node_or_null("UI")
	if ui_node and ui_node is CanvasLayer:
		return ui_node
	
	return null

func show_text_bubble():
	if active_bubble == null and player_ref != null and canvas_layer != null:
		# Create the text bubble dynamically
		active_bubble = TextBubble.new()
		
		# Add to the CanvasLayer instead of the 3D scene
		canvas_layer.add_child(active_bubble)
		
		# Configure the bubble
		active_bubble.setup_bubble(bubble_text, bubble_color, text_color, bubble_size)
		
		# Position it in an arc around the player
		update_bubble_position()

func hide_text_bubble():
	if active_bubble != null:
		active_bubble.queue_free()
		active_bubble = null

func update_bubble_position():
	if active_bubble != null and player_ref != null:
		# Get camera for screen projection
		var camera = get_viewport().get_camera_3d()
		if camera == null:
			return
		
		# Calculate arc position around player
		var player_pos = player_ref.global_position
		var angle_rad = deg_to_rad(arc_angle)
		
		# Create arc position in 3D space
		var arc_pos = Vector3(
			player_pos.x + cos(angle_rad) * arc_radius,
			player_pos.y + bubble_offset_y,
			player_pos.z + sin(angle_rad) * arc_radius
		)
		
		# Project 3D position to screen coordinates
		var screen_pos = camera.unproject_position(arc_pos)
		
		# Center the bubble on the screen position
		active_bubble.position = screen_pos - bubble_size / 2

func _process(_delta):
	# Continuously update bubble position to follow player
	if active_bubble != null and player_ref != null:
		update_bubble_position()
