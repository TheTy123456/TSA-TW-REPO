extends CanvasLayer
@onready var animation_player: AnimationPlayer = $ColorRect/AnimationPlayer

func play_circle_fade_in():
	animation_player.play("circle_fade_out")
