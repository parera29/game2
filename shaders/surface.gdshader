// Superficies genéricas con patrón procedural en coordenadas de mundo.
// mode: 0 acera, 1 césped, 2 baldosas, 3 parqué, 4 hormigón, 5 pared interior, 6 tierra/grava, 7 moqueta
shader_type spatial;
render_mode cull_back, diffuse_burley;

uniform float mode = 0.0;
uniform vec3 color_a : source_color = vec3(0.6, 0.6, 0.6);
uniform vec3 color_b : source_color = vec3(0.5, 0.5, 0.5);
uniform float scale = 1.0;

varying vec3 wpos;
varying vec3 wnorm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wnorm);
	vec2 uv = abs(n.y) > 0.5 ? wpos.xz : (abs(n.x) > 0.5 ? vec2(wpos.z, wpos.y) : vec2(wpos.x, wpos.y));
	uv *= scale;
	vec3 col = color_a;
	float rough = 0.9;
	float nz = vnoise(uv * 2.0) * 0.5 + vnoise(uv * 7.0) * 0.5;
	if (mode < 0.5) {
		vec2 f = fract(uv / 1.5);
		float seam = clamp(step(f.x, 0.025) + step(f.y, 0.025), 0.0, 1.0);
		col = color_a * (0.88 + 0.16 * hash(floor(uv / 1.5))) * (0.92 + 0.1 * nz);
		col = mix(col, color_b, seam);
	} else if (mode < 1.5) {
		float big = vnoise(uv * 0.15);
		col = mix(color_a, color_b, big) * (0.8 + 0.3 * nz);
		col += vec3(0.02, 0.05, 0.0) * step(0.7, vnoise(uv * 25.0));
	} else if (mode < 2.5) {
		vec2 f = fract(uv / 0.6);
		vec2 id = floor(uv / 0.6);
		float chk = mod(id.x + id.y, 2.0);
		col = mix(color_a, color_b, chk) * (0.95 + 0.05 * nz);
		float seam = clamp(step(f.x, 0.03) + step(f.y, 0.03), 0.0, 1.0);
		col = mix(col, col * 0.6, seam);
		rough = 0.35;
	} else if (mode < 3.5) {
		float row = floor(uv.y / 0.2);
		float off = hash(vec2(row, 3.0)) * 3.0;
		float plank = floor((uv.x + off) / 1.2);
		float grain = vnoise(vec2((uv.x + off) * 0.8, uv.y * 30.0));
		col = mix(color_a, color_b, hash(vec2(plank, row))) * (0.85 + 0.2 * grain);
		float seam = clamp(step(fract(uv.y / 0.2), 0.05) + step(fract((uv.x + off) / 1.2), 0.01), 0.0, 1.0);
		col = mix(col, col * 0.55, seam);
		rough = 0.55;
	} else if (mode < 4.5) {
		col = color_a * (0.85 + 0.2 * nz) * (0.9 + 0.1 * vnoise(uv * 0.3));
		col = mix(col, color_b, step(0.8, vnoise(uv * 0.6 + 7.0)) * 0.4);
	} else if (mode < 5.5) {
		col = color_a * (0.95 + 0.06 * nz);
		if (abs(n.y) < 0.5 && wpos.y < 0.3) { col = color_b; }
		if (abs(n.y) < 0.5 && wpos.y > 3.0 && wpos.y < 3.12) { col = color_b * 1.2; }
		rough = 0.8;
	} else if (mode < 6.5) {
		col = mix(color_a, color_b, vnoise(uv * 3.0)) * (0.8 + 0.3 * vnoise(uv * 20.0));
		rough = 1.0;
	} else {
		col = color_a * (0.9 + 0.1 * vnoise(uv * 40.0)) * (0.95 + 0.05 * nz);
		rough = 1.0;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
}
