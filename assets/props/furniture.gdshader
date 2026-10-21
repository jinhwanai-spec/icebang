shader_type spatial;
// 가구·소품 (상자 부품) 공통: 부품 색 그대로 + 세월의 때·얼룩·미세한 색 차이·거칠기 변화
// (예전엔 단색이라 하얀 가구가 맨 상자처럼 보였음)
render_mode cull_back;

uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D scratch_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float grime = 0.4;
uniform float rough_v = 0.85;
uniform float metallic_v = 0.0;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float tri(sampler2D t, vec3 p, vec3 n, float s) {
	vec3 b = pow(abs(n), vec3(4.0));
	b /= (b.x + b.y + b.z + 1e-4);
	return texture(t, p.zy * s).r * b.x + texture(t, p.xz * s).r * b.y + texture(t, p.xy * s).r * b.z;
}

void fragment() {
	vec3 c = COLOR.rgb;
	float big = tri(noise_tex, wpos, wnorm, 0.23);
	float mid = tri(noise_tex, wpos + 17.0, wnorm, 1.3);
	float fine = tri(scratch_tex, wpos, wnorm, 3.1);
	// 얼룩진 때: 큰 무늬로 군데군데, 밝은 색일수록 더 잘 보임
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float stain = smoothstep(0.5, 0.82, big) * grime * (0.55 + 0.6 * lum);
	// 아래쪽(바닥 가까운 면)에 더 쌓인 먼지·때
	float low = 1.0 - smoothstep(0.0, 0.5, fract(wpos.y / 3.6) * 3.6);
	stain += low * grime * 0.35 * (1.0 - wnorm.y * wnorm.y);
	vec3 dirt = c * vec3(0.62, 0.56, 0.48);
	c = mix(c, dirt, clamp(stain, 0.0, 0.85));
	// 미세한 색 차이 + 긁힘
	c *= 0.9 + 0.2 * mid;
	c *= 1.0 - smoothstep(0.78, 0.95, fine) * 0.18;
	// 윗면은 먼지가 살짝 덮여 뿌옇게
	c = mix(c, vec3(0.5, 0.49, 0.46) * lum + c * 0.5, max(wnorm.y, 0.0) * 0.12 * grime);
	ALBEDO = c;
	ROUGHNESS = clamp(rough_v + (mid - 0.5) * 0.25 + stain * 0.15, 0.05, 1.0);
	METALLIC = metallic_v * (1.0 - stain * 0.6);
	SPECULAR = 0.4;
}
