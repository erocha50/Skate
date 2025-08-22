extends SpotLight3D

@export var target_path: NodePath = "../../../Player"
@export var follow_speed: float = 5.0
@export var height_offset: float = 12.0
@export var look_ahead_distance: float = 2.0
@export var light_flicker: bool = false
@export var base_energy: float = 8.0

var target: Node3D
var target_velocity: Vector3 = Vector3.ZERO
var flicker_time: float = 0.0

func _ready():
	# Get reference to the player
	target = get_node(target_path)
	
	# Configure spotlight for HIGH VISIBILITY
	light_energy = base_energy
	spot_range = 25.0
	spot_angle = 50.0
	spot_angle_attenuation = 0.3
	light_color = Color(1.0, 0.95, 0.8)  # Warm white
	
	# Enable shadows for dramatic effect
	shadow_enabled = true
	shadow_bias = 0.01
	shadow_normal_bias = 1.0
	
	# Position initially above player
	if target:
		global_position = target.global_position + Vector3(0, height_offset, 0)
		look_at(target.global_position, Vector3.UP)

func _process(delta):
	if not target:
		return
	
	# Optional flickering effect
	if light_flicker:
		flicker_time += delta * 10.0
		var flicker_amount = sin(flicker_time) * 0.1 + sin(flicker_time * 3.7) * 0.05
		light_energy = base_energy + flicker_amount
	
	# Calculate target position with look-ahead
	var player_velocity = Vector3.ZERO
	if target.has_method("get_velocity"):
		player_velocity = target.get_velocity()
	
	var look_ahead = player_velocity.normalized() * look_ahead_distance
	var target_pos = target.global_position + look_ahead + Vector3(0, height_offset, 0)
	
	# Smoothly move spotlight to target position
	global_position = global_position.lerp(target_pos, follow_speed * delta)
	
	# Always point down at the player
	var look_target = target.global_position + look_ahead
	look_at(look_target, Vector3.UP)
