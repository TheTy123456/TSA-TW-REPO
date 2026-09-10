extends Camera2D

@export var player: Node2D
@export var horizontal_smooth = 6.0
@export var vertical_smooth = 25.0
@export var fall_delay = 0.0
@export var lookahead_distance = 40.0

var fall_timer = 0.0
var look_dir = 0.0

func _process(delta):
	if player == null:
		return
	var target_pos = player.global_position
	
	var raw_dir = sign(player.velocity.x)
	if abs(player.velocity.x) < 10:
		raw_dir = 0
	look_dir = lerp(look_dir, float(sign(player.velocity.x)), delta * 10.0)
	target_pos.x += look_dir * lookahead_distance
	
	global_position.x = lerp(global_position.x, target_pos.x, delta * horizontal_smooth)
	global_position.y = lerp(global_position.y, target_pos.y, delta * vertical_smooth)
