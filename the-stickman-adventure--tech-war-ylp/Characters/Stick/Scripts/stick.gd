extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var gpu_particles_2d_x_tuning: GPUParticles2D = $GPUParticles2D

var _gpu_mat: ParticleProcessMaterial = null

# Movement tuning
@export var move_speed: float = 220.0
@export var run_speed: float = 340.0
@export var crouch_speed: float = 70.0
@export var acceleration: float = 2600.0
@export var deceleration: float = 850.0
@export var ground_friction_multiplier: float = 2.0
@export var turn_reaccel_multiplier: float = 1.7

# Jump and gravity
@export var jump_force: float = 430.0
@export var gravity: float = 900.0
@export var max_fall_speed: float = 1050.0

# Jump settings
@export var coyote_time: float = 0.14
@export var jump_buffer_time: float = 0.14
@export var jump_cut_multiplier: float = 0.45
@export var enable_variable_jump: bool = false
@export var auto_jump: bool = false
@export var max_air_jumps: int = 1

# Turn and particles
@export var turn_slowdown: float = 0.015
@export var turn_blend: float = 0.35
@export var skid_particle_front_offset: float = 18.0
@export var normal_particle_offset: float = -12.0

# Respawn
@export var spawn_lock_duration: float = 0.75
@export var respawn_position: Vector2 = Vector2.ZERO

# Music
@export var music_node_path: NodePath = NodePath("../Music")
@export var music_fade_duration: float = 0.5

enum State {
	Idle,
	Walk,
	Run,
	Turn,
	Skid,
	Jump,
	Fall,
	Crouch,
	Land,
	DoubleJump,
	WalkStart,
	WalkEnd
}

var current_state: State = State.Idle

# Runtime movement state
var is_crouching: bool = false
var was_crouching: bool = false
var is_running: bool = false
var was_running: bool = false

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var air_jumps_used: int = 0

var input_dir: float = 0.0
var last_dir: int = 1

var was_on_floor: bool = false
var landing: bool = false

var turn_cooldown: float = 0.0
var camera_should_follow: bool = true

var movement_locked: bool = false
var movement_lock_timer: float = 0.0

var jump_cut_applied: bool = false
var jump_active: bool = false

# Animation state
var crouch_reversing: bool = false
var crouch_release_requested: bool = false
var turn_animation_finished: bool = false

const STICK_NORMAL = preload("uid://d168j72ka1a35")
const STICK_CROUCH = preload("uid://c5p4qg4p8701i")


func _reset_jump_state() -> void:
	jump_cut_applied = false
	jump_active = false


func _ready() -> void:
	if (
		gpu_particles_2d_x_tuning != null
		and gpu_particles_2d_x_tuning.process_material
		is ParticleProcessMaterial
	):
		_gpu_mat = (
			gpu_particles_2d_x_tuning.process_material
			as ParticleProcessMaterial
		)

	if animated_sprite_2d != null and animated_sprite_2d.sprite_frames != null:
		animated_sprite_2d.sprite_frames.set_animation_speed(
			&"turn",
			12.0
		)
		animated_sprite_2d.sprite_frames.set_animation_speed(
			&"single_jump",
			10.0
		)
		animated_sprite_2d.sprite_frames.set_animation_speed(
			&"double_jump",
			10.0
		)

	was_on_floor = is_on_floor()
	update_hitbox()
	start_respawn_lock(spawn_lock_duration)


