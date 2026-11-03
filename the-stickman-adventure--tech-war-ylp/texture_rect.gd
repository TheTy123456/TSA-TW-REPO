extends TextureRect

@export var float_speed := 1.5
@export var float_amount := 10.0

@export var rotate_speed := 1.0
@export var rotate_amount := 5.0

var start_position: Vector2
var time := 0.0

func _ready():
	start_position = position
	pivot_offset = size / 2

func _process(delta):
	time += delta

	# Float up and down
	position.y = start_position.y + sin(time * float_speed) * float_amount

	# Slowly sway left and right
	rotation_degrees = sin(time * rotate_speed) * rotate_amount
