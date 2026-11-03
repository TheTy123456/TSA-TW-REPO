extends Area2D

const SCREEN_SIZE := Vector2(1920, 1080)

var velocity: Vector2

func _ready():
	add_to_group("balls")

	velocity = Vector2(
		randf_range(-1200, 1200),
		randf_range(-1200, 1200)
	)

	body_entered.connect(_ball_hit)
	area_entered.connect(_ball_hit)

func _process(delta):
	position += velocity * delta

	# Screen bounce
	if position.x < 0:
		position.x = 0
		velocity.x *= -1

	elif position.x > SCREEN_SIZE.x:
		position.x = SCREEN_SIZE.x
		velocity.x *= -1

	if position.y < 0:
		position.y = 0
		velocity.y *= -1

	elif position.y > SCREEN_SIZE.y:
		position.y = SCREEN_SIZE.y
		velocity.y *= -1

func _ball_hit(other):
	if other == self:
		return

	var dir = (global_position - other.global_position).normalized()

	velocity = dir * velocity.length()
	other.velocity = -dir * other.velocity.length()
