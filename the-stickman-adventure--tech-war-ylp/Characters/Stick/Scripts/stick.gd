extends CharacterBody2D

# Scene references
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var run_turn_slid_particles: GPUParticles2D = $Run_Turn_SlidParticles
@onready var wall_check_left: RayCast2D = $WallCheckLeft
@onready var wall_check_right: RayCast2D = $WallCheckRight
@onready var ledge_shape_cast: ShapeCast2D = $LedgeShapeCast
@onready var head_clearance_shape_cast: ShapeCast2D = $HeadClearanceShapeCast

var _gpu_mat: ParticleProcessMaterial = null

# Movement tuning
@export var move_speed: float = 180.0
@export var run_speed: float = 270.0
@export var crouch_speed: float = 70.0
@export var acceleration: float = 2600.0
@export var deceleration: float = 850.0
@export var ground_friction_multiplier: float = 2.0
@export var turn_reaccel_multiplier: float = 1.7

# Jump and gravity
@export var jump_force: float = 400.0
@export var gravity: float = 950.0
@export var max_fall_speed: float = 1200.0
@export var fast_fall_multiplier: float = 1.6

# Jump settings
@export var coyote_time: float = 0.11
@export var jump_buffer_time: float = 0.11
@export var jump_cut_multiplier: float = 0.5
@export var enable_variable_jump: bool = true
@export var auto_jump: bool = false
@export var max_air_jumps: int = 1

# Jump apex hang
@export var apex_hang_threshold: float = 80.0
@export var apex_gravity_multiplier: float = 0.62

# Momentum and air control
@export var momentum_jump_boost: float = 0.12
@export var momentum_max_boost: float = 1.3
@export var air_acceleration: float = 2200.0
@export var air_acceleration_multiplier: float = 0.9
@export var air_deceleration: float = 900.0
@export var air_deceleration_multiplier: float = 0.45
@export var max_air_speed: float = 300.0

# Turn and particles
@export var turn_slowdown: float = 0.015
@export var turn_blend: float = 0.35
@export var skid_particle_front_offset: float = 18.0
@export var normal_particle_offset: float = -12.0

# Respawn
@export var spawn_lock_duration: float = 0.75
@export var player1_respawn_position: Vector2 = Vector2.ZERO
@export var player2_respawn_position: Vector2 = Vector2.ZERO
@export var rail_height_offset: float = -20.0

# Music
@export var music_node_path: NodePath = NodePath("../Music")
@export var music_fade_duration: float = 0.5

# Wall movement
@export var wall_slide_gravity_multiplier: float = 0.4
@export var wall_climb_speed: float = 120.0
@export var short_wall_slide_speed: float = 80.0
@export var min_wall_contact_time: float = 0.1

# Kept for existing scene Inspector overrides.
# This controller does not use wall-jump behavior.
@export var wall_jump_force: float = 450.0
@export var wall_jump_horizontal_force: float = 300.0
@export var wall_jump_buffer_time: float = 0.12
@export var wall_jump_lockout_time: float = 0.3

var is_on_wall: bool = false
var wall_direction: int = 0
var wall_contact_timer: float = 0.0
var is_climbing_wall: bool = false
var wall_is_short: bool = false

# Ledge detection and mantle
@export_group("Ledge mantle")
@export var ledge_forward_distance: float = 12.0
@export var ledge_side_offset: float = 8.0
@export var ledge_head_offset: float = -10.0
@export var ledge_probe_up: float = 16.0
@export var ledge_probe_down: float = 18.0
@export var ledge_pause_duration: float = 0.10
@export var ledge_mantle_duration: float = 0.20
@export var ledge_outward_offset: float = 4.0

var ledge_direction: int = 0
var ledge_surface_position: Vector2 = Vector2.ZERO
var ledge_mantling: bool = false
var ledge_mantle_failed_on_wall: bool = false
var ledge_mantle_timer: float = 0.0
var ledge_mantle_start: Vector2 = Vector2.ZERO
var ledge_mantle_control_1: Vector2 = Vector2.ZERO
var ledge_mantle_control_2: Vector2 = Vector2.ZERO
var ledge_mantle_end: Vector2 = Vector2.ZERO
var ledge_retry_timer: float = 0.0
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
	Land,
	DoubleJump,
	WalkStart,
	WalkEnd
}

