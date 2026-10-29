extends Node2D

@onready var transitions: CanvasLayer = $Transitions

# One camera
@onready var cam: Camera2D = $Camera as Camera2D

# Respawn points
const P1_RESPAWN := Vector2(160, -30)
const P2_RESPAWN := Vector2(195, -30)

func _ready() -> void:
	print("=== CAMERA DEBUG START ===")
	print("Camera node:", $Camera)
	print("Camera class:", $Camera.get_class())
	print("Camera script:", $Camera.get_script())
	print("Is Camera2D:", $Camera is Camera2D)
	print("Has make_current:", $Camera.has_method("make_current"))
	
	var names := []
	for p in $Camera.get_property_list():
		names.append(p.name)
		print("Camera properties:", names)
		print("=== CAMERA DEBUG END ===")
		print("Selected characters:", GameState.selected_characters)

	var mode = GameState.game_mode
	var chars = GameState.selected_characters
	
	if chars.size() == 0:
		print("ERROR: No character selected!")
		return
		
	if mode == "single":
		var p1 = spawn_single(chars[0])
		setup_single_player(p1)
	else:
		var players = spawn_multi(chars)
		setup_multi_player(players[0], players[1])
		
	await get_tree().process_frame
	await get_tree().process_frame
	
	transitions.play_circle_fade_out()


# ---------------------------------------------------------
# SPAWN FUNCTIONS
# ---------------------------------------------------------
func spawn_single(character):
	var player_scene = load(character["scene"])
	var player = player_scene.instantiate()
	add_child(player)
	return player


func spawn_multi(characters):
	var p1_scene = load(characters[0]["scene"])
	var p2_scene = load(characters[1]["scene"])

	var player1 = p1_scene.instantiate()
	var player2 = p2_scene.instantiate()

	add_child(player1)
	add_child(player2)

	return [player1, player2]


# ---------------------------------------------------------
# SINGLE PLAYER SETUP
# ---------------------------------------------------------
func setup_single_player(player1):
	# Respawn position
	player1.global_position = P1_RESPAWN

	# Camera mode
	cam.player = player1
	cam.player2 = null
	call_deferred("_deferred_make_current")
	# Hide player 2 if it exists
	if has_node("Max"):
		$Max.visible = false


# ---------------------------------------------------------
# MULTI PLAYER SETUP
# ---------------------------------------------------------
func setup_multi_player(player1, player2):
	# Respawn positions
	player1.global_position = P1_RESPAWN
	player2.global_position = P2_RESPAWN

	# Camera mode
	
	cam.player = player1
	cam.player2 = player2
	call_deferred("_deferred_make_current")
	
func _deferred_make_current() -> void:
	if cam and cam.is_inside_tree():
		cam.make_current()
