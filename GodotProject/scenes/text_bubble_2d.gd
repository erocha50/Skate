extends Control
class_name TextBubble

@export var padding: Vector2 = Vector2(20, 15)
@export var corner_radius: float = 15.0
@export var border_width: float = 2.0
@export var border_color: Color = Color.BLACK

var bubble_color: Color = Color.WHITE
var text_color: Color = Color.BLACK
var bubble_text: String = ""

var label: Label

func _ready():
	# Create label
	label = Label.new()
	add_child(label)
	
	# Configure label
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func setup_bubble(text: String, bg_color: Color, txt_color: Color, size: Vector2):
	bubble_text = text
	bubble_color = bg_color
	text_color = txt_color
	
	# Set size and configure label
	custom_minimum_size = size
	self.size = size
	
	if label:
		label.text = bubble_text
		label.add_theme_color_override("font_color", text_color)
		label.size = size - padding * 2
		label.position = padding
	
	queue_redraw()

func _draw():
	# Draw bubble background with rounded corners
	var rect = Rect2(Vector2.ZERO, size)
	draw_rounded_rect(rect, corner_radius, bubble_color)
	
	# Draw border
	if border_width > 0:
		draw_rounded_rect_border(rect, corner_radius, border_color, border_width)

func draw_rounded_rect(rect: Rect2, radius: float, color: Color):
	# Draw rounded rectangle background
	draw_rect(Rect2(rect.position.x + radius, rect.position.y, rect.size.x - 2 * radius, rect.size.y), color)
	draw_rect(Rect2(rect.position.x, rect.position.y + radius, rect.size.x, rect.size.y - 2 * radius), color)
	
	# Draw corner circles
	draw_circle(Vector2(rect.position.x + radius, rect.position.y + radius), radius, color)
	draw_circle(Vector2(rect.position.x + rect.size.x - radius, rect.position.y + radius), radius, color)
	draw_circle(Vector2(rect.position.x + radius, rect.position.y + rect.size.y - radius), radius, color)
	draw_circle(Vector2(rect.position.x + rect.size.x - radius, rect.position.y + rect.size.y - radius), radius, color)

func draw_rounded_rect_border(rect: Rect2, radius: float, color: Color, width: float):
	# Draw border lines
	var inner_rect = Rect2(rect.position + Vector2(width/2, width/2), rect.size - Vector2(width, width))
	
	# Top and bottom lines
	draw_line(Vector2(inner_rect.position.x + radius, rect.position.y + width/2), 
			 Vector2(inner_rect.position.x + inner_rect.size.x - radius, rect.position.y + width/2), color, width)
	draw_line(Vector2(inner_rect.position.x + radius, rect.position.y + rect.size.y - width/2), 
			 Vector2(inner_rect.position.x + inner_rect.size.x - radius, rect.position.y + rect.size.y - width/2), color, width)
	
	# Left and right lines
	draw_line(Vector2(rect.position.x + width/2, inner_rect.position.y + radius), 
			 Vector2(rect.position.x + width/2, inner_rect.position.y + inner_rect.size.y - radius), color, width)
	draw_line(Vector2(rect.position.x + rect.size.x - width/2, inner_rect.position.y + radius), 
			 Vector2(rect.position.x + rect.size.x - width/2, inner_rect.position.y + inner_rect.size.y - radius), color, width)
