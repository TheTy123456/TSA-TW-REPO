extends Node2D

@onready var cutscene_player: AnimationPlayer = $AnimationPlayer
@onready var transitions = $Transitions
@onready var transition_player: AnimationPlayer = $Transitions/AnimationPlayer
@onready var cutscene_sprite: Sprite2D = $Sprite2D

@export_file("*.tscn") var next_level: String

@export var fit_sprite_to_viewport: bool = true
@export var preserve_aspect_ratio: bool = true

var viewport_size: Vector2
var changing_scene: bool = false
var cutscene_ready: bool = false


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)

	_update_viewport_size()
	_update_sprite_to_viewport()

	# Keep the screen black while the cutscene initializes.
	transitions.show_black_screen()

	await get_tree().process_frame

	# Start the animation behind the black screen.
	cutscene_player.play(&"cutscene")

	await get_tree().process_frame

	cutscene_ready = true

	# Reveal the cutscene.
	transitions.play_circle_fade_out()


func _on_viewport_size_changed() -> void:
	_update_viewport_size()
	_update_sprite_to_viewport()


func _update_viewport_size() -> void:
	viewport_size = get_viewport().get_visible_rect().size


func _update_sprite_to_viewport() -> void:
	if cutscene_sprite == null:
		return

	if cutscene_sprite.texture == null:
		return

	var texture_size: Vector2 = cutscene_sprite.texture.get_size()

	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	# Put the Sprite2D in the center of the viewport.
	cutscene_sprite.position = viewport_size * 0.7

	if not fit_sprite_to_viewport:
		return

	var scale_x: float = viewport_size.x / texture_size.x
	var scale_y: float = viewport_size.y / texture_size.y

	if preserve_aspect_ratio:
		var uniform_scale: float = max(scale_x, scale_y)
		cutscene_sprite.scale = Vector2.ONE * uniform_scale
	else:
		cutscene_sprite.scale = Vector2(scale_x, scale_y)


func _unhandled_input(event: InputEvent) -> void:
	if changing_scene or not cutscene_ready:
		return

	if event.is_action_pressed(&"skip_cutscene"):
		get_viewport().set_input_as_handled()
		finish_cutscene()


func _on_animation_player_animation_finished(
	animation_name: StringName
) -> void:
	if animation_name == &"cutscene":
		finish_cutscene()


func finish_cutscene() -> void:
	if changing_scene:
		return

	if next_level.is_empty():
		push_error("No next level has been assigned.")
		return

	changing_scene = true
	cutscene_ready = false
	set_process_unhandled_input(false)

	# Fade the cutscene to black.
	transitions.play_circle_fade_in()

	await transition_player.animation_finished

	var result: Error = get_tree().change_scene_to_file(next_level)

	if result != OK:
		push_error("Could not load next level: " + next_level)
