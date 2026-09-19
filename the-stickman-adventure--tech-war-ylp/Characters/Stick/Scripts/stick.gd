extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var gpu_particles_2d: GPUParticles2D = $GPUParticles2D

var _gpu_mat: ParticleProcessMaterial = null

# Basic movement
@export var move_speed: float = 220.0
@export var acceleration: float = 2600.0
@export var deceleration: float = 850.0
@export var turn_slowdown: float = 0.015
@export var turn_blend: float = 0.35

# Jump and gravity
@export var jump_force: float = 400.0
@export var gravity: float = 780.0
@export var max_fall_speed: float = 1050.0

# Jumping / coyote / buffer
@export var coyote_time: float = 0.14
@export var jump_buffer_time: float = 0.14
@export var jump_cut_multiplier: float = 0.55
@export var enable_variable_jump: bool = true
@export var auto_jump: bool = true

# Movement tuning
@export var ground_friction_multiplier: float = 2.0
@export var turn_reaccel_multiplier: float = 1.7
@export var turn_snap_speed_fraction: float = 0.7
@export var run_speed: float = 340.0
@export var respawn_position: Vector2 = Vector2.ZERO
@export var crouch_speed: float = 70.0

# Particles and spawn
@export var skid_particle_front_offset: float = 18.0
@export var normal_particle_offset: float = -12.0
@export var spawn_lock_duration: float = 0.75

# State
enum State {
	Idle,
	Walk,
	Run,
	Turn,
	Skid,
	Jump,
	Fall,
	Crouch,
	Land
}

var current_state: State = State.Idle

# Runtime variables
var is_crouching: bool = false
var is_running: bool = false
var was_running: bool = false

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

var input_dir: float = 0.0
var last_dir: int = 1

var was_on_floor: bool = false
var landing: bool = false

var turn_cooldown: float = 0.0
var camera_should_follow: bool = true

var movement_locked: bool = false
var movement_lock_timer: float = 0.0

const STICK_NORMAL = preload("uid://d168j72ka1a35")
const STICK_CROUCH = preload("uid://c5p4qg4p8701i")


func _ready() -> void:
	if gpu_particles_2d and gpu_particles_2d.process_material is ParticleProcessMaterial:
		_gpu_mat = gpu_particles_2d.process_material as ParticleProcessMaterial

	was_on_floor = is_on_floor()

	update_hitbox()
	start_respawn_lock(spawn_lock_duration)


func _physics_process(delta: float) -> void:
	turn_cooldown = max(turn_cooldown - delta, 0.0)

	if movement_locked:
		_handle_movement_lock(delta)
		return

	_update_input_state(delta)

	var prev_velocity_x: float = velocity.x

	# Continue an active turn.
	if current_state == State.Turn and turn_cooldown > 0.0:
		_apply_turn_movement(delta, prev_velocity_x)
		_try_jump()
		_move_and_resolve_landing()
		_finalize_frame()
		return

	# Handle the landing animation state.
	if current_state == State.Land:
		if _try_jump_from_land():
			return

		if abs(input_dir) > 0.0:
			current_state = State.Walk
		else:
			_move_and_resolve_landing()
			_finalize_frame()
			return

	# Detect a direction reversal.
	var turn_threshold: float = move_speed * 0.45

	var reversing: bool = (
		is_on_floor()
		and input_dir != 0.0
		and sign(input_dir) != sign(prev_velocity_x)
		and abs(prev_velocity_x) > turn_threshold
		and turn_cooldown <= 0.0
		and not is_crouching
	)

	if reversing:
		last_dir = int(sign(input_dir))
		turn_cooldown = 0.18

		# Start the turn animation immediately.
		_start_turn_animation()

		_apply_turn_movement(delta, prev_velocity_x)
		_move_and_resolve_landing()
		_finalize_frame()
		return

	# Main horizontal movement.
	if is_crouching:
		current_state = State.Crouch
		velocity.x = move_toward(
			prev_velocity_x,
			input_dir * crouch_speed,
			acceleration * delta
		)

	elif is_running and input_dir != 0.0:
		current_state = State.Run
		velocity.x = move_toward(
			prev_velocity_x,
			input_dir * run_speed,
			acceleration * delta
		)

	elif input_dir != 0.0:
		current_state = State.Walk
		velocity.x = move_toward(
			prev_velocity_x,
			input_dir * move_speed,
			acceleration * delta
		)

	else:
		if is_on_floor():
			velocity.x = move_toward(
				prev_velocity_x,
				0.0,
				deceleration * delta * ground_friction_multiplier
			)

			if abs(prev_velocity_x) > move_speed * 0.4:
				current_state = State.Skid
			else:
				current_state = State.Idle
		else:
			velocity.x = move_toward(
				prev_velocity_x,
				0.0,
				deceleration * delta
			)

	# Apply gravity.
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)

		current_state = State.Jump if velocity.y < 0.0 else State.Fall

	# Cut the jump only once when the button is released.
	if (
		enable_variable_jump
		and velocity.y < 0.0
		and Input.is_action_just_released("move_up")
	):
		velocity.y *= jump_cut_multiplier

	# Try to jump.
	_try_jump()

	_move_and_resolve_landing()

	# Update direction after normal movement.
	if input_dir != 0.0:
		last_dir = int(sign(input_dir))

	_finalize_frame()


