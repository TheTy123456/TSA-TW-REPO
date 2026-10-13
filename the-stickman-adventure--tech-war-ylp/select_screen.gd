extends Control

var characters = [
	{
		"name": "Stick",
		"banner": preload("res://pixil-layer-Background (4).png"),
		"effect": preload("res://pixil-layer-1.png"),
		"portrait": preload("res://pixil-layer-Layer 1 (2).png")
	},
	{
		"name": "Max",
		"banner": preload("res://pixil-layer-Background (3).png"),
		"effect": preload("res://pixil-layer-2.png"),
		"portrait": preload("res://pixil-layer-3.png")
	}
]

var current_index := 0


func _ready():
	update_character()


func _input(event):
	if event.is_action_pressed("ui_left"):
		change_character(-1)
	elif event.is_action_pressed("ui_right"):
		change_character(1)
	elif event.is_action_pressed("ui_accept"):
		start_cutscene()


func change_character(direction):
	current_index = (current_index + direction) % characters.size()
	if current_index < 0:
		current_index = characters.size() - 1

	tween_portrait(direction)
	update_character()


func update_character():
	var data = characters[current_index]

	# Swap textures
	$Portraits.texture = data["portrait"]
	$Banner.texture = data["banner"]
	$Effect.texture = data["effect"]

	# Update name
	$Label.text = data["name"]


func tween_portrait(direction):
	var tween = create_tween()

	var start_pos = $Portraits.position
	var offscreen = start_pos + Vector2(direction * -200, 0)

	# Slide out
	tween.tween_property($Portraits, "position", offscreen, 0.15)

	tween.tween_callback(func():
		# Reset to opposite side
		$Portraits.position = start_pos + Vector2(direction * 200, 0)
	)

	# Slide in
	tween.tween_property($Portraits, "position", start_pos, 0.15)
func start_cutscene():
	# Optional: play a sound or animation here
	get_tree().change_scene_to_file("res://Cutscenes/TestCutscene/Scene/cutscene.tscn")
