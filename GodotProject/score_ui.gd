extends Control
class_name ScoreUI

# Constants - Combined configurations
const TRICK_COLORS = {"EASY": Color.GREEN, "MEDIUM": Color.ORANGE, "HARD": Color.RED, "INSANE": Color.PURPLE}
const TRICK_MULTIPLIERS = {"EASY": 1.0, "MEDIUM": 1.2, "HARD": 1.5, "INSANE": 2.0}
const GRADE_NAMES = ["D", "C", "B", "A", "S", "U"]
const GRADE_COLORS = {"D": Color.GRAY, "C": Color.GREEN, "B": Color.BLUE, "A": Color.YELLOW, "S": Color.RED, "U": Color.CYAN}
const PROGRESS_THRESHOLDS = [100, 300, 600, 1000, 1500, 2500, 4000, 6000, 10000]
const MAX_MULTIPLIER = 3.0
const MAX_TRICKS_DISPLAYED = 5

# Export groups for UI configuration
@export_group("UI Positioning")
@export var trick_box_position: Vector2 = Vector2(20, 80)
@export var trick_box_size: Vector2 = Vector2(280, 180)
@export var progress_container_position: Vector2 = Vector2(20, 20)
@export var combo_container_position: Vector2 = Vector2(320, 20)
@export var multiplier_container_position: Vector2 = Vector2(320, 60)

@export_group("UI Styling")
@export var trick_box_color: Color = Color(0, 0, 0, 0.3)
@export var main_container_rotation: float = -2.0

@export var player: RigidBody3D

# UI References
@onready var main_container: Control = $MainContainer
@onready var progress_container: Control = $MainContainer/ProgressContainer
@onready var progress_label: RichTextLabel = $MainContainer/ProgressContainer/ProgressLabel
@onready var progress_bar: ProgressBar = $MainContainer/ProgressContainer/ProgressBar
@onready var combo_container: Control = $MainContainer/ComboContainer
@onready var combo_label: Label = $MainContainer/ComboContainer/ComboLabel
@onready var multiplier_container: Control = $MainContainer/MultiplierContainer
@onready var multiplier_label: Label = $MainContainer/MultiplierContainer/MultiplierLabel

# Game state
var current_score: int = 0
var progress_level: int = 0
var combo_count: int = 0
var combo_timer: float = 0.0
var current_multiplier: float = 1.0
var active_tricks: Dictionary = {}
var trick_display_order: Array[String] = []
var trick_sequence: Array[String] = []

# Timers and effects
var score_decay_pause_timer: float = 0.0
var last_trick_time: float = 0.0
var original_multiplier_position: Vector2
var multiplier_shake_tween: Tween
var trick_display: VBoxContainer
var trick_box: ColorRect

# Configuration
var trick_difficulty = {
	"RAIL_GRIND": "EASY", "FREEZE_BLOCK": "MEDIUM", "DASH": "EASY", "AIR_TIME": "EASY",
	"LONG_GRIND": "HARD", "AIR_TIME_BONUS": "MEDIUM", "COMBO_TRICK": "HARD", "STYLE_COMBO": "INSANE"
}

func _ready():
	_setup_ui()
	_connect_signals()
	_update_display()

func _setup_ui():
	# Position elements
	for container in [progress_container, combo_container, multiplier_container]:
		if container:
			match container.name:
				"ProgressContainer": container.position = progress_container_position
				"ComboContainer": container.position = combo_container_position
				"MultiplierContainer": 
					container.position = multiplier_container_position
					original_multiplier_position = container.position
	
	# Style main container
	if main_container: main_container.rotation_degrees = main_container_rotation
	
	# Setup progress elements
	if progress_bar:
		progress_bar.show_percentage = false
		progress_bar.max_value = 100
		progress_bar.custom_minimum_size.y = 20
	
	if progress_label:
		progress_label.bbcode_enabled = true
		progress_label.add_theme_font_size_override("normal_font_size", 48)
	
	# Setup containers
	if combo_container: combo_container.modulate = Color.TRANSPARENT
	if multiplier_container: multiplier_container.modulate = Color.WHITE
	
	# Create trick display box
	_create_trick_box()

func _create_trick_box():
	trick_box = ColorRect.new()
	trick_box.color = trick_box_color
	trick_box.custom_minimum_size = trick_box_size
	trick_box.position = trick_box_position
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	
	trick_display = VBoxContainer.new()
	trick_display.add_theme_constant_override("separation", 4)
	
	trick_box.add_child(margin)
	margin.add_child(trick_display)
	(main_container if main_container else self).add_child(trick_box)

func _connect_signals():
	if not player: return
	
	var signals = ["rail_grind_started", "rail_grind_ended", "freeze_block_used", 
				   "dash_performed", "player_became_airborne", "player_landed"]
	var methods = [_on_rail_grind_started, _on_rail_grind_ended, _on_freeze_block_used,
				   _on_dash_performed, _on_became_airborne, _on_landed]
	
	for i in signals.size():
		if player.has_signal(signals[i]):
			player.connect(signals[i], methods[i])