func _physics_process(delta: float) -> void:
	turn_cooldown = max(turn_cooldown - delta, 0.0)

	if movement_locked:
		_handle_movement_lock(delta)
		return

	_update_input_state(delta)
	_handle_jump_input()

	if enable_variable_jump:
		_handle_variable_jump()

	var previous_velocity_x: float = velocity.x

	# Turn handling
	if current_state == State.Turn and turn_cooldown > 0.0:
		_apply_turn_movement(delta, previous_velocity_x)
		_apply_gravity(delta)
		_move_and_resolve_landing()
		_finalize_frame()
		return

	if current_state == State.Land:
		if abs(input_dir) > 0.0:
			current_state = State.Walk
		else:
			_apply_gravity(delta)
			_move_and_resolve_landing()
			_finalize_frame()
			return

	var turn_threshold: float = move_speed * 0.45

	var reversing: bool = (
		is_on_floor()
		and input_dir != 0.0
		and sign(input_dir) != sign(previous_velocity_x)
		and abs(previous_velocity_x) > turn_threshold
		and turn_cooldown <= 0.0
		and not is_crouching
	)

	if reversing:
		last_dir = int(sign(input_dir))
		turn_cooldown = 0.18
		_start_turn_animation()
		_apply_turn_movement(delta, previous_velocity_x)
		_apply_gravity(delta)
		_move_and_resolve_landing()
		_finalize_frame()
		return

	if is_on_floor():
		if is_crouching:
			current_state = State.Crouch
			velocity.x = move_toward(
				previous_velocity_x,
				input_dir * crouch_speed,
				acceleration * delta
			)
		elif is_running and input_dir != 0.0:
			current_state = State.Run
			velocity.x = move_toward(
				previous_velocity_x,
				input_dir * run_speed,
				acceleration * delta
			)
		elif input_dir != 0.0:
			current_state = State.Walk
			velocity.x = move_toward(
				previous_velocity_x,
				input_dir * move_speed,
				acceleration * delta
			)
		else:
			velocity.x = move_toward(
				previous_velocity_x,
				0.0,
				deceleration * delta * ground_friction_multiplier
			)

			if abs(previous_velocity_x) > move_speed * 0.4:
				current_state = State.Skid
			elif (
				current_state == State.Walk
				or current_state == State.WalkStart
				or current_state == State.Run
			):
				current_state = State.WalkEnd
			else:
				current_state = State.Idle
	else:
		if input_dir != 0.0:
			velocity.x = move_toward(
				previous_velocity_x,
				input_dir * move_speed,
				acceleration * delta * 0.5
			)
		else:
			velocity.x = move_toward(
				previous_velocity_x,
				0.0,
				deceleration * delta
			)

	_apply_gravity(delta)

	if not is_on_floor():
		if current_state == State.DoubleJump:
			pass
		elif current_state == State.Jump:
			if velocity.y >= 0.0:
				current_state = State.Fall
		elif velocity.y < 0.0:
			current_state = State.Jump
		else:
			current_state = State.Fall

	_move_and_resolve_landing()

	if input_dir != 0.0:
		last_dir = int(sign(input_dir))

	_finalize_frame()


func _update_input_state(delta: float) -> void:
	was_running = is_running
	was_crouching = is_crouching

	input_dir = (
		Input.get_action_strength(&"move_right")
		- Input.get_action_strength(&"move_left")
	)

	var crouch_input: bool = Input.is_action_pressed(&"move_down")
	var run_input: bool = Input.is_action_pressed(&"sprint")

	is_running = run_input and input_dir != 0.0
	is_crouching = crouch_input and is_on_floor()

	if was_crouching and not is_crouching:
		crouch_release_requested = true

	jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)

	if is_on_floor():
		coyote_timer = coyote_time
		air_jumps_used = 0
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

	if not is_on_floor():
		landing = false


func _handle_jump_input() -> void:
	var jump_pressed: bool = Input.is_action_just_pressed(&"move_up")
	var jump_held: bool = Input.is_action_pressed(&"move_up")

	if jump_pressed:
		jump_buffer_timer = jump_buffer_time

	if auto_jump and not jump_held:
		jump_buffer_timer = 0.0

	var manual_jump_requested: bool = jump_buffer_timer > 0.0
	var automatic_jump_requested: bool = (
		auto_jump and jump_held and is_on_floor()
	)

	if (
		coyote_timer > 0.0
		and (manual_jump_requested or automatic_jump_requested)
	):
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		air_jumps_used = 0
		_start_jump(jump_force, true)
		return

	if (
		jump_pressed
		and not is_on_floor()
		and air_jumps_used < max_air_jumps
	):
		air_jumps_used += 1
		_start_double_jump()


func _start_jump(force: float, allow_variable_cut: bool) -> void:
	velocity.y = -force
	jump_cut_applied = not allow_variable_cut
	jump_active = allow_variable_cut
	current_state = State.Jump

	if animated_sprite_2d != null:
		animated_sprite_2d.scale = Vector2(1.1, 0.9)

	if gpu_particles_2d_x_tuning != null:
		gpu_particles_2d_x_tuning.emitting = true


