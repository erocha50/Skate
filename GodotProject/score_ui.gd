extends Control
class_name ScoreUI

# Constants
const TRICK_COLORS = {"EASY": Color.GREEN, "MEDIUM": Color.ORANGE, "HARD": Color.RED, "INSANE": Color.PURPLE}
const TRICK_MULTIPLIERS = {"EASY": 1.0, "MEDIUM": 1.2, "HARD": 1.5, "INSANE": 2.0}
const GRADE_NAMES = ["D", "C", "B", "A", "S", "U"]
const GRADE_COLORS = {"D": Color.GRAY, "C": Color.GREEN, "B": Color.BLUE, "A": Color.YELLOW, "S": Color.RED, "U": Color.CYAN}
const PROGRESS_THRESHOLDS = [100, 300, 600, 1000, 1500, 2500, 4000, 6000, 10000]
const MAX_MULTIPLIER = 3.0
const MAX_TRICKS = 5

# Exports
@export_group("UI Positioning")
@export var trick_box_pos: Vector2 = Vector2(20, 80)
@export var trick_box_size: Vector2 = Vector2(280, 180)
@export var progress_pos: Vector2 = Vector2(20, 20)
@export var combo_pos: Vector2 = Vector2(320, 20)
@export var multiplier_pos: Vector2 = Vector2(320, 60)

@export_group("UI Styling")
@export var trick_box_color: Color = Color(0, 0, 0, 0.3)
@export var container_rotation: float = -2.0

@export_group("Score Decay")
@export var base_decay_rate: float = 1.0  # Base decay rate, scaled by level range

@export var player: RigidBody3D

# UI References
@onready var container: Control = $MainContainer
@onready var progress: Control = $MainContainer/ProgressContainer
@onready var progress_label: RichTextLabel = $MainContainer/ProgressContainer/ProgressLabel
@onready var progress_bar: ProgressBar = $MainContainer/ProgressContainer/ProgressBar
@onready var combo: Control = $MainContainer/ComboContainer
@onready var combo_label: Label = $MainContainer/ComboContainer/ComboLabel
@onready var multiplier: Control = $MainContainer/MultiplierContainer
@onready var multiplier_label: Label = $MainContainer/MultiplierContainer/MultiplierLabel

# State
var score: float = 0.0  # Changed to float for smoother decay
var level: int = 0
var combo_count: int = 0
var multiplier_val: float = 1.0
var tricks: Dictionary = {}
var trick_order: Array[String] = []
var trick_seq: Array[String] = []
var last_trick: float = 0.0
var orig_multiplier_pos: Vector2
var shake_tween: Tween
var trick_display: VBoxContainer
var trick_box: ColorRect
var multiplier_decay_timer: float = 0.0
var trick_diff = {
	"RAIL_GRIND": "EASY", "FREEZE_BLOCK": "MEDIUM", "DASH": "EASY", "AIR_TIME": "EASY",
	"LONG_GRIND": "HARD", "AIR_TIME_BONUS": "MEDIUM", "COMBO_TRICK": "HARD", "STYLE_COMBO": "INSANE"
}

func _ready():
	_setup_ui()
	_connect_signals()
	_update_progress()
	_update_combo()
	_update_multiplier()

func _setup_ui():
	# Position containers
	progress.position = progress_pos
	combo.position = combo_pos
	multiplier.position = multiplier_pos
	orig_multiplier_pos = multiplier_pos
	container.rotation_degrees = container_rotation
	
	# Style progress
	progress_bar.show_percentage = false
	progress_bar.max_value = 100
	progress_bar.custom_minimum_size.y = 20
	progress_label.bbcode_enabled = true
	progress_label.add_theme_font_size_override("normal_font_size", 48)
	
	# Style containers
	combo.modulate = Color.TRANSPARENT
	multiplier.modulate = Color.WHITE
	
	# Create trick box
	trick_box = ColorRect.new()
	trick_box.color = trick_box_color
	trick_box.custom_minimum_size = trick_box_size
	trick_box.position = trick_box_pos
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	trick_display = VBoxContainer.new()
	trick_display.add_theme_constant_override("separation", 4)
	trick_box.add_child(margin)
	margin.add_child(trick_display)
	container.add_child(trick_box)

func _connect_signals():
	if not player: return
	var signals = ["rail_grind_started", "rail_grind_ended", "freeze_block_used", "dash_performed", "player_became_airborne", "player_landed"]
	var methods = [_on_rail_grind_started, _on_rail_grind_ended, _on_freeze_block_used, _on_dash_performed, _on_became_airborne, _on_landed]
	for i in signals.size():
		if player.has_signal(signals[i]): player.connect(signals[i], methods[i])

