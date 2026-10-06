extends Camera2D

@export var player: Node2D

# Smoothness
@export var smooth_speed := 6.0

# Player should be slightly above center
@export var vertical_offset := -40.0

# Look-ahead
@export var lookahead_distance := 40.0
var look_dir := 0.0

func _process(delta: float) -> void:
	if player == null:
		return

	if not player.camera_should_follow:
		return

	# --- LOOK DIRECTION ---
	if player.input_dir != 0:
		look_dir = player.input_dir

	# --- TARGET POSITION ---
	var target := player.global_position

	# Move camera UP slightly so player sees more ground
	target.y += vertical_offset

	# Horizontal look-ahead
	target.x += look_dir * lookahead_distance

	# --- SMOOTH FOLLOW ---
	global_position = global_position.lerp(target, delta * smooth_speed)
