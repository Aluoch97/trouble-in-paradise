// GTA-style mission checkpoint: a glowing column that fades upward.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.43, 0.57, 1.0);
uniform float height = 8.0;
uniform float strength = 0.6;

varying float vy;

void vertex() {
	vy = VERTEX.y;
}

void fragment() {
	float t = clamp((vy + height * 0.5) / height, 0.0, 1.0);
	float pulse = 0.82 + 0.18 * sin(TIME * 4.0);
	float a = pow(1.0 - t, 1.6) * strength * pulse;
	ALBEDO = color.rgb * a;
	ALPHA = a;
}
