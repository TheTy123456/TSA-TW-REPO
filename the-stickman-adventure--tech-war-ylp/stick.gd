extends AnimatedSprite2D

@export var bop_height := 10.0
@export var bop_speed := 3.0

var start_y := 0.0
var time := 0.0

func _ready():
	start_y = position.y

func _process(delta):
	time += delta

	position.y = start_y + sin(time * bop_speed) * bop_height