func _start_double_jump() -> void:
	velocity.y = -(jump_force * 0.92)
	jump_cut_applied = false
	jump_active = enable_variable_jump
	current_state = State.DoubleJump

	if animated_sprite_2d != null:
		animated_sprite_2d.stop()
		animated_sprite_2d.frame = 0
		animated_sprite_2d.play(&"double_jump")


func _handle_variable_jump() -> void:
	if not jump_active:
		return

	if jump_cut_applied:
		return

	if velocity.y >= 0.0:
		jump_active = false
		return

	if not Input.is_action_pressed(&"move_up"):
		velocity.y *= jump_cut_multiplier
		jump_cut_applied = true


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return

	velocity.y += gravity * delta
	velocity.y = min(velocity.y, max_fall_speed)


func _handle_movement_lock(delta: float) -> void:
	movement_lock_timer -= delta

	velocity.x = 0.0

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
		_reset_jump_state()

	_finalize_frame()


func _start_turn_animation() -> void:
	current_state = State.Turn
	turn_animation_finished = false
	if animated_sprite_2d != null:
		animated_sprite_2d.stop()
		animated_sprite_2d.frame = 0
		animated_sprite_2d.play(&"turn")


func _apply_turn_movement(
	delta: float,
	previous_velocity_x: float
) -> void:
	var turn_direction: float = float(last_dir)
	var turn_target_speed: float = turn_direction * move_speed

	var turn_brake_acceleration: float = acceleration * 2.5
	var turn_acceleration: float = acceleration * turn_reaccel_multiplier

	if (
		sign(previous_velocity_x) != sign(turn_direction)
		and abs(previous_velocity_x) > 5.0
	):
		velocity.x = move_toward(
			previous_velocity_x,
			0.0,
			turn_brake_acceleration * delta
		)
	else:
		velocity.x = move_toward(
			previous_velocity_x,
			turn_target_speed,
			turn_acceleration * delta
		)

	if (
		animated_sprite_2d != null
		and animated_sprite_2d.animation != &"turn"
		and not turn_animation_finished
	):
		animated_sprite_2d.play(&"turn")

	if gpu_particles_2d_x_tuning != null:
		gpu_particles_2d_x_tuning.emitting = true


func _move_and_resolve_landing() -> void:
	move_and_slide()
	handle_landing()


func handle_landing() -> void:
	var on_floor_now: bool = is_on_floor()

	if not was_on_floor and on_floor_now and velocity.y >= 0.0:
		if abs(velocity.x) < 10.0:
			current_state = State.Land
			landing = true
			if animated_sprite_2d != null:
				animated_sprite_2d.play(&"land")
		else:
			current_state = State.Walk

		_reset_jump_state()

	was_on_floor = on_floor_now
	update_hitbox()


func start_respawn_lock(duration: float = 0.75) -> void:
	movement_locked = true
	movement_lock_timer = duration

	velocity = Vector2.ZERO
	input_dir = 0.0
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	landing = false
	air_jumps_used = 0
	turn_cooldown = 0.0
	turn_animation_finished = false
	_reset_jump_state()

	current_state = State.Idle
	was_on_floor = is_on_floor()

	if gpu_particles_2d_x_tuning != null:
		gpu_particles_2d_x_tuning.emitting = false

	update_animation()


func update_hitbox() -> void:
	if collision_shape_2d == null:
		return

	if is_crouching:
		collision_shape_2d.shape = STICK_CROUCH
		collision_shape_2d.position = Vector2(0, 6)
	else:
		collision_shape_2d.shape = STICK_NORMAL
		collision_shape_2d.position = Vector2(0, 0)


