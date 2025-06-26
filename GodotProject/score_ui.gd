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
	"MEDIUM": 1.2,  # Reduced from 1.5
	"HARD": 1.5,    # Reduced from 2.0
	"INSANE": 2.0   # Reduced from 3.0
}

# Maximum multiplier cap
const MAX_MULTIPLIER = 3.0

# Trick box configuration - STRICT LIMIT
const MAX_TRICKS_DISPLAYED = 5

# POSITION CONFIGURATION VARIABLES
@export_group("UI Positioning")
@export var trick_box_position: Vector2 = Vector2(20, 80)
@export var trick_box_size: Vector2 = Vector2(280, 180)
@export var progress_container_position: Vector2 = Vector2(20, 20)
@export var combo_container_position: Vector2 = Vector2(320, 20)
@export var multiplier_container_position: Vector2 = Vector2(320, 60)

@export_group("UI Styling")
@export var trick_box_color: Color = Color(0, 0, 0, 0.3)
@export var trick_box_margin: int = 12
@export var trick_label_spacing: int = 4
@export var main_container_rotation: float = -2.0

@export_group("Progress Bar")
@export var progress_bar_height: int = 20
@export var progress_label_font_size: int = 48

@export_group("Multiplier Effects")
@export var multiplier_small_font_size: int = 18
@export var multiplier_medium_font_size: int = 24
@export var multiplier_large_font_size: int = 30
@export var multiplier_shake_intensity: float = 2.0

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

# UI References - Updated layout with score display
@onready var main_container: Control = $MainContainer
@onready var progress_container: Control = $MainContainer/ProgressContainer
@onready var progress_label: RichTextLabel = $MainContainer/ProgressContainer/ProgressLabel
@onready var progress_bar: ProgressBar = $MainContainer/ProgressContainer/ProgressBar
@onready var trick_display: VBoxContainer = $MainContainer/TrickContainer
@onready var combo_container: Control = $MainContainer/ComboContainer
@onready var combo_label: Label = $MainContainer/ComboContainer/ComboLabel
@onready var multiplier_container: Control = $MainContainer/MultiplierContainer
@onready var multiplier_label: Label = $MainContainer/MultiplierContainer/MultiplierLabel

# Score tracking (internal - not displayed directly)
var current_score: int = 0
var progress_level: int = 0
var combo_count: int = 0
var combo_timer: float = 0.0
var combo_timeout: float = 3.0
var current_multiplier: float = 1.0

# Score decay system
var score_decay_rate: float = 2.0  # Points lost per second
var score_decay_pause_timer: float = 0.0
var score_decay_pause_duration: float = 0.5  # Half second pause after trick

# Trick tracking - Updated for stacking system and ordered display
var active_tricks: Dictionary = {}
var trick_display_order: Array[String] = []  # Keep track of display order
var trick_sequence: Array[String] = []
var last_trick_time: float = 0.0

# Transparent box for tricks
var trick_box: ColorRect
var trick_box_container: VBoxContainer

# Visual effects
var score_tween: Tween
var combo_tween: Tween
var multiplier_shake_tween: Tween
var trick_display_timer: float = 0.0

# Multiplier shake effect
var original_multiplier_position: Vector2

func _ready():
	_setup_ui_style()
	_create_trick_box()
	_initialize_progress_bar()
	_connect_player_signals()
	_position_ui_elements()
	_update_display()
	
	# Store original multiplier position for shake effect
	if multiplier_container:
		original_multiplier_position = multiplier_container.position

func _position_ui_elements():
	"""Position all UI elements according to the exported variables"""
	
	# Position the progress container
	if progress_container:
		progress_container.position = progress_container_position
	
	# Position the combo container
	if combo_container:
		combo_container.position = combo_container_position
	
	# Position the multiplier container
	if multiplier_container:
		multiplier_container.position = multiplier_container_position
		original_multiplier_position = multiplier_container.position
	
	# Position the trick box (this will be positioned separately since it's created dynamically)
	if trick_box:
		trick_box.position = trick_box_position
		trick_box.custom_minimum_size = trick_box_size
		trick_box.color = trick_box_color

