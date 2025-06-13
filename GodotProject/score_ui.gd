extends Control
class_name ScoreUI

# Score thresholds for different ranks
const RANK_THRESHOLDS = {
	"DOG": 0,
	"COOL": 100,
	"BETTER": 300,
	"AWESOME": 600,
	"SKATZ": 1000
}

# Score values for different actions
const SCORE_VALUES = {
	"RAIL_GRIND": 15,        # Points per second while grinding
	"RAIL_GRIND_COMBO": 5,   # Bonus points for extended grinding
	"FREEZE_BLOCK": 50,      # One-time bonus for using freeze block
	"DASH": 25,              # Points for dashing
	"AIR_TIME": 5,           # Points per second in air
	"COMBO_MULTIPLIER": 1.5, # Multiplier for combo actions
	"STYLE_BONUS": 10        # Bonus for varied tricks
}
@export var player : RigidBody3D
# UI References
@onready var rank_label: Label = $VBoxContainer/RankLabel
@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var action_label: Label = $VBoxContainer/ActionLabel
@onready var combo_label: Label = $VBoxContainer/ComboLabel
@onready var style_meter: ProgressBar = $VBoxContainer/StyleMeter

# Score tracking
var current_score: int = 0
var current_rank: String = "D"
var combo_count: int = 0
var combo_timer: float = 0.0
var combo_timeout: float = 3.0  # Combo breaks after 3 seconds

# Action tracking
var last_action: String = ""
var action_timer: float = 0.0
var grind_timer: float = 0.0
var air_timer: float = 0.0
var style_variety: Array[String] = []
var style_decay_timer: float = 0.0

# Visual effects
var rank_tween: Tween
var score_tween: Tween
var action_fade_timer: float = 0.0

func _ready():
	# Initialize UI
	_update_ui()
	
	# Connect to player signals
	#var player = get_node("../Player")  # Adjust path as needed
	if player:
		# Connect the renamed signals
		if player.has_signal("rail_grind_started"):
			player.rail_grind_started.connect(_on_rail_grind_started)
		if player.has_signal("rail_grind_ended"):
			player.rail_grind_ended.connect(_on_rail_grind_ended)
		if player.has_signal("freeze_block_used"):
			player.freeze_block_used.connect(_on_freeze_block_used)
		if player.has_signal("dash_performed"):
			player.dash_performed.connect(_on_dash_performed)
		if player.has_signal("player_became_airborne"):
			player.player_became_airborne.connect(_on_became_airborne)
		if player.has_signal("player_landed"):
			player.player_landed.connect(_on_landed)

func _process(delta):
	# Update timers
	_update_timers(delta)
	
	# Update combo system
	_update_combo_system(delta)
	
	# Update UI
	_update_ui()
	
	# Handle action label fade
	if action_fade_timer > 0:
		action_fade_timer -= delta
		var alpha = action_fade_timer / 2.0
		action_label.modulate.a = alpha

func _update_timers(delta):
	# Combo timer
	if combo_timer > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			_reset_combo()
	
	# Style variety decay
	if style_decay_timer > 0:
		style_decay_timer -= delta
		if style_decay_timer <= 0:
			_decay_style_variety()
	
	# Grind scoring
	if grind_timer > 0:
		grind_timer += delta
		_add_score_continuous("RAIL_GRIND", delta)
	
	# Air time scoring
	if air_timer > 0:
		air_timer += delta
		_add_score_continuous("AIR_TIME", delta)

func _update_combo_system(delta):
	# Update combo timeout
	if combo_count > 0 and combo_timer <= 0:
		_reset_combo()

func _add_score(action: String, base_points: int = 0):
	var points = base_points if base_points > 0 else SCORE_VALUES.get(action, 0)
	
	# Apply combo multiplier
	if combo_count > 1:
		points = int(points * (1.0 + (combo_count - 1) * 0.2))  # 20% bonus per combo level
	
	# Apply style variety bonus
	var style_bonus = _get_style_bonus()
	points += style_bonus
	
	current_score += points
	_update_rank()
	
	# Update combo
	_extend_combo()
	_add_to_style_variety(action)
	
	# Show action feedback
	_show_action_feedback(action, points)
	
	print("Score added: ", points, " for ", action, " (Total: ", current_score, ")")

