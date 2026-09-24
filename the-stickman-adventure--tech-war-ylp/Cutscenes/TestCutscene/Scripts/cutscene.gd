extends Node2D

@onready var cutscene_player: AnimationPlayer = $AnimationPlayer
@onready var transitions = $Transitions
@onready var transition_player: AnimationPlayer = $Transitions/AnimationPlayer

@onready var viewport_size: Vector2 = get_viewport_rect().size

@export_file("*.tscn") var next_level: String

var changing_scene: bool = false
var cutscene_ready: bool = false


func _ready() -> void:
	# Keep the screen completely black while the cutscene initializes.
	transitions.show_black_screen()

	# Allow the scene tree to finish initializing.
	await get_tree().process_frame

	# Start the cutscene behind the black loading screen.
	cutscene_player.play(&"cutscene")

	# Allow the first cutscene frame to be prepared.
	await get_tree().process_frame

	cutscene_ready = true

	# Reveal the cutscene with the circular transition.
	transitions.play_circle_fade_out()


func _unhandled_input(event: InputEvent) -> void:
	if changing_scene:
		return

	if event.is_action_pressed("skip_cutscene"):
		finish_cutscene()


func _on_animation_player_animation_finished(
	animation_name: StringName
) -> void:
	if animation_name == &"cutscene":
		finish_cutscene()


func finish_cutscene() -> void:
	if changing_scene:
		return

	changing_scene = true
	set_process_unhandled_input(false)

	# Close the cutscene with the circular transition.
	transitions.play_circle_fade_in()

	await transition_player.animation_finished

	if next_level.is_empty():
		push_error("No next level has been assigned.")
		return

	get_tree().change_scene_to_file(next_level)
