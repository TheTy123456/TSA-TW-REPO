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

# FOLLOW SETTINGS (player-like)
@export var follow_min_distance: float = 60.0     # stop when close
@export var follow_max_distance: float = 260.0    # walk when far
@export var follow_run_distance: float = 340.0    # run when very far
@export var follow_smoothness: float = 8.0        # smooth movement

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
var player: CharacterBody2D = null

# Facing direction
var facing_dir: int = 1

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready():
	if spawn_position == Vector2.ZERO:
		spawn_position = global_position

	player = get_tree().root.find_child("Player", true, false)


func _physics_process(delta: float) -> void:
	respawn_cooldown = max(respawn_cooldown - delta, 0.0)

	if on_rail:
		move_and_slide()
		return

	if movement_locked:
		_apply_air_gravity(delta)
		move_and_slide()
		return

	var move_dir: float = 0.0

	# -------------------------
	# PLAYER-LIKE FOLLOW LOGIC
	# -------------------------
	if player != null:
		var dist: float = abs(player.global_position.x - global_position.x)

		# AI is very far → RUN
		if dist > follow_run_distance:
			want_run = true
			move_dir = sign(player.global_position.x - global_position.x)

		# AI is moderately far → WALK
		elif dist > follow_min_distance:
			want_run = false
			move_dir = sign(player.global_position.x - global_position.x)

		# AI is close → STOP
		else:
			want_run = false
			move_dir = 0.0

	else:
		move_dir = 0.0
		want_run = false

	# Smooth movement
	move_dir = lerp(input_dir, move_dir, delta * follow_smoothness)

	# -------------------------
	# GAP DETECTION
	# -------------------------
	var gap_ahead: bool = false

	if is_on_floor() and move_dir != 0.0:
		gap_ahead = not _has_ground_in_front(move_dir)

	var should_jump: bool = gap_ahead

	apply_input(move_dir, want_run, should_jump, false)

	coyote_timer = max(coyote_timer - delta, 0.0)
	jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)

	if want_jump_pressed:
		jump_buffer_timer = jump_buffer_time

	var target_speed: float = (run_speed if want_run else move_speed) * input_dir

	if abs(target_speed) > abs(velocity.x):
		velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, target_speed, deceleration * delta)

	if is_on_floor():
		coyote_timer = coyote_time

	if coyote_timer > 0.0 and jump_buffer_timer > 0.0:
		velocity.y = -jump_force
		jump_buffer_timer = 0.0
		coyote_timer = 0.0

	_apply_air_gravity(delta)
	move_and_slide()

	if input_dir != 0.0:
		facing_dir = int(sign(input_dir))

	want_jump_pressed = false
	_update_animation()

	if respawn_cooldown == 0.0 and global_position.y > spawn_position.y + 800:
		respawn()


func _apply_air_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)
	else:
		if velocity.y > 0:
			velocity.y = 0


func apply_input(dir: float, run: bool, jump_pressed: bool, jump_held: bool) -> void:
	input_dir = clamp(dir, -1.0, 1.0)
	want_run = run

	if jump_pressed:
		want_jump_pressed = true

	want_jump_held = jump_held


func set_on_rail(state: bool) -> void:
	on_rail = state


func _update_animation() -> void:
	if not anim:
		return

	if not is_on_floor():
		anim.play("single_jump")
	elif abs(velocity.x) < 1:
		anim.play("idle")
	elif abs(velocity.x) > move_speed * 0.9:
		anim.play("run")
	else:
		anim.play("walk")

	anim.flip_h = facing_dir < 0


func _has_ground_in_front(direction: float) -> bool:
	var ray_start: Vector2 = global_position + Vector2(direction * gap_check_distance, 0)
	var ray_end: Vector2 = ray_start + Vector2(0, gap_check_depth)

	var result := get_world_2d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	)

	return result.size() > 0


func respawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	respawn_cooldown = 1.0
