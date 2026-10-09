// Asfalto con marcas viales calculadas en coordenadas de mundo.
// La rejilla de calles tiene periodo 50 m y calzadas de 10 m.
shader_type spatial;
render_mode cull_back, diffuse_burley;

uniform float axis = 0.0;     // 0: calle a lo largo de X, 1: a lo largo de Z
uniform float period = 50.0;
global uniform float night_factor;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float a = axis < 0.5 ? wpos.x : wpos.z;
	float b = axis < 0.5 ? wpos.z : wpos.x;
	float c = b - round(b / period) * period;
	float t = mod(a + 5.0, period);
	float n = vnoise(wpos.xz * 1.7) * 0.5 + vnoise(wpos.xz * 6.0) * 0.3 + vnoise(wpos.xz * 0.2) * 0.4;
	vec3 col = vec3(0.17, 0.17, 0.18) * (0.75 + 0.35 * n);
	// Grietas / parches
	float patch_n = vnoise(wpos.xz * 0.35 + 13.0);
	col = mix(col, col * 0.75, step(0.78, patch_n));
	float paint = 0.0;
	vec3 paint_col = vec3(0.9);
	if (t >= 10.0) {
		if (t >= 13.0 && t <= 47.0) {
			if (abs(c) < 0.09 && fract(a / 6.0) < 0.5) { paint = 1.0; paint_col = vec3(0.95, 0.75, 0.15); }
			if (abs(abs(c) - 4.3) < 0.08) { paint = 1.0; }
		} else if (abs(c) < 4.6) {
			if (fract((c + 4.6) / 0.9) < 0.5) { paint = 1.0; }
		}
	}
	paint *= 0.75 + 0.25 * vnoise(wpos.xz * 8.0);
	col = mix(col, paint_col, paint);
	ALBEDO = col;
	ROUGHNESS = mix(0.9, 0.55, night_factor * 0.5);
	SPECULAR = 0.3;
}
