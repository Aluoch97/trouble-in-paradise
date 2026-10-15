// The Knox Ridge pool. Moving ripples and caustic glints, no textures needed.
shader_type spatial;

uniform vec4 shallow : source_color = vec4(0.3, 0.82, 0.86, 1.0);
uniform vec4 deep : source_color = vec4(0.08, 0.48, 0.66, 1.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float w = sin(wpos.x * 1.7 + TIME * 1.6) * 0.5 + sin(wpos.z * 2.3 - TIME * 1.2) * 0.5;
	float c = sin(wpos.x * 3.1 + TIME * 2.0 + sin(wpos.z * 2.7 + TIME)) * 0.5 + 0.5;
	float caustic = smoothstep(0.75, 1.0, c);
	ALBEDO = mix(deep.rgb, shallow.rgb, 0.55 + 0.2 * w) + caustic * 0.18;
	NORMAL = normalize(NORMAL + vec3(cos(wpos.x * 1.7 + TIME * 1.6) * 0.06, 0.0, cos(wpos.z * 2.3 - TIME * 1.2) * 0.06));
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
}
