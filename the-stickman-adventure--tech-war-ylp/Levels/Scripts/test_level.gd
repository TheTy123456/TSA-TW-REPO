extends Node2D

@onready var transitions: CanvasLayer = $Transitions


func _ready() -> void:
	transitions.play_circle_fade_out()
