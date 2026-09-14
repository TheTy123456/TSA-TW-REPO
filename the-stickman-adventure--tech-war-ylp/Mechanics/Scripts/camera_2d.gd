extends Camera2D

@export var player: Node2D
@export var horizontal_smooth = 6.0
@export var vertical_smooth = 25.0
@export var fall_vertical_smoothing = 30.0
@export var fall_delay = 0.0
@export var lookahead_distance = 40.0

var fall_timer = 0.0
var look_dir = 0.0

func _process(delta):
	if player == null:
		return
	var target_pos = player.global_position
	
	if not player.is_on_floor():
		fall_timer += delta
	else:
		fall_timer = 0.0
		
	var h_speed = horizontal_smooth
	var v_speed = vertical_smooth
	
	if fall_timer > fall_delay:
		v_speed = fall_vertical_smoothing
		
	global_position.x = lerp(global_position.x, target_pos.x, delta * h_speed)
	global_position.y = lerp(global_position.y, target_pos.y, delta * v_speed)