func update_animation() -> void:
	if animated_sprite_2d == null:
		return

	if crouch_reversing:
		return

	if crouch_release_requested:
		crouch_release_requested = false
		crouch_reversing = true
		animated_sprite_2d.play_backwards(&"crouch")
		_update_facing()
		return

	var animation_name: StringName = &"idle"

	match current_state:
		State.Idle:
			animation_name = &"idle"
		State.Walk:
			animation_name = &"walk"
		State.Run:
			animation_name = &"run"
		State.Turn:
			animation_name = &"turn"
		State.Skid:
			animation_name = &"skid"
		State.Jump:
			animation_name = &"single_jump"
		State.DoubleJump:
			animation_name = &"double_jump"
		State.Fall:
			animation_name = &"fall"
		State.Crouch:
			animation_name = &"crouch"
		State.Land:
			animation_name = &"land"
		State.WalkStart:
			animation_name = &"start walk"
		State.WalkEnd:
			animation_name = &"end walk"

	if current_state == State.DoubleJump:
		if animated_sprite_2d.animation != &"double_jump":
			animated_sprite_2d.play(&"double_jump")
		_update_facing()
		return

	if animated_sprite_2d.animation != animation_name:
		animated_sprite_2d.play(animation_name)

	_update_facing()


func _update_facing() -> void:
	if animated_sprite_2d == null:
		return

	animated_sprite_2d.flip_h = last_dir < 0


func _finalize_frame() -> void:
	_update_dust_particles()
	update_animation()
	_update_facing()


func _update_dust_particles() -> void:
	if gpu_particles_2d_x_tuning == null:
		return

	var should_emit: bool = (
		is_on_floor()
		and (
			current_state == State.Run
			or current_state == State.Turn
			or current_state == State.Skid
		)
	)

	gpu_particles_2d_x_tuning.emitting = should_emit

	if not should_emit:
		gpu_particles_2d_x_tuning.position.x = 0.0
		return

	var facing_direction: float = float(last_dir)

	if (
		current_state == State.Skid
		or current_state == State.Turn
	):
		gpu_particles_2d_x_tuning.position.x = (
			facing_direction * skid_particle_front_offset
		)
	else:
		gpu_particles_2d_x_tuning.position.x = (
			facing_direction * normal_particle_offset
		)

	if _gpu_mat != null:
		_gpu_mat.direction = Vector3(-facing_direction, 0.0, 0.0)


func _on_animated_sprite_2d_animation_finished() -> void:
	if crouch_reversing:
		crouch_reversing = false

		if is_crouching:
			current_state = State.Crouch
		elif abs(input_dir) > 0.0:
			current_state = State.Walk
		else:
			current_state = State.Idle

		update_animation()
		return

	match animated_sprite_2d.animation:
		&"start walk":
			if is_running and input_dir != 0.0:
				current_state = State.Run
			elif input_dir != 0.0:
				current_state = State.Walk
			else:
				current_state = State.Idle

		&"end walk":
			if input_dir != 0.0:
				current_state = State.Walk
			else:
				current_state = State.Idle

		&"turn":
			turn_animation_finished = true

		&"land":
			if current_state == State.Land:
				landing = false
				current_state = State.Idle

		&"double_jump":
			if is_on_floor():
				current_state = State.Idle
			elif velocity.y < 0.0:
				current_state = State.Jump
			else:
				current_state = State.Fall

	update_animation()


func _on_fall_death_area_body_entered(body: Node2D) -> void:
	if body != self:
		return

	if movement_locked:
		return

	camera_should_follow = false

	var music: AudioStreamPlayer = (
		get_node_or_null(music_node_path)
		as AudioStreamPlayer
	)

	if music != null:
		var music_tween: Tween = create_tween()
		music_tween.tween_property(
			music,
			"volume_db",
			-80.0,
			music_fade_duration
		)

	var current_scene: Node = get_tree().current_scene
	var fade: Node = current_scene.get_node_or_null("Transitions")

	if fade != null and fade.has_method("fade_in_black"):
		fade.fade_in_black()

	await get_tree().create_timer(0.5).timeout

	global_position = respawn_position
	velocity = Vector2.ZERO
	last_dir = 1
	if animated_sprite_2d != null:
		animated_sprite_2d.flip_h = false

	start_respawn_lock(spawn_lock_duration)

	camera_should_follow = true

	if music != null:
		var restore_tween: Tween = create_tween()
		restore_tween.tween_property(
			music,
			"volume_db",
			0.0,
			music_fade_duration
		)

	if fade != null and fade.has_method("fade_out_black"):
		fade.fade_out_black()


func _on_music_finished() -> void:
	var music: AudioStreamPlayer = (
		get_node_or_null(music_node_path)
		as AudioStreamPlayer
	)

	if music != null:
		music.play()