func _add_score_continuous(action: String, delta: float):
	var points_per_second = SCORE_VALUES.get(action, 0)
	var points = points_per_second * delta
	
	# Add combo bonus for extended actions
	if action == "RAIL_GRIND" and grind_timer > 2.0:
		points += SCORE_VALUES.get("RAIL_GRIND_COMBO", 0) * delta
	
	current_score += int(points)
	_update_rank()

func _extend_combo():
	combo_count += 1
	combo_timer = combo_timeout
	combo_label.text = "COMBO x" + str(combo_count)
	
	# Visual effect for combo
	if combo_count > 1:
		_animate_combo_label()

func _reset_combo():
	combo_count = 0
	combo_timer = 0.0
	combo_label.text = ""

func _add_to_style_variety(action: String):
	if not style_variety.has(action):
		style_variety.append(action)
		style_decay_timer = 10.0  # Reset style variety after 10 seconds
		_update_style_meter()

func _decay_style_variety():
	if style_variety.size() > 0:
		style_variety.pop_front()
		_update_style_meter()
		if style_variety.size() > 0:
			style_decay_timer = 10.0

func _get_style_bonus() -> int:
	return style_variety.size() * SCORE_VALUES.get("STYLE_BONUS", 0)

func _update_style_meter():
	var style_value = min(style_variety.size() * 25, 100)  # Max 4 different actions = 100%

func _update_rank():
	var new_rank = "D"
	for rank in ["SKATZ", "AWESOME", "BETTER", "COOL", "DOG"]:  # Check from highest to lowest
		if current_score >= RANK_THRESHOLDS[rank]:
			new_rank = rank
			break
	
	if new_rank != current_rank:
		current_rank = new_rank
		_animate_rank_change()

func _update_ui():
	score_label.text = str(current_score)
	rank_label.text = current_rank
	
	# Color coding for ranks
	match current_rank:
		"SKATZ":
			rank_label.modulate = Color.GOLD
		"AWESOME":
			rank_label.modulate = Color.ORANGE_RED
		"BETTER":
			rank_label.modulate = Color.BLUE
		"COOL":
			rank_label.modulate = Color.GREEN
		"DOG":
			rank_label.modulate = Color.GRAY

func _show_action_feedback(action: String, points: int):
	var display_text = action.replace("_", " ") + " +" + str(points)
	action_label.text = display_text
	action_label.modulate.a = 1.0
	action_fade_timer = 2.0

func _animate_rank_change():
	if rank_tween:
		rank_tween.kill()
	
	rank_tween = create_tween()
	rank_tween.set_ease(Tween.EASE_OUT)
	rank_tween.set_trans(Tween.TRANS_ELASTIC)
	
	# Scale animation
	rank_label.scale = Vector2.ONE
	rank_tween.tween_property(rank_label, "scale", Vector2.ONE * 1.5, 0.2)
	rank_tween.tween_property(rank_label, "scale", Vector2.ONE, 0.3)

func _animate_combo_label():
	if combo_label.has_method("create_tween"):
		var tween = combo_label.create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BOUNCE)
		
		combo_label.scale = Vector2.ONE
		tween.tween_property(combo_label, "scale", Vector2.ONE * 1.3, 0.1)
		tween.tween_property(combo_label, "scale", Vector2.ONE, 0.2)

# Signal handlers - these match the renamed signals in player script
func _on_rail_grind_started():
	print("STARTING GRIND")
	grind_timer = 0.01  # Start the timer
	_add_score("RAIL_GRIND", 25)  # Initial grind bonus

func _on_rail_grind_ended():
	# Bonus points for long grinds
	print("ENDING GRIND")
	if grind_timer > 3.0:
		var bonus = int(grind_timer * 10)  # 10 points per second of grinding
		_add_score("LONG_GRIND", bonus)
	grind_timer = 0.0

func _on_freeze_block_used():
	_add_score("FREEZE_BLOCK")

func _on_dash_performed():
	_add_score("DASH")

func _on_became_airborne():
	air_timer = 0.01  # Start air time tracking

func _on_landed():
	# Bonus for long air time
	if air_timer > 2.0:
		var bonus = int(air_timer * 5)  # 5 points per second in air
		_add_score("AIR_TIME_BONUS", bonus)
	air_timer = 0.0

# Public methods for external scoring
func add_custom_score(action_name: String, points: int):
	_add_score(action_name, points)

func reset_score():
	current_score = 0
	current_rank = "FUMBLE"
	combo_count = 0
	combo_timer = 0.0
	style_variety.clear()
	_update_ui()

func get_current_score() -> int:
	return current_score

func get_current_rank() -> String:
	return current_rank
