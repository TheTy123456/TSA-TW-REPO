extends Camera2D

@export var player: Node2D
@export var player2: Node2D

@export var smooth_speed := 6.0

# Move camera down to reveal platforms below
@export var vertical_offset := 10.0

# Horizontal lookahead
@export var lookahead_distance := 40.0

var look_dir := 0.0

func _process(delta: float) -> void:
	if player == null or player2 == null:
		return

	if not player.camera_should_follow or not player2.camera_should_follow:
		return

	# --- LOOK DIRECTION ---
	if player.input_dir != 0:
		look_dir = player.input_dir
	elif player2.input_dir != 0:
		look_dir = player2.input_dir

	# --- MIDPOINT BETWEEN BOTH PLAYERS ---
	var midpoint := (player.global_position + player2.global_position) * 0.5

	# --- TARGET POSITION ---
	var target := midpoint

	# Lower camera to show platforms
	target.y += vertical_offset

	# Add horizontal lookahead
	target.x += look_dir * lookahead_distance

	# --- SMOOTH FOLLOW ---
	global_position = global_position.lerp(target, delta * smooth_speed)
