extends RefCounted
## 그래픽 분위기 설정 (하늘·조명·안개·빛 번짐·색감·떠다니는 먼지)
## main.gd 가 맵을 만든 뒤 apply() 를 부르고, 플레이어가 생기면 add_motes() 를 부릅니다.
## 맵마다 색감이 다름 (PROFILES): 도시 = 주황 도시 불빛이 깔린 지평선, 학교 = 차가운 달빛,
## 병원 = 병든 청록빛, 숲 = 별이 많은 깊은 남색 밤 + 땅안개
## 그래픽 품질 "낮음"(SaveData.graphics = "low")이면 무거운 효과(볼류메트릭 안개, 간접광, 가까운 불빛 그림자)는 끕니다.
## 숫자는 balance.cfg [graphics] 에서 바꿀 수 있어요.

const LightLod := preload("res://scripts/light_lod.gd")

## 맵별 색감
## sky_top / horizon / ground = 하늘 색, glow = 지평선에 깔린 불빛(도시 불빛), stars = 별 밝기
## ambient = 그늘 속 기본 빛 색, fog = 안개 색, moon = 달빛 색·세기, moon_pitch = 달 높이(라디안, 낮을수록 그림자가 길고 창문으로 깊이 들어옴)
## shadow_tint / high_tint = 어두운 곳·밝은 곳 색 틀기 (영화 같은 색 보정), sat = 채도, contrast = 대비
## height_fog = 땅 가까이 깔리는 안개 (숲·도시), mist = 볼류메트릭 땅안개 진하기 (Forward+ 만)
const PROFILES := {
	"city": {
		"sky_top": Color(0.012, 0.016, 0.035), "horizon": Color(0.085, 0.08, 0.1), "ground": Color(0.03, 0.03, 0.04),
		"glow": Color(0.55, 0.28, 0.1), "glow_amount": 0.45, "stars": 0.5,
		"ambient": Color(0.33, 0.36, 0.47), "fog": Color(0.15, 0.15, 0.2),
		"moon": Color(0.62, 0.7, 1.0), "moon_energy": 1.0, "moon_pitch": -0.68,
		"shadow_tint": Color(-0.012, 0.0, 0.03), "high_tint": Color(0.035, 0.012, -0.025), "sat": 0.9, "contrast": 1.12,
		"height_fog": 0.06, "mist": 0.025,
	},
	"school": {
		"sky_top": Color(0.01, 0.015, 0.035), "horizon": Color(0.07, 0.08, 0.11), "ground": Color(0.03, 0.03, 0.04),
		"glow": Color(0.25, 0.18, 0.12), "glow_amount": 0.15, "stars": 1.0,
		"ambient": Color(0.32, 0.36, 0.45), "fog": Color(0.13, 0.15, 0.2),
		"moon": Color(0.62, 0.72, 1.0), "moon_energy": 1.0, "moon_pitch": -0.62,
		"shadow_tint": Color(-0.012, 0.008, 0.025), "high_tint": Color(0.025, 0.015, -0.02), "sat": 0.88, "contrast": 1.12,
		"height_fog": 0.0, "mist": 0.0,
	},
	"hospital": {
		"sky_top": Color(0.01, 0.016, 0.03), "horizon": Color(0.065, 0.085, 0.09), "ground": Color(0.03, 0.035, 0.035),
		"glow": Color(0.2, 0.22, 0.18), "glow_amount": 0.12, "stars": 0.9,
		"ambient": Color(0.31, 0.37, 0.4), "fog": Color(0.13, 0.16, 0.18),
		"moon": Color(0.6, 0.75, 0.95), "moon_energy": 1.0, "moon_pitch": -0.62,
		"shadow_tint": Color(-0.015, 0.012, 0.012), "high_tint": Color(0.02, 0.02, -0.02), "sat": 0.8, "contrast": 1.14,
		"height_fog": 0.0, "mist": 0.0,
	},
	"forest": {
		"sky_top": Color(0.006, 0.01, 0.028), "horizon": Color(0.055, 0.07, 0.1), "ground": Color(0.02, 0.025, 0.035),
		"glow": Color(0.1, 0.12, 0.2), "glow_amount": 0.1, "stars": 1.5,
		"ambient": Color(0.3, 0.35, 0.48), "fog": Color(0.12, 0.14, 0.2),
		"moon": Color(0.6, 0.7, 1.0), "moon_energy": 1.15, "moon_pitch": -0.7,
		"shadow_tint": Color(-0.012, 0.0, 0.035), "high_tint": Color(0.03, 0.01, -0.02), "sat": 0.9, "contrast": 1.1,
		"height_fog": 0.12, "mist": 0.05,
	},
}


