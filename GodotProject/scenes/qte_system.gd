extends Control

# QTE System for Rail Grinding Tricks
# Shows a scrolling WASD sequence that the player must input correctly

signal qte_completed(success)

# QTE Configuration
export var sequence_length: int = 4
export var time_per_input: float = 0.8
export var scroll_speed: float = 200.0
export var letter_spacing: float = 100.0

# UI Elements
onready var qte_container: Control = $QTEContainer
onready var letter_container: Control = $QTEContainer/LetterContainer
onready var center_indicator: Control = $QTEContainer/CenterIndicator
onready var progress_bar: ProgressBar = $QTEContainer/ProgressBar
onready var feedback_label: Label = $QTEContainer/FeedbackLabel

# QTE State
var is_active: bool = false
var current_sequence: Array = []
var current_index: int = 0
var letter_nodes: Array = []
var input_timer: float = 0.0
var total_time: float = 0.0

# Input mapping
var input_map: Dictionary = {
	"w": "move_up",
	"a": "move_left", 
	"s": "move_down",
	"d": "move_right"
}

# Colors for visual feedback
var default_color: Color = Color.white
var active_color: Color = Color.yellow
var success_color: Color = Color.green
var fail_color: Color = Color.red

func _ready():
	# Hide the QTE initially
	hide_qte()
	
	# Setup UI elements
	_setup_ui()

func _setup_ui():
	# Create main container if it doesn't exist
	if not qte_container:
		qte_container = Control.new()
		qte_container.name = "QTEContainer"
		qte_container.anchor_left = 0.5
		qte_container.anchor_right = 0.5
		qte_container.anchor_top = 0.5
		qte_container.anchor_bottom = 0.5
		qte_container.margin_left = -200
		qte_container.margin_right = 200
		qte_container.margin_top = -100
		qte_container.margin_bottom = 100
		add_child(qte_container)
	
	# Create letter container for scrolling letters
	if not letter_container:
		letter_container = Control.new()
		letter_container.name = "LetterContainer"
		letter_container.rect_position = Vector2(0, -50)
		letter_container.rect_size = Vector2(400, 100)
		qte_container.add_child(letter_container)
	
	# Create center indicator (shows current letter position)
	if not center_indicator:
		center_indicator = Panel.new()
		center_indicator.name = "CenterIndicator"
		center_indicator.rect_position = Vector2(175, -60)
		center_indicator.rect_size = Vector2(50, 120)
		center_indicator.modulate = Color(1, 1, 1, 0.3)
		qte_container.add_child(center_indicator)
	
	# Create progress bar
	if not progress_bar:
		progress_bar = ProgressBar.new()
		progress_bar.name = "ProgressBar"
		progress_bar.rect_position = Vector2(-100, 80)
		progress_bar.rect_size = Vector2(200, 20)
		progress_bar.max_value = 100
		qte_container.add_child(progress_bar)
	
	# Create feedback label
	if not feedback_label:
		feedback_label = Label.new()
		feedback_label.name = "FeedbackLabel"
		feedback_label.rect_position = Vector2(-50, 110)
		feedback_label.rect_size = Vector2(100, 30)
		feedback_label.align = Label.ALIGN_CENTER
		feedback_label.add_font_override("font", load("res://fonts/default_font.tres"))
		qte_container.add_child(feedback_label)

func start_qte():
	if is_active:
		return
	
	print("QTE System: Starting new QTE sequence")
	
	# Generate random sequence
	_generate_sequence()
	
	# Setup QTE state
	is_active = true
	current_index = 0
	total_time = sequence_length * time_per_input
	input_timer = time_per_input
	
	# Show and setup UI
	show_qte()
	_create_letter_display()
	_update_progress()
	
	# Clear feedback
	feedback_label.text = ""

func _generate_sequence():
	current_sequence.clear()
	var letters = ["w", "a", "s", "d"]
	
	for i in range(sequence_length):
		current_sequence.append(letters[randi() % letters.size()])
	
	print("QTE System: Generated sequence: ", current_sequence)

func _create_letter_display():
	# Clear existing letter nodes
	for node in letter_nodes:
		if node:
			node.queue_free()
	letter_nodes.clear()
	
	# Create letter nodes for the sequence
	for i in range(current_sequence.size()):
		var letter_node = _create_letter_node(current_sequence[i], i)
		letter_container.add_child(letter_node)
		letter_nodes.append(letter_node)

