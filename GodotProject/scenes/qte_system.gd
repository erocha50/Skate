extends Control

# QTE System for Rail Grinding Tricks
# Shows a single letter that player must press before time runs out

signal qte_completed(success: bool, score_bonus: int)

# QTE Configuration
@export var qte_time: float = 2.0  # Total time to complete QTE
@export var slowdown_factor: float = 0.3  # How much to slow game (0.3 = 30% speed)
@export var max_score_bonus: int = 100  # Maximum bonus points

# UI Elements
@onready var qte_container: Control = $QTEContainer
@onready var letter_label: Label = $QTEContainer/LetterLabel
@onready var progress_bar: ProgressBar = $QTEContainer/ProgressBar
@onready var feedback_label: Label = $QTEContainer/FeedbackLabel
@onready var background: ColorRect = $QTEContainer/Background

# QTE State
var is_active: bool = false
var current_letter: String = ""
var input_timer: float = 0.0
var original_time_scale: float = 1.0

# Input mapping
var input_map: Dictionary = {
	"w": "move_up",
	"a": "move_left", 
	"s": "move_down",
	"d": "move_right"
}

# Colors for visual feedback
var success_color: Color = Color.GREEN
var fail_color: Color = Color.RED
var warning_color: Color = Color.ORANGE

func _ready():
	# Hide the QTE initially
	hide_qte()
	
	# Setup UI elements
	_setup_ui()

func _setup_ui():
	# Center the container on screen
	if qte_container:
		qte_container.anchors_preset = Control.PRESET_CENTER
		qte_container.size = Vector2(300, 200)
		qte_container.position = qte_container.position - qte_container.size / 2
	
	# Setup letter label (large, centered)
	if letter_label:
		letter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter_label.add_theme_font_size_override("font_size", 72)
	
	# Setup progress bar
	if progress_bar:
		progress_bar.show_percentage = false
		progress_bar.max_value = 100
	
	# Setup feedback label
	if feedback_label:
		feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		feedback_label.add_theme_font_size_override("font_size", 24)
	
	# Setup background
	if background:
		background.color = Color(0, 0, 0, 0.7)  # Semi-transparent dark background

func start_qte():
	if is_active:
		return
	
	print("QTE System: Starting QTE")
	
	# Store original time scale and slow down game
	original_time_scale = Engine.time_scale
	Engine.time_scale = slowdown_factor
	
	# Generate random letter
	current_letter = _generate_random_letter()
	
	# Setup QTE state
	is_active = true
	input_timer = qte_time
	
	# Show and setup UI
	show_qte()
	_setup_letter_display()
	_update_progress()
	
	# Clear feedback
	feedback_label.text = "PRESS " + current_letter.to_upper() + "!"

func _generate_random_letter() -> String:
	var letters = ["w", "a", "s", "d"]
	var random_letter = letters[randi() % letters.size()]
	print("QTE System: Generated letter: ", random_letter)
	return random_letter

func _setup_letter_display():
	# Display the current letter
	if letter_label:
		letter_label.text = current_letter.to_upper()
		letter_label.modulate = Color.WHITE

func _process(delta):
	if not is_active:
		return
	
	# Update timer (account for slowdown)
	input_timer -= delta / slowdown_factor
	
	# Update progress bar
	_update_progress()
	
	# Update letter color based on time remaining
	_update_letter_color()
	
	# Check for timeout
	if input_timer <= 0:
		_handle_timeout()
		return
	
	# Handle input
	_handle_input()

func _update_letter_color():
	if not letter_label:
		return
	
	# Change color based on time remaining
	var time_ratio = input_timer / qte_time
	if time_ratio > 0.5:
		letter_label.modulate = Color.WHITE
	elif time_ratio > 0.25:
		letter_label.modulate = warning_color
	else:
		letter_label.modulate = fail_color

func _handle_input():
	var input_action = input_map.get(current_letter, "")
	
	if input_action and Input.is_action_just_pressed(input_action):
		_handle_correct_input()
	else:
		# Check for wrong input
		for letter in input_map.keys():
			if letter != current_letter and Input.is_action_just_pressed(input_map[letter]):
				_handle_wrong_input()
				break

func _handle_correct_input():
	print("QTE System: Correct input for letter: ", current_letter)
	
	# Calculate score bonus based on remaining time
	var time_ratio = input_timer / qte_time
	var score_bonus = int(max_score_bonus * time_ratio)
	
	# Show success feedback
	_show_feedback("PERFECT! +" + str(score_bonus), success_color)
	
	# Complete QTE with success
	_complete_qte(true, score_bonus)

func _handle_wrong_input():
	print("QTE System: Wrong input! Expected: ", current_letter)
	
	# Show failure feedback
	_show_feedback("WRONG KEY!", fail_color)
	
	# Flash the letter red
	if letter_label:
		letter_label.modulate = fail_color
	
	# End QTE with failure
	_complete_qte(false, 0)

func _handle_timeout():
	print("QTE System: Timeout!")
	_show_feedback("TOO SLOW!", fail_color)
	_complete_qte(false, 0)

func _complete_qte(success: bool, score_bonus: int):
	print("QTE System: QTE completed with success: ", success, ", bonus: ", score_bonus)
	
	is_active = false
	
	# Restore original time scale
	Engine.time_scale = original_time_scale
	
	# Emit completion signal
	qte_completed.emit(success, score_bonus)
	
	# Hide QTE after a brief delay
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.process_mode = Node.PROCESS_MODE_ALWAYS  # Continue during pause
	add_child(timer)
	timer.timeout.connect(_on_completion_delay_timeout)
	timer.start()

func _on_completion_delay_timeout():
	hide_qte()

func _update_progress():
	if progress_bar:
		var progress = (input_timer / qte_time) * 100.0
		progress_bar.value = progress
		
		# Change color based on time remaining
		if progress < 25:
			progress_bar.modulate = fail_color
		elif progress < 50:
			progress_bar.modulate = warning_color
		else:
			progress_bar.modulate = success_color

func _show_feedback(text: String, color: Color):
	if feedback_label:
		feedback_label.text = text
		feedback_label.modulate = color
		
		# Create a tween for feedback animation
		var tween = create_tween()
		tween.tween_property(feedback_label, "modulate", Color(color.r, color.g, color.b, 0), 0.8)

func show_qte():
	visible = true
	print("QTE System: Showing QTE UI")

func hide_qte():
	visible = false
	is_active = false
	
	# Restore time scale if still active
	if Engine.time_scale != original_time_scale:
		Engine.time_scale = original_time_scale
	
	print("QTE System: Hiding QTE UI")
