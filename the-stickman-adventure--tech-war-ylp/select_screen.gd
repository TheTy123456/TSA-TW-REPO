extends Control

var characters = [
	{
		"name": "Stick",
		"banner": preload("res://pixil-layer-Background (4).png"),
		"effect": preload("res://pixil-layer-1.png"),
		"portrait": preload("res://pixil-layer-Layer 1 (2).png"),
		"scene": "res://Characters/Stick/Scenes/stick.tscn"
		
	},
	{
		"name": "Max",
		"banner": preload("res://pixil-layer-Background (3).png"),
		"effect": preload("res://pixil-layer-2.png"),
		"portrait": preload("res://pixil-layer-3.png"),
		"scene": "res://Characters/Max/Scenes/max.tscn"
	}
]

var is_multiplayer := false
var p1_index := 0
var p2_index := 0

var portrait_tween : Tween
var portrait_center


func _ready():
	is_multiplayer = GameState.game_mode == "multi"
	update_menu_mode()

	portrait_center = $Single/Portraits.position

	if is_multiplayer:
		update_p1()
		update_p2()
	else:
		update_single()


func update_menu_mode():
	$Single.visible = not is_multiplayer
	$Multi.visible = is_multiplayer


func _input(event):
	if not is_visible_in_tree():
		return

	if is_multiplayer:
		handle_multi_input(event)
	else:
		handle_single_input(event)


# ---------------------------------------------------------
# SINGLE PLAYER
# ---------------------------------------------------------
func handle_single_input(event):
	if event.is_action_pressed("player1_left"):
		p1_index = (p1_index - 1 + characters.size()) % characters.size()
		tween_portrait(-1)
		update_single()

	elif event.is_action_pressed("player1_right"):
		p1_index = (p1_index + 1) % characters.size()
		tween_portrait(1)
		update_single()

	elif event.is_action_pressed("player1_enter"):
		start_cutscene_single()


func update_single():
	var data = characters[p1_index]
	var slot = $Single

	slot.get_node("Portraits").texture = data["portrait"]
	slot.get_node("Banner").texture = data["banner"]
	slot.get_node("Effect").texture = data["effect"]
	slot.get_node("Label").text = data["name"]


func start_cutscene_single():
	GameState.selected_characters = [characters[p1_index]]
	get_tree().change_scene_to_file("res://Cutscenes/TestCutscene/Scene/cutscene.tscn")


# ---------------------------------------------------------
# MULTI PLAYER
# ---------------------------------------------------------
func handle_multi_input(event):
	if event.is_action_pressed("player1_left"):
		p1_index = (p1_index - 1 + characters.size()) % characters.size()
		update_p1()

	elif event.is_action_pressed("player1_right"):
		p1_index = (p1_index + 1) % characters.size()
		update_p1()

	if event.is_action_pressed("player2_left"):
		p2_index = (p2_index - 1 + characters.size()) % characters.size()
		update_p2()

	elif event.is_action_pressed("player2_right"):
		p2_index = (p2_index + 1) % characters.size()
		update_p2()

	if event.is_action_pressed("player1_enter"):
		start_cutscene_multi()


func update_p1():
	var data = characters[p1_index]
	var slot = $"Multi/First Player"

	slot.get_node("Portraits").texture = data["portrait"]
	slot.get_node("Banner").texture = data["banner"]
	slot.get_node("Effect").texture = data["effect"]
	slot.get_node("Label").text = data["name"]


func update_p2():
	var data = characters[p2_index]
	var slot = $"Multi/Second Player"

	slot.get_node("Portraits").texture = data["portrait"]
	slot.get_node("Banner").texture = data["banner"]
	slot.get_node("Effect").texture = data["effect"]
	slot.get_node("Label").text = data["name"]


func start_cutscene_multi():
	GameState.selected_characters = [
		characters[p1_index],
		characters[p2_index]
	]
	get_tree().change_scene_to_file("res://Cutscenes/TestCutscene/Scene/cutscene.tscn")


# ---------------------------------------------------------
# PORTRAIT TWEEN (single only)
# ---------------------------------------------------------
func tween_portrait(direction):
	var portraits = $Single/Portraits

	if portrait_tween and portrait_tween.is_running():
		portrait_tween.kill()
		portraits.position = portrait_center

	portrait_tween = create_tween()

	var start_pos = portrait_center
	var offscreen = start_pos + Vector2(direction * -200, 0)

	portrait_tween.tween_property(portraits, "position", offscreen, 0.15)

	portrait_tween.tween_callback(func():
		portraits.position = start_pos + Vector2(direction * 200, 0)
	)

	portrait_tween.tween_property(portraits, "position", start_pos, 0.15)
