// Fachada procedural: ladrillo / panel / revoque / madera, ventanas con marcos
// y ventanas iluminadas por la noche (uniforme global night_factor).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

global uniform float night_factor;
uniform vec3 wall_color : source_color = vec3(0.62, 0.42, 0.34);
uniform vec3 trim_color : source_color = vec3(0.86, 0.83, 0.78);
uniform vec3 roof_color : source_color = vec3(0.30, 0.30, 0.32);
uniform vec3 window_light : source_color = vec3(1.0, 0.8, 0.5);
uniform float pattern = 1.0;          // 0 revoque, 1 ladrillo, 2 paneles, 3 tablones
uniform vec2 cell = vec2(3.0, 3.2);
uniform float windows = 1.0;
uniform float shop_front = 0.0;       // escaparate en planta baja
uniform float lit_ratio = 0.4;
uniform float base_y = 0.0;
uniform float seed = 0.0;

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
	vec3 col;
	vec3 emit = vec3(0.0);
	float rough = 0.85;
	float metal = 0.0;
	if (abs(n.y) > 0.6) {
		float g = vnoise(wpos.xz * 2.5) * 0.12 + vnoise(wpos.xz * 0.4) * 0.12;
		col = roof_color * (0.85 + g);
		rough = 0.95;
	} else {
		float u = abs(n.x) > 0.5 ? wpos.z : wpos.x;
		float v = wpos.y - base_y;
		col = wall_color;
		if (pattern > 0.5 && pattern < 1.5) {
			float bh = 0.22;
			float bw = 0.55;
			float row = floor(v / bh);
			float off = mod(row, 2.0) * 0.5 * bw;
			vec2 b = vec2(fract((u + off) / bw), fract(v / bh));
			float mortar = clamp(step(b.x, 0.05) + step(b.y, 0.1), 0.0, 1.0);
			float var_b = hash(vec2(floor((u + off) / bw), row) + seed);
			col = mix(col * (0.82 + 0.3 * var_b), vec3(0.72, 0.69, 0.64), mortar * 0.8);
		} else if (pattern > 1.5 && pattern < 2.5) {
			vec2 pnl = fract(vec2(u / 1.5, v / 1.6));
			float seam = clamp(step(pnl.x, 0.012) + step(pnl.y, 0.012), 0.0, 1.0);
			col *= 0.92 + 0.12 * vnoise(vec2(u, v) * 2.0);
			col = mix(col, col * 0.6, seam);
		} else if (pattern > 2.5) {
			float s = fract(v / 0.24);
			col *= 0.88 + 0.12 * smoothstep(0.0, 0.2, s);
			col = mix(col * 0.65, col, smoothstep(0.0, 0.07, s));
		} else {
			col *= 0.9 + 0.14 * vnoise(vec2(u, v) * 1.3) + 0.05 * vnoise(vec2(u, v) * 9.0);
		}
		col *= mix(0.72, 1.0, smoothstep(0.0, 1.3, v));
		// Cornisa de cada planta
		float fl = fract((v - 0.9) / cell.y);
		if (v > 3.0 && fl < 0.03) {
			col = trim_color * 0.85;
		}
		if (windows > 0.5 && v > 0.9) {
			vec2 c = vec2(u / cell.x, (v - 0.9) / cell.y);
			vec2 f = fract(c);
			vec2 id = floor(c);
			bool ground = id.y < 0.5 && shop_front > 0.5;
			vec2 lo = ground ? vec2(0.05, 0.02) : vec2(0.25, 0.2);
			vec2 hi = ground ? vec2(0.95, 0.72) : vec2(0.75, 0.82);
			if (f.x > lo.x && f.x < hi.x && f.y > lo.y && f.y < hi.y) {
				float fr = min(min(f.x - lo.x, hi.x - f.x) * cell.x, min(f.y - lo.y, hi.y - f.y) * cell.y);
				float h = hash(id + vec2(seed, seed * 1.7));
				if (fr < 0.07) {
					col = trim_color;
				} else {
					float lit = step(1.0 - lit_ratio, h);
					vec3 glass = mix(vec3(0.10, 0.14, 0.2), vec3(0.42, 0.52, 0.62), smoothstep(0.0, 1.0, f.y));
					glass += vec3(0.08) * step(0.6, fract((f.x + f.y) * 2.0));
					// Parteluz
					float mull = step(abs(f.x - 0.5) * cell.x, 0.03);
					col = mix(glass, trim_color, ground ? 0.0 : mull);
					rough = 0.1;
					metal = 0.2;
					vec3 inner = window_light * (0.7 + 0.3 * hash(id * 3.1 + seed));
					emit = inner * lit * night_factor * 0.75;
					col = mix(col, inner * 0.25, lit * night_factor);
				}
			} else if (f.y < lo.y && f.y > lo.y - 0.05 && f.x > lo.x - 0.04 && f.x < hi.x + 0.04) {
				col = trim_color;
			}
		}
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emit;
}
