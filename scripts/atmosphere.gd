extends RefCounted
## 그래픽 분위기 설정 (조명·안개·빛 번짐·색감·떠다니는 먼지)
## main.gd 가 맵을 만든 뒤 apply() 를 부르고, 플레이어가 생기면 add_motes() 를 부릅니다.
## 그래픽 품질 "낮음"(SaveData.graphics = "low")이면 무거운 효과(볼류메트릭 안개, 간접광)는 끕니다.
## 숫자는 balance.cfg [graphics] 에서 바꿀 수 있어요.


static func apply(main: Node3D, map_id: String) -> void:
	var high := SaveData.high_graphics()
	var forest := map_id == "forest"
	var env: Environment = (main.get("world_env") as WorldEnvironment).environment

	# --- 하늘·주변광: 보랏빛이 도는 깊은 밤
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	if sky:
		sky.sky_top_color = Color(0.025, 0.025, 0.07)
		sky.sky_horizon_color = Color(0.13, 0.11, 0.22)
		sky.ground_horizon_color = Color(0.13, 0.11, 0.22)
		sky.ground_bottom_color = Color(0.05, 0.05, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.33, 0.34, 0.45) if forest else Color(0.3, 0.31, 0.42)
	env.ambient_light_energy = GameConfig.num("graphics", "ambient", 0.55)

	# --- 거리 안개 (시야 거리는 balance.cfg [view] fog_density 그대로, 색만 보랏빛 청록)
	env.fog_light_color = Color(0.16, 0.15, 0.26) if forest else Color(0.15, 0.16, 0.24)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.15

	# --- 볼류메트릭 안개: 빛이 안개 속에서 기둥·빛줄기처럼 보임 (높음 품질만)
	env.volumetric_fog_enabled = high
	if high:
		env.volumetric_fog_density = GameConfig.num("graphics", "volumetric_fog", 0.02)
		env.volumetric_fog_albedo = Color(0.62, 0.62, 0.85)
		env.volumetric_fog_emission = Color(0.012, 0.01, 0.025)
		env.volumetric_fog_anisotropy = 0.45
		env.volumetric_fog_length = 48.0
		env.volumetric_fog_detail_spread = 2.0
		env.volumetric_fog_ambient_inject = 0.25
		env.volumetric_fog_sky_affect = 0.3
		env.fog_density *= GameConfig.num("graphics", "distance_fog_scale", 0.75)  # 두 안개가 겹쳐 너무 진하지 않게

	# --- 빛 번짐 (봉인석·불빛·이펙트가 은은하게 번짐)
	env.glow_enabled = true
	env.glow_intensity = GameConfig.num("graphics", "glow", 0.75)
	env.glow_strength = 1.0
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for i in 7:
		env.set_glow_level(i, i >= 2 and i <= 5)

	# --- 그림자 진 곳의 깊이감 + 색감 보정
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.0
	env.ssil_enabled = high
	env.ssil_intensity = 0.8
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 0.95
	env.adjustment_brightness = 1.0

	# --- 달빛: 푸른 보랏빛, 안개 속에서 빛줄기가 보이게
	var moon := main.get_node_or_null("Moon") as DirectionalLight3D
	if moon:
		moon.light_color = Color(0.62, 0.66, 1.0)
		moon.light_energy = GameConfig.num("graphics", "moon", 0.38)
		moon.light_volumetric_fog_energy = 3.0
		moon.shadow_blur = 1.5
		moon.directional_shadow_max_distance = 55.0 if high else 35.0

	# --- 맵의 모든 불빛이 안개를 비추게 (봉인석·모닥불·랜턴·가로등)
	for l in main.find_children("*", "Light3D", true, false):
		if l is OmniLight3D or l is SpotLight3D:
			(l as Light3D).light_volumetric_fog_energy = 1.6


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
