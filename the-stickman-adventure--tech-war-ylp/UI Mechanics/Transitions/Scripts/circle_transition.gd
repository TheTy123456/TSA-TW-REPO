extends CanvasLayer

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func show_black_screen() -> void:
	$FadeTrans.visible = true
	$CircleTrans.visible = false

	# Stop any previous transition animation.
	animation_player.stop()

	# Set the black fade fully opaque.
	var fade_material := $FadeTrans.material as ShaderMaterial

	if fade_material:
		fade_material.set_shader_parameter("fade", 1.0)


func fade_in_black() -> void:
	$FadeTrans.visible = true
	$CircleTrans.visible = false
	animation_player.play(&"fade_in")


func fade_out_black() -> void:
	$FadeTrans.visible = true
	$CircleTrans.visible = false
	animation_player.play(&"fade_out")


func play_circle_fade_in() -> void:
	$FadeTrans.visible = false
	$CircleTrans.visible = true
	animation_player.play(&"circle_fade_in")


func play_circle_fade_out() -> void:
	$FadeTrans.visible = false
	$CircleTrans.visible = true
	animation_player.play(&"circle_fade_out")