func _process(delta):
	# Update timers for tricks
	for trick in tricks.keys():
		tricks[trick].timer -= delta
		if tricks[trick].timer <= 0: _remove_trick(trick)
	
	# Handle multiplier decay when no tricks are performed
	var current_time = Time.get_ticks_msec() / 1000.0
	if combo_count > 0 and current_time - last_trick >= 1.0:
		multiplier_decay_timer += delta
		if multiplier_decay_timer >= 1.0:
			multiplier_val = max(0.0, multiplier_val - 0.5)
			multiplier_decay_timer = 0.0
			if multiplier_val <= 0.0:
				combo_count = 0
				multiplier_val = 1.0
				_update_combo()
	else:
		multiplier_decay_timer = 0.0
	
	# Continuous score decay with level-scaled rate
	if score > 0:
		var old_score = score
		var current_threshold = PROGRESS_THRESHOLDS[level] if level < PROGRESS_THRESHOLDS.size() else PROGRESS_THRESHOLDS[-1]
		var next_threshold = PROGRESS_THRESHOLDS[level - 1] if level > 0 else 0
		var range_width = current_threshold - next_threshold
		var scaled_decay_rate = base_decay_rate * (range_width / 100.0)  # Scale decay with range width
		score = max(0.0, score - (scaled_decay_rate * delta))
		if score < old_score:  # Only update level if score actually decreased
			var new_level = _calc_level(int(score))
			if new_level < level:
				while level > new_level:
					level -= 1
					_rank_down(level + 1)  # Pass the previous level for animation
			elif new_level > level:
				level = new_level
				_level_up()
			_update_progress()
	
	_update_multiplier()

func _calc_level(score: int) -> int:
	var lvl = 0
	for i in PROGRESS_THRESHOLDS.size():
		if score < PROGRESS_THRESHOLDS[i]: break
		lvl = i + 1
	return min(lvl, GRADE_NAMES.size() - 1)

func _add_score(trick: String, points: int):
	var old_level = level
	score += float(points)  # Ensure points are added as float
	combo_count += 1
	multiplier_val = 1.0 + (combo_count * 0.1)  # Reset multiplier to base level for current combo
	multiplier_decay_timer = 0.0  # Reset decay timer
	_update_combo()
	_animate(combo, 1.2, 0.15)
	_display_trick(trick, points)
	var new_level = _calc_level(int(score))
	if new_level > old_level:
		level = new_level
		_level_up()
	else:
		_update_progress()
	trick_seq.append(trick)
	last_trick = Time.get_ticks_msec() / 1000.0
	if trick_seq.size() > 10: trick_seq.pop_front()

func _rank_down(old_level: int):
	var grade = GRADE_NAMES[level]
	var tween = create_tween().set_parallel().set_loops(2)
	tween.tween_property(progress_bar, "modulate", Color.RED, 0.15)
	tween.tween_property(progress_bar, "modulate", GRADE_COLORS[grade], 0.15)
	_animate(progress_label, 0.8, 0.2)

func _display_trick(trick: String, points: int):
	while trick_order.size() >= MAX_TRICKS:
		_remove_trick_immediate(trick_order[0])
	var diff = trick_diff.get(trick, "EASY")
	var name = trick.replace("_", " ")
	if trick in tricks:
		tricks[trick].count += 1
		tricks[trick].timer = 3.0
		_update_trick_label(trick)
	else:
		tricks[trick] = {"name": name, "difficulty": diff, "timer": 3.0, "count": 1}
		trick_order.append(trick)
		_create_trick_label(trick)

func _create_trick_label(trick: String):
	var info = tricks[trick]
	var label = Label.new()
	label.text = info.name
	label.modulate = TRICK_COLORS[info.difficulty]
	label.add_theme_font_size_override("font_size", 20)
	label.rotation_degrees = randf_range(-2.0, 2.0)
	trick_display.add_child(label)
	info.label = label
	_animate_trick(label)

func _update_trick_label(trick: String):
	var info = tricks[trick]
	var label = info.label
	if not is_instance_valid(label): return
	label.text = info.name + (" X" + str(info.count) if info.count > 1 else "")
	label.modulate = TRICK_COLORS[info.difficulty]
	_animate(label, 1.15, 0.1)

func _remove_trick_immediate(trick: String):
	if trick not in tricks: return
	trick_order.erase(trick)
	if is_instance_valid(tricks[trick].label): tricks[trick].label.queue_free()
	tricks.erase(trick)

func _remove_trick(trick: String):
	if trick not in tricks: return
	trick_order.erase(trick)
	var label = tricks[trick].label
	if is_instance_valid(label):
		var tween = create_tween().set_parallel()
		tween.tween_property(label, "position:x", label.position.x + 30, 0.3)
		tween.tween_property(label, "modulate:a", 0.0, 0.5)
		tween.tween_callback(label.queue_free).set_delay(0.5)
	tricks.erase(trick)

