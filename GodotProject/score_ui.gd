extends Control
class_name ScoreUI

# Trick difficulty colors and multipliers
const TRICK_COLORS = {
	"EASY": Color.GREEN,
	"MEDIUM": Color.ORANGE, 
	"HARD": Color.RED,
	"INSANE": Color.PURPLE
}

const TRICK_MULTIPLIERS = {
	"EASY": 1.0,
	"MEDIUM": 1.5,
	"HARD": 2.0,
	"INSANE": 3.0
}

# Maximum multiplier cap
const MAX_MULTIPLIER = 3.0

# Trick classifications (using var instead of const so we can modify it)
var trick_difficulty = {
	"RAIL_GRIND": "EASY",
	"FREEZE_BLOCK": "MEDIUM",
	"DASH": "EASY",
	"AIR_TIME": "EASY",
	"LONG_GRIND": "HARD",
	"AIR_TIME_BONUS": "MEDIUM",
	"COMBO_TRICK": "HARD",
	"STYLE_COMBO": "INSANE"
}

# Score thresholds for progress bar segments
const PROGRESS_THRESHOLDS = [100, 300, 600, 1000, 1500, 2500, 4000, 6000, 10000]

# Grade names corresponding to each threshold
const GRADE_NAMES = ["D", "C", "B", "A", "S", "U"]

# Grade colors for visual feedback
const GRADE_COLORS = {
	"D": Color.GRAY,
	"C": Color.GREEN,
	"B": Color.BLUE,
	"A": Color.YELLOW,
	"S": Color.RED,
	"U": Color.CYAN
}

@export var player: RigidBody3D

# UI References - Updated for new layout
@onready var main_container: Control = $MainContainer
@onready var progress_bar: ProgressBar = $MainContainer/ProgressContainer/ScoreProgress
@onready var progress_label: RichTextLabel = $MainContainer/ProgressContainer/ProgressLabel
@onready var score_container: Control = $MainContainer/ScoreContainer
@onready var score_label: Label = $MainContainer/ScoreContainer/ScoreLabel
@onready var score_multiplier: Label = $MainContainer/ScoreContainer/ScoreMultiplier
@onready var multiplier_label: Label = $MainContainer/MultiplierContainer/MultiplierLabel
@onready var trick_display: VBoxContainer = $MainContainer/TrickContainer
@onready var combo_container: Control = $MainContainer/ComboContainer
@onready var combo_label: Label = $MainContainer/ComboContainer/ComboLabel
@onready var combo_multiplier: Label = $MainContainer/ComboContainer/ComboMultiplier

# Score tracking
var current_score: int = 0
var progress_level: int = 0
var combo_count: int = 0
var combo_timer: float = 0.0
var combo_timeout: float = 3.0
var current_multiplier: float = 1.0

# Trick tracking
var active_tricks: Array[Dictionary] = []
var trick_sequence: Array[String] = []
var last_trick_time: float = 0.0

# Visual effects
var score_tween: Tween
var combo_tween: Tween
var trick_display_timer: float = 0.0

func _ready():
	_setup_ui_style()
	_initialize_progress_bar()
	_connect_player_signals()
	_update_display()

func _setup_ui_style():
	# Apply slanted/skewed transform to main container
	if main_container:
		main_container.rotation_degrees = -5.0  # Slight rotation for dynamic feel
	
	# Set up progress bar styling
	if progress_bar:
		progress_bar.show_percentage = false
		progress_bar.max_value = 100
		progress_bar.value = 0
	
	# Enable BBCode for the progress label (if using RichTextLabel)
	if progress_label is RichTextLabel:
		progress_label.bbcode_enabled = true
		# Make the text bigger and fit properly
		progress_label.fit_content = true
		progress_label.add_theme_font_size_override("normal_font_size", 64)
	
	# Style the combo container
	if combo_container:
		combo_container.modulate = Color.TRANSPARENT
	
	# Style the score container
	if score_container:
		score_container.modulate = Color.WHITE
	
	# Apply skew effect to containers (simulated with rotation)
	if progress_bar and progress_bar.get_parent():
		progress_bar.get_parent().rotation_degrees = 2.0
	if multiplier_label and multiplier_label.get_parent():
		multiplier_label.get_parent().rotation_degrees = -3.0

