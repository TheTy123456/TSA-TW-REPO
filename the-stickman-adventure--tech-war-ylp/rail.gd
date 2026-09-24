extends Node2D

@onready var path: Path2D = $Path2D
@onready var follow: PathFollow2D = $Path2D/PathFollow2D
@onready var rail_area: Area2D = $Area2D

@export var rail_speed: float = 400.0
@export var exit_jump_force: float = 350.0
@export var exit_forward_force: float = 80.0
@export var rail_stand_offset: float = 16.0
@export var rotate_player_with_rail: bool = true
@export var reverse_direction_on_reentry: bool = true
@export var jump_action: StringName = &"move_up"

var riding: bool = false
var player: CharacterBody2D = null

# 1 = travel toward the end of the Path2D.
# -1 = travel toward the beginning of the Path2D.
var travel_direction: int = 1
var has_used_rail: bool = false


func _ready() -> void:
	follow.loop = false

	if not rail_area.body_entered.is_connected(_on_area_2d_body_entered):
		rail_area.body_entered.connect(_on_area_2d_body_entered)


func _physics_process(delta: float) -> void:
	if not riding or player == null:
		return

	if (
		Input.is_action_just_pressed(jump_action)
	):
		stop_rail(true)
		return

	var curve: Curve2D = path.curve

	if curve == null:
		stop_rail(false)
		return

	var curve_length: float = curve.get_baked_length()

	if curve_length <= 0.0:
		stop_rail(false)
		return

	var new_progress: float = (
		follow.progress
		+ rail_speed * delta * float(travel_direction)
	)

	if travel_direction > 0 and new_progress >= curve_length:
		follow.progress = curve_length
		_update_player_on_rail()
		stop_rail(true)
		return

	if travel_direction < 0 and new_progress <= 0.0:
		follow.progress = 0.0
		_update_player_on_rail()
		stop_rail(true)
		return

	follow.progress = new_progress
	_update_player_on_rail()


func _set_player_collision_enabled(
	target_player: CharacterBody2D,
	enabled: bool
) -> void:
	if target_player == null:
		return

	var collision: CollisionShape2D = (
		target_player.get_node_or_null("CollisionShape2D")
		as CollisionShape2D
	)

	if collision != null:
		collision.set_deferred("disabled", not enabled)


func _update_player_on_rail() -> void:
	if player == null:
		return

	var rail_rotation: float = follow.global_rotation
	var stand_offset: Vector2 = (
		Vector2.UP.rotated(rail_rotation) * rail_stand_offset
	)

	player.global_position = follow.global_position + stand_offset

	if rotate_player_with_rail:
		player.global_rotation = rail_rotation
	else:
		player.global_rotation = 0.0

	var sprite: AnimatedSprite2D = (
		player.get_node_or_null("AnimatedSprite2D")
		as AnimatedSprite2D
	)

	if sprite != null:
		sprite.flip_h = travel_direction < 0


func start_rail(p: CharacterBody2D) -> void:
	if p == null or riding:
		return

	var curve: Curve2D = path.curve

	if curve == null:
		return

	var curve_length: float = curve.get_baked_length()

	if curve_length <= 0.0:
		return

	player = p
	riding = true

	if has_used_rail and reverse_direction_on_reentry:
		travel_direction *= -1

	has_used_rail = true

	player.set("movement_locked", true)
	player.velocity = Vector2.ZERO

	# Disable collision while the rail controls the player.
	_set_player_collision_enabled(player, false)

	player.set_physics_process(false)

	var local_player_position: Vector2 = (
		path.to_local(player.global_position)
	)

	var closest_progress: float = (
		curve.get_closest_offset(local_player_position)
	)

	follow.progress = clamp(
		closest_progress,
		0.0,
		curve_length
	)

	_update_player_on_rail()


func _restore_player_after_rail(
	exiting_player: CharacterBody2D,
	launch_player: bool
) -> void:
	if exiting_player == null:
		return

	# Move the player slightly away from the rail before restoring collision.
	var rail_rotation: float = follow.global_rotation
	var stand_offset: Vector2 = (
		Vector2.UP.rotated(rail_rotation)
		* (rail_stand_offset + 8.0)
	)

	exiting_player.global_position = follow.global_position + stand_offset
	exiting_player.global_rotation = 0.0

	var sprite: AnimatedSprite2D = (
		exiting_player.get_node_or_null("AnimatedSprite2D")
		as AnimatedSprite2D
	)

	if sprite != null:
		sprite.rotation = 0.0
		sprite.flip_h = false

	exiting_player.set("movement_locked", false)
	exiting_player.set_physics_process(true)

	_set_player_collision_enabled(exiting_player, true)

	if launch_player:
		var push_direction: Vector2 = Vector2.RIGHT.rotated(
			follow.global_rotation
		)

		if travel_direction < 0:
			push_direction = -push_direction

		exiting_player.velocity = (
			push_direction * exit_forward_force
			+ Vector2.UP * exit_jump_force
		)
	else:
		exiting_player.velocity = Vector2.ZERO


func stop_rail(launch_player: bool = true) -> void:
	if not riding:
		return

	riding = false

	var exiting_player: CharacterBody2D = player
	player = null

	if exiting_player == null:
		return

	exiting_player.velocity = Vector2.ZERO

	call_deferred(
		"_restore_player_after_rail",
		exiting_player,
		launch_player
	)


func _input(event: InputEvent) -> void:
	if not riding:
		return

	if event.is_action_pressed(jump_action):
		stop_rail(true)
		get_viewport().set_input_as_handled()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if riding:
		return

	if body is CharacterBody2D:
		start_rail(body)
