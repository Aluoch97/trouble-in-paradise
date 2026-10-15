// Stucco walls with a procedural window grid. Windows light up at dusk
// (the DayCycle sets the global "city_lights" from 0 to 1).
shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.95, 0.56, 0.47, 1.0);
uniform float floor_height = 3.2;
uniform float bay_width = 3.2;
global uniform float city_lights;

varying vec3 wpos;
varying vec3 wnorm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = base_color.rgb;
	float rough = 0.9;
	vec3 emis = vec3(0.0);
	if (wnorm.y > 0.5) {
		col *= 0.7; // roof
	} else {
		float u = abs(wnorm.x) > 0.5 ? wpos.z : wpos.x;
		float fy = (wpos.y - 0.15) / floor_height;
		float cy = fract(fy);
		float fl = floor(fy);
		float cu = u / bay_width;
		float cx = fract(cu);
		// trim band at each floor line
		if (cy < 0.06) col *= 0.82;
		bool win = cy > 0.3 && cy < 0.8 && cx > 0.24 && cx < 0.76 && fy > 0.05;
		if (win) {
			float h = hash(vec2(floor(cu), fl) + floor(wpos.xz * 0.05));
			float lit = step(0.42, h) * city_lights;
			vec3 glass = mix(vec3(0.17, 0.2, 0.3), vec3(0.32, 0.38, 0.5), step(0.7, h));
			col = mix(glass, vec3(1.0, 0.84, 0.58), lit);
			rough = 0.15;
			emis = vec3(1.0, 0.76, 0.42) * lit * 1.6;
			// window frame shadow
			float edge = min(min(cx - 0.24, 0.76 - cx), min(cy - 0.3, 0.8 - cy));
			col *= mix(0.6, 1.0, smoothstep(0.0, 0.03, edge));
		}
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	EMISSION = emis;
}