var current_state: State = State.Idle

# Movement state
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
var jump_anim_hold: float = 0.1

# Animation state
var crouch_reversing: bool = false
var crouch_release_requested: bool = false
var turn_animation_finished: bool = false
var landing_squash_timer: float = 0.0

# Rail state
var is_on_rail: bool = false

# Idle animation state
var idle_timer: float = 0.0
var idle_variant_playing: bool = false

const STICK_NORMAL = preload("uid://d168j72ka1a35")
const STICK_CROUCH = preload("uid://c5p4qg4p8701i")


func _reset_jump_state() -> void:
	jump_cut_applied = false
	jump_active = false


func _ready() -> void:
	add_to_group("player")
	if (
		run_turn_slid_particles != null
		and run_turn_slid_particles.process_material is ParticleProcessMaterial
	):
		_gpu_mat = run_turn_slid_particles.process_material as ParticleProcessMaterial

	if animated_sprite_2d != null and animated_sprite_2d.sprite_frames != null:
		animated_sprite_2d.sprite_frames.set_animation_speed(&"turn", 12.0)
		animated_sprite_2d.sprite_frames.set_animation_speed(&"single_jump", 6.0)
		animated_sprite_2d.sprite_frames.set_animation_speed(&"double_jump", 10.0)

	was_on_floor = is_on_floor()
	update_hitbox()
	start_respawn_lock(spawn_lock_duration)


func _physics_process(delta: float) -> void:
	# Rail.gd controls the rider's global position and rotation.
	if is_on_rail:
		_handle_rail_input()
		_finalize_frame()
		return

	if ledge_mantling:
		_update_ledge_mantle(delta)
		_finalize_frame()
		return

	if current_state == State.Idle:
		idle_timer += delta
	else:
		idle_timer = 0.0
		idle_variant_playing = false
		
	ledge_retry_timer = maxf(ledge_retry_timer - delta, 0.0)
	
	turn_cooldown = maxf(turn_cooldown - delta, 0.0)

	if landing_squash_timer > 0.0:
		landing_squash_timer = maxf(landing_squash_timer - delta, 0.0)

	if movement_locked:
		_handle_movement_lock(delta)
		return

	_update_input_state(delta)
	_check_wall_contact(delta)

	if ledge_mantling:
		_update_ledge_mantle(delta)
		_finalize_frame()
		return

	# W/S are wall-climb controls while touching a wall.
	# Do not let W trigger a normal jump or double jump there.
	if is_on_wall:
		jump_buffer_timer = 0.0
		jump_active = false
	else:
		_handle_jump_input()

	if enable_variable_jump:
		_handle_variable_jump()

	var previous_velocity_x: float = velocity.x

	if current_state == State.Turn and turn_cooldown > 0.0:
		_apply_turn_movement(delta, previous_velocity_x)
		_apply_gravity(delta)
		_move_and_resolve_landing()
		_finalize_frame()
		return

	if current_state == State.Land:
		if absf(input_dir) > 0.0:
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
		and absf(previous_velocity_x) > turn_threshold
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
			if current_state == State.Idle:
				current_state = State.WalkStart
			elif (
				current_state != State.WalkStart
				and current_state != State.Walk
			):
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
			if current_state == State.Walk:
				current_state = State.WalkEnd
				
			elif current_state == State.Run \
				and absf(previous_velocity_x) > run_speed * 0.5:
				current_state = State.Skid
	else:
		_apply_air_movement(delta, previous_velocity_x)

	if is_on_wall:
		_handle_wall_climb(delta)
	else:
		_apply_gravity(delta)

	if not is_on_floor():
		if current_state == State.DoubleJump:
			pass
		elif current_state == State.Jump:
			jump_anim_hold -= delta
			if jump_anim_hold <= 0.0 and velocity.y >= 0.0:
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
		Input.get_action_strength("player1_right")
		- Input.get_action_strength("player1_left")
	)

	var crouch_input: bool = Input.is_action_pressed("player1_down")
	var run_input: bool = Input.is_action_pressed("player1_sprint")

	is_running = run_input and input_dir != 0.0
	is_crouching = crouch_input and is_on_floor()

	if was_crouching and not is_crouching:
		crouch_release_requested = false

	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

	if is_on_floor():
		coyote_timer = coyote_time
		air_jumps_used = 0
		ledge_mantle_failed_on_wall = false
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)

	if not is_on_floor():
		landing = false