func _process(delta):
	# Update combo timer
	if combo_timer > 0:
		combo_timer -= delta
		if combo_timer <= 0: _end_combo()
	
	# Update trick displays
	for trick_name in active_tricks.keys():
		active_tricks[trick_name].timer -= delta
		if active_tricks[trick_name].timer <= 0:
			_remove_trick_display(trick_name)
	
	# Score decay
	if score_decay_pause_timer > 0:
		score_decay_pause_timer -= delta
	elif current_score > 0:
		current_score = max(0, current_score - int(2.0 * delta))
		_update_progress_bar()
	
	_update_multiplier_display()

func _add_score_for_trick(trick_name: String, base_points: int):
	current_score += base_points
	score_decay_pause_timer = 0.5  # Pause decay
	
	combo_count += 1
	combo_timer = 3.0
	_update_combo_display()
	_animate_element(combo_container, 1.2, 0.15)
	
	_display_trick_score(trick_name, base_points)
	_update_progress_bar()
	
	# Update trick sequence
	trick_sequence.append(trick_name)
	last_trick_time = Time.get_ticks_msec() / 1000.0
	if trick_sequence.size() > 10: trick_sequence.pop_front()

func _display_trick_score(trick_name: String, points: int):
	# Enforce trick limit
	while trick_display_order.size() >= MAX_TRICKS_DISPLAYED:
		_remove_trick_display_immediately(trick_display_order[0])
	
	var difficulty = trick_difficulty.get(trick_name, "EASY")
	var display_name = trick_name.replace("_", " ")
	
	if trick_name in active_tricks:
		# Update existing
		active_tricks[trick_name].count += 1
		active_tricks[trick_name].timer = 3.0
		_update_trick_label(trick_name)
	else:
		# Create new
		active_tricks[trick_name] = {"name": display_name, "difficulty": difficulty, "timer": 3.0, "count": 1}
		trick_display_order.append(trick_name)
		_create_trick_label(trick_name)

func _create_trick_label(trick_name: String):
	var info = active_tricks[trick_name]
	var label = Label.new()
	label.text = info.name
	label.modulate = TRICK_COLORS[info.difficulty]
	label.add_theme_font_size_override("font_size", 20)
	label.rotation_degrees = randf_range(-2.0, 2.0)
	
	trick_display.add_child(label)
	info["label"] = label
	_animate_trick_entrance(label)

func _update_trick_label(trick_name: String):
	var info = active_tricks[trick_name]
	var label = info["label"]
	if not label or not is_instance_valid(label): return
	
	label.text = info.name + (" X" + str(info.count) if info.count > 1 else "")
	label.modulate = Color(TRICK_COLORS[info.difficulty], 1.0)
	_animate_element(label, 1.15, 0.1)

func _remove_trick_display_immediately(trick_name: String):
	if not active_tricks.has(trick_name): return
	
	trick_display_order.erase(trick_name)
	if active_tricks[trick_name].has("label"):
		var label = active_tricks[trick_name]["label"]
		if label and is_instance_valid(label): label.queue_free()
	active_tricks.erase(trick_name)

func _remove_trick_display(trick_name: String):
	if not active_tricks.has(trick_name): return
	
	trick_display_order.erase(trick_name)
	if active_tricks[trick_name].has("label"):
		var label = active_tricks[trick_name]["label"]
		if label and is_instance_valid(label):
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(label, "position:x", label.position.x + 30, 0.3)
			tween.tween_property(label, "modulate:a", 0.0, 0.5)
			tween.tween_callback(func(): if label and is_instance_valid(label): label.queue_free()).set_delay(0.5)
	active_tricks.erase(trick_name)

