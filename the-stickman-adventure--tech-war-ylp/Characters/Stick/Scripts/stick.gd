extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

@export var move_speed : float = 200.0
@export var acceleration : float = 2000.0
@export var deceleration : float= 480.0
@export var turn_slowdown :float = 0.015
@export var turn_blend : float = 0.35
@export var jump_force : float = 380.0
@export var gravity :float = 900.0

@export var coyote_time := 0.12
@export var jump_buffer_time := 0.12

@export var jump_cut_multiplier := 0.45
@export var enable_variable_jump := true
@export var auto_jump := true

@export var respawn_position := Vector2.ZERO

var turn_cooldown := 0.10
var camera_should_follow := true

var coyote_timer := 0.0
var jump_buffer_timer := 0.0

enum State {
	Idle,
	Walk,
	Turn,
	Skid,
	Jump,
	Fall,
	Land
}

var current_state := State.Idle

var input_dir : float= 0.0
var last_dir := 1

var was_on_floor := false
var landing := false
func _physics_process(delta):
	turn_cooldown -= delta
	
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
	input_dir = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	
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
		var wants_to_jump = (jump_buffer_timer > 0.0 or (auto_jump and Input.is_action_pressed("move_up")))
		if wants_to_jump and coyote_timer > 0.0:
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
	var reversing = (is_on_floor() and input_dir != 0 and sign(input_dir) != sign(prev_velocity_x) and abs(prev_velocity_x) > turn_threshold and turn_cooldown <= 0.0)
	if reversing:
		current_state = State.Turn
		turn_cooldown = 0.18
		_apply_turn_movement(delta, prev_velocity_x)
		move_and_slide()
		handle_landing()
		update_animation()
		print("STATE: ", State.keys()[current_state])
		return
		
	if input_dir != 0:
		current_state = State.Walk
		velocity.x = move_toward(prev_velocity_x, input_dir * move_speed, acceleration * delta)
		last_dir = input_dir
	else:
		velocity.x = move_toward(prev_velocity_x, 0, deceleration * delta)
		var skid_threshold = move_speed * 0.4
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
		else:
			current_state = State.Walk
	was_on_floor = on_floor_now
	
func update_animation():
	if current_state == State.Land:
		return
		
	match current_state:
		State.Idle:
			animated_sprite_2d.play("idle")
		State.Walk:
			animated_sprite_2d.play("walk")
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
		
		camera_should_follow = true
		fade.fade_out_black()
	
func _on_animated_sprite_2d_animation_finished():
	if current_state == State.Land:
		landing = false
		current_state = State.Idle
