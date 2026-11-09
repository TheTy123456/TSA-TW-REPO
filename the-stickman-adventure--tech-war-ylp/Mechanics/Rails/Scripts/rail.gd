extends Node2D

@onready var path: Path2D = $Path2D
@onready var rail_area: Area2D = $Area2D
@onready var line_2d: Line2D = $Line2D

@export var loop_speed: float = 400.0
@export var exit_jump_force: float = 350.0
@export var exit_forward_force: float = 80.0

# Half of a 16-pixel-wide rail. Increase this if the rider overlaps the rail.
@export var rail_surface_offset: float = 8.0

# Ignore left/right input on nearly vertical sections to avoid direction flicker.
@export_range(0.0, 1.0) var horizontal_direction_threshold: float = 0.15

var riders: Array[CharacterBody2D] = []
var rider_follows: Dictionary = {}
var rider_directions: Dictionary = {}

@export var base_speed: float = 350.0
@export var max_speed: float = 1200.0
@export var min_speed: float = 150.0
@export var gravity_acceleration: float = 900.0
@export var player_acceleration: float = 300.0

var rider_speeds: Dictionary = {}

var rider_boosting: Dictionary = {}

func _ready() -> void:
	if rail_area == null:
		push_error("Rail Area2D not found.")
		return

	if not rail_area.body_entered.is_connected(_on_area_2d_body_entered):
		rail_area.body_entered.connect(_on_area_2d_body_entered)

	if not rail_area.body_exited.is_connected(_on_area_2d_body_exited):
		rail_area.body_exited.connect(_on_area_2d_body_exited)

	if line_2d == null:
		push_error("Line2D node not found.")
		return

	if path == null or path.curve == null:
		push_error("Path2D or its curve not found.")
		return

	line_2d.clear_points()
	for point in path.curve.get_baked_points():
		line_2d.add_point(point)


func _physics_process(delta: float) -> void:
	if riders.is_empty() or path == null or path.curve == null:
		return

	var curve_length: float = path.curve.get_baked_length()

	if curve_length <= 0.0:
		return

	var riders_to_stop: Array[CharacterBody2D] = []

	for rider in riders:
		if not is_instance_valid(rider):
			riders_to_stop.append(rider)
			continue

		var follow: PathFollow2D = rider_follows.get(rider) as PathFollow2D

		if not is_instance_valid(follow):
			riders_to_stop.append(rider)
			continue

		var direction: float = rider_directions.get(rider, 1.0)
		var speed: float = rider_speeds.get(rider, base_speed)

		var tangent := Vector2.RIGHT.rotated(follow.global_rotation)

		# Gravity-powered acceleration
		speed += tangent.y * gravity_acceleration * delta

		# Optional pumping
		var horizontal := _get_horizontal_input()
		
		var boosting: bool = rider_boosting.get(rider, false)
		
		if absf(horizontal) > 0.1:
			if not boosting:
				speed += 120.0
				rider_boosting[rider] = true
			else:
				rider_boosting[rider] = false

		speed = clampf(
			speed,
			min_speed,
			max_speed
		)
		if tangent.y < -0.85 and speed < 150.0:
			riders_to_stop.append(rider)
			continue
			
		rider_speeds[rider] = speed
		
		follow.progress = clampf(
			follow.progress + speed * delta * direction,
			0.0,
			curve_length
		)

		_place_rider(rider, follow)

		if (
			(direction > 0.0 and follow.progress >= curve_length)
			or
			(direction < 0.0 and follow.progress <= 0.0)
		):
			riders_to_stop.append(rider)

	for rider in riders_to_stop:
		if is_instance_valid(rider):
			stop_loop(rider)

		riders.erase(rider)
		rider_follows.erase(rider)
		rider_directions.erase(rider)
		rider_speeds.erase(rider)

func _get_rider_clearance(body: CharacterBody2D) -> float:
	var clearance: float = rail_surface_offset
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D

	if shape_node == null or shape_node.shape == null:
		return clearance + 16.0

	var scale_y: float = absf(body.global_scale.y)
	var shape_rect: Rect2 = shape_node.shape.get_rect()

	clearance += shape_rect.size.y * scale_y * 0.5
	clearance += shape_node.position.y * scale_y

	return clearance


