shader_type canvas_item;
// Vignette layar (art-direction.md §7b: 0.35). Tepi gelap kecoklatan, bukan hitam.

uniform float strength : hint_range(0.0, 1.0) = 0.35;
uniform float softness : hint_range(0.05, 1.0) = 0.55;
uniform vec4 tint : source_color = vec4(0.16, 0.09, 0.06, 1.0);

void fragment() {
	vec2 d = UV - vec2(0.5);
	float v = smoothstep(0.75 - softness, 0.75, length(d * vec2(1.0, 0.85)) * 1.25);
	COLOR = vec4(tint.rgb, v * strength);
}
