extends CharacterBody2D

# Movement
@export var move_speed: float = 220.0
@export var run_speed: float = 340.0
@export var acceleration: float = 2600.0
@export var deceleration: float = 850.0
@export var gravity: float = 900.0
@export var jump_force: float = 430.0
@export var max_fall_speed: float = 1050.0

# Jump timing
@export var coyote_time: float = 0.14
@export var jump_buffer_time: float = 0.14

# Gap detection
@export var gap_check_distance: float = 36.0
@export var gap_check_depth: float = 100.0

# Follow settings (player-like)
@export var follow_min_distance: float = 60.0
@export var follow_max_distance: float = 260.0
@export var follow_run_distance: float = 340.0
@export var follow_smoothness: float = 8.0

# Respawn
@export var spawn_position: Vector2 = Vector2.ZERO
var respawn_cooldown: float = 0.0

# Input
var input_dir: float = 0.0
var want_run: bool = false
var want_jump_pressed: bool = false
var want_jump_held: bool = false

# Jump timers
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

# State
var movement_locked: bool = false
var on_rail: bool = false

# Player reference
@export var player: CharacterBody2D = null

# Facing direction
var facing_dir: int = 1

# AI personality

var random_move_timer := 0.0
var random_move_dir := 0.0

var double_jump_used := false

var teabag_timer := 0.0
var teabag_active := false


var air_jumps_used: int = 0

@export var random_move_chance: float = 0.20
@export var random_jump_chance: float = 0.04
@export var random_double_jump_chance: float = 0.10
@export var random_teabag_chance: float = 0.002

@export var max_air_jumps: int = 1

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D2


func _ready() -> void:
	add_to_group("ai")
	
	if spawn_position == Vector2.ZERO:
		spawn_position = global_position
	player = get_tree().root.find_child("Player", true, false)
	
	print(get_tree().get_nodes_in_group("player"))


func _physics_process(delta: float) -> void:
	_find_player()
	
	respawn_cooldown = maxf(respawn_cooldown - delta, 0.0)

	if on_rail:
		move_and_slide()
		return

	if movement_locked:
		_apply_air_gravity(delta)
		move_and_slide()
		return

	var move_dir: float = 0.0

	if player != null:
		var dist: float = absf(
			player.global_position.x - global_position.x
		)

		if dist > follow_run_distance:
			want_run = true
			move_dir = signf(
				player.global_position.x - global_position.x
			)

		elif dist > follow_min_distance:
			want_run = false
			move_dir = signf(
				player.global_position.x - global_position.x
			)

		else:
			want_run = false
			move_dir = 0.0

	else:
		want_run = false
		move_dir = 0.0

	random_move_timer -= delta

	if random_move_timer <= 0.0:
		random_move_timer = randf_range(1.0, 3.0)

		if randf() < random_move_chance:
			random_move_dir = randf_range(-1.0, 1.0)
		else:
			random_move_dir = 0.0

	move_dir = clampf(
		move_dir + random_move_dir * 0.5,
		-1.0,
		1.0
	)

	input_dir = move_toward(
		input_dir,
		move_dir,
		delta * follow_smoothness
	)

	# random teabag
	if is_on_floor():
		if not teabag_active:
			if randf() < random_teabag_chance:
				teabag_active = true
				teabag_timer = randf_range(0.3, 1.5)

		else:
			teabag_timer -= delta

			if teabag_timer <= 0.0:
				teabag_active = false

	var gap_ahead: bool = (
		is_on_floor()
		and input_dir != 0.0
		and not _has_ground_in_front(input_dir)
	)

	apply_input(
		input_dir,
		want_run,
		gap_ahead,
		false
	)

	# random jump
	if is_on_floor():
		if randf() < random_jump_chance * delta:
			want_jump_pressed = true

	# random double jump
	if (
		not is_on_floor()
		and air_jumps_used < max_air_jumps
		and randf() < random_double_jump_chance * delta
	):
		want_jump_pressed = true

	_update_jump_timers(delta)

	_apply_horizontal_motion(delta)

	_apply_air_gravity(delta)

	move_and_slide()

	if input_dir != 0.0:
		facing_dir = int(signf(input_dir))

	want_jump_pressed = false

	_update_animation()

	if (
		respawn_cooldown <= 0.0
		and global_position.y > spawn_position.y + 800.0
	):
		respawn()


func _update_jump_timers(delta: float) -> void:
	coyote_timer = maxf(
		coyote_timer - delta,
		0.0
	)

	jump_buffer_timer = maxf(
		jump_buffer_timer - delta,
		0.0
	)

	if want_jump_pressed:
		jump_buffer_timer = jump_buffer_time

	if is_on_floor():
		coyote_timer = coyote_time
		air_jumps_used = 0

	if (
		coyote_timer > 0.0
		and jump_buffer_timer > 0.0
	):
		velocity.y = -jump_force

		jump_buffer_timer = 0.0
		coyote_timer = 0.0

	elif (
		want_jump_pressed
		and not is_on_floor()
		and air_jumps_used < max_air_jumps
	):
		velocity.y = -(jump_force * 0.9)

		air_jumps_used += 1

		jump_buffer_timer = 0.0

func _apply_horizontal_motion(delta: float) -> void:
	var target_speed := (run_speed if want_run else move_speed) * input_dir

	if abs(target_speed) > abs(velocity.x):
		velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, target_speed, deceleration * delta)


func _apply_air_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0


func apply_input(dir: float, run: bool, jump_pressed: bool, jump_held: bool) -> void:
	input_dir = clamp(dir, -1.0, 1.0)
	want_run = run

	if jump_pressed:
		want_jump_pressed = true

	want_jump_held = jump_held


func set_on_rail(state: bool) -> void:
	on_rail = state


func _update_animation() -> void:
	if anim == null:
		return

	if not is_on_floor():
		anim.play("single_jump")

	elif teabag_active:
		anim.play("crouch")

	elif absf(velocity.x) < 1.0:
		anim.play("idle")

	elif absf(velocity.x) > move_speed * 0.9:
		anim.play("run")

	else:
		anim.play("walk")

	anim.flip_h = facing_dir < 0


func _has_ground_in_front(direction: float) -> bool:
	if direction == 0.0:
		return true

	var world := get_world_2d()
	if world == null:
		return true

	var ray_start := global_position + Vector2(direction * gap_check_distance, 0.0)
	var ray_end := ray_start + Vector2(0.0, gap_check_depth)

	var query := PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.exclude = [self]
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result := world.direct_space_state.intersect_ray(query)
	return not result.is_empty()


func respawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	respawn_cooldown = 1.0

func _find_player() -> void:
	if is_instance_valid(player):
		return

	player = get_tree().get_first_node_in_group(
		"player"
	) as CharacterBody2D
	
	if player:
		print("PLAYER FOUND")
	else:
		print("NO PLAYER")
		
func _on_animated_sprite_2d_2_animation_finished() -> void:
	pass # Replace with function body.
