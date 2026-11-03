extends Node2D
@onready var stick: AnimatedSprite2D = $Stick
@onready var title :Sprite2D = $Sprite2D
@onready var music: AudioStreamPlayer = $TitleMusic
@onready var label: Label = $Label
@onready var running_sound: AudioStreamPlayer = $RunningSoundEffect
@onready var bg_music: AudioStreamPlayer = $BackGroundMusic

var run_ground_y := 600.0
var title_bopping := false
var title_time := 0.0
var title_base_y := 0.0
var beat_interval := 60.0 / 150.0 # Initial 150 BPM for title music
var logo_bumping := false

var base_logo_scale := Vector2(3.0, 3.0)
var logo_scale := Vector2(3.0, 3.0)

var beat_enabled := false

var run_bop := [
	0,
	-10,
	-20, # highest point
	-15,
	-8,
	0,
	3,
	1,
	0
]
func _ready():
	logo_scale = title.scale
	title.hide()
	label.hide()
	
	music.finished.connect(_on_title_music_finished)
	
	if has_node("Transitions"):
		$Transitions.play_circle_fade_out()
	else:
		print("Transitions node not found!")
	await intro_run()

var target_bop := 0.0

var run_time := 0.0
var sway_time := 0.0

func _process(delta):
	if stick.animation == "run":
		run_time += delta
		stick.position.y = run_ground_y + sin(run_time * 35.0) * -4.0

	if beat_enabled:
		# decay back to normal size
		logo_scale = logo_scale.lerp(base_logo_scale, 10.0 * delta)

		title.scale = logo_scale

		# slow rocking
		title.rotation_degrees = sin(Time.get_ticks_msec() * 0.001 * 1.2) * 4.0
		
func intro_run():
	# Start off-screen right
	stick.position = Vector2(2200, run_ground_y)

	# Face left
	stick.flip_h = true

	# Play run animation
	stick.play("run")
	
	# --- AUDIO FADE IN (STARTS IMMEDIATELY) ---
	running_sound.volume_db = -80.0
	running_sound.play()
	
	var fade_in_tween := create_tween()
	fade_in_tween.tween_property(running_sound, "volume_db", 0.0, 2.3)
	# ------------------------------------------

	# Constant speed run
	var run_tween := create_tween()
	run_tween.set_trans(Tween.TRANS_LINEAR)

	run_tween.tween_property(
		stick,
		"position:x",
		1100,
		1.8
	).set_delay(0.5)

	await  get_tree().create_timer(2.3).timeout

	# Slow down naturally
	var stop_tween := create_tween()
	stop_tween.set_trans(Tween.TRANS_QUAD)
	stop_tween.set_ease(Tween.EASE_OUT)

	stop_tween.tween_property(
		stick,
		"position:x",
		960,
		0.7
	)

	await stop_tween.finished

	await get_tree().create_timer(1.0).timeout
	
	stick.play("run")
	
	# --- AUDIO FADE OUT ---
	var fade_out_tween := create_tween()
	fade_out_tween.tween_property(running_sound, "volume_db", -80.0, 1.5)
	# ----------------------
	
	var exit_tween := create_tween()
	exit_tween.set_trans(Tween.TRANS_QUAD)
	exit_tween.set_ease(Tween.EASE_IN)
	exit_tween.tween_property(
		stick,
		"position:x",
		-200,
		1.5
	)
	await exit_tween.finished
	
	# Stop the sound entirely once off screen
	running_sound.stop()
	
	show_title()
	
func show_title():
	var final_y: float = title.position.y

	# Make it visible
	title.show()

	# Start below screen
	title.position.y = 1400

	var tween := create_tween()

	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		title,
		"position:y",
		final_y - 80,
		0.7
	)

	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		title,
		"position:y",
		final_y,
		0.3
	)
	await tween.finished
	
	music.play()
	label.show()
	logo_bumping = true
	
	base_logo_scale = title.scale
	logo_scale = title.scale
	beat_enabled = true
	start_beat()
	
func start_logo_bump():
	while logo_bumping:
		var bump := create_tween()

		# Grow slightly
		bump.tween_property(
			title,
			"scale",
			logo_scale * 1.08,
			0.08
		)

		# Return to normal size
		bump.tween_property(
			title,
			"scale",
			logo_scale,
			0.12
		)

		await get_tree().create_timer(beat_interval).timeout

func start_beat():
	while beat_enabled:
		# instant bump
		logo_scale += Vector2(0.25, 0.25)

		await get_tree().create_timer(beat_interval).timeout

func _on_title_music_finished():
	# Wait for a delay before playing the background music (e.g., 2.0 seconds)
	await get_tree().create_timer(2.0).timeout
	
	# --- UPDATE TEMPO TO 120 BPM ---
	# Changing this updates the loop timers automatically in start_beat() and start_logo_bump()
	beat_interval = 60.0 / 120.0 
	# --------------------------------
	
	bg_music.play()
