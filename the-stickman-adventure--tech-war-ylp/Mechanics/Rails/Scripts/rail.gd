extends Node2D

@onready var path: Path2D = $Path2D
@onready var rail_area: Area2D = $Area2D
@onready var line_2d: Line2D = $Line2D

@export var loop_speed: float = 400.0
@export var exit_jump_force: float = 350.0
@export var exit_forward_force: float = 80.0
@export var rail_height_offset: float = -20.0

var riders: Array[CharacterBody2D] = []
var rider_follows: Dictionary = {}
var rider_directions: Dictionary = {}


func _ready() -> void:
	if not rail_area.is_connected("body_entered", Callable(self, "_on_area_2d_body_entered")):
		rail_area.body_entered.connect(_on_area_2d_body_entered)
	
	if not rail_area.is_connected("body_exited", Callable(self, "_on_area_2d_body_exited")):
		rail_area.body_exited.connect(_on_area_2d_body_exited)

	if line_2d == null:
		push_error("Line2D node not found! Make sure it is named 'Line2D'.")
		return

	if path == null:
		push_error("Path2D node not found!")
		return

	var curve := path.curve
	if curve == null:
		push_error("Path2D has no curve!")
		return

	line_2d.clear_points()
	var baked_points := curve.get_baked_points()
	for p in baked_points:
		line_2d.add_point(p)


func _physics_process(delta: float) -> void:
	if riders.is_empty():
		return

	var curve := path.curve
	if curve == null:
		return

	var curve_length := curve.get_baked_length()
	if curve_length <= 0.0:
		return

	var riders_to_stop: Array[CharacterBody2D] = []

	for rider in riders:
		if not is_instance_valid(rider):
			riders_to_stop.append(rider)
			continue

		var rider_follow: PathFollow2D = rider_follows.get(rider)
		if rider_follow == null:
			riders_to_stop.append(rider)
			continue

		var direction: float = rider_directions.get(rider, 1.0)
		rider_follow.progress += loop_speed * delta * direction

		# Check if reached end of rail
		if direction > 0 and rider_follow.progress >= curve_length:
			rider_follow.progress = curve_length
			rider.global_position = rider_follow.global_position + Vector2(0, rail_height_offset)
			rider.global_rotation = rider_follow.global_rotation
			riders_to_stop.append(rider)

		elif direction < 0 and rider_follow.progress <= 0.0:
			rider_follow.progress = 0.0
			rider.global_position = rider_follow.global_position + Vector2(0, rail_height_offset)
			rider.global_rotation = rider_follow.global_rotation
			riders_to_stop.append(rider)

		else:
			# Keep player on rail with offset
			rider.global_position = rider_follow.global_position + Vector2(0, rail_height_offset)
			rider.global_rotation = rider_follow.global_rotation

	for rider in riders_to_stop:
		if is_instance_valid(rider):
			stop_loop(rider)
		riders.erase(rider)
		rider_follows.erase(rider)
		rider_directions.erase(rider)


func start_loop(body: CharacterBody2D) -> void:
	if body == null or body in riders:
		return

	if path.curve == null:
		return

	var curve_length := path.curve.get_baked_length()
	if curve_length <= 0.0:
		return

	var rider_follow := PathFollow2D.new()
	rider_follow.loop = false
	rider_follow.rotates = true

	path.add_child(rider_follow)

	var local_position := path.to_local(body.global_position)
	rider_follow.progress = clamp(
		path.curve.get_closest_offset(local_position),
		0.0,
		curve_length
	)

	riders.append(body)
	rider_follows[body] = rider_follow

	var previous_direction: float = rider_directions.get(body, 1.0)
	var new_direction: float = -previous_direction
	rider_directions[body] = new_direction

	if body.has_method("set_on_rail"):
		body.set_on_rail(true)

	body.set_meta("rail_node", self)

	# Position player on top of the rail
	body.velocity = Vector2.ZERO
	body.global_position = rider_follow.global_position + Vector2(0, rail_height_offset)
	body.global_rotation = rider_follow.global_rotation


func stop_loop(body: CharacterBody2D) -> void:
	if body == null or body not in riders:
		return

	var rider_follow: PathFollow2D = rider_follows.get(body)

	var exit_position := body.global_position
	var exit_rotation := body.global_rotation

	if rider_follow != null:
		exit_position = rider_follow.global_position + Vector2(0, rail_height_offset)
		exit_rotation = rider_follow.global_rotation

	riders.erase(body)
	rider_follows.erase(body)

	if is_instance_valid(rider_follow):
		rider_follow.queue_free()

	if not is_instance_valid(body):
		return

	body.global_position = exit_position
	body.global_rotation = 0.0

	if body.has_method("set_on_rail"):
		body.set_on_rail(false)

	var exit_direction := Vector2.RIGHT.rotated(exit_rotation)
	var current_direction: float = rider_directions.get(body, 1.0)

	body.velocity = (
		exit_direction * exit_forward_force * current_direction
		+ Vector2.UP * exit_jump_force
	)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		start_loop(body)


func _on_area_2d_body_exited(_body: Node2D) -> void:
	pass
