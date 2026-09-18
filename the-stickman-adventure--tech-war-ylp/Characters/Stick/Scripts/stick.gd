extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var gpu_particles_2d: GPUParticles2D = $GPUParticles2D

# basic movement variables
@export var move_speed : float = 200.0
@export var acceleration : float = 2000.0
@export var deceleration : float = 580.0
@export var turn_slowdown :float = 0.015
@export var turn_blend : float = 0.35
@export var jump_force : float = 380.0
@export var gravity : float = 900.0

# jumping and coyote principle variables
@export var coyote_time := 0.12
@export var jump_buffer_time := 0.12

@export var jump_cut_multiplier := 0.45
@export var enable_variable_jump := true
@export var auto_jump := true

@export var run_speed := 320.0

@export var respawn_position := Vector2.ZERO

@export var crouch_speed := 60.0
var is_crouching := false

const STICK_NORMAL = preload("uid://d168j72ka1a35")
const STICK_CROUCH = preload("uid://c5p4qg4p8701i")

# variables that are not exported
var turn_cooldown := 0.10
var camera_should_follow := true

var coyote_timer := 0.0
var jump_buffer_timer := 0.0

var last_tap_dir := 0
var double_tap_timer := 0.0

var is_running := false
var was_running := false

var default_hitbox_height := 42.0
var crouch_hitbox_height := 20.0

var movement_locked := false
var movement_lock_timer := 0.0

var has_spawned := false
var freeze_on_next_landing := false

# state
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
var current_state := State.Idle

# inputs and landing variables
var input_dir : float = 0.0
var last_dir : float = 1

var was_on_floor := false
var landing := false

