extends Control

var characters = [
	{
		"name": "Stick",
		"scene": "res://Characters/Stick/Scenes/stick.tscn",
		"banner": preload("res://pixil-layer-Background (4).png"),
		"effect": preload("res://pixil-layer-1.png"),
		"portrait": preload("res://pixil-layer-Layer 1 (2).png")
	},
	{
		"name": "Max",
		"scene": "res://Characters/Max/Scenes/max.tscn",
		"banner": preload("res://pixil-layer-Background (3).png"),
		"effect": preload("res://pixil-layer-2.png"),
		"portrait": preload("res://pixil-layer-3.png")
	}
]

var current_index := 0
var portrait_tween : Tween

var portrait_center
func _ready():
	portrait_center = $Portraits.position
	update_character()


func _input(event):
	if event.is_action_pressed("player2_left"):
		change_character(-1)
	elif event.is_action_pressed("player2_right"):
		change_character(1)
	elif event.is_action_pressed("player2_enter"):
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
	# Cancel previous tween if still running
	if portrait_tween and portrait_tween.is_running():
		portrait_tween.kill()
		$Portraits.position = Vector2(0, 0)  # reset to center

	portrait_tween = create_tween()

	var start_pos = $Portraits.position
	var offscreen = start_pos + Vector2(direction * -200, 0)

	# Slide out
	portrait_tween.tween_property($Portraits, "position", offscreen, 0.15)

	portrait_tween.tween_callback(func():
		$Portraits.position = start_pos + Vector2(direction * 200, 0)
	)

	# Slide in
	portrait_tween.tween_property($Portraits, "position", start_pos, 0.15)

func start_cutscene():
	# Optional: play a sound or animation here
	GameState.selected_characters = [characters[current_index]]
	print("Selected:", GameState.selected_characters)
	get_tree().change_scene_to_file("res://Cutscenes/TestCutscene/Scene/cutscene.tscn")