func _handle_jump_input() -> void:
	if is_on_wall:
		jump_buffer_timer = 0.0
		return

	var jump_pressed: bool = Input.is_action_just_pressed("player1_up")
	var jump_held: bool = Input.is_action_pressed("player1_up")

	if jump_pressed:
		jump_buffer_timer = jump_buffer_time

	if auto_jump and jump_held and is_on_floor():
		jump_buffer_timer = jump_buffer_time

	var can_jump: bool = (
		coyote_timer > 0.0
		and jump_buffer_timer > 0.0
	)

	if can_jump:
		_start_jump()
		return

	if (
		jump_pressed
		and not is_on_floor()
		and air_jumps_used < max_air_jumps
	):
		air_jumps_used += 1
		_start_double_jump()


func _start_jump() -> void:
	var momentum_bonus: float = absf(velocity.x) * momentum_jump_boost
	var boosted_force: float = minf(
		jump_force + momentum_bonus,
		jump_force * momentum_max_boost
	)

	velocity.y = -boosted_force
	jump_anim_hold = 0.1
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	air_jumps_used = 0
	jump_active = true
	jump_cut_applied = false
	current_state = State.Jump

	if run_turn_slid_particles != null:
		run_turn_slid_particles.emitting = true


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
	if not jump_active or jump_cut_applied:
		return

	if velocity.y >= 0.0:
		jump_active = false
		return

	if not Input.is_action_pressed("player1_up"):
		velocity.y *= jump_cut_multiplier
		jump_cut_applied = true


func _apply_air_movement(delta: float, previous_velocity_x: float) -> void:
	if input_dir != 0.0:
		velocity.x = move_toward(
			previous_velocity_x,
			input_dir * max_air_speed,
			air_acceleration * air_acceleration_multiplier * delta
		)
	else:
		velocity.x = move_toward(
			previous_velocity_x,
			0.0,
			air_deceleration * air_deceleration_multiplier * delta
		)


func _apply_gravity(delta: float) -> void:
	if is_climbing_wall or is_on_floor():
		return

	var gravity_amount: float = gravity

	if absf(velocity.y) < apex_hang_threshold:
		gravity_amount *= apex_gravity_multiplier

	if Input.is_action_pressed("player1_down") and velocity.y > 0.0:
		gravity_amount *= fast_fall_multiplier

	velocity.y += gravity_amount * delta
	velocity.y = minf(velocity.y, max_fall_speed)


func _handle_movement_lock(delta: float) -> void:
	movement_lock_timer -= delta
	velocity.x = 0.0

	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = minf(velocity.y, max_fall_speed)
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


