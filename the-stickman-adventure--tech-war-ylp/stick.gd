extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

@export var move_speed := 200.0
@export var acceleration := 1500.0
@export var deceleration := 600.0
@export var turn_slowdown := 0.45
@export var turn_blend := 6.0
@export var jump_force := 380.0
@export var gravity := 900.0

@export var respawn_position := Vector2.ZERO
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

var input_dir := 0.0
var last_dir := 1

var was_on_floor := false
var landing := false
func _physics_process(delta):
	var prev_velocity_x = velocity.x
	input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	
	if landing:
		move_and_slide()
		update_animation()
		return
		
	var reversing = is_on_floor() and input_dir != 0 and sign(input_dir) != sign(prev_velocity_x) and abs(prev_velocity_x) > 20
	if reversing:
		current_state = State.Turn
		velocity.x = move_toward(prev_velocity_x, 0, deceleration * delta)
		
		if abs(prev_velocity_x) < move_speed * 0.6:
			velocity.x = lerp(prev_velocity_x, input_dir * move_speed, delta * 5.0)
			
		last_dir = input_dir
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
		current_state = State.Skid if abs(prev_velocity_x) > 5 else State.Idle

	# gravity
	if not is_on_floor():
		velocity.y += gravity * delta
		current_state = State.Jump if velocity.y < 0 else State.Fall
	
	if is_on_floor() and Input.is_action_just_pressed("ui_accept"):
		velocity.y = -jump_force
		current_state = State.Jump
		
	move_and_slide()
	
	handle_landing()
	
	update_animation()
	print("STATE: ", State.keys()[current_state])

func handle_landing():
	var on_floor_now = is_on_floor()
	
	if !was_on_floor and on_floor_now and current_state == State.Fall:
		
		if abs(velocity.x) < 10:
			current_state = State.Land
			landing = true
			animated_sprite_2d.play("land")
		else:
			current_state = State.Walk
	was_on_floor = on_floor_now
	
func update_animation():
	if landing:
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
		State.Land:
			animated_sprite_2d.play("land")
		
	animated_sprite_2d.flip_h = last_dir < 0


func _on_fall_death_area_body_entered(body: Node2D) -> void:
	if body == self:
		global_position = respawn_position
		velocity = Vector2.ZERO
		current_state = State.Idle
	



func _on_animated_sprite_2d_animation_finished() -> void:
	if landing and animated_sprite_2d.animation == "land":
		landing = false
		current_state = State.Idle