func _create_trick_box():
	# Create the transparent background box
	trick_box = ColorRect.new()
	trick_box.color = trick_box_color
	trick_box.custom_minimum_size = trick_box_size
	trick_box.position = trick_box_position
	
	# Create container for trick labels inside the box
	trick_box_container = VBoxContainer.new()
	trick_box_container.add_theme_constant_override("separation", trick_label_spacing)
	
	# Add some padding with configurable margins
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", trick_box_margin)
	margin_container.add_theme_constant_override("margin_right", trick_box_margin)
	margin_container.add_theme_constant_override("margin_top", trick_box_margin)
	margin_container.add_theme_constant_override("margin_bottom", trick_box_margin)
	
	# Setup hierarchy: trick_box -> margin_container -> trick_box_container
	trick_box.add_child(margin_container)
	margin_container.add_child(trick_box_container)
	
	# Add the trick box directly to the main container or scene
	# We'll add it to the main container if it exists, otherwise to this control
	var parent_node = main_container if main_container else self
	parent_node.add_child(trick_box)
	
	# Update the trick_display reference
	trick_display = trick_box_container

func _setup_ui_style():
	# Apply modern styling to main container
	if main_container:
		main_container.rotation_degrees = main_container_rotation
	
	# Set up progress bar styling
	if progress_bar:
		progress_bar.show_percentage = false
		progress_bar.max_value = 100
		progress_bar.value = 0
		# Make progress bar thicker and more prominent
		progress_bar.custom_minimum_size.y = progress_bar_height
	
	# Enable BBCode for the progress label
	if progress_label is RichTextLabel:
		progress_label.bbcode_enabled = true
		progress_label.fit_content = true
		progress_label.add_theme_font_size_override("normal_font_size", progress_label_font_size)
	
	# Style the combo container
	if combo_container:
		combo_container.modulate = Color.TRANSPARENT
	
	# Style the multiplier container
	if multiplier_container:
		multiplier_container.modulate = Color.WHITE

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

# Method to update positions at runtime (useful for testing)
func update_positions():
	"""Call this method to update positions after changing the exported variables"""
	_position_ui_elements()

func _process(delta):
	_update_combo_timer(delta)
	_update_trick_displays(delta)
	_update_multiplier_display()
	_update_score_decay(delta)

func _update_combo_timer(delta):
	if combo_timer > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			_end_combo()

func _update_trick_displays(delta):
	# Update active trick displays
	var tricks_to_remove = []
	for trick_name in active_tricks.keys():
		active_tricks[trick_name].timer -= delta
		if active_tricks[trick_name].timer <= 0:
			tricks_to_remove.append(trick_name)
	
	# Remove expired tricks
	for trick_name in tricks_to_remove:
		_remove_trick_display(trick_name)

func _update_score_decay(delta):
	# Update decay pause timer
	if score_decay_pause_timer > 0:
		score_decay_pause_timer -= delta
		return
	
	# Apply score decay
	if current_score > 0:
		var decay_amount = score_decay_rate * delta
		current_score = max(0, current_score - int(decay_amount))
		_update_progress_bar()

func _pause_score_decay():
	"""Pause score decay for a short duration after performing a trick"""
	score_decay_pause_timer = score_decay_pause_duration

func _update_multiplier_display():
	if not multiplier_label:
		return
		
	# Calculate current multiplier based on combo and recent tricks (MADE HARDER)
	var base_multiplier = 1.0 + (combo_count * 0.1)  # Reduced from 0.2
	var trick_multiplier = _calculate_trick_multiplier()
	current_multiplier = base_multiplier * trick_multiplier
	
	# Cap the multiplier at MAX_MULTIPLIER
	current_multiplier = min(current_multiplier, MAX_MULTIPLIER)
	
	# Only show multiplier if it's greater than 1.0
	if current_multiplier > 1.0:
		multiplier_label.text = "MULTIPLIER X" + ("%.1f" % current_multiplier)
		multiplier_container.modulate = Color.WHITE
		
		# Dynamic font size and effects based on multiplier level
		if current_multiplier >= 3.0:
			# MAX multiplier - large font, intense shake
			multiplier_label.add_theme_font_size_override("font_size", multiplier_large_font_size)
			multiplier_label.modulate = TRICK_COLORS["INSANE"]
			_start_multiplier_shake(multiplier_shake_intensity)
		elif current_multiplier >= 2.0:
			# High multiplier - medium font, moderate shake
			multiplier_label.add_theme_font_size_override("font_size", multiplier_medium_font_size)
			multiplier_label.modulate = TRICK_COLORS["HARD"]
			_start_multiplier_shake(multiplier_shake_intensity * 0.7)
		elif current_multiplier >= 1.0:
			# Low multiplier - small font, gentle shake
			multiplier_label.add_theme_font_size_override("font_size", multiplier_small_font_size)
			multiplier_label.modulate = TRICK_COLORS["MEDIUM"]
			_start_multiplier_shake(multiplier_shake_intensity * 0.4)
	else:
		multiplier_container.modulate = Color.TRANSPARENT
		_stop_multiplier_shake()

