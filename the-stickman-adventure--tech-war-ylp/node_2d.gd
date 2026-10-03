extends Node2D

@export var patrol_change_time: float = 3.0
@export var gap_check_distance: float = 28.0
@export var gap_check_depth: float = 80.0

@onready var body: Node2D = get_parent()

var patrol_direction: float = 1.0
var patrol_timer: float = 0.0

func _physics_process(delta):
	if not is_instance_valid(body):
		return

	patrol_timer -= delta
	
	if patrol_timer <= 0.0:
		patrol_direction = randf_range(-1.0, 1.0)
		if abs(patrol_direction) < 0.5:
			patrol_direction = 0.0
		patrol_timer = patrol_change_time

	var gap_ahead = not _has_ground_in_front(patrol_direction)
	var should_jump = body.is_on_floor() and gap_ahead and patrol_direction != 0.0

	body.apply_input(patrol_direction, false, should_jump, false)

func _has_ground_in_front(direction: float, extra_height: float = 0.0) -> bool:
	if direction == 0.0:
		return true
	
	var world = body.get_world_2d()
	if world == null:
		return true

	var space_state = world.direct_space_state
	var from = body.global_position + Vector2(direction * gap_check_distance, -8.0)
	var to = from + Vector2(0.0, gap_check_depth + extra_height)

	var query = PhysicsRayQueryParameters2D.create(from, to)
	query.exclude = [body]
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result = space_state.intersect_ray(query)
	return result.size() > 0
