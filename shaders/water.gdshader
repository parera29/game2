shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 deep : source_color = vec3(0.05, 0.18, 0.25);
uniform vec3 shallow : source_color = vec3(0.12, 0.35, 0.42);
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
	VERTEX.y += sin(wpos.x * 0.3 + TIME * 1.2) * 0.08 + cos(wpos.z * 0.25 + TIME) * 0.08;
}

void fragment() {
	vec2 uv = wpos.xz * 0.15;
	float w = vnoise(uv + vec2(TIME * 0.05, TIME * 0.03)) * 0.5 + vnoise(uv * 3.0 - vec2(TIME * 0.1, 0.0)) * 0.5;
	ALBEDO = mix(deep, shallow, w) * mix(1.0, 0.4, night_factor);
	ROUGHNESS = 0.08 + 0.1 * w;
	METALLIC = 0.1;
	SPECULAR = 0.7;
	vec3 nmap = normalize(vec3(vnoise(uv * 4.0 + TIME * 0.2) - 0.5, 1.0, vnoise(uv * 4.0 - TIME * 0.2) - 0.5));
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(nmap, 0.0)).xyz, 0.3));
}