func _start_multiplier_shake(intensity: float):
	if not multiplier_container:
		return
		
	# Stop any existing shake
	if multiplier_shake_tween:
		multiplier_shake_tween.kill()
	
	multiplier_shake_tween = create_tween()
	multiplier_shake_tween.set_loops()
	
	# Create continuous shake effect
	var shake_duration = 0.1
	multiplier_shake_tween.tween_method(_apply_multiplier_shake, 0.0, 1.0, shake_duration)

func _apply_multiplier_shake(value: float):
	if not multiplier_container:
		return
		
	var shake_x = randf_range(-multiplier_shake_intensity, multiplier_shake_intensity)
	var shake_y = randf_range(-multiplier_shake_intensity, multiplier_shake_intensity)
	multiplier_container.position = original_multiplier_position + Vector2(shake_x, shake_y)

func _stop_multiplier_shake():
	if multiplier_shake_tween:
		multiplier_shake_tween.kill()
		multiplier_shake_tween = null
	
	if multiplier_container:
		multiplier_container.position = original_multiplier_position

func _calculate_trick_multiplier() -> float:
	var multiplier = 1.0
	var recent_time = 3.0  # Reduced from 5.0 seconds - tricks must be more recent
	var current_time = Time.get_ticks_msec() / 1000.0
	
	for trick in trick_sequence:
		if current_time - last_trick_time < recent_time:
			var difficulty = trick_difficulty.get(trick, "EASY")
			multiplier += (TRICK_MULTIPLIERS[difficulty] - 1.0) * 0.1  # Reduced from 0.15
	
	return multiplier

func _add_score_for_trick(trick_name: String, base_points: int):
	var difficulty = trick_difficulty.get(trick_name, "EASY")
	
	# Add base points to score (internal tracking)
	current_score += base_points
	
	# Pause score decay when performing trick
	_pause_score_decay()
	
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
		# Bonus points for combo (internal)
		var combo_bonus = combo_count * combo_count * 10
		current_score += combo_bonus
	
	combo_count = 0
	combo_timer = 0.0
	_update_combo_display()
	_fade_out_combo()

func _update_combo_display():
	if not combo_label or not combo_container:
		return
		
	if combo_count > 1:
		combo_label.text = "COMBO X" + str(combo_count)
		combo_container.modulate = Color.WHITE
		
		# Color combo based on count
		if combo_count >= 10:
			combo_label.modulate = TRICK_COLORS["INSANE"]
		elif combo_count >= 7:
			combo_label.modulate = TRICK_COLORS["HARD"]
		elif combo_count >= 4:
			combo_label.modulate = TRICK_COLORS["MEDIUM"]
		else:
			combo_label.modulate = TRICK_COLORS["EASY"]
	else:
		combo_container.modulate = Color.TRANSPARENT

func _display_trick_score(trick_name: String, points: int, difficulty: String):
	# STRICT ENFORCEMENT: Always check and enforce the limit BEFORE adding
	while trick_display_order.size() >= MAX_TRICKS_DISPLAYED:
		var oldest_trick = trick_display_order[0]
		_remove_trick_display_immediately(oldest_trick)
	
	# Check if this trick is already being displayed
	if trick_name in active_tricks:
		# Update existing trick
		active_tricks[trick_name].count += 1
		active_tricks[trick_name].total_points += points
		active_tricks[trick_name].timer = 3.0  # Reset timer
		_update_existing_trick_display(trick_name)
	else:
		# Create new trick entry
		var trick_info = {
			"name": trick_name.replace("_", " "),
			"points": points,
			"total_points": points,
			"difficulty": difficulty,
			"timer": 3.0,
			"count": 1
		}
		active_tricks[trick_name] = trick_info
		trick_display_order.append(trick_name)
		_create_trick_display(trick_info, trick_name)

func _create_trick_display(trick_info: Dictionary, trick_name: String):
	if not trick_display:
		return
		
	var trick_label = Label.new()
	# Just show the trick name without points
	trick_label.text = trick_info.name
	trick_label.modulate = TRICK_COLORS[trick_info.difficulty]
	trick_label.add_theme_font_size_override("font_size", 20)
	
	# Add slight rotation for style
	trick_label.rotation_degrees = randf_range(-2.0, 2.0)
	
	# Add to the container at the end (newest tricks appear at bottom)
	trick_display.add_child(trick_label)
	
	# Store reference for updates
	if not active_tricks.has(trick_name):
		active_tricks[trick_name] = {}
	active_tricks[trick_name]["label"] = trick_label
	
	# Animate the trick label entrance
	_animate_trick_entrance(trick_label)