static func apply(main: Node3D, map_id: String) -> void:
	var high := SaveData.high_graphics()
	# 볼류메트릭 안개·SSAO·SSIL·SDFGI 는 Forward+ 전용 (호환 모드에서 켜면 경고만 나옴)
	var fplus := RenderingServer.get_current_rendering_method() == "forward_plus"
	var pr: Dictionary = PROFILES.get(map_id, PROFILES["city"])
	var env: Environment = (main.get("world_env") as WorldEnvironment).environment

	# --- 하늘: 별·달·지평선 불빛이 있는 밤하늘 (셰이더)
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = _sky_material(pr)
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.fog_sky_affect = 0.55

	# --- 그늘 속 기본 빛 (너무 새카맣지 않게, 실루엣이 읽히게)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = pr["ambient"]
	env.ambient_light_energy = GameConfig.num("graphics", "ambient", 0.55)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY  # 물웅덩이·유리에 하늘·불빛이 비침

	# --- 톤매핑: 필름 같은 ACES, 밝은 불빛은 부드럽게 눌림
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = GameConfig.num("graphics", "exposure", 1.15)

	# --- 거리 안개 (시야 거리는 balance.cfg [view] fog_density 그대로) + 땅에 깔리는 안개
	env.fog_light_color = pr["fog"]
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.2
	var hf: float = pr["height_fog"] * GameConfig.num("graphics", "ground_fog", 1.0)
	if hf > 0.0:
		env.fog_height = 0.6
		env.fog_height_density = hf

	# --- 볼류메트릭 안개: 빛이 안개 속에서 기둥·빛줄기처럼 보임 (높음 품질 + Forward+)
	env.volumetric_fog_enabled = high and fplus
	if high and fplus:
		env.volumetric_fog_density = GameConfig.num("graphics", "volumetric_fog", 0.02)
		env.volumetric_fog_albedo = Color(0.7, 0.72, 0.85)
		env.volumetric_fog_emission = (pr["fog"] as Color) * 0.06
		env.volumetric_fog_anisotropy = 0.55  # 빛 쪽을 볼 때 더 빛나게 (빛줄기·후광)
		env.volumetric_fog_length = 48.0
		env.volumetric_fog_detail_spread = 2.0
		env.volumetric_fog_ambient_inject = 0.15
		env.volumetric_fog_sky_affect = 0.3
		env.volumetric_fog_temporal_reprojection_enabled = true
		env.fog_density *= GameConfig.num("graphics", "distance_fog_scale", 0.75)  # 두 안개가 겹쳐 너무 진하지 않게
		_ground_mist(main, map_id, pr)

	# --- 빛 번짐: 창문·형광등·간판·눈빛이 은은하게 번짐 (밝은 것만)
	env.glow_enabled = true
	env.glow_intensity = GameConfig.num("graphics", "glow", 0.75)
	env.glow_strength = 1.0
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 0.9
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var levels := [0.0, 0.5, 1.0, 1.0, 0.8, 0.5, 0.0]
	for i in 7:
		env.set_glow_level(i, levels[i])

	# --- 그늘 깊이감: SSAO(구석·가구 밑 접촉 그림자), SSIL(불빛이 벽·바닥에 튀는 색), 선택: SDFGI 실시간 간접광
	env.ssao_enabled = fplus
	env.ssao_radius = 1.0
	env.ssao_intensity = 2.4
	env.ssao_power = 1.6
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.15  # 불빛 아래에서도 구석은 살짝 어둡게
	env.ssil_enabled = high and fplus
	env.ssil_radius = 4.0
	env.ssil_intensity = 1.1
	env.ssil_sharpness = 0.98
	env.ssil_normal_rejection = 1.0
	var use_sdfgi := high and fplus and GameConfig.num("graphics", "sdfgi", 0.0) > 0.0
	env.sdfgi_enabled = use_sdfgi
	if use_sdfgi:
		# 맵 크기(약 130~160m) + 안개 시야(30~40m)에 맞춘 가벼운 설정: 3단계, 가까운 칸 15cm
		env.sdfgi_cascades = 3
		env.sdfgi_min_cell_size = 0.15
		env.sdfgi_use_occlusion = true
		env.sdfgi_read_sky_light = map_id in ["city", "forest"]
		env.sdfgi_energy = GameConfig.num("graphics", "sdfgi_energy", 1.0)
		env.sdfgi_bounce_feedback = 0.4
		RenderingServer.gi_set_use_half_resolution(true)
		env.ssil_enabled = false  # SDFGI 가 대신함

	# --- 색감 보정: 어두운 곳은 차갑게(청록·남색), 불빛은 따뜻하게 → 불빛이 더 돋보임
	env.adjustment_enabled = true
	env.adjustment_brightness = GameConfig.num("graphics", "brightness", 1.0)
	env.adjustment_contrast = pr["contrast"] * GameConfig.num("graphics", "contrast", 1.0)
	env.adjustment_saturation = pr["sat"] * GameConfig.num("graphics", "saturation", 1.0)
	var grade := GameConfig.num("graphics", "grade", 1.0)
	env.adjustment_color_correction = _grade_texture(pr["shadow_tint"], pr["high_tint"], grade) if grade > 0.0 else null

	# --- 달빛: 맵 색에 맞춘 달빛. 달을 조금 낮춰서 그림자가 길고, 유리창 사이로 들어와 바닥에 창틀 모양을 그림
	var moon := main.get_node_or_null("Moon") as DirectionalLight3D
	if moon:
		moon.light_color = pr["moon"]
		moon.light_energy = GameConfig.num("graphics", "moon", 0.38) * float(pr["moon_energy"])
		moon.rotation.x = pr["moon_pitch"]
		moon.light_volumetric_fog_energy = 3.0
		moon.light_angular_distance = 0.5  # 부드러운 그림자 끝
		moon.shadow_blur = 1.5
		moon.shadow_bias = 0.05
		moon.directional_shadow_max_distance = 55.0 if high else 35.0
		moon.directional_shadow_blend_splits = high

	# --- 맵의 모든 불빛이 안개를 비추게 (따로 정하지 않은 불빛만)
	for l in main.find_children("*", "Light3D", true, false):
		if (l is OmniLight3D or l is SpotLight3D) and is_equal_approx((l as Light3D).light_volumetric_fog_energy, 1.0):
			(l as Light3D).light_volumetric_fog_energy = 1.6

	# --- 가까운 불빛 몇 개만 그림자 (천장등·가로등·모닥불이 가구·사람 그림자를 드리움)
	if high and GameConfig.num("graphics", "shadow_lights", 4.0) > 0.0:
		var lod := LightLod.new()
		lod.name = "LightLod"
		lod.max_shadows = int(GameConfig.num("graphics", "shadow_lights", 4.0))
		lod.radius = GameConfig.num("graphics", "shadow_light_range", 16.0)
		main.add_child(lod)


