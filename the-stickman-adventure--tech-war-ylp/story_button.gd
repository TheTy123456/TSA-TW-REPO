extends TextureButton

var start_pos: Vector2
var tween: Tween

func _ready():
	start_pos = position

	mouse_entered.connect(_hover)
	mouse_exited.connect(_unhover)

func _hover():
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_parallel()

	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		self,
		"position",
		start_pos + Vector2(35, 0),
		0.15
	)

	tween.tween_property(
		self,
		"scale",
		Vector2(1.08, 1.08),
		0.15
	)

	tween.tween_property(
		self,
		"modulate",
		Color(1.2, 1.2, 1.2),
		0.15
	)

func _unhover():
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_parallel()

	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		self,
		"position",
		start_pos,
		0.15
	)

	tween.tween_property(
		self,
		"scale",
		Vector2.ONE,
		0.15
	)

	tween.tween_property(
		self,
		"modulate",
		Color.WHITE,
		0.15
	)