func _initialize_progress_bar():
	progress_level = 0
	_update_progress_bar()

func _connect_player_signals():
	if player:
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
	_update_combo_timer(delta)
	_update_trick_displays(delta)
	_update_multiplier_display()
	_update_score_display()

func _update_combo_timer(delta):
	if combo_timer > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			_end_combo()

func _update_trick_displays(delta):
	# Update active trick displays
	for i in range(active_tricks.size() - 1, -1, -1):
		active_tricks[i].timer -= delta
		if active_tricks[i].timer <= 0:
			_remove_trick_display(i)

func _update_multiplier_display():
	if not multiplier_label:
		return
		
	# Calculate current multiplier based on combo and recent tricks (made harder)
	var base_multiplier = 1.0 + (combo_count * 0.2)  # Reduced from +0.5x to +0.2x per combo
	var trick_multiplier = _calculate_trick_multiplier()
	current_multiplier = base_multiplier * trick_multiplier
	
	# Cap the multiplier at MAX_MULTIPLIER
	current_multiplier = min(current_multiplier, MAX_MULTIPLIER)
	
	multiplier_label.text = "x" + ("%.1f" % current_multiplier)
	
	# Color based on multiplier level
	if current_multiplier >= MAX_MULTIPLIER:
		multiplier_label.modulate = TRICK_COLORS["INSANE"]
	elif current_multiplier >= 2.5:
		multiplier_label.modulate = TRICK_COLORS["HARD"]
	elif current_multiplier >= 1.5:
		multiplier_label.modulate = TRICK_COLORS["MEDIUM"]
	else:
		multiplier_label.modulate = TRICK_COLORS["EASY"]

func _calculate_trick_multiplier() -> float:
	var multiplier = 1.0
	var recent_time = 5.0  # Consider tricks from last 5 seconds
	var current_time = Time.get_ticks_msec() / 1000.0
	
	for trick in trick_sequence:
		if current_time - last_trick_time < recent_time:
			var difficulty = trick_difficulty.get(trick, "EASY")
			multiplier += (TRICK_MULTIPLIERS[difficulty] - 1.0) * 0.15  # Reduced from 0.3 to 0.15
	
	return multiplier

func _add_score_for_trick(trick_name: String, base_points: int):
	var difficulty = trick_difficulty.get(trick_name, "EASY")
	
	# Add base points to score (not affected by multiplier)
	current_score += base_points
	_add_to_combo(trick_name)
	_display_trick_score(trick_name, base_points, difficulty)
	_update_progress_bar()
	
	# Add to trick sequence for style tracking
	trick_sequence.append(trick_name)
	last_trick_time = Time.get_ticks_msec() / 1000.0
	
	# Limit sequence length
	if trick_sequence.size() > 10:
		trick_sequence.pop_front()

func _add_to_combo(trick_name: String):
	combo_count += 1
	combo_timer = combo_timeout
	_update_combo_display()
	_animate_combo()

func _end_combo():
	if combo_count > 1:
		# Bonus points for combo
		var combo_bonus = combo_count * combo_count * 10  # Exponential bonus
		current_score += combo_bonus
		_display_combo_bonus(combo_bonus)
	
	combo_count = 0
	combo_timer = 0.0
	_update_combo_display()
	_fade_out_combo()

func _update_combo_display():
	if not combo_label or not combo_multiplier or not combo_container:
		return
		
	if combo_count > 1:
		combo_label.text = str(combo_count) + " COMBO"
		combo_multiplier.text = "+" + str(combo_count * 10) + " pts"
		combo_container.modulate = Color.WHITE
	else:
		combo_container.modulate = Color.TRANSPARENT

