// 술래(괴물) 공용 셰이더 본문. creature*.gdshader 에서 include 해서 씁니다.
// 얼룩(mottle)·때(grime)·핏자국(blood)·갈라짐(cracks)·빛나는 핏줄(veins)·가장자리 빛(rim)을
// 모두 물체 좌표 노이즈로 그려서 텍스처 없이도 질감이 나옵니다.
uniform vec4 albedo : source_color = vec4(0.6, 0.6, 0.6, 1.0);
uniform vec4 albedo2 : source_color = vec4(0.4, 0.4, 0.4, 1.0);
uniform float mottle : hint_range(0.0, 1.0) = 0.35;
uniform float mottle_scale = 5.0;
uniform vec4 grime_color : source_color = vec4(0.05, 0.04, 0.035, 1.0);
uniform float grime : hint_range(0.0, 1.0) = 0.3;
uniform vec4 blood_color : source_color = vec4(0.11, 0.004, 0.004, 1.0);
uniform float blood : hint_range(0.0, 1.0) = 0.0;
uniform float blood_scale = 2.5;
uniform float roughness_v : hint_range(0.0, 1.0) = 0.8;
uniform float metallic_v : hint_range(0.0, 1.0) = 0.0;
uniform float bump = 0.5;
uniform float bump_scale = 14.0;
uniform vec4 rim_color : source_color = vec4(0.45, 0.5, 0.65, 1.0);
uniform float rim = 0.1;
uniform float rim_power = 3.0;
uniform float backlight_v = 0.0;
uniform float under_ao : hint_range(0.0, 1.0) = 0.35;
uniform float sway = 0.0;
uniform float sway_speed = 1.6;
uniform vec4 vein_color : source_color = vec4(0.25, 1.0, 0.35, 1.0);
uniform float veins = 0.0;
uniform float cracks = 0.0;
uniform vec4 crack_color : source_color = vec4(0.03, 0.02, 0.02, 1.0);
uniform float crack_scale = 6.0;
uniform vec4 tint_color : source_color = vec4(0.35, 0.35, 0.4, 1.0);
uniform float tint : hint_range(0.0, 1.0) = 0.0;
uniform float fade_start = 0.35;

varying vec3 lp;
varying float wy;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.11, 0.17, 0.13));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1.0, 0.0, 0.0)), f.x),
				   mix(hash3(i + vec3(0.0, 1.0, 0.0)), hash3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
			   mix(mix(hash3(i + vec3(0.0, 0.0, 1.0)), hash3(i + vec3(1.0, 0.0, 1.0)), f.x),
				   mix(hash3(i + vec3(0.0, 1.0, 1.0)), hash3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return s;
}

void vertex() {
	lp = VERTEX;
	if (sway > 0.0) {
		float w = UV.y * UV.y;
		vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float ph = TIME * sway_speed + wp.x * 0.7 + wp.z * 0.5;
		VERTEX.x += sin(ph + VERTEX.y * 2.5 + VERTEX.z * 3.0) * sway * w;
		VERTEX.z += cos(ph * 0.83 + VERTEX.y * 2.0 + VERTEX.x * 3.0) * sway * w;
	}
	wy = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}

void fragment() {
	float n1 = fbm(lp * mottle_scale);
	vec3 col = mix(albedo.rgb, albedo2.rgb, smoothstep(0.3, 0.75, n1) * mottle);
	col *= COLOR.rgb;
	float g = fbm(lp * 3.1 + vec3(7.0));
	col = mix(col, grime_color.rgb, smoothstep(0.42, 0.78, g) * grime);
	float bm = 0.0;
	if (blood > 0.0) {
		// 아래로 흘러내린 자국처럼 세로로 늘인 노이즈
		vec3 bp = lp * vec3(1.0, 0.3, 1.0) * blood_scale * 1.6;
		float b = fbm(bp + vec3(13.0)) * 0.75 + 0.35 * vnoise(lp * blood_scale * 9.0);
		float th = 0.8 - blood * 0.26;
		bm = smoothstep(th, th + 0.05, b);
		col = mix(col, blood_color.rgb * (0.6 + 0.8 * vnoise(lp * 25.0)), bm * 0.92);
	}
	float cr = 0.0;
	if (cracks > 0.0) {
		float cn = abs(vnoise(lp * crack_scale) - 0.5) + abs(vnoise(lp * crack_scale * 2.3 + vec3(3.0)) - 0.5) * 0.5;
		cr = (1.0 - smoothstep(0.0, 0.03, cn)) * cracks;
		col = mix(col, crack_color.rgb, cr);
	}
	col *= 1.0 - under_ao * clamp(-wy, 0.0, 1.0);

	// 노이즈로 표면을 울퉁불퉁하게 (화면 미분으로 노멀 흔들기)
	float h = fbm(lp * min(bump_scale, 16.0)) - cr * 0.6 + bm * 0.15;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float hx = dFdx(h);
	float hy = dFdy(h);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (hx * r1 + hy * r2);
	vec3 nn = normalize(abs(det) * NORMAL - grad * min(bump, 0.8) * 0.3);
	NORMAL = nn;

	col = mix(col, tint_color.rgb, tint);
	ALBEDO = col;
	ROUGHNESS = mix(roughness_v, 0.22, bm);
	METALLIC = metallic_v * (1.0 - bm);
	SPECULAR = 0.5;
	float fres = pow(1.0 - clamp(dot(nn, VIEW), 0.0, 1.0), rim_power);
	vec3 em = rim_color.rgb * fres * rim;
	if (veins > 0.0) {
		float vn = abs(fbm(lp * 4.0 + vec3(2.0)) - 0.5);
		float vm = 1.0 - smoothstep(0.0, 0.035, vn);
		em += vein_color.rgb * vm * veins * (0.75 + 0.25 * sin(TIME * 3.0 + lp.y * 4.0));
	}
	EMISSION = em * (1.0 - tint);
	BACKLIGHT = vec3(backlight_v) * col;
#ifdef FADE
	ALPHA = albedo.a * (1.0 - smoothstep(fade_start, 1.0, UV.y));
#endif
}