func _update_input_state(delta: float) -> void:
	was_running = is_running

	input_dir = (
		Input.get_action_strength("move_right")
		- Input.get_action_strength("move_left")
	)

	var crouch_input: bool = Input.is_action_pressed("move_down")
	var shift_run: bool = Input.is_action_pressed("sprint")

	is_running = shift_run and input_dir != 0.0

	if crouch_input and is_on_floor():
		is_crouching = true
	else:
		is_crouching = false

	if Input.is_action_just_pressed("move_up"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)

	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

	if not is_on_floor():
		landing = false


func _handle_movement_lock(delta: float) -> void:
	movement_lock_timer -= delta

	# Prevent horizontal movement while locked.
	velocity.x = 0.0

	# Allow gravity if the spawn point is above the floor.
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)
	else:
		velocity.y = 0.0

	move_and_slide()

	was_on_floor = is_on_floor()
	update_hitbox()

	if movement_lock_timer <= 0.0:
		movement_locked = false
		velocity = Vector2.ZERO
		current_state = State.Idle

	_finalize_frame()


func start_respawn_lock(duration: float = 0.75) -> void:
	movement_locked = true
	movement_lock_timer = duration

	velocity = Vector2.ZERO
	input_dir = 0.0
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	landing = false

	current_state = State.Idle
	was_on_floor = is_on_floor()

	if gpu_particles_2d:
		gpu_particles_2d.emitting = false

	update_animation()


func _try_jump() -> bool:
	var wants_to_jump: bool = (
		jump_buffer_timer > 0.0
		or (auto_jump and Input.is_action_pressed("move_up"))
	)

	if wants_to_jump and coyote_timer > 0.0:
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		velocity.y = -jump_force
		current_state = State.Jump
		return true

	return false


func _try_jump_from_land() -> bool:
	var wants_to_jump: bool = (
		jump_buffer_timer > 0.0
		or (auto_jump and Input.is_action_pressed("move_up"))
	)

	if wants_to_jump and coyote_timer > 0.0:
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		velocity.y = -jump_force
		current_state = State.Jump

		move_and_slide()
		update_animation()

		return true

	return false


func _move_and_resolve_landing() -> void:
	move_and_slide()
	handle_landing()


func _start_turn_animation() -> void:
	current_state = State.Turn

	# Restart from the first turn frame immediately.
	animated_sprite_2d.stop()
	animated_sprite_2d.frame = 0
	animated_sprite_2d.play(&"turn")


