extends TextureRect

var time := 0.0

func _ready():
	pivot_offset = size / 2

func _process(delta):
	time += delta
	rotation_degrees = sin(time * 0.3) * 10.0
