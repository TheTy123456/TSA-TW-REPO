extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var label: Label = $Panel/Label

var current_tween: Tween

func _ready() -> void:
	add_to_group("captions")

	hide()

	panel.modulate.a = 0.0
	label.modulate.a = 0.0


func show_caption(text: String, duration: float = 3.0) -> void:
	if current_tween:
		current_tween.kill()

	label.text = text

	show()

	panel.modulate.a = 0.0
	label.modulate.a = 0.0

	current_tween = create_tween()

	current_tween.parallel().tween_property(
		panel,
		"modulate:a",
		1.0,
		0.15
	)

	current_tween.parallel().tween_property(
		label,
		"modulate:a",
		1.0,
		0.15
	)

	await get_tree().create_timer(duration).timeout

	current_tween = create_tween()

	current_tween.parallel().tween_property(
		panel,
		"modulate:a",
		0.0,
		0.25
	)

	current_tween.parallel().tween_property(
		label,
		"modulate:a",
		0.0,
		0.25
	)

	await current_tween.finished

	hide()