func _animate_trick_entrance(label: Label):
	var tween = create_tween()
	tween.set_parallel(true)
	var start_pos = label.position
	label.position.x += 50
	label.scale = Vector2.ZERO
	tween.tween_property(label, "position:x", start_pos.x, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _animate_element(element: Control, scale_to: float, duration: float):
	if not element: return
	var tween = create_tween()
	tween.tween_property(element, "scale", Vector2.ONE * scale_to, duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(element, "scale", Vector2.ONE, duration * 1.5).set_ease(Tween.EASE_OUT).set_delay(duration)

func _update_multiplier_display():
	if not multiplier_label: return
	
	# Calculate multiplier
	var base_multiplier = 1.0 + (combo_count * 0.1)
	var trick_multiplier = 1.0
	var current_time = Time.get_ticks_msec() / 1000.0
	
	for trick in trick_sequence:
		if current_time - last_trick_time < 3.0:
			var difficulty = trick_difficulty.get(trick, "EASY")
			trick_multiplier += (TRICK_MULTIPLIERS[difficulty] - 1.0) * 0.1
	
	current_multiplier = min(base_multiplier * trick_multiplier, MAX_MULTIPLIER)
	
	if current_multiplier > 1.0:
		multiplier_label.text = "MULTIPLIER X%.1f" % current_multiplier
		multiplier_container.modulate = Color.WHITE
		
		# Set effects based on multiplier level
		var effects = [[3.0, 30, TRICK_COLORS["INSANE"], 2.0], [2.0, 24, TRICK_COLORS["HARD"], 1.4], [1.0, 18, TRICK_COLORS["MEDIUM"], 0.8]]
		for effect in effects:
			if current_multiplier >= effect[0]:
				multiplier_label.add_theme_font_size_override("font_size", effect[1])
				multiplier_label.modulate = effect[2]
				_start_multiplier_shake(effect[3])
				break
	else:
		multiplier_container.modulate = Color.TRANSPARENT
		_stop_multiplier_shake()

func _start_multiplier_shake(intensity: float):
	if multiplier_shake_tween: multiplier_shake_tween.kill()
	multiplier_shake_tween = create_tween()
	multiplier_shake_tween.set_loops()
	multiplier_shake_tween.tween_method(_apply_shake, 0.0, 1.0, 0.1)

func _apply_shake(_value: float):
	if multiplier_container:
		var shake = Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
		multiplier_container.position = original_multiplier_position + shake

func _stop_multiplier_shake():
	if multiplier_shake_tween: multiplier_shake_tween.kill()
	if multiplier_container: multiplier_container.position = original_multiplier_position

func _end_combo():
	if combo_count > 1: current_score += combo_count * combo_count * 10
	combo_count = 0
	combo_timer = 0.0
	_update_combo_display()
	if combo_container:
		var tween = create_tween()
		tween.tween_property(combo_container, "modulate", Color.TRANSPARENT, 0.5)

func _update_combo_display():
	if not combo_label or not combo_container: return
	
	if combo_count > 1:
		combo_label.text = "COMBO X" + str(combo_count)
		combo_container.modulate = Color.WHITE
		
		# Set color based on combo count
		var colors = [[10, "INSANE"], [7, "HARD"], [4, "MEDIUM"], [0, "EASY"]]
		for color_data in colors:
			if combo_count >= color_data[0]:
				combo_label.modulate = TRICK_COLORS[color_data[1]]
				break
	else:
		combo_container.modulate = Color.TRANSPARENT

func _update_progress_bar():
	if not progress_bar or not progress_label: return
	
	if progress_level < PROGRESS_THRESHOLDS.size():
		var current_threshold = PROGRESS_THRESHOLDS[progress_level]
		var previous_threshold = 0 if progress_level == 0 else PROGRESS_THRESHOLDS[progress_level - 1]
		var progress_percent = float(current_score - previous_threshold) / float(current_threshold - previous_threshold) * 100.0
		
		progress_bar.value = clamp(progress_percent, 0, 100)
		
		var current_grade = GRADE_NAMES[progress_level] if progress_level < GRADE_NAMES.size() else "U"
		var next_grade = GRADE_NAMES[progress_level + 1] if progress_level + 1 < GRADE_NAMES.size() else "MAX"
		
		var current_hex = _color_to_hex(GRADE_COLORS.get(current_grade, Color.WHITE))
		var next_hex = _color_to_hex(GRADE_COLORS.get(next_grade, Color.GOLD) if next_grade != "MAX" else Color.GOLD)
		
		progress_label.text = "[color=%s]%s[/color] [color=#808080]→[/color] [color=%s]%s[/color]" % [current_hex, current_grade, next_hex, next_grade]
		progress_bar.modulate = GRADE_COLORS.get(current_grade, Color.WHITE)
		
		if current_score >= current_threshold: _level_up()
	else:
		progress_bar.value = 100
		progress_label.text = "[color=%s]U RANK[/color]" % _color_to_hex(GRADE_COLORS["U"])
		progress_bar.modulate = GRADE_COLORS["U"]

func _level_up():
	progress_level += 1
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_loops(3)
	tween.tween_property(progress_bar, "modulate", Color.GOLD, 0.1)
	tween.tween_property(progress_bar, "modulate", Color.WHITE, 0.1)
	_animate_element(progress_label, 1.3, 0.2)
	_update_progress_bar()

func _color_to_hex(color: Color) -> String:
	return "#%02x%02x%02x" % [int(color.r * 255), int(color.g * 255), int(color.b * 255)]

func _update_display():
	_update_progress_bar()
	_update_combo_display()
	_update_multiplier_display()

# Signal handlers - simplified
func _on_rail_grind_started(): _add_score_for_trick("RAIL_GRIND", 15)
func _on_rail_grind_ended(): if combo_count > 3: _add_score_for_trick("LONG_GRIND", 50)
func _on_freeze_block_used(): _add_score_for_trick("FREEZE_BLOCK", 25)
func _on_dash_performed(): _add_score_for_trick("DASH", 10)
func _on_became_airborne(): pass
func _on_landed(): _add_score_for_trick("AIR_TIME", 20)

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
	_stop_multiplier_shake()
	if trick_display:
		for child in trick_display.get_children(): child.queue_free()
	_update_display()

func get_current_score() -> int: return current_score
func get_current_multiplier() -> float: return current_multiplier