## 밤하늘 셰이더: 위는 깊은 남색, 지평선은 안개 색 + 도시 불빛, 별(정적), 달 원반과 달무리
## (TIME 을 쓰지 않아서 하늘 반사 지도는 한 번만 그림 → 가벼움)
static func _sky_material(pr: Dictionary) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type sky;
render_mode use_debanding;
uniform vec3 top_color : source_color;
uniform vec3 horizon_color : source_color;
uniform vec3 ground_color : source_color;
uniform vec3 glow_color : source_color;
uniform float glow_amount = 0.0;
uniform float star_amount = 1.0;
uniform vec3 moon_color : source_color = vec3(0.85, 0.9, 1.0);
uniform float moon_size = 0.035;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.11, 0.17, 0.13));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color, top_color, pow(smoothstep(0.0, 0.65, h), 0.6));
		col += glow_color * glow_amount * exp(-h * 9.0);
		if (!AT_CUBEMAP_PASS) {
			vec3 g = d * 150.0;
			vec3 cell = floor(g);
			float s = hash3(cell);
			if (s > 0.993) {
				float dist = length(g - (cell + 0.5));
				float b = (s - 0.993) / 0.007;
				col += vec3(0.8, 0.86, 1.0) * star_amount * (0.3 + b * b * 1.7) * smoothstep(0.55, 0.0, dist) * smoothstep(0.04, 0.3, h);
			}
		}
	} else {
		col = mix(horizon_color, ground_color, smoothstep(0.0, -0.2, h));
		col += glow_color * glow_amount * exp(h * 30.0) * 0.6;
	}
	if (LIGHT0_ENABLED) {
		float md = dot(d, LIGHT0_DIRECTION);
		float disc = smoothstep(cos(moon_size), cos(moon_size * 0.8), md);
		// 달 표면 얼룩
		float spots = 0.85 + 0.15 * sin(d.x * 300.0) * sin(d.z * 260.0 + 1.3);
		col = mix(col, moon_color * 2.2 * spots, disc);
		col += moon_color * (0.08 * pow(max(md, 0.0), 400.0) + 0.04 * pow(max(md, 0.0), 24.0));
	}
	COLOR = col;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("top_color", pr["sky_top"])
	m.set_shader_parameter("horizon_color", pr["horizon"])
	m.set_shader_parameter("ground_color", pr["ground"])
	m.set_shader_parameter("glow_color", pr["glow"])
	m.set_shader_parameter("glow_amount", pr["glow_amount"])
	m.set_shader_parameter("star_amount", pr["stars"])
	m.set_shader_parameter("moon_color", (pr["moon"] as Color).lerp(Color(1, 1, 0.95), 0.5))
	return m


