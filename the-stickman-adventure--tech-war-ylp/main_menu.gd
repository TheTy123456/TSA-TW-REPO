extends Control

func _ready():
	if has_node("Transitions"):
		$Transitions.play_circle_fade_out()
	else:
		print("Transitions node not found!")
