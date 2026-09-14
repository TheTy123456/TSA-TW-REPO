shader_type canvas_item;


uniform float fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    // fade = 1 → fully black
    // fade = 0 → fully transparent
	COLOR = vec4(0.0, 0.0, 0.0, fade);
}