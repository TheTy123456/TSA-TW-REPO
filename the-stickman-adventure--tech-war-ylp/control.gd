extends Control

func select_single():
	GameState.game_mode = "single"
	get_tree().change_scene_to_file("res://character_controller.tscn")

func select_multi():
	GameState.game_mode = "multi"
	get_tree().change_scene_to_file("res://character_controller.tscn")

func _on_button_pressed() -> void:
	select_single()


func _on_button_2_pressed() -> void:
	select_multi()