func _physics_process(delta):
	if movement_locked:
		movement_lock_timer -= delta
		if movement_lock_timer <= 0.0:
			movement_locked = false
		return
		
	turn_cooldown -= delta
	
	was_running = is_running
	
	input_dir = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var crouch_input = Input.is_action_pressed("move_down")
	
	var shift_run := Input.is_action_pressed("sprint")
	
	if shift_run and input_dir != 0:
		is_running = true
	else:
		is_running = false
		
	if crouch_input and is_on_floor():
		is_running = false
		is_crouching = true
	else:
		is_crouching = false
		
	if Input.is_action_just_pressed("move_up"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta
	
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta
		
	if not is_on_floor():
		landing = false
		
	var prev_velocity_x = velocity.x
	
	if current_state == State.Turn and turn_cooldown > 0.0:
		_apply_turn_movement(delta, prev_velocity_x)
		
		if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
			jump_buffer_timer = 0.0
			coyote_timer = 0.0
			velocity.y = -jump_force
			current_state = State.Jump
			
		move_and_slide()
		handle_landing()
		update_animation()
		return
		
	if current_state == State.Land:
		var wants_to_jump_land = (jump_buffer_timer > 0.0 or (auto_jump and Input.is_action_pressed("move_up")))
		if wants_to_jump_land and coyote_timer > 0.0:
			jump_buffer_timer = 0.0
			coyote_timer = 0.0
			velocity.y = -jump_force
			current_state = State.Jump
			move_and_slide()
			update_animation()
			return
			
		if abs(input_dir) > 0:
			landing = false
			current_state = State.Walk
		else:
			move_and_slide()
			update_animation()
			return
			
	var turn_threshold = move_speed * 0.45
	var reversing = (is_on_floor() and input_dir != 0 and sign(input_dir) != sign(prev_velocity_x) and abs(prev_velocity_x) > turn_threshold and turn_cooldown <= 0.0 and not is_crouching)
	if reversing:
		current_state = State.Turn
		turn_cooldown = 0.18
		_apply_turn_movement(delta, prev_velocity_x)
		move_and_slide()
		handle_landing()
		update_animation()
		print("STATE: ", State.keys()[current_state])
		return
		
	if is_crouching:
		current_state = State.Crouch
		velocity.x = move_toward(prev_velocity_x, input_dir * crouch_speed, acceleration * delta)
	elif is_running and input_dir != 0:
		current_state = State.Run
		velocity.x = move_toward(prev_velocity_x, input_dir * run_speed, acceleration * delta)
	elif input_dir != 0:
		current_state = State.Walk
		velocity.x = move_toward(prev_velocity_x, input_dir * move_speed, acceleration * delta)
	else:
		velocity.x = move_toward(prev_velocity_x, 0, deceleration * delta)
		var skid_threshold = move_speed * 0.4
		if input_dir == 0:
			current_state = State.Skid if abs(prev_velocity_x) > skid_threshold else State.Idle

	# gravity
	if not is_on_floor():
		velocity.y += gravity * delta
		current_state = State.Jump if velocity.y < 0 else State.Fall
		
	if enable_variable_jump:
		if velocity.y < 0 and not Input.is_action_pressed("move_up"):
			velocity.y *= jump_cut_multiplier
		
	var wants_to_jump = (jump_buffer_timer > 0.0 or (auto_jump and Input.is_action_pressed("move_up")))
	
	if wants_to_jump and coyote_timer > 0.0:
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		velocity.y = -jump_force
		current_state = State.Jump
		
	move_and_slide()
	handle_landing()
	update_animation()
	
	if input_dir != 0:
		last_dir = input_dir
		
	if is_on_floor() and (current_state == State.Run or current_state == State.Turn or current_state == State.Skid):
		gpu_particles_2d.emitting = true
		
		if last_dir > 0:
			gpu_particles_2d.process_material.direction.x = -1
		elif last_dir < 0:
			gpu_particles_2d.process_material.direction.x = 1
	else:
		gpu_particles_2d.emitting = false
		
	print("STATE: ", State.keys()[current_state])

func _apply_turn_movement(delta, prev_velocity_x):
	var locked_dir := last_dir
	
	velocity.x = move_toward(prev_velocity_x, 0.0, delta * move_speed * turn_slowdown)
	
	var target_speed : float = float(locked_dir) * move_speed
	velocity.x = move_toward(velocity.x, target_speed, move_speed * delta * turn_blend)
	
	velocity.x = clamp(velocity.x, -move_speed * 0.35, move_speed * 0.35)

func handle_landing():
	var on_floor_now = is_on_floor()
	
	if !was_on_floor and on_floor_now and velocity.y >= 0:
		if abs(velocity.x) < 10:
			current_state = State.Land
			landing = true
			animated_sprite_2d.play("land")
			
			if freeze_on_next_landing:
				movement_locked = true
				movement_lock_timer = 1.0
				freeze_on_next_landing = false
			else:
				has_spawned = true
		else:
			current_state = State.Walk
	was_on_floor = on_floor_now
	
	update_hitbox()

func update_hitbox():
	var shape := collision_shape_2d.shape as CapsuleShape2D
	
	if is_crouching:
		collision_shape_2d.shape = STICK_CROUCH
		
		collision_shape_2d.position = Vector2(0,8)
	else:
		collision_shape_2d.shape = STICK_NORMAL
		collision_shape_2d.position = Vector2(0,3)
		
func update_animation():
	if current_state == State.Land:
		return
		
	match current_state:
		State.Idle:
			animated_sprite_2d.play("idle")
		State.Walk:
			animated_sprite_2d.play("walk")
		State.Run:
			animated_sprite_2d.play("run")
		State.Crouch:
			animated_sprite_2d.play("crouch")
		State.Turn:
			animated_sprite_2d.play("turn")
		State.Skid:
			animated_sprite_2d.play("skid")
		State.Jump:
			animated_sprite_2d.play("jump")
		State.Fall:
			animated_sprite_2d.play("fall")
		
	animated_sprite_2d.flip_h = last_dir < 0


func _on_fall_death_area_body_entered(body: Node2D) -> void:
	if body == self:
		camera_should_follow = false
		var fade = get_tree().current_scene.get_node("Transitions")
		
		fade.fade_in_black()
		
		await  get_tree().create_timer(0.5).timeout
		
		global_position = respawn_position
		velocity = Vector2.ZERO
		current_state = State.Idle
		
		last_dir = 1
		animated_sprite_2d.flip_h = false
		
		freeze_on_next_landing = true
		
		camera_should_follow = true
		fade.fade_out_black()
	
func _on_animated_sprite_2d_animation_finished():
	if current_state == State.Land:
		landing = false
		current_state = State.Idle