func _place_rider(body: CharacterBody2D, follow: PathFollow2D) -> void:
	var tangent: Vector2 = (
		follow.transform.x.normalized()
	)
	
	var tangent_rotation := tangent.angle()
	body.global_rotation = lerp_angle(
		body.global_rotation,
		tangent_rotation,
		0.25
	)
	var target_rotation := tangent_rotation

	if absf(rad_to_deg(target_rotation)) > 90.0:
		target_rotation += PI
		
	body.global_rotation = lerp_angle(
	body.global_rotation,
	target_rotation,
	0.25
	)
	var path_up: Vector2 = Vector2.UP.rotated(tangent_rotation)
	var clearance: float = _get_rider_clearance(body)

	body.global_position = follow.global_position + path_up * clearance

	# When traveling backward, face along the reverse tangent.
	var direction: float = rider_directions.get(body, 1.0)
	
	body.global_rotation = lerp_angle(body.global_rotation, tangent_rotation, 0.25)
	if "last_dir" in body:
		body.last_dir = int(sign(direction))

func _get_horizontal_input() -> float:
	return (
		Input.get_action_strength("player1_right")
		- Input.get_action_strength("player1_left")
	)


func _choose_direction_from_input(
	follow: PathFollow2D,
	horizontal: float
) -> float:
	var tangent: Vector2 = Vector2.RIGHT.rotated(follow.global_rotation)

	if absf(tangent.x) < horizontal_direction_threshold:
		return 0.0

	# Positive path progress follows the tangent. Choose the progress direction
	# whose world X direction matches the player's left/right input.
	return 1.0 if tangent.x * horizontal > 0.0 else -1.0


func set_rider_input_direction(
	body: CharacterBody2D,
	horizontal: float
) -> void:
	if not rider_follows.has(body) or is_zero_approx(horizontal):
		return

	var follow: PathFollow2D = rider_follows.get(body) as PathFollow2D
	if not is_instance_valid(follow):
		return

	var direction: float = _choose_direction_from_input(follow, horizontal)
	if not is_zero_approx(direction):
		rider_directions[body] = direction


func start_loop(body: CharacterBody2D) -> void:
	if body == null or body in riders:
		return
	if path == null or path.curve == null:
		return

	var curve_length: float = path.curve.get_baked_length()
	if curve_length <= 0.0:
		return

	var follow := PathFollow2D.new()
	follow.loop = false
	follow.rotates = true
	path.add_child(follow)

	var local_position: Vector2 = path.to_local(body.global_position)
	follow.progress = clampf(
		path.curve.get_closest_offset(local_position),
		0.0,
		curve_length
	)

	riders.append(body)
	rider_boosting[body] = false
	rider_follows[body] = follow

	var horizontal: float = _get_horizontal_input()
	var direction: float = _choose_direction_from_input(follow, horizontal)

	if is_zero_approx(direction):
		# If no usable horizontal input is held, use the character's facing.
		var facing: float = 1.0
		var facing_value: Variant = body.get("last_dir")
		if facing_value is int or facing_value is float:
			facing = signf(float(facing_value))
		if is_zero_approx(facing):
			facing = 1.0

		direction = _choose_direction_from_input(follow, facing)

	if is_zero_approx(direction):
		direction = 1.0

	rider_directions[body] = direction
	rider_boosting.erase(body)
	rider_speeds[body] = base_speed

	if body.has_method("set_on_rail"):
		body.call("set_on_rail", true)

	body.set_meta("rail_node", self)
	body.velocity = Vector2.ZERO
	_place_rider(body, follow)


func stop_loop(body: CharacterBody2D, drop: bool = false) -> void:
	if body == null or body not in riders:
		return

	var follow: PathFollow2D = rider_follows.get(body) as PathFollow2D
	var exit_position: Vector2 = body.global_position
	var exit_rotation: float = body.global_rotation
	var direction: float = rider_directions.get(body, 1.0)

	if is_instance_valid(follow):
		_place_rider(body, follow)
		exit_position = body.global_position
		exit_rotation = follow.global_rotation

	riders.erase(body)
	rider_follows.erase(body)
	rider_directions.erase(body)

	if is_instance_valid(follow):
		follow.queue_free()

	if not is_instance_valid(body):
		return

	if body.has_method("set_on_rail"):
		body.call("set_on_rail", false)

	body.set_meta("rail_node", null)
	body.global_position = exit_position
	body.global_rotation = 0.0

	if drop:
		body.velocity = Vector2(0.0, 120.0)
		return

	var exit_direction: Vector2 = Vector2.RIGHT.rotated(exit_rotation)
	
	var current_speed: float = rider_speeds.get(body, base_speed)
	body.velocity = (
		exit_direction * current_speed * direction
		+ Vector2.UP * exit_jump_force
	)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		start_loop(body)


func _on_area_2d_body_exited(_body: Node2D) -> void:
	pass
