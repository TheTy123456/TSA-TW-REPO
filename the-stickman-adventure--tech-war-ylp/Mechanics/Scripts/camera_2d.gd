extends Camera2D

@export var player: Node2D
@export var horizontal_smooth := 6.0

# Hollow Knight style horizontal look-ahead
@export var lookahead_distance := 60.0
@export var lookahead_smooth := 6.0

# Fixed vertical offset (camera stays above player)
@export var vertical_offset := -60.0

var lookahead := 0.0


func _process(delta):
	if player == null:
		return

	if not player.camera_should_follow:
		return

	# -----------------------------------------
	# Horizontal Look-Ahead (predictive camera)
	# -----------------------------------------
	var player_vel := Vector2.ZERO
	if "velocity" in player:
		player_vel = player.velocity

	if abs(player_vel.x) > 10:
		lookahead = lerp(lookahead, sign(player_vel.x) * lookahead_distance, delta * lookahead_smooth)
	else:
		lookahead = lerp(lookahead, 0.0, delta * lookahead_smooth)

	# -----------------------------------------
	# Target camera position
	# -----------------------------------------
	var target_x := player.global_position.x + lookahead
	var target_y := player.global_position.y + vertical_offset

	# -----------------------------------------
	# Horizontal-only movement
	# -----------------------------------------
	global_position.x = lerp(global_position.x, target_x, delta * horizontal_smooth)

	# Vertical stays fixed — no lerp
	global_position.y = target_y