func _update_score_display():
	if not score_label or not score_multiplier:
		return
		
	# Update score container similar to combo display
	score_label.text = str(current_score) + " SCORE"
	var multiplied_score = int(current_score * current_multiplier)
	score_multiplier.text = "x" + ("%.1f" % current_multiplier) + " = " + str(multiplied_score)
	
	# Color based on multiplier level
	if current_multiplier >= MAX_MULTIPLIER:
		score_multiplier.modulate = TRICK_COLORS["INSANE"]
	elif current_multiplier >= 2.5:
		score_multiplier.modulate = TRICK_COLORS["HARD"]
	elif current_multiplier >= 1.5:
		score_multiplier.modulate = TRICK_COLORS["MEDIUM"]
	else:
		score_multiplier.modulate = TRICK_COLORS["EASY"]

func _display_trick_score(trick_name: String, points: int, difficulty: String):
	var trick_info = {
		"name": trick_name.replace("_", " "),
		"points": points,
		"difficulty": difficulty,
		"timer": 2.0
	}
	active_tricks.append(trick_info)
	_create_trick_display(trick_info)

func _create_trick_display(trick_info: Dictionary):
	if not trick_display:
		return
		
	var trick_label = Label.new()
	# Display as "base_points x multiplier" format
	trick_label.text = trick_info.name + " +" + str(trick_info.points) + " x" + ("%.1f" % current_multiplier)
	trick_label.modulate = TRICK_COLORS[trick_info.difficulty]
	
	# Add slight rotation for style
	trick_label.rotation_degrees = randf_range(-5.0, 5.0)
	
	trick_display.add_child(trick_label)
	
	# Animate the trick label
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(trick_label, "position:x", trick_label.position.x + 50, 0.5)
	tween.tween_property(trick_label, "modulate:a", 0.0, 1.5)
	
	# Remove after animation
	tween.tween_callback(func(): if trick_label: trick_label.queue_free()).set_delay(2.0)

func _remove_trick_display(index: int):
	if index < active_tricks.size():
		active_tricks.remove_at(index)

func _display_combo_bonus(bonus: int):
	if not combo_container:
		return
		
	var bonus_label = Label.new()
	bonus_label.text = "COMBO BONUS +" + str(bonus)
	bonus_label.modulate = Color.GOLD
	bonus_label.add_theme_font_size_override("font_size", 20)
	
	combo_container.add_child(bonus_label)
	
	# Animate bonus display
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(bonus_label, "position:y", bonus_label.position.y - 30, 0.8)
	tween.tween_property(bonus_label, "modulate:a", 0.0, 1.2)
	tween.tween_callback(func(): if bonus_label: bonus_label.queue_free()).set_delay(1.5)

# Helper function to convert Color to hex string for BBCode
func _color_to_hex(color: Color) -> String:
	var r = int(color.r * 255)
	var g = int(color.g * 255)
	var b = int(color.b * 255)
	return "#" + "%02x%02x%02x" % [r, g, b]

