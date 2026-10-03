extends Node2D

# Path nodes for the rail path and trigger area.
@onready var path: Path2D = $Path2D
@onready var rail_area: Area2D = $Area2D

# Rail tuning
@export var loop_speed: float = 400.0
@export var exit_jump_force: float = 350.0
@export var exit_forward_force: float = 80.0

# Track all riders currently on the rail.
var riders: Array[CharacterBody2D] = []

# Store each rider's path follower so each rider has an independent offset.
var rider_follows: Dictionary = {}

# Store each rider's direction to move back and forth along the path.
var rider_directions: Dictionary = {}


func _ready() -> void:
	# Connect the Area2D signals in code since we need to handle input.
	rail_area.body_entered.connect(_on_area_2d_body_entered)
	rail_area.body_exited.connect(_on_area_2d_body_exited)


func _input(event: InputEvent) -> void:
	# Check if any rider (who is in the player group) presses jump.
	if not event.is_action_pressed("move_up"):
		return

	for rider in riders:
		if is_instance_valid(rider) and rider.is_in_group("player"):
			# Player jumped while on rail - remove them.
			stop_loop(rider)
			get_viewport().set_input_as_handled()
			return


func _physics_process(delta: float) -> void:
	# If nobody is riding, do nothing.
	if riders.is_empty():
		return

	var curve := path.curve

	if curve == null:
		return

	var curve_length := curve.get_baked_length()

	if curve_length <= 0.0:
		return

	var riders_to_stop: Array[CharacterBody2D] = []

	# Update each rider's position along the rail.
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

		# If direction is positive and rider reached end, stop them.
		if direction > 0 and rider_follow.progress >= curve_length:
			rider_follow.progress = curve_length
			rider.global_position = rider_follow.global_position
			rider.global_rotation = rider_follow.global_rotation
			riders_to_stop.append(rider)

		# If direction is negative and rider reached start, stop them.
		elif direction < 0 and rider_follow.progress <= 0.0:
			rider_follow.progress = 0.0
			rider.global_position = rider_follow.global_position
			rider.global_rotation = rider_follow.global_rotation
			riders_to_stop.append(rider)

		# Otherwise keep them moving along the path.
		else:
			rider.global_position = rider_follow.global_position
			rider.global_rotation = rider_follow.global_rotation

	# Remove riders that reached the end/start.
	for rider in riders_to_stop:
		if is_instance_valid(rider):
			stop_loop(rider)
		else:
			riders.erase(rider)
			rider_follows.erase(rider)
			rider_directions.erase(rider)


func start_loop(body: CharacterBody2D) -> void:
	# Ignore null or duplicate riders.
	if body == null or body in riders:
		return

	if path.curve == null:
		return

	var curve_length := path.curve.get_baked_length()

	if curve_length <= 0.0:
		return

	# Create a dedicated PathFollow2D for this rider.
	var rider_follow := PathFollow2D.new()
	rider_follow.loop = false
	rider_follow.rotates = true

	path.add_child(rider_follow)

	# Place the rider on the closest point on the path.
	var local_position := path.to_local(body.global_position)
	rider_follow.progress = clamp(
		path.curve.get_closest_offset(local_position),
		0.0,
		curve_length
	)

	# Save this rider and its follower.
	riders.append(body)
	rider_follows[body] = rider_follow

	# Reverse direction each time a rider re-enters.
	var previous_direction: float = rider_directions.get(body, 1.0)
	var new_direction: float = -previous_direction
	rider_directions[body] = new_direction

	# Tell the character it is on the rail.
	if body.has_method("set_on_rail"):
		body.set_on_rail(true)

	# Save the rail reference on the body so the player can jump off later.
	body.set_meta("rail_node", self)

	# Reset body movement and snap to the rail position.
	body.velocity = Vector2.ZERO
	body.global_position = rider_follow.global_position
	body.global_rotation = rider_follow.global_rotation


func stop_loop(body: CharacterBody2D) -> void:
	# Ignore null or non-riding bodies.
	if body == null or body not in riders:
		return

	var rider_follow: PathFollow2D = rider_follows.get(body)

	var exit_position := body.global_position
	var exit_rotation := body.global_rotation

	if rider_follow != null:
		exit_position = rider_follow.global_position
		exit_rotation = rider_follow.global_rotation

	# Remove rider from the rail tracking.
	riders.erase(body)
	rider_follows.erase(body)

	if is_instance_valid(rider_follow):
		rider_follow.queue_free()

	if not is_instance_valid(body):
		return

	# Move the body off the rail and reset rotation.
	body.global_position = exit_position
	body.global_rotation = 0.0

	if body.has_method("set_on_rail"):
		body.set_on_rail(false)

	# Launch the character forward/up as they leave the rail.
	var exit_direction := Vector2.RIGHT.rotated(exit_rotation)
	var current_direction: float = rider_directions.get(body, 1.0)

	body.velocity = (
		exit_direction * exit_forward_force * current_direction
		+ Vector2.UP * exit_jump_force
	)


func _on_area_2d_body_entered(body: Node2D) -> void:
	# Any CharacterBody2D entering the rail trigger starts riding it.
	if body is CharacterBody2D:
		start_loop(body)


func _on_area_2d_body_exited(body: Node2D) -> void:
	# This is intentionally left blank.
	# We remove riders only when they hit the end of the path or jump off.
	pass