func _animate_trick(label: Label):
	var tween = create_tween().set_parallel()
	var start_pos = label.position
	label.position.x += 50
	label.scale = Vector2.ZERO
	tween.tween_property(label, "position:x", start_pos.x, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _animate(element: Control, scale: float, dur: float):
	var tween = create_tween()
	tween.tween_property(element, "scale", Vector2.ONE * scale, dur).set_ease(Tween.EASE_OUT)
	tween.tween_property(element, "scale", Vector2.ONE, dur * 1.5).set_ease(Tween.EASE_OUT).set_delay(dur)

func _update_multiplier():
	var base = 1.0 + (combo_count * 0.1)
	var trick_mult = 1.0
	var time = Time.get_ticks_msec() / 1000.0
	for trick in trick_seq:
		if time - last_trick < 3.0:
			trick_mult += (TRICK_MULTIPLIERS[trick_diff.get(trick, "EASY")] - 1.0) * 0.1
	
	# Apply trick multiplier to current multiplier value, but don't go below base
	var full_multiplier = min(base * trick_mult, MAX_MULTIPLIER)
	if multiplier_val > full_multiplier:
		multiplier_val = full_multiplier
	
	if multiplier_val > 1.0:
		multiplier_label.text = "MULTIPLIER X%.1f" % multiplier_val
		multiplier.modulate = Color.WHITE
		var effects = [[3.0, 30, TRICK_COLORS.INSANE, 2.0], [2.0, 24, TRICK_COLORS.HARD, 1.4], [1.0, 18, TRICK_COLORS.MEDIUM, 0.8]]
		for e in effects:
			if multiplier_val >= e[0]:
				multiplier_label.add_theme_font_size_override("font_size", e[1])
				multiplier_label.modulate = e[2]
				_start_shake(e[3])
				break
	else:
		multiplier.modulate = Color.TRANSPARENT
		_stop_shake()

func _start_shake(intensity: float):
	if shake_tween: shake_tween.kill()
	shake_tween = create_tween().set_loops()
	shake_tween.tween_method(_apply_shake, 0.0, 1.0, 0.1)

func _apply_shake(_val: float):
	multiplier.position = orig_multiplier_pos + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))

func _stop_shake():
	if shake_tween: shake_tween.kill()
	multiplier.position = orig_multiplier_pos

func _update_combo():
	if combo_count > 1:
		combo_label.text = "COMBO X" + str(combo_count)
		combo.modulate = Color.WHITE
		var colors = [[10, "INSANE"], [7, "HARD"], [4, "MEDIUM"], [0, "EASY"]]
		for c in colors:
			if combo_count >= c[0]:
				combo_label.modulate = TRICK_COLORS[c[1]]
				break
	else:
		combo.modulate = Color.TRANSPARENT

func _update_progress():
	# Get the current level thresholds
	var current_min = 0 if level == 0 else PROGRESS_THRESHOLDS[level - 1]
	var current_max = PROGRESS_THRESHOLDS[level] if level < PROGRESS_THRESHOLDS.size() else PROGRESS_THRESHOLDS[-1]
	
	# Calculate progress within the current level range
	var progress_value = 0.0
	if level < PROGRESS_THRESHOLDS.size():
		progress_value = (float(score - current_min) / (current_max - current_min)) * 100.0
	else:
		progress_value = 100.0  # Max level reached
	
	progress_bar.value = clamp(progress_value, 0, 100)
	
	# Update grade display
	var grade = GRADE_NAMES[level]
	var hex = _color_to_hex(GRADE_COLORS[grade])
	if level < GRADE_NAMES.size() - 1:
		var next_grade = GRADE_NAMES[level + 1]
		var next_hex = _color_to_hex(GRADE_COLORS[next_grade])
		progress_label.text = "[color=%s]%s[/color] [color=#808080]→[/color] [color=%s]%s[/color]" % [hex, grade, next_hex, next_grade]
	else:
		progress_label.text = "[color=%s]%s RANK[/color]" % [hex, grade]
	progress_bar.modulate = GRADE_COLORS[grade]

func _level_up():
	var grade = GRADE_NAMES[level]
	var tween = create_tween().set_parallel().set_loops(3)
	tween.tween_property(progress_bar, "modulate", Color.GOLD, 0.1)
	tween.tween_property(progress_bar, "modulate", GRADE_COLORS[grade], 0.1)
	_animate(progress_label, 1.3, 0.2)
	_update_progress()

func _color_to_hex(color: Color) -> String:
	return "#%02x%02x%02x" % [int(color.r * 255), int(color.g * 255), int(color.b * 255)]

func _on_rail_grind_started(): _add_score("RAIL_GRIND", 15)
func _on_rail_grind_ended(): if combo_count > 3: _add_score("LONG_GRIND", 50)
func _on_freeze_block_used(): _add_score("FREEZE_BLOCK", 25)
func _on_dash_performed(): _add_score("DASH", 10)
func _on_became_airborne(): pass
func _on_landed(): _add_score("AIR_TIME", 20)

func add_custom_trick(trick: String, points: int, diff: String = "MEDIUM"):
	trick_diff[trick] = diff
	_add_score(trick, points)

func reset_score():
	score = 0.0
	level = 0
	combo_count = 0
	multiplier_val = 1.0
	multiplier_decay_timer = 0.0
	tricks.clear()
	trick_order.clear()
	trick_seq.clear()
	_stop_shake()
	for child in trick_display.get_children(): child.queue_free()
	_update_display()

func get_current_score() -> int: return int(score)  # Return as int for consistency with external calls
func get_current_multiplier() -> float: return multiplier_val
func get_current_rank() -> String: return GRADE_NAMES[level]

func _update_display():
	_update_progress()
	_update_combo()
	_update_multiplier()
