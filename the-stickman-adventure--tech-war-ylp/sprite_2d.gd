extends Sprite2D

const SCREEN_SIZE := Vector2(1920, 1080)

var velocity := Vector2.ZERO
var direction_timer := 0.0

func _ready():
	randomize()
	_new_direction()

func _process(delta):
	position += velocity * delta

	# bounce
	if position.x < 0 or position.x > SCREEN_SIZE.x:
		velocity.x *= -1

	if position.y < 0 or position.y > SCREEN_SIZE.y:
		velocity.y *= -1

	# pick a new random direction occasionally
	direction_timer -= delta

	if direction_timer <= 0:
		_new_direction()

func _new_direction():
	direction_timer = randf_range(1.0, 3.0)

	velocity = Vector2(
		randf_range(-1000, 1000),
		randf_range(-1000, 1000)
	)