func _update_existing_trick_display(trick_name: String):
	if not active_tricks.has(trick_name) or not active_tricks[trick_name].has("label"):
		return
		
	var trick_label = active_tricks[trick_name]["label"]
	var trick_info = active_tricks[trick_name]
	
	if not trick_label or not is_instance_valid(trick_label):
		return
	
	# Update the text with count if more than 1
	var display_text = trick_info.name
	if trick_info.count > 1:
		display_text += " X" + str(trick_info.count)
	
	trick_label.text = display_text
	
	# Reset transparency and animate refresh
	trick_label.modulate.a = 1.0
	
	# Apply the base color again
	var base_color = TRICK_COLORS[trick_info.difficulty]
	trick_label.modulate = Color(base_color.r, base_color.g, base_color.b, 1.0)
	
	# Animate the refresh
	_animate_trick_refresh(trick_label)

func _animate_trick_entrance(trick_label: Label):
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Slide in from the right
	var start_pos = trick_label.position
	trick_label.position.x += 50
	tween.tween_property(trick_label, "position:x", start_pos.x, 0.3).set_ease(Tween.EASE_OUT)
	
	# Scale bounce
	trick_label.scale = Vector2.ZERO
	tween.tween_property(trick_label, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _animate_trick_refresh(trick_label: Label):
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Scale bounce to show refresh
	tween.tween_property(trick_label, "scale", Vector2.ONE * 1.15, 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(trick_label, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_delay(0.1)

func _remove_trick_display_immediately(trick_name: String):
	"""Immediately remove trick display without animation for limit enforcement"""
	if not active_tricks.has(trick_name):
		return
		
	# Remove from display order
	var index = trick_display_order.find(trick_name)
	if index >= 0:
		trick_display_order.remove_at(index)
	
	# Immediately remove the label
	if active_tricks[trick_name].has("label"):
		var trick_label = active_tricks[trick_name]["label"]
		if trick_label and is_instance_valid(trick_label):
			trick_label.queue_free()
	
	# Remove from active tricks
	active_tricks.erase(trick_name)

func _remove_trick_display(trick_name: String):
	if not active_tricks.has(trick_name):
		return
		
	# Remove from display order
	var index = trick_display_order.find(trick_name)
	if index >= 0:
		trick_display_order.remove_at(index)
	
	# Remove and fade out the label
	if active_tricks[trick_name].has("label"):
		var trick_label = active_tricks[trick_name]["label"]
		if trick_label and is_instance_valid(trick_label):
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(trick_label, "position:x", trick_label.position.x + 30, 0.3)
			tween.tween_property(trick_label, "modulate:a", 0.0, 0.5)
			tween.tween_callback(func(): if trick_label and is_instance_valid(trick_label): trick_label.queue_free()).set_delay(0.5)
	
	# Remove from active tricks
	active_tricks.erase(trick_name)

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
		
		# Display current grade and progress to next grade (like original)
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
		
		# Create BBCode formatted text showing grade progression
		if next_grade == "MAX":
			progress_label.text = "[color=" + current_hex + "]" + current_grade + "[/color] [color=" + arrow_hex + "]→[/color] [color=" + next_hex + "]MAX[/color]"
		else:
			progress_label.text = "[color=" + current_hex + "]" + current_grade + "[/color] [color=" + arrow_hex + "]→[/color] [color=" + next_hex + "]" + next_grade + "[/color]"
		
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
		progress_bar.modulate = GRADE_COLORS["U"]

func _level_up():
	progress_level += 1
	_animate_level_up()
	_update_progress_bar()

func _animate_level_up():
	if not progress_bar or not progress_label:
		return
		
	# Flash effect for level up
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_loops(3)
	
	# Flash progress bar
	tween.tween_property(progress_bar, "modulate", Color.GOLD, 0.1)
	tween.tween_property(progress_bar, "modulate", Color.WHITE, 0.1)
	
	# Scale bounce for progress label
	var original_scale = progress_label.scale
	tween.tween_property(progress_label, "scale", original_scale * 1.3, 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(progress_label, "scale", original_scale, 0.3).set_ease(Tween.EASE_OUT).set_delay(0.2)

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

# Signal handlers
func _on_rail_grind_started():
	_add_score_for_trick("RAIL_GRIND", 15)

func _on_rail_grind_ended():
	# Check for long grind bonus
	if combo_count > 3:
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
	trick_display_order.clear()
	trick_sequence.clear()
	
	# Stop any active shake effects
	_stop_multiplier_shake()
	
	# Clear all trick display labels
	if trick_display:
		for child in trick_display.get_children():
			child.queue_free()
	
	_update_display()

func get_current_score() -> int:
	return current_score

func get_current_multiplier() -> float:
	return current_multiplier
