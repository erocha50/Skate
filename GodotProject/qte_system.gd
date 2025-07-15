# QTESystem.gd
extends Control

signal qte_completed(success: bool)
signal qte_started
signal qte_ended

var letter_container: HBoxContainer
var progress_bar: ProgressBar
var instruction_label: Label
var ui_ready: bool = false

var current_letters: Array[String] = []
var current_index: int = 0
var qte_duration: float = 5.0  # Total time to complete QTE
var time_remaining: float = 0.0
var is_active: bool = false

# Visual feedback
var correct_color: Color = Color.GREEN
var incorrect_color: Color = Color.RED
var pending_color: Color = Color.WHITE
var current_color: Color = Color.YELLOW

func _ready():
	# Wait for the scene to be fully loaded
	await get_tree().process_frame
	
	print("=== QTE System Debug ===")
	print("All children of QTESystem:")
	for child in get_children():
		print("  ", child.name, " (", child.get_class(), ")")
	
	# Try multiple methods to find the nodes
	var center_container = get_node("CenterContainer")
	if center_container:
		print("Found CenterContainer")
		var vbox = center_container.get_node("VBoxContainer")
		if vbox:
			print("Found VBoxContainer")
			print("VBoxContainer children:")
			for child in vbox.get_children():
				print("  ", child.name, " (", child.get_class(), ")")
			
			# Try to get the specific nodes
			letter_container = vbox.get_node("LetterContainer") as HBoxContainer
			progress_bar = vbox.get_node("ProgressBar") as ProgressBar
			instruction_label = vbox.get_node("InstructionLabel") as Label
		else:
			print("VBoxContainer not found!")
	else:
		print("CenterContainer not found!")
	
	print("Final results:")
	print("Letter Container: ", letter_container != null)
	print("Progress Bar: ", progress_bar != null)
	print("Instruction Label: ", instruction_label != null)
	
	visible = false
	
	if letter_container and progress_bar and instruction_label:
		_setup_ui()
		ui_ready = true
		print("QTE System ready!")
	else:
		print("ERROR: UI elements not found!")

func _setup_ui():
	# Set up the instruction label
	instruction_label.text = "Press the WASD keys in order!"
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Set up progress bar
	progress_bar.min_value = 0
	progress_bar.max_value = qte_duration
	progress_bar.value = qte_duration

func _process(delta):
	if not is_active:
		return
	
	time_remaining -= delta
	progress_bar.value = time_remaining
	
	# Check if time ran out
	if time_remaining <= 0:
		_end_qte(false)
		return
	
	# Handle input
	_handle_input()

func _handle_input():
	if not is_active or current_index >= current_letters.size():
		return
	
	var expected_letter = current_letters[current_index]
	
	# Check WASD keys only
	var key_pressed = ""
	if Input.is_action_just_pressed("move_up") or Input.is_key_pressed(KEY_W):
		key_pressed = "W"
	elif Input.is_action_just_pressed("move_left") or Input.is_key_pressed(KEY_A):
		key_pressed = "A"
	elif Input.is_action_just_pressed("move_down") or Input.is_key_pressed(KEY_S):
		key_pressed = "S"
	elif Input.is_action_just_pressed("move_right") or Input.is_key_pressed(KEY_D):
		key_pressed = "D"
	
	if key_pressed != "":
		if key_pressed == expected_letter:
			_correct_input()
		else:
			_incorrect_input()

func _correct_input():
	# Update visual feedback
	var letter_label = letter_container.get_child(current_index)
	letter_label.modulate = correct_color
	
	current_index += 1
	
	# Update current letter highlight
	if current_index < current_letters.size():
		var next_letter_label = letter_container.get_child(current_index)
		next_letter_label.modulate = current_color
	
	# Check if completed
	if current_index >= current_letters.size():
		_end_qte(true)

func _incorrect_input():
	# Visual feedback for wrong input
	var letter_label = letter_container.get_child(current_index)
	letter_label.modulate = incorrect_color
	
	# Flash back to current color
	var tween = create_tween()
	tween.tween_property(letter_label, "modulate", current_color, 0.3)

func start_qte():
	if is_active:
		return
	
	print("Starting QTE...")
	
	# Check if UI is ready
	if not ui_ready:
		print("ERROR: QTE UI not ready yet!")
		return
	
	# Ensure all UI elements are available
	if not letter_container or not progress_bar or not instruction_label:
		print("ERROR: UI elements not found!")
		return
	
	is_active = true
	current_index = 0
	time_remaining = qte_duration
	
	# Reset progress bar
	progress_bar.value = qte_duration
	
	# Generate random letters
	_generate_letters()
	
	# Force show UI and bring to front
	visible = true
	modulate = Color.WHITE
	z_index = 100  # Bring to front
	
	# Emit signal
	qte_started.emit()
	
	print("QTE Started! Letters: ", current_letters)
	print("QTE UI visible: ", visible)

func _generate_letters():
	current_letters.clear()
	
	print("Generating letters...")
	
	# Clear previous letter displays only if letter_container exists and has children
	if letter_container and letter_container.get_child_count() > 0:
		print("Clearing previous letters...")
		for child in letter_container.get_children():
			child.free()  # Use free() instead of queue_free() for immediate cleanup
	
	# WASD keys only
	var wasd_keys = ["W", "A", "S", "D"]
	
	# Generate 10 random WASD letters
	for i in range(10):
		var random_letter = wasd_keys[randi_range(0, 3)]
		current_letters.append(random_letter)
		
		# Create letter label
		var letter_label = Label.new()
		letter_label.text = random_letter
		letter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter_label.custom_minimum_size = Vector2(40, 40)
		letter_label.add_theme_font_size_override("font_size", 24)
		
		# Set initial color
		if i == 0:
			letter_label.modulate = current_color
		else:
			letter_label.modulate = pending_color
		
		# Only add child if letter_container exists
		if letter_container:
			letter_container.add_child(letter_label)
			print("Added letter: ", random_letter)
		else:
			print("ERROR: letter_container is null!")
	
	print("Total letters generated: ", current_letters.size())

func _end_qte(success: bool):
	if not is_active:
		return
	
	is_active = false
	visible = false
	
	# Emit completion signal
	qte_completed.emit(success)
	qte_ended.emit()
	
	var result_text = "SUCCESS!" if success else "FAILED!"
	print("QTE ", result_text)

func _input(event):
	if not is_active:
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		var key_pressed = ""
		
		# Check for WASD keys
		match event.keycode:
			KEY_W:
				key_pressed = "W"
			KEY_A:
				key_pressed = "A"
			KEY_S:
				key_pressed = "S"
			KEY_D:
				key_pressed = "D"
		
		if key_pressed != "":
			var expected_letter = current_letters[current_index]
			
			if key_pressed == expected_letter:
				_correct_input()
			else:
				_incorrect_input()