func _create_letter_node(letter: String, index: int) -> Control:
	var letter_panel = Panel.new()
	letter_panel.rect_size = Vector2(80, 80)
	letter_panel.rect_position = Vector2(index * letter_spacing, 0)
	
	var letter_label = Label.new()
	letter_label.text = letter.to_upper()
	letter_label.align = Label.ALIGN_CENTER
	letter_label.valign = Label.VALIGN_CENTER
	letter_label.anchor_left = 0
	letter_label.anchor_right = 1
	letter_label.anchor_top = 0
	letter_label.anchor_bottom = 1
	letter_label.modulate = default_color
	
	letter_panel.add_child(letter_label)
	
	return letter_panel

func _process(delta):
	if not is_active:
		return
	
	# Update timers
	input_timer -= delta
	total_time -= delta
	
	# Update progress bar
	_update_progress()
	
	# Scroll letters towards center
	_scroll_letters(delta)
	
	# Check for timeout
	if input_timer <= 0:
		_handle_timeout()
		return
	
	# Handle input
	_handle_input()

func _scroll_letters(delta):
	var scroll_offset = scroll_speed * delta
	
	for i in range(letter_nodes.size()):
		if letter_nodes[i]:
			var target_x = (i - current_index) * letter_spacing + 175  # 175 is center position
			var current_x = letter_nodes[i].rect_position.x
			letter_nodes[i].rect_position.x = lerp(current_x, target_x, 5.0 * delta)
			
			# Update color based on position and status
			_update_letter_color(i)

func _update_letter_color(index: int):
	if index >= letter_nodes.size() or not letter_nodes[index]:
		return
	
	var letter_label = letter_nodes[index].get_child(0) as Label
	if not letter_label:
		return
	
	if index < current_index:
		# Completed letters - fade out as they move left
		var distance_from_center = abs(letter_nodes[index].rect_position.x - 175)
		var fade_alpha = max(0.0, 1.0 - (distance_from_center / 200.0))
		letter_label.modulate = Color(success_color.r, success_color.g, success_color.b, fade_alpha)
	elif index == current_index:
		# Current letter - highlight
		letter_label.modulate = active_color
	else:
		# Future letters - fade in as they approach from right
		var distance_from_center = abs(letter_nodes[index].rect_position.x - 175)
		var fade_alpha = max(0.3, 1.0 - (distance_from_center / 300.0))
		letter_label.modulate = Color(default_color.r, default_color.g, default_color.b, fade_alpha)

func _handle_input():
	var current_letter = current_sequence[current_index]
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
	print("QTE System: Correct input for letter: ", current_sequence[current_index])
	
	# Show success feedback
	_show_feedback("GOOD!", success_color)
	
	# Move to next letter
	current_index += 1
	input_timer = time_per_input
	
	# Check if sequence is complete
	if current_index >= current_sequence.size():
		_complete_qte(true)

func _handle_wrong_input():
	print("QTE System: Wrong input! Expected: ", current_sequence[current_index])
	
	# Show failure feedback
	_show_feedback("MISS!", fail_color)
	
	# Flash the current letter red
	if current_index < letter_nodes.size() and letter_nodes[current_index]:
		var letter_label = letter_nodes[current_index].get_child(0) as Label
		if letter_label:
			letter_label.modulate = fail_color
	
	# End QTE with failure
	_complete_qte(false)

func _handle_timeout():
	print("QTE System: Timeout!")
	_show_feedback("TOO SLOW!", fail_color)
	_complete_qte(false)

func _complete_qte(success: bool):
	print("QTE System: QTE completed with success: ", success)
	
	is_active = false
	
	# Emit completion signal
	emit_signal("qte_completed", success)
	
	# Hide QTE after a brief delay
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	add_child(timer)
	timer.connect("timeout", self, "_on_completion_delay_timeout")
	timer.start()

func _on_completion_delay_timeout():
	hide_qte()

func _update_progress():
	if progress_bar:
		var progress = (input_timer / time_per_input) * 100.0
		progress_bar.value = progress
		
		# Change color based on time remaining
		if progress < 30:
			progress_bar.modulate = fail_color
		elif progress < 60:
			progress_bar.modulate = Color.orange
		else:
			progress_bar.modulate = success_color

func _show_feedback(text: String, color: Color):
	if feedback_label:
		feedback_label.text = text
		feedback_label.modulate = color
		
		# Create a tween for feedback animation
		var tween = Tween.new()
		add_child(tween)
		tween.interpolate_property(feedback_label, "modulate", color, Color(color.r, color.g, color.b, 0), 0.8)
		tween.start()

func show_qte():
	visible = true
	print("QTE System: Showing QTE UI")

func hide_qte():
	visible = false
	is_active = false
	
	# Clear letter nodes
	for node in letter_nodes:
		if node:
			node.queue_free()
	letter_nodes.clear()
	
	print("QTE System: Hiding QTE UI")
