extends CanvasLayer
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func fade_in_black():
	$FadeTrans.visible = true
	$CircleTrans.visible = false
	animation_player.play("fade_in")

func fade_out_black():
	$FadeTrans.visible = true
	$CircleTrans.visible = false
	animation_player.play("fade_out")
	
func play_circle_fade_in():
	$FadeTrans.visible = false
	$CircleTrans.visible = true
	animation_player.play("circle_fade_in")

func play_circle_fade_out():
	$FadeTrans.visible = false
	$CircleTrans.visible = true
	animation_player.play("circle_fade_out")