func _update_progress_bar():
	if not progress_bar or not progress_label:
		return
		
	if progress_level < PROGRESS_THRESHOLDS.size():
		var current_threshold = PROGRESS_THRESHOLDS[progress_level]
		var previous_threshold = 0 if progress_level == 0 else PROGRESS_THRESHOLDS[progress_level - 1]
		
		var progress_in_level = current_score - previous_threshold
		var level_range = current_threshold - previous_threshold
		var progress_percent = (float(progress_in_level) / float(level_range)) * 100.0
		
		progress_bar.value = clamp(progress_percent, 0, 100)
		
		# Display current grade and progress to next grade
		var current_grade = GRADE_NAMES[progress_level] if progress_level < GRADE_NAMES.size() else "U"
		var next_grade = GRADE_NAMES[progress_level + 1] if progress_level + 1 < GRADE_NAMES.size() else "MAX"
		
		# Get colors for current and next grade
		var current_grade_color = GRADE_COLORS.get(current_grade, Color.WHITE)
		var next_grade_color = GRADE_COLORS.get(next_grade, Color.GRAY) if next_grade != "MAX" else Color.GOLD
		var arrow_color = Color.GRAY
		
		# Convert colors to hex for BBCode
		var current_hex = _color_to_hex(current_grade_color)
		var next_hex = _color_to_hex(next_grade_color)
		var arrow_hex = _color_to_hex(arrow_color)
		
		# Create BBCode formatted text
		if next_grade == "MAX":
			progress_label.text = "[color=" + current_hex + "]" + current_grade + "[/color] [color=" + arrow_hex + "]→[/color] [color=" + next_hex + "]MAX[/color]"
		else:
			progress_label.text = "[color=" + current_hex + "]" + current_grade + "[/color] [color=" + arrow_hex + "]→[/color] [color=" + next_hex + "]" + next_grade + "[/color]"
		
		# Don't modulate the entire label anymore since we're using BBCode colors
		progress_label.modulate = Color.WHITE
		
		# Set progress bar color based on current grade
		progress_bar.modulate = current_grade_color
		
		# Check for level up
		if current_score >= current_threshold:
			_level_up()
	else:
		# Max level reached (U grade)
		progress_bar.value = 100
		var u_color_hex = _color_to_hex(GRADE_COLORS["U"])
		progress_label.text = "[color=" + u_color_hex + "]U RANK[/color]"
		progress_label.modulate = Color.WHITE  # Don't modulate since we're using BBCode
		progress_bar.modulate = GRADE_COLORS["U"]

func _level_up():
	progress_level += 1
	_animate_level_up()
	_update_progress_bar()

func _animate_level_up():
	if not progress_bar:
		return
		
	# Flash effect for level up
	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(progress_bar, "modulate", Color.GOLD, 0.1)
	tween.tween_property(progress_bar, "modulate", Color.WHITE, 0.1)

func _animate_combo():
	if not combo_container:
		return
		
	if combo_tween:
		combo_tween.kill()
	
	combo_tween = create_tween()
	combo_tween.set_ease(Tween.EASE_OUT)
	combo_tween.set_trans(Tween.TRANS_BACK)
	
	combo_container.scale = Vector2.ONE
	combo_tween.tween_property(combo_container, "scale", Vector2.ONE * 1.2, 0.15)
	combo_tween.tween_property(combo_container, "scale", Vector2.ONE, 0.25)

func _fade_out_combo():
	if not combo_container:
		return
		
	var tween = create_tween()
	tween.tween_property(combo_container, "modulate", Color.TRANSPARENT, 0.5)

func _update_display():
	_update_progress_bar()
	_update_combo_display()
	_update_multiplier_display()
	_update_score_display()

# Signal handlers
func _on_rail_grind_started():
	_add_score_for_trick("RAIL_GRIND", 15)

func _on_rail_grind_ended():
	# Check for long grind bonus
	if combo_count > 3:  # If we've been grinding for a while
		_add_score_for_trick("LONG_GRIND", 50)

func _on_freeze_block_used():
	_add_score_for_trick("FREEZE_BLOCK", 25)

func _on_dash_performed():
	_add_score_for_trick("DASH", 10)

func _on_became_airborne():
	# Start air time tracking
	pass

func _on_landed():
	# Add air time bonus based on hang time
	_add_score_for_trick("AIR_TIME", 20)

# Public methods
func add_custom_trick(trick_name: String, points: int, difficulty: String = "MEDIUM"):
	trick_difficulty[trick_name] = difficulty
	_add_score_for_trick(trick_name, points)

func reset_score():
	current_score = 0
	progress_level = 0
	combo_count = 0
	combo_timer = 0.0
	current_multiplier = 1.0
	active_tricks.clear()
	trick_sequence.clear()
	_update_display()

func get_current_score() -> int:
	return current_score

func get_current_multiplier() -> float:
	return current_multiplier
