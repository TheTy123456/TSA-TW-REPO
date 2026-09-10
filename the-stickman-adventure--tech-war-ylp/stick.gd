extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

@export var move_speed = 200.0
@export var acceleration = 1200.0
@export var deceleration = 600.0
@export var jump_force = 380.0
@export var gravity = 900.0

enum  State { 
	Idle,
	Walk,
	Turn,
	Skid, 
	Jump, 
	Fall
	}
var current_state: State = State.Idle

var input_dir = 0.0
var last_dir = 1

func _physics_process(delta):
	input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	if input_dir != 0:
		var turning = sign(input_dir) != sign(velocity.x) and abs(velocity.x) > 20
		if turning:
			current_state = State.Turn
		else:
			current_state = State.Walk
			
		velocity.x = move_toward(velocity.x, input_dir * move_speed, acceleration * delta)
		last_dir = input_dir
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration * delta)
		if abs(velocity.x) > 5:
			current_state = State.Skid
		else:
			current_state = State.Idle
		
	if not is_on_floor():
		velocity.y += gravity * delta
		current_state = State.Jump if velocity.y < 0 else State.Fall
		
	if is_on_floor() and Input.is_action_just_pressed("ui_accept"):
		velocity.y = -jump_force
		current_state = State.Jump
		
	move_and_slide()
	
	update_animation()
	
	print("STATE: ", State.keys()[current_state])

func update_animation():
	match current_state:
		State.Idle:
			animated_sprite_2d.play("idle")
		State.Walk:
			animated_sprite_2d.play("walk")
		State.Jump:
			animated_sprite_2d.play("jump")
		State.Fall:
			animated_sprite_2d.play("fall")
			
	animated_sprite_2d.flip_h = last_dir < 0