func _apply_turn_movement(delta: float, prev_velocity_x: float) -> void:
	var turn_direction: float = float(last_dir)
	var turn_target_speed: float = turn_direction * move_speed

	var turn_brake_acceleration: float = acceleration * 2.5
	var turn_acceleration: float = acceleration * turn_reaccel_multiplier

	# Brake the old velocity first.
	if sign(prev_velocity_x) != sign(turn_direction) and abs(prev_velocity_x) > 5.0:
		velocity.x = move_toward(
			prev_velocity_x,
			0.0,
			turn_brake_acceleration * delta
		)
	else:
		velocity.x = move_toward(
			prev_velocity_x,
			turn_target_speed,
			turn_acceleration * delta
		)

	current_state = State.Turn

	# Do not restart the animation every physics frame.
	if animated_sprite_2d.animation != &"turn":
		animated_sprite_2d.play(&"turn")

	if gpu_particles_2d:
		gpu_particles_2d.emitting = true


func handle_landing() -> void:
	var on_floor_now: bool = is_on_floor()

	if not was_on_floor and on_floor_now and velocity.y >= 0.0:
		if abs(velocity.x) < 10.0:
			current_state = State.Land
			landing = true
			animated_sprite_2d.play(&"land")
		else:
			current_state = State.Walk

	was_on_floor = on_floor_now
	update_hitbox()


func update_hitbox() -> void:
	if is_crouching:
		collision_shape_2d.shape = STICK_CROUCH
		collision_shape_2d.position = Vector2(0, 8)
	else:
		collision_shape_2d.shape = STICK_NORMAL
		collision_shape_2d.position = Vector2(0, 3)


func update_animation() -> void:
	if current_state == State.Land:
		return

	var animation_name: StringName = &"idle"

	match current_state:
		State.Idle:
			animation_name = &"idle"
		State.Walk:
			animation_name = &"walk"
		State.Run:
			animation_name = &"run"
		State.Crouch:
			animation_name = &"crouch"
		State.Turn:
			animation_name = &"turn"
		State.Skid:
			animation_name = &"skid"
		State.Jump:
			animation_name = &"jump"
		State.Fall:
			animation_name = &"fall"

	# Only change animations when the state animation changes.
	if animated_sprite_2d.animation != animation_name:
		animated_sprite_2d.play(animation_name)

	_update_facing()


func _finalize_frame() -> void:
	_update_dust_particles()
	update_animation()
	_update_facing()


func _update_facing() -> void:
	animated_sprite_2d.flip_h = last_dir < 0


func _update_dust_particles() -> void:
	if not gpu_particles_2d:
		return

	var should_emit: bool = (
		is_on_floor()
		and (
			current_state == State.Run
			or current_state == State.Turn
			or current_state == State.Skid
		)
	)

	gpu_particles_2d.emitting = should_emit

	if not should_emit:
		gpu_particles_2d.position.x = 0.0
		return

	var facing_direction: float = float(last_dir)

	if current_state == State.Skid or current_state == State.Turn:
		# Turn and skid dust appears in front of the player.
		gpu_particles_2d.position.x = (
			facing_direction * skid_particle_front_offset
		)
	else:
		# Running dust appears behind the player.
		gpu_particles_2d.position.x = (
			facing_direction * normal_particle_offset
		)

	if _gpu_mat:
		# Dust travels backward relative to the player.
		_gpu_mat.direction = Vector3(-facing_direction, 0.0, 0.0)


func _on_fall_death_area_body_entered(body: Node2D) -> void:
	if body != self:
		return

	camera_should_follow = false

	var fade = get_tree().current_scene.get_node("Transitions")
	fade.fade_in_black()

	await get_tree().create_timer(0.5).timeout

	global_position = respawn_position
	last_dir = 1
	animated_sprite_2d.flip_h = false

	start_respawn_lock(spawn_lock_duration)

	camera_should_follow = true
	fade.fade_out_black()


func _on_animated_sprite_2d_animation_finished() -> void:
	if current_state == State.Land:
		landing = false
		current_state = State.Idle
		update_animation()