func _apply_turn_movement(delta: float, previous_velocity_x: float) -> void:
	var turn_direction: float = float(last_dir)
	var turn_target_speed: float = turn_direction * move_speed
	var turn_brake_acceleration: float = acceleration * 2.5
	var turn_acceleration: float = acceleration * turn_reaccel_multiplier

	if (
		sign(previous_velocity_x) != sign(turn_direction)
		and absf(previous_velocity_x) > 5.0
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

	if run_turn_slid_particles != null:
		run_turn_slid_particles.emitting = true


func _move_and_resolve_landing() -> void:
	move_and_slide()
	handle_landing()


func handle_landing() -> void:
	var on_floor_now: bool = is_on_floor()
	if not was_on_floor and on_floor_now and velocity.y >= 0.0:
		if absf(velocity.x) < 10.0:
			current_state = State.Land
			landing = true
			if animated_sprite_2d != null:
				animated_sprite_2d.play(&"land")
		else:
			current_state = State.Walk

		_reset_jump_state()
		ledge_mantle_failed_on_wall = false

	was_on_floor = on_floor_now
	update_hitbox()

	if animated_sprite_2d != null:
		animated_sprite_2d.rotation = 0.0
		landing_squash_timer = 0.0


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

	is_on_wall = false
	wall_direction = 0
	wall_contact_timer = 0.0
	is_climbing_wall = false
	wall_is_short = false

	ledge_direction = 0
	ledge_mantling = false
	ledge_mantle_failed_on_wall = false
	ledge_mantle_timer = 0.0

	_reset_jump_state()

	current_state = State.Idle
	was_on_floor = is_on_floor()

	if run_turn_slid_particles != null:
		run_turn_slid_particles.emitting = false

	update_animation()


func update_hitbox() -> void:
	if collision_shape_2d == null:
		return

	if is_crouching:
		collision_shape_2d.shape = STICK_CROUCH
		collision_shape_2d.position = Vector2(0.0, 6.0)
	else:
		collision_shape_2d.shape = STICK_NORMAL
		collision_shape_2d.position = Vector2.ZERO


func update_animation() -> void:
	if animated_sprite_2d == null:
		return
	if (
	current_state == State.WalkStart
	or current_state == State.WalkEnd
	):
		if animated_sprite_2d.animation == &"start walk" \
		or animated_sprite_2d.animation == &"end walk":
			if animated_sprite_2d.is_playing():
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
			if idle_variant_playing:
				return

			if idle_timer > 10.0:
				if randf() < 0.5:
					animated_sprite_2d.play(&"idle 2")
				else:
					animated_sprite_2d.play(&"idle 3")

				idle_variant_playing = true
				idle_timer = 0.0


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

	if current_state == State.Jump or current_state == State.DoubleJump:
		if animated_sprite_2d.animation != animation_name:
			animated_sprite_2d.play(animation_name)
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

	if is_on_rail:
		# Rail.gd rotates the CharacterBody2D root.
		# Keep child rotations at zero so they follow the root rotation.
		if animated_sprite_2d != null:
			animated_sprite_2d.rotation = 0.0
		if collision_shape_2d != null:
			collision_shape_2d.rotation = 0.0
		return

	if animated_sprite_2d == null:
		return

	if absf(velocity.x) > 40.0:
		animated_sprite_2d.rotation = deg_to_rad(velocity.x * 0.03)
	else:
		animated_sprite_2d.rotation = lerp(
			animated_sprite_2d.rotation,
			0.0,
			0.2
		)

	if collision_shape_2d != null:
		collision_shape_2d.rotation = animated_sprite_2d.rotation


func _update_dust_particles() -> void:
	if run_turn_slid_particles == null:
		return

	if (
		_gpu_mat == null
		and run_turn_slid_particles.process_material is ParticleProcessMaterial
	):
		_gpu_mat = run_turn_slid_particles.process_material as ParticleProcessMaterial

	var should_emit: bool = (
		is_on_floor()
		and (
			current_state == State.Run
			or current_state == State.Turn
			or current_state == State.Skid
		)
	)

	run_turn_slid_particles.emitting = should_emit

	if not should_emit:
		run_turn_slid_particles.position.x = 0.0
		return

	var facing_direction: float = float(last_dir)

	if current_state == State.Skid or current_state == State.Turn:
		run_turn_slid_particles.position.x = (
			facing_direction * skid_particle_front_offset
		)
	else:
		run_turn_slid_particles.position.x = (
			facing_direction * normal_particle_offset
		)

	if _gpu_mat != null:
		_gpu_mat.direction = Vector3(-facing_direction, 0.0, 0.0)


func _check_wall_contact(delta: float) -> void:
	if ledge_mantling:
		is_on_wall = false
		return
	
	var was_on_wall: bool = is_on_wall
	var previous_wall_direction: int = wall_direction

	is_on_wall = false
	wall_direction = 0
	ledge_direction = 0
	wall_is_short = false

	if wall_check_left == null or wall_check_right == null:
		wall_contact_timer = 0.0
		is_climbing_wall = false
		return

	wall_check_left.force_raycast_update()
	wall_check_right.force_raycast_update()

	if not is_on_floor():
		if wall_check_left.is_colliding():
			is_on_wall = true
			wall_direction = -1
		elif wall_check_right.is_colliding():
			is_on_wall = true
			wall_direction = 1

	if is_on_wall:
		if not was_on_wall or wall_direction != previous_wall_direction:
			wall_contact_timer = 0.0
		
		wall_contact_timer += delta
		
		var ledge_check_dir := wall_direction

		ledge_shape_cast.position.x = ledge_check_dir * 12.0
		ledge_shape_cast.target_position.x = ledge_check_dir * 8.0
		head_clearance_shape_cast.position.x = ledge_check_dir * 12.0

		ledge_direction = _detect_ledge(ledge_check_dir)

		print("wall timer:", wall_contact_timer)

		if (
			ledge_direction != 0
			and velocity.y >= 0.0
			and wall_contact_timer >= min_wall_contact_time
			and not ledge_mantle_failed_on_wall
			and ledge_retry_timer <= 0.0
		):
			_start_ledge_mantle(ledge_direction)
	else:
		wall_contact_timer = 0.0
		is_climbing_wall = false
	print("wall timer:", wall_contact_timer)
		
	if wall_check_left.is_colliding():
		print("LEFT WALL")
		is_on_wall = true
		wall_direction = -1
	elif wall_check_right.is_colliding():
		print("RIGHT WALL")
		is_on_wall = true
		wall_direction = 1

func _detect_ledge(side: int) -> int:
	print("DETECT LEDGE CALLED")

	if side == 0:
		print("SIDE IS 0")
		return 0

	if (
		ledge_shape_cast == null
		or head_clearance_shape_cast == null
	):
		print("SHAPECAST NULL")
		return 0

	ledge_shape_cast.force_shapecast_update()
	head_clearance_shape_cast.force_shapecast_update()

	print("WALL COLLIDING:", ledge_shape_cast.is_colliding())
	print("HEAD COLLIDING:", head_clearance_shape_cast.is_colliding())

	if !ledge_shape_cast.is_colliding():
		print("NO WALL")
		return 0

	if head_clearance_shape_cast.is_colliding():
		print("HEAD BLOCKED")
		return 0

	print("LEDGE FOUND")
	var space_state := get_world_2d().direct_space_state
	
	var ray_start := global_position + Vector2(
	side * 24.0,
	-64.0
	)
	var ray_end := global_position + Vector2(
	side * 24.0,
	64.0
	)
	var query := PhysicsRayQueryParameters2D.create(
	ray_start,
	ray_end
	)
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return 0
		
	ledge_surface_position = result.position
	print("SURFACE:", ledge_surface_position)

	return side

func _start_ledge_mantle(side: int) -> void:
	print("MANTLE STARTED")
	
	
	if ledge_mantling:
		return

	ledge_mantling = true
	ledge_mantle_timer = 0.0
	ledge_direction = side
	is_on_wall = false
	is_climbing_wall = false
	wall_contact_timer = 0.0
	velocity = Vector2.ZERO
	ledge_mantle_start = global_position

	var half_width: float = 8.0
	var half_height: float = 16.0
	var shape_offset_y: float = 0.0

	if collision_shape_2d != null:
		shape_offset_y = collision_shape_2d.position.y * absf(global_scale.y)

		if collision_shape_2d.shape != null:
			var shape_rect: Rect2 = collision_shape_2d.shape.get_rect()
			half_width = shape_rect.size.x * absf(global_scale.x) * 0.5
			half_height = shape_rect.size.y * absf(global_scale.y) * 0.5

	var collider_height := half_height
	ledge_mantle_end = Vector2(
	ledge_surface_position.x,
	ledge_surface_position.y
		- collision_shape_2d.shape.get_rect().size.y * 0.5
	)
	print("START:", ledge_mantle_start)
	print("END:", ledge_mantle_end)
	
	ledge_mantle_control_1 = ledge_mantle_start + Vector2(
	side * 12.0,
	-48.0
	)

	ledge_mantle_control_2 = ledge_mantle_end + Vector2(
	-side * 12.0,
	-24.0
	)
	if ledge_shape_cast.is_colliding():
		print("WALL FOUND")
		
	if head_clearance_shape_cast.is_colliding():
		print("HEAD BLOCKED")


func _update_ledge_mantle(delta: float) -> void:
	velocity = Vector2.ZERO
	ledge_mantle_timer += delta

	if ledge_mantle_timer < ledge_pause_duration:
		return

	var move_time: float = ledge_mantle_timer - ledge_pause_duration
	var t: float = clampf(
		move_time / maxf(ledge_mantle_duration, 0.01),
		0.0,
		1.0
	)

	var eased_t: float = t * t * (3.0 - 2.0 * t)
	var inverse_t: float = 1.0 - eased_t

	var curve_position: Vector2 = (
	inverse_t * inverse_t * inverse_t * ledge_mantle_start
	+ 3.0 * inverse_t * inverse_t * eased_t * ledge_mantle_control_1
	+ 3.0 * inverse_t * eased_t * eased_t * ledge_mantle_control_2
	+ eased_t * eased_t * eased_t * ledge_mantle_end
	)

	global_position = curve_position

	if t >= 1.0:
		_finish_ledge_mantle()
	print("MANTLING")
	print("T:", t)


func _cancel_ledge_mantle() -> void:
	ledge_mantling = false
	ledge_mantle_timer = 0.0
	ledge_mantle_failed_on_wall = true
	ledge_retry_timer = 0.3
	ledge_direction = 0
	velocity = Vector2.ZERO


func _finish_ledge_mantle() -> void:
	print("MANTLE FINISHED")
	global_position = ledge_mantle_end
	
	ledge_mantling = false
	ledge_mantle_timer = 0.0
	ledge_direction = 0
	
	velocity = Vector2.ZERO
	current_state = State.Idle
	
	was_on_floor = false
	ledge_mantle_failed_on_wall = true

func _handle_wall_climb(delta: float) -> void:
	if not is_on_wall:
		is_climbing_wall = false
		return

	var up_pressed: bool = Input.is_action_pressed("player1_up")
	var down_pressed: bool = Input.is_action_pressed("player1_down")

	if up_pressed and not down_pressed:
		is_climbing_wall = true
		velocity.y = -wall_climb_speed
	elif down_pressed and not up_pressed:
		is_climbing_wall = true
		velocity.y = wall_climb_speed
	elif wall_is_short:
		is_climbing_wall = false
		velocity.y = minf(
			velocity.y + gravity * wall_slide_gravity_multiplier * delta,
			short_wall_slide_speed
		)
	else:
		is_climbing_wall = true
		velocity.y = 0.0


func _on_animated_sprite_2d_animation_finished() -> void:
	if (
		animated_sprite_2d.animation == &"idle 2"
		or animated_sprite_2d.animation == &"idle 3"
	):
		idle_variant_playing = false
		animated_sprite_2d.play(&"idle")
		return

	if crouch_reversing:
		crouch_reversing = false
		update_animation()
		return

	match animated_sprite_2d.animation:
		&"start walk":
			current_state = State.Walk

		&"end walk":
			current_state = State.Idle

		&"skid":
			current_state = State.Idle

		&"turn":
			turn_animation_finished = true

		&"land":
			landing = false

			if absf(input_dir) > 0.0:
				current_state = State.Walk
			else:
				current_state = State.Idle

		&"double_jump":
			if is_on_floor():
				current_state = State.Idle
			elif velocity.y < 0.0:
				current_state = State.Jump
			else:
				current_state = State.Fall
	update_animation()


func set_on_rail(on_rail: bool) -> void:
	is_on_rail = on_rail

	if on_rail:
		velocity = Vector2.ZERO
		current_state = State.Idle
		air_jumps_used = 0
		coyote_timer = 0.0
		is_on_wall = false
		is_climbing_wall = false
		ledge_mantling = false


func _handle_rail_input() -> void:
	var horizontal: float = (
		Input.get_action_strength("player1_right")
		- Input.get_action_strength("player1_left")
	)

	if not is_zero_approx(horizontal):
		last_dir = int(sign(horizontal))

	var jump_pressed: bool = Input.is_action_just_pressed("player1_up")
	var down_pressed: bool = Input.is_action_pressed("player1_down")
	var rail: Node = get_meta("rail_node") if has_meta("rail_node") else null

	if rail == null:
		return

	if rail.has_method("set_rider_input_direction"):
		rail.call("set_rider_input_direction", self, horizontal)

	if not rail.has_method("stop_loop"):
		return

	if jump_pressed:
		rail.call("stop_loop", self, false)
	elif down_pressed:
		rail.call("stop_loop", self, true)


func _on_fall_death_area_body_entered(body: Node2D) -> void:
	if body != self or movement_locked:
		return

	camera_should_follow = false

	var music := get_node_or_null(music_node_path) as AudioStreamPlayer
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
		fade.call("fade_in_black")

	await get_tree().create_timer(0.5).timeout

	if not is_inside_tree():
		return

	global_position = player1_respawn_position
	global_rotation = 0.0
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
		fade.call("fade_out_black")


func _on_music_finished() -> void:
	var music := get_node_or_null(music_node_path) as AudioStreamPlayer
	if music != null:
		music.play()


func _on_fall_death_area_body_exited(_body: Node2D) -> void:
	pass
