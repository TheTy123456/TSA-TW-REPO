extends Camera2D

@export var player: Node2D
@export var player2: Node2D

@export var smooth_speed := 6.0
@export var vertical_offset := 10.0
@export var lookahead_distance := 40.0

var look_dir := 0.0

func _process(delta: float) -> void:
	print("Camera script loaded on node:", name)
	print("Node type is Camera2D? ->", self is Camera2D)
	print("Attached script file ->", get_script())

	if GameState.game_mode == "single":
		follow_single(delta)
	else:
		follow_multi(delta)


func follow_single(delta):
	if player == null:
		return
	if not player.camera_should_follow:
		return

	if player.input_dir != 0:
		look_dir = player.input_dir

	var target := player.global_position
	target.y += vertical_offset
	target.x += look_dir * lookahead_distance

	global_position = global_position.lerp(target, delta * smooth_speed)


func follow_multi(delta):
	if player == null or player2 == null:
		return
	if not player.camera_should_follow or not player2.camera_should_follow:
		return

	if player.input_dir != 0:
		look_dir = player.input_dir
	elif player2.input_dir != 0:
		look_dir = player2.input_dir

	var midpoint := (player.global_position + player2.global_position) * 0.5

	var target := midpoint
	target.y += vertical_offset
	target.x += look_dir * lookahead_distance

	global_position = global_position.lerp(target, delta * smooth_speed)
