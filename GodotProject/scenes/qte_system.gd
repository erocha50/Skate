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

# Input mapping - Updated to match movement system actions
var input_map: Dictionary = {
	"w": "accelerate",
	"a": "steer_left", 
	"s": "brake",
	"d": "steer_right"
}

# Fallback input mapping for ui_* actions
var fallback_input_map: Dictionary = {
	"w": "ui_up",
	"a": "ui_left", 
	"s": "ui_down",
	"d": "ui_right"
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
	
	# Debug print
	print("QTE System initialized")

func _setup_ui():
	# Make sure we have all required nodes
	if not qte_container:
		print("ERROR: QTEContainer not found! Creating basic UI...")
		_create_basic_ui()
		return
	
	print("QTE System: Setting up UI with container: ", qte_container.name)
	
	# Make sure the container is visible
	qte_container.visible = true
	qte_container.modulate = Color.WHITE
	
	# Center the container on screen and make it large enough to see
	qte_container.anchors_preset = Control.PRESET_CENTER
	qte_container.size = Vector2(400, 300)  # Made larger
	qte_container.position = -qte_container.size / 2  # Center it properly
	
	print("QTE Container size: ", qte_container.size, ", position: ", qte_container.position)
	
	# Setup letter label (large, centered)
	if letter_label:
		letter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter_label.add_theme_font_size_override("font_size", 72)
		letter_label.modulate = Color.WHITE
		letter_label.visible = true
		print("Letter label configured")
	else:
		print("WARNING: LetterLabel not found!")
	
	# Setup progress bar
	if progress_bar:
		progress_bar.show_percentage = false
		progress_bar.max_value = 100
		progress_bar.modulate = Color.WHITE
		progress_bar.visible = true
		print("Progress bar configured")
	else:
		print("WARNING: ProgressBar not found!")
	
	# Setup feedback label
	if feedback_label:
		feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		feedback_label.add_theme_font_size_override("font_size", 24)
		feedback_label.modulate = Color.WHITE
		feedback_label.visible = true
		print("Feedback label configured")
	else:
		print("WARNING: FeedbackLabel not found!")
	
	# Setup background
	if background:
		background.color = Color(0.2, 0.2, 0.2, 0.9)  # More visible background
		background.visible = true
		# Make background fill the container
		background.anchors_preset = Control.PRESET_FULL_RECT
		print("Background configured with color: ", background.color)
	else:
		print("WARNING: Background not found!")

# Create basic UI if nodes are missing
func _create_basic_ui():
	print("Creating basic QTE UI...")
	
	# Create container if it doesn't exist
	if not qte_container:
		qte_container = Control.new()
		qte_container.name = "QTEContainer"
		add_child(qte_container)
	
	# Create background
	if not background:
		background = ColorRect.new()
		background.name = "Background"
		background.color = Color(0.2, 0.2, 0.2, 0.9)
		qte_container.add_child(background)
		background.anchors_preset = Control.PRESET_FULL_RECT
	
	# Create letter label
	if not letter_label:
		letter_label = Label.new()
		letter_label.name = "LetterLabel"
		letter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter_label.add_theme_font_size_override("font_size", 72)
		qte_container.add_child(letter_label)
		letter_label.anchors_preset = Control.PRESET_FULL_RECT
	
	# Create feedback label
	if not feedback_label:
		feedback_label = Label.new()
		feedback_label.name = "FeedbackLabel"
		feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		feedback_label.add_theme_font_size_override("font_size", 24)
		qte_container.add_child(feedback_label)
		feedback_label.anchors_preset = Control.PRESET_BOTTOM_WIDE
		feedback_label.position.y = -50
	
	# Create progress bar
	if not progress_bar:
		progress_bar = ProgressBar.new()
		progress_bar.name = "ProgressBar"
		progress_bar.show_percentage = false
		progress_bar.max_value = 100
		qte_container.add_child(progress_bar)
		progress_bar.anchors_preset = Control.PRESET_TOP_WIDE
		progress_bar.position.y = 20
		progress_bar.size.y = 20
	
	# Now setup with the created nodes
	_setup_ui()

func start_qte():
	if is_active:
		print("QTE System: Already active, ignoring start request")
		return
	
	print("QTE System: Starting QTE")
	print("QTE System: Current visibility before start: ", visible)
	
	# Store original time scale and slow down game
	original_time_scale = Engine.time_scale
	Engine.time_scale = slowdown_factor
	print("QTE System: Time scale changed from ", original_time_scale, " to ", Engine.time_scale)
	
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
	if feedback_label:
		feedback_label.text = "PRESS " + current_letter.to_upper() + "!"
		feedback_label.modulate = Color.WHITE
		print("QTE System: Feedback text set to: ", feedback_label.text)
	
	print("QTE System: QTE fully started - visible: ", visible, ", is_active: ", is_active)

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
	else:
		print("ERROR: Cannot setup letter display - letter_label is null!")

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
	var fallback_action = fallback_input_map.get(current_letter, "")
	
	# Check if the correct input is pressed (try both custom and fallback actions)
	var correct_input_pressed = false
	if input_action != "" and Input.is_action_just_pressed(input_action):
		correct_input_pressed = true
	elif fallback_action != "" and Input.is_action_just_pressed(fallback_action):
		correct_input_pressed = true
	
	if correct_input_pressed:
		_handle_correct_input()
		return
	
	# Check for wrong input (check both custom and fallback actions)
	for letter in input_map.keys():
		if letter != current_letter:
			var wrong_action = input_map[letter]
			var wrong_fallback = fallback_input_map[letter]
			
			if (wrong_action != "" and Input.is_action_just_pressed(wrong_action)) or \
			   (wrong_fallback != "" and Input.is_action_just_pressed(wrong_fallback)):
				_handle_wrong_input()
				return

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
	print("HIDING ON COMPLETEON DELAY TIMEOUT")
	hide_qte()
	# Clean up the timer
	var timer_nodes = get_children().filter(func(node): return node is Timer)
	for timer in timer_nodes:
		if timer.is_connected("timeout", _on_completion_delay_timeout):
			timer.queue_free()

func _update_progress():
	if not progress_bar:
		return
		
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
	if not feedback_label:
		return
		
	feedback_label.text = text
	feedback_label.modulate = color
	
	# Create a tween for feedback animation
	var tween = create_tween()
	tween.tween_property(feedback_label, "modulate", Color(color.r, color.g, color.b, 0), 0.8)

func show_qte():
	visible = true
	modulate = Color.WHITE  # Make sure it's not transparent
	
	# Force the container to be visible too
	if qte_container:
		qte_container.visible = true
		qte_container.modulate = Color.WHITE
		print("QTE System: QTEContainer made visible")
	
	# Make sure we're on top of everything
	move_to_front()
	
	print("QTE System: Showing QTE UI - visible: ", visible, ", big booty latinas: ", modulate)

func hide_qte():
	
	visible = false
	is_active = false
	
	# Restore time scale if still active
	if Engine.time_scale != original_time_scale:
		Engine.time_scale = original_time_scale
	
	print("QTE System: Hiding QTE UI")

# Force stop QTE (for cleanup purposes)
func force_stop_qte():
	if is_active:
		print("QTE System: Force stopping QTE")
		is_active = false
		Engine.time_scale = original_time_scale
		print("HIDING FORCE STOP QTE")
		hide_qte()