## 색 보정 곡선 (빨강·초록·파랑 따로): 어두운 영역에 shadow_tint, 밝은 영역에 high_tint 를 더함
static func _grade_texture(shadow_tint: Color, high_tint: Color, amount: float) -> GradientTexture1D:
	var g := Gradient.new()
	var n := 17
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in n:
		var v := float(i) / float(n - 1)
		var sw := clampf(1.0 - v * 2.2, 0.0, 1.0) * minf(v * 10.0, 1.0)  # 어두운 곳 (완전 검정은 그대로)
		var hw := smoothstep(0.4, 1.0, v) * (1.0 - smoothstep(0.92, 1.0, v) * 0.6)  # 밝은 곳
		var c := Color(
			clampf(v + (shadow_tint.r * sw + high_tint.r * hw) * amount, 0.0, 1.0),
			clampf(v + (shadow_tint.g * sw + high_tint.g * hw) * amount, 0.0, 1.0),
			clampf(v + (shadow_tint.b * sw + high_tint.b * hw) * amount, 0.0, 1.0))
		offs.append(v)
		cols.append(c)
	g.offsets = offs
	g.colors = cols
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 256
	t.use_hdr = false
	return t


## 볼류메트릭 땅안개·지하 안개 (FogVolume, Forward+ 에서만 보임)
static func _ground_mist(main: Node3D, map_id: String, pr: Dictionary) -> void:
	var b = main.get("_builder")
	var half: float = float(b.get("half")) if b and b.get("half") != null else 80.0
	var mist: float = pr["mist"] * GameConfig.num("graphics", "ground_fog", 1.0)
	if mist > 0.0:
		_fog_volume(main, Vector3(0, 0.8, 0), Vector3(half * 2.0, 2.4, half * 2.0), mist, pr["fog"], true)
	if map_id == "hospital":
		# 지하층: 탁하고 무거운 공기
		_fog_volume(main, Vector3(0, -2.0, -21), Vector3(86, 3.8, 32), 0.05, Color(0.5, 0.45, 0.4), false)
	elif map_id == "school":
		# 본관 복도·교실에 떠 있는 먼지 (아주 옅게)
		_fog_volume(main, Vector3(0, 4.0, -52), Vector3(88, 8, 28), 0.012, Color(0.6, 0.6, 0.65), false)


static func _fog_volume(main: Node3D, pos: Vector3, size: Vector3, density: float, col: Color, patchy: bool) -> void:
	var fv := FogVolume.new()
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fv.size = size
	fv.position = pos
	var fm := FogMaterial.new()
	fm.density = density
	fm.albedo = col.lerp(Color(0.8, 0.82, 0.9), 0.6)
	fm.height_falloff = 0.6 if patchy else 0.0
	fm.edge_fade = 0.3
	if patchy:
		var nt := NoiseTexture3D.new()
		nt.width = 64
		nt.height = 16
		nt.depth = 64
		nt.seamless = true
		var fn := FastNoiseLite.new()
		fn.frequency = 0.05
		fn.fractal_octaves = 3
		nt.noise = fn
		fm.density_texture = nt
	fv.material = fm
	main.add_child(fv)


## 플레이어 주위에 떠다니는 빛 먼지 (반딧불 같은 작은 점들). 플레이어를 따라다님
static func add_motes(player: Node3D, map_id: String) -> void:
	var p := CPUParticles3D.new()
	player.add_child(p)
	p.position = Vector3(0, 2.0, 0)
	p.local_coords = false
	p.amount = 180 if SaveData.high_graphics() else 60
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(14, 3.5, 14)
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.3
	p.gravity = Vector3(0, 0.03, 0)
	p.scale_amount_min = 0.015
	p.scale_amount_max = 0.04
	var dot := SphereMesh.new()
	dot.radius = 1.0
	dot.height = 2.0
	dot.radial_segments = 6
	dot.rings = 3
	p.mesh = dot
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_fog = true
	p.material_override = m
	var grad := Gradient.new()
	var c := Color(0.75, 0.7, 1.0) if map_id == "forest" else Color(1.0, 0.85, 0.6)
	grad.set_color(0, Color(c, 0.0))
	grad.add_point(0.3, Color(c, 0.9))
	grad.add_point(0.7, Color(c, 0.7))
	grad.set_color(grad.get_point_count() - 1, Color(c, 0.0))
	p.color_ramp = grad
	p.emitting = true
