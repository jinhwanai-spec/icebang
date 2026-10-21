class_name ForestBuilder
extends LevelBuilder
## 두 번째 맵: 안개 낀 숲속 폐캠핑장
## - 160m x 160m. 빽빽한 나무와 바위, 오두막, 텐트, 모닥불, 키 큰 풀숲이 많음
## - 도시보다 시야를 가리는 것이 많고 숨을 곳(풀숲)이 많지만, 길이 구불구불함
## - 재질·나무·풀숲 만드는 함수는 LevelBuilder 것을 그대로 물려받아 씀

## 봉인석이 놓이는 공터 6곳 (나무를 심지 않는 곳)
const CLEARINGS := [
	Vector3(-48, 0, 16), Vector3(-13, 0, 51), Vector3(45, 0, 48), Vector3(51, 0, -16),
	Vector3(10, 0, -35), Vector3(-10, 0, 6), Vector3(-55, 0, -45), Vector3(60, 0, -60),
]
const CLEARING_RADIUS := 6.0


func build(target: Node3D, map_seed: int) -> void:
	region = target
	rng.seed = map_seed
	_make_materials()
	kit = BuildingKit.new(self)
	floor_levels = [0.0]
	_mat["forest_floor"] = _textured_ground() if _has_tex("forrest_ground_01") else _forest_floor_mat()
	_mat["bark"] = _bark_mat()
	_mat["canopy"] = _noise_mat(Color(0.07, 0.13, 0.08), 0.55, 1.0, 2.5)
	_mat["canvas"] = _noise_mat(Color(0.34, 0.3, 0.2), 0.45, 0.95, 1.5)
	_mat["charred"] = _flat_mat(Color(0.06, 0.05, 0.05), 0.95)
	_mat["rock"] = _tex_mat("rock_moss_set_01", 1.5, Color(1, 1, 1)) if _has_tex("rock_moss_set_01") else _noise_mat(Color(0.38, 0.38, 0.36), 0.5, 0.95, 2.0)
	_mat["log"] = _tex_mat("moss_wood", 1.2, Color(0.85, 0.8, 0.75)) if _has_tex("moss_wood") else _noise_mat(Color(0.32, 0.22, 0.13), 0.5, 1.0, 1.5)
	_mat["roof"] = _tex_mat("moss_wood", 1.6, Color(0.6, 0.55, 0.5)) if _has_tex("moss_wood") else _noise_mat(Color(0.22, 0.16, 0.12), 0.4, 1.0, 2.0)
	_mat["tent"] = _flat_mat(Color(0.55, 0.3, 0.15), 0.9)

	_mark_indestructible(_box(Vector3(0, -0.5, 0), Vector3(HALF * 2, 1, HALF * 2), _mat["forest_floor"]))
	_outer_walls()
	for c in CLEARINGS:
		generator_spots.append(c + Vector3.UP * 0.02)
	_paths()
	_cabins()
	_camp_sites()
	_forest()
	_lantern_posts()
	_scatter_floor()
	_flush_batches()


## 흙길: 스폰에서 각 공터로 이어지는 밝은 길 (장식, 충돌 없음)
func _paths() -> void:
	if _has_tex("forrest_ground_01"):
		return  # 진짜 질감 바닥에서는 바닥 셰이더가 흙길을 부드럽게 그려 줌
	var dirt := _noise_mat(Color(0.3, 0.26, 0.18), 0.35, 1.0, 3.0)
	var start := Vector3(SURVIVOR_SPAWNS[0].x, 0, SURVIVOR_SPAWNS[0].z)
	var points := [start] + CLEARINGS + [Vector3(SEEKER_SPAWN.x, 0, SEEKER_SPAWN.z)]
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var mid := (a + b) / 2.0
		var length := a.distance_to(b)
		var yaw := atan2(b.x - a.x, b.z - a.z)
		_box(Vector3(mid.x, 0.005, mid.z), Vector3(2.6, 0.01, length), dirt, false, yaw)


# ================================================================ 재질

# ================================================================ 진짜 질감 (assets/textures, Poly Haven CC0)

const TEX_DIR := "res://assets/textures/%s/%s_%s.%s"


func _has_tex(name: String) -> bool:
	return ResourceLoader.exists(TEX_DIR % [name, name, "diff", "jpg"])


func _tex(name: String, kind: String) -> Texture2D:
	var path := TEX_DIR % [name, name, kind, "jpg" if kind == "diff" else "png"]
	return load(path) if ResourceLoader.exists(path) else null


## 질감 하나로 만든 재질 (어느 방향에서 봐도 늘어나지 않게 월드 좌표로 입힘)
func _tex_mat(name: String, tile_m: float, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(name, "diff")
	m.albedo_color = tint
	var n := _tex(name, "nor")
	if n:
		m.normal_enabled = true
		m.normal_texture = n
		m.normal_scale = 1.2
	var r := _tex(name, "rough")
	if r:
		m.roughness_texture = r
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / tile_m
	return m


## 숲 바닥 셰이더: 이끼 숲 바닥(기본) + 흙길·캠프 주변 진흙 낙엽 + 봉인석 공터 자갈 흙을
## 부드럽게 섞어서 그림. 큰 얼룩 노이즈로 바닥이 반복돼 보이지 않게 함
const GROUND_SHADER := """
shader_type spatial;
uniform sampler2D a_col : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D a_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D a_rgh : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D b_col : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D b_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D c_col : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D c_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D big_noise : filter_linear, repeat_enable;
uniform float tile = 3.5;
uniform vec4 segs[9];
uniform vec3 clears[8];
uniform float path_width = 1.6;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
	return length(pa - ba * h);
}
void fragment() {
	vec2 p = wp.xz;
	vec2 uv = p / tile;
	float n = texture(big_noise, p / 55.0).r;
	float n2 = texture(big_noise, p / 13.0 + vec2(0.37, 0.71)).r;
	// 흙길까지의 거리 (구불구불하게 노이즈로 흔듦)
	float d = 1e5;
	for (int i = 0; i < 9; i++) { d = min(d, seg_dist(p, segs[i].xy, segs[i].zw)); }
	d += (n2 - 0.5) * 1.6;
	float mud = 1.0 - smoothstep(path_width * 0.6, path_width * 1.4, d);
	mud = max(mud, smoothstep(0.62, 0.8, n) * 0.85);  // 숲 곳곳의 진흙 웅덩이
	// 봉인석 공터
	float clr = 0.0;
	for (int i = 0; i < 8; i++) { clr = max(clr, 1.0 - smoothstep(clears[i].z * 0.55, clears[i].z * 1.05, length(p - clears[i].xy) + (n2 - 0.5) * 2.0)); }
	vec3 ca = texture(a_col, uv).rgb;
	vec3 cb = texture(b_col, uv * 0.8).rgb;
	vec3 cc = texture(c_col, uv * 1.1).rgb;
	vec3 na = texture(a_nor, uv).rgb;
	vec3 nb = texture(b_nor, uv * 0.8).rgb;
	vec3 nc = texture(c_nor, uv * 1.1).rgb;
	vec3 col = mix(ca, cb, mud);
	vec3 nor = mix(na, nb, mud);
	col = mix(col, cc, clr);
	nor = mix(nor, nc, clr);
	// 큰 얼룩으로 밝기·색을 조금씩 다르게 (반복 무늬가 안 보이게)
	col *= mix(0.5, 0.8, n) * vec3(0.9, 1.0, 0.85);  // 밤 숲답게 어둡고 살짝 초록빛
	ALBEDO = col;
	NORMAL_MAP = nor;
	NORMAL_MAP_DEPTH = 1.3;
	ROUGHNESS = mix(texture(a_rgh, uv).r, 0.75, mud * 0.6);
}
"""


func _textured_ground() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = GROUND_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("a_col", _tex("forrest_ground_01", "diff"))
	m.set_shader_parameter("a_nor", _tex("forrest_ground_01", "nor"))
	m.set_shader_parameter("a_rgh", _tex("forrest_ground_01", "rough"))
	var b := "brown_mud_leaves_01" if _has_tex("brown_mud_leaves_01") else "forrest_ground_01"
	var c := "forest_ground_04" if _has_tex("forest_ground_04") else "forrest_ground_01"
	m.set_shader_parameter("b_col", _tex(b, "diff"))
	m.set_shader_parameter("b_nor", _tex(b, "nor"))
	m.set_shader_parameter("c_col", _tex(c, "diff"))
	m.set_shader_parameter("c_nor", _tex(c, "nor"))
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	nt.noise = noise
	m.set_shader_parameter("big_noise", nt)
	# 흙길: 스폰 → 공터들 → 술래 시작 지점
	var start := Vector3(SURVIVOR_SPAWNS[0].x, 0, SURVIVOR_SPAWNS[0].z)
	var points := [start] + CLEARINGS + [Vector3(SEEKER_SPAWN.x, 0, SEEKER_SPAWN.z)]
	var segs: Array = []
	for i in 9:
		var a: Vector3 = points[mini(i, points.size() - 2)]
		var e: Vector3 = points[mini(i + 1, points.size() - 1)]
		segs.append(Vector4(a.x, a.z, e.x, e.z))
	m.set_shader_parameter("segs", segs)
	var clears: Array = []
	for c2 in CLEARINGS:
		clears.append(Vector3(c2.x, c2.z, CLEARING_RADIUS))
	m.set_shader_parameter("clears", clears)
	return m


## 숲 바닥: 이끼·흙·낙엽이 섞인 얼룩 + 울퉁불퉁한 입체감
func _forest_floor_mat() -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.035
	noise.fractal_octaves = 5
	noise.fractal_gain = 0.55
	var grad := Gradient.new()
	grad.set_color(0, Color(0.08, 0.1, 0.05))
	grad.set_color(1, Color(0.3, 0.26, 0.16))
	grad.add_point(0.3, Color(0.16, 0.25, 0.08))
	grad.add_point(0.55, Color(0.22, 0.32, 0.11))
	grad.add_point(0.78, Color(0.25, 0.21, 0.12))
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = grad
	var bump := FastNoiseLite.new()
	bump.seed = rng.randi()
	bump.frequency = 0.08
	bump.fractal_octaves = 4
	var ntex := NoiseTexture2D.new()
	ntex.width = 512
	ntex.height = 512
	ntex.seamless = true
	ntex.noise = bump
	ntex.as_normal_map = true
	ntex.bump_strength = 7.0
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.normal_enabled = true
	m.normal_texture = ntex
	m.normal_scale = 1.1
	m.roughness = 0.97
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 4.0
	return m


## 나무껍질: 세로로 갈라진 무늬
func _bark_mat() -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.05
	noise.fractal_octaves = 4
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	var grad := Gradient.new()
	grad.set_color(0, Color(0.08, 0.06, 0.05))
	grad.set_color(1, Color(0.27, 0.22, 0.17))
	var tex := NoiseTexture2D.new()
	tex.width = 128
	tex.height = 512
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = grad
	var ntex := NoiseTexture2D.new()
	ntex.width = 128
	ntex.height = 512
	ntex.seamless = true
	ntex.noise = noise
	ntex.as_normal_map = true
	ntex.bump_strength = 8.0
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.normal_enabled = true
	m.normal_texture = ntex
	m.roughness = 0.95
	m.vertex_color_use_as_albedo = true
	m.uv1_scale = Vector3(3.0, 1.0, 1.0)
	return m


# ================================================================ 큰 나무 (키 큰 줄기 + 뿌리 + 높은 곳의 잎 덩어리)

func _tree(pos: Vector3) -> void:
	var h := rng.randf_range(7.0, 11.0)
	var r := rng.randf_range(0.28, 0.45)
	_prop(pos, 0.0, Vector3(r * 2.0, 3.0, r * 2.0))  # 부딪히는 부분 (줄기)
	var trunk := _shared_mesh("trunk")
	var yaw := rng.randf() * TAU
	var tint := Color(1, 1, 1).darkened(rng.randf_range(0.0, 0.3))
	_batch("trunk", trunk, _mat["bark"], Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(r, h, r)), pos + Vector3.UP * h / 2.0), tint)
	# 뿌리: 줄기 밑에서 바깥으로 비스듬히 뻗어 땅에 반쯤 묻힘
	for k in rng.randi_range(3, 5):
		var a := yaw + TAU * k / 5.0 + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0, sin(a))
		var len := rng.randf_range(0.9, 1.6)
		# 캡슐의 긴 축(Y)을 바깥·아래쪽으로 눕힘
		var axis := (out + Vector3.DOWN * 0.3).normalized()
		var side := axis.cross(Vector3.UP).normalized()
		var basis := Basis(side, axis, side.cross(axis))
		_batch("root", _shared_mesh("root"), _mat["bark"], Transform3D(basis * Basis.from_scale(Vector3(r * 0.45, len * 0.5, r * 0.45)), pos + out * (r + len * 0.35) + Vector3.UP * 0.08), tint)
	# 잎 덩어리: 높은 곳에 여러 개 (아래는 탁 트여서 줄기만 보임)
	var leaf_tint := Color(rng.randf_range(0.75, 1.1), rng.randf_range(0.8, 1.1), rng.randf_range(0.8, 1.05))
	for k in rng.randi_range(4, 6):
		var off := Vector3(rng.randf_range(-1.8, 1.8), rng.randf_range(-0.3, 1.6), rng.randf_range(-1.8, 1.8))
		var sz := rng.randf_range(1.5, 2.6)
		_batch("canopy", _shared_mesh("blob"), _mat["canopy"], Transform3D(Basis().scaled(Vector3(sz, sz * 0.7, sz)), pos + Vector3.UP * (h * 0.85) + off), leaf_tint)
	# 굵은 가지 2개 (줄기에서 비스듬히 위로)
	for k in 2:
		var a := yaw + PI * k + rng.randf_range(-0.5, 0.5)
		var out := Vector3(cos(a), 0, sin(a))
		var axis := (out + Vector3.UP * 1.2).normalized()
		var side := axis.cross(Vector3.UP).normalized()
		var basis := Basis(side, axis, side.cross(axis))
		var len := rng.randf_range(1.8, 2.8)
		var start := pos + Vector3.UP * (h * rng.randf_range(0.55, 0.7))
		_batch("branch", _shared_mesh("trunk"), _mat["bark"], Transform3D(basis * Basis.from_scale(Vector3(r * 0.35, len, r * 0.35)), start + axis * len * 0.5), tint)


var _meshes := {}
func _shared_mesh(id: String) -> Mesh:
	if _meshes.has(id):
		return _meshes[id]
	var m: Mesh
	match id:
		"trunk":
			var c := CylinderMesh.new()
			c.top_radius = 0.55
			c.bottom_radius = 1.0
			c.height = 1.0
			c.radial_segments = 10
			c.rings = 1
			m = c
		"root":
			var c := CapsuleMesh.new()
			c.radius = 0.5
			c.height = 2.0
			c.radial_segments = 8
			c.rings = 2
			m = c
		"blob":
			var s := SphereMesh.new()
			s.radius = 1.0
			s.height = 2.0
			s.radial_segments = 12
			s.rings = 6
			m = s
	_meshes[id] = m
	return m


# ================================================================ 숲 바닥 장식 (부딪히지 않음)

func _scatter_floor() -> void:
	var high := SaveData.high_graphics()
	var leaf := QuadMesh.new()
	leaf.size = Vector2(0.15, 0.1)
	leaf.orientation = PlaneMesh.FACE_Y
	var leaf_colors := [Color(0.28, 0.18, 0.09), Color(0.33, 0.24, 0.12), Color(0.22, 0.22, 0.1), Color(0.25, 0.13, 0.07), Color(0.18, 0.15, 0.08)]
	var real_ground := _has_tex("forrest_ground_01")  # 진짜 질감 바닥에는 이미 낙엽·이끼가 그려져 있어서 조금만
	for i in ((2500 if real_ground else 22000) if high else (800 if real_ground else 7000)):
		var p := Vector3(rng.randf_range(-HALF + 2, HALF - 2), 0.012 + rng.randf() * 0.01, rng.randf_range(-HALF + 2, HALF - 2))
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.25, 0.25))
		var s := rng.randf_range(0.7, 1.5)
		_batch("leaf", leaf, _tint_mat(0.9, true), Transform3D(b.scaled(Vector3.ONE * s), p), leaf_colors[rng.randi() % leaf_colors.size()].darkened(rng.randf() * 0.3), false)
	# 이끼 덩어리
	var moss := SphereMesh.new()
	moss.radius = 1.0
	moss.height = 2.0
	moss.radial_segments = 10
	moss.rings = 5
	for i in ((0 if real_ground else 700) if high else (0 if real_ground else 300)):
		var p := Vector3(rng.randf_range(-HALF + 2, HALF - 2), 0.0, rng.randf_range(-HALF + 2, HALF - 2))
		var s := rng.randf_range(0.25, 0.7)
		_batch("moss", moss, _tint_mat(1.0), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 0.22, s * rng.randf_range(0.7, 1.3))), p),
				Color(0.22, 0.4, 0.12).lightened(rng.randf() * 0.15), false)
	# 자갈
	var pebble := SphereMesh.new()
	pebble.radius = 1.0
	pebble.height = 2.0
	pebble.radial_segments = 6
	pebble.rings = 3
	for i in (1400 if high else 500):
		var p := Vector3(rng.randf_range(-HALF + 2, HALF - 2), 0.02, rng.randf_range(-HALF + 2, HALF - 2))
		var s := rng.randf_range(0.04, 0.14)
		_batch("pebble", pebble, _tint_mat(0.9), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * 1.3, s * 0.6, s)), p),
				Color(0.3, 0.3, 0.3).darkened(rng.randf() * 0.4), false)
	# 떨어진 잔가지
	var twig := CylinderMesh.new()
	twig.top_radius = 0.6
	twig.bottom_radius = 1.0
	twig.height = 1.0
	twig.radial_segments = 4
	twig.rings = 1
	for i in (900 if high else 300):
		var p := Vector3(rng.randf_range(-HALF + 2, HALF - 2), 0.03, rng.randf_range(-HALF + 2, HALF - 2))
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.FORWARD, PI / 2.0 + rng.randf_range(-0.1, 0.1))
		var len := rng.randf_range(0.4, 1.4)
		_batch("twig", twig, _tint_mat(0.95), Transform3D(b * Basis.from_scale(Vector3(0.025, len, 0.025)), p), Color(0.2, 0.15, 0.1).darkened(rng.randf() * 0.4), false)


## 길가의 랜턴 기둥 (일부만 켜져 있음)
func _lantern_posts() -> void:
	for i in 26:
		var p := Vector3(rng.randf_range(-HALF + 8, HALF - 8), 0, rng.randf_range(-HALF + 8, HALF - 8))
		if i < 14:
			# 절반 이상은 공터 가장자리에 (숲 아무 데나 꽂힌 막대처럼 보이지 않게)
			var cl: Vector3 = CLEARINGS[i % CLEARINGS.size()]
			var a := rng.randf() * TAU
			p = Vector3(cl.x + cos(a) * (CLEARING_RADIUS - 0.6), 0, cl.z + sin(a) * (CLEARING_RADIUS - 0.6))
		if _near_spawn(p, 5.0):
			continue
		var in_cabin := false
		for cr in _cabin_rects:
			if (cr as Rect2).grow(1.5).has_point(Vector2(p.x, p.z)):
				in_cabin = true
		if in_cabin:
			continue
		var body := _prop(p, rng.randf() * TAU, Vector3(0.25, 2.2, 0.25))
		var pole := CylinderMesh.new()
		pole.top_radius = 0.065
		pole.bottom_radius = 0.085
		pole.height = 2.25
		pole.radial_segments = 8
		var post := _part(body, Vector3(0, 1.12, 0), pole, _mat["log"])
		post.rotation.z = rng.randf_range(-0.04, 0.04)
		# 밑동: 땅에 박은 돌 몇 개 + 비스듬한 버팀목
		for k in 3:
			var ka := k * TAU / 3.0 + rng.randf() * 0.5
			var st := _part(body, Vector3(cos(ka) * 0.16, 0.06, sin(ka) * 0.16), _box_mesh(Vector3(0.18, 0.12, 0.15)), _mat["rock"] if _mat.has("rock") else _mat["log"])
			st.rotation.y = ka
		var brace := _part(body, Vector3(-0.18, 0.35, 0), _box_mesh(Vector3(0.05, 0.75, 0.05)), _mat["log"])
		brace.rotation.z = -0.5
		# 팔 + 버팀대 + 고리에 매단 랜턴
		_part(body, Vector3(0.22, 2.1, 0), _box_mesh(Vector3(0.5, 0.06, 0.06)), _mat["log"])
		var kn := _part(body, Vector3(0.12, 1.98, 0), _box_mesh(Vector3(0.04, 0.26, 0.04)), _mat["log"])
		kn.rotation.z = 0.8
		_part(body, Vector3(0.4, 2.03, 0), _box_mesh(Vector3(0.015, 0.12, 0.015)), _mat["metal"])
		_lantern(body, Vector3(0.4, 1.84, 0), rng.randf() < 0.45)


## 작은 랜턴 (켜져 있으면 따뜻한 빛)
func _lantern(parent: Node3D, local: Vector3, lit: bool) -> void:
	_part(parent, local, _box_mesh(Vector3(0.17, 0.25, 0.17)), _mat["metal"])
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(1.0, 0.75, 0.4) if lit else Color(0.15, 0.15, 0.13)
	if lit:
		glass.emission_enabled = true
		glass.emission = Color(1.0, 0.6, 0.25)
		glass.emission_energy_multiplier = 2.5
	_part(parent, local, _box_mesh(Vector3(0.12, 0.19, 0.19)), glass)
	_part(parent, local, _box_mesh(Vector3(0.19, 0.19, 0.12)), glass)
	if lit:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.65, 0.35)
		light.omni_range = 6.0
		light.light_energy = 1.3
		light.position = local
		parent.add_child(light)
		LightFX.practical(light, 35.0, false)
		LightFX.flicker(light, "fire", [glass])


## 오두막 4채 (통나무 벽 + 지붕). 안에 들어갈 수는 없고 엄폐물 역할
func _cabins() -> void:
	for spot in [Vector3(-32, 0, -29), Vector3(29, 0, 19), Vector3(-54, 0, 54), Vector3(58, 0, -54),
			Vector3(-62, 0, -8), Vector3(20, 0, 66), Vector3(66, 0, 30), Vector3(-30, 0, -66)]:
		if _blocked(spot, 7.0):
			continue
		_cabin(spot)


## 들어갈 수 있는 통나무 오두막: 문, 창문, 침대·탁자·옷장(숨는 곳)·벽난로
func _cabin(spot: Vector3) -> void:
	var w := rng.randf_range(9.0, 11.0)
	var d := rng.randf_range(7.5, 8.5)
	var r := Rect2(spot.x - w * 0.5, spot.z - d * 0.5, w, d)
	_cabin_rects.append(r)
	var h := 3.3
	# 안쪽 마감: 아래쪽 나무 판넬, 위는 통나무 그대로
	kit.wainscot_mat = _mat["crate"]
	kit.wainscot_h = 1.0
	kit.trim_col = Color(0.22, 0.15, 0.09)
	kit.room_h = h
	var key := "w_log"
	var sides := [
		[Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0, r.position.y)],
		[Vector3(r.end.x, 0, r.position.y), Vector3(r.end.x, 0, r.end.y)],
		[Vector3(r.end.x, 0, r.end.y), Vector3(r.position.x, 0, r.end.y)],
		[Vector3(r.position.x, 0, r.end.y), Vector3(r.position.x, 0, r.position.y)],
	]
	var door_side := rng.randi() % 4
	for si in 4:
		var a: Vector3 = sides[si][0]
		var b: Vector3 = sides[si][1]
		var L := Vector2(b.x - a.x, b.z - a.z).length()
		var dir := (b - a).normalized()
		var ops := []
		if si == door_side:
			ops.append([L * 0.5 - 0.9, L * 0.5 + 0.9, 0.0, 2.3])
			var dc := a + dir * (L * 0.5)
			kit._door_frame(dc, dir, Color(0.25, 0.17, 0.1))
			if rng.randf() < 0.6:
				props.append(["door", dc, atan2(dir.z, -dir.x) + PI, 1.7])
		else:
			ops.append([L * 0.5 - 0.6, L * 0.5 + 0.6, 1.0, 2.0])
			var gc := a + dir * (L * 0.5)
			gc.y = 1.5
			var lit := rng.randf() < 0.5
			kit.block(gc, Vector3(1.2, 1.0, 0.04), _deco_mat("lit" if lit else "glass"), "b_" + ("lit" if lit else "glass"), true, Basis(dir, Vector3.UP, dir.cross(Vector3.UP).normalized()), false, Color(1.0, 0.65, 0.3, 0.5) if lit else Color(0.06, 0.07, 0.08))
			# 창문 십자 창살 + 창턱
			var yawc := atan2(-dir.z, dir.x)
			kit.part(gc, Vector3(1.2, 0.06, 0.36), Color(0.25, 0.17, 0.1), "trim", false, yawc)
			kit.part(gc, Vector3(0.06, 1.0, 0.36), Color(0.25, 0.17, 0.1), "trim", false, yawc)
			kit.part(gc + Vector3.UP * -0.53, Vector3(1.4, 0.06, 0.45), Color(0.3, 0.2, 0.12), "trim", false, yawc)
		var cn := dir.cross(Vector3.UP).normalized()
		var to_c := Vector3(spot.x, 0, spot.z) - (a + b) * 0.5
		kit.wall(a, b, 0.0, h, _mat["log"], key, ops, 0.3, 1 if cn.dot(to_c) > 0.0 else -1)
	# 모서리 통나무 기둥
	for x in [r.position.x, r.end.x]:
		for z in [r.position.y, r.end.y]:
			_bx("trim", Vector3(x, h * 0.5, z), Vector3.RIGHT, Vector3.BACK, Vector3(0.42, h + 0.2, 0.42), Color(0.28, 0.2, 0.13))
	# 바닥·지붕 (지붕 위는 길 계산에서 뺌)
	kit.slab(r.grow(-0.15), 0.06, _mat["crate"], "w_cabin_floor", [], false, 0.06)
	kit.slab(r.grow(0.1), h + 0.15, _mat["roof"], "w_roof", [], true, 0.3)
	var roof := PrismMesh.new()
	roof.size = Vector3(w + 0.9, 1.6, d + 0.9)
	var rm := MeshInstance3D.new()
	rm.mesh = roof
	rm.material_override = _mat["roof"]
	rm.position = Vector3(spot.x, h + 1.1, spot.z)
	region.add_child(rm)
	kit.wainscot_mat = null
	# 바닥 깔개·천장 들보·매달린 랜턴
	kit.floor_overlay(r.grow(-0.3), 0.06, _mat["in_wood"])
	kit.part(Vector3(spot.x, 0.075, spot.z), Vector3(2.6, 0.01, 1.8), Color(0.45, 0.15, 0.12), "trim")
	kit.part(Vector3(spot.x, 0.08, spot.z), Vector3(2.2, 0.01, 1.4), Color(0.6, 0.45, 0.25), "trim")
	for i in 3:
		var bx := r.position.x + (i + 1) * r.size.x / 4.0
		kit.part(Vector3(bx, h - 0.2, spot.z), Vector3(0.3, 0.3, d - 0.3), Color(0.26, 0.18, 0.11), "trim")
	kit.part(Vector3(spot.x, h - 0.75, spot.z), Vector3(0.02, 0.9, 0.02), Color(0.1, 0.1, 0.1), "metal")
	kit.part(Vector3(spot.x, h - 1.3, spot.z), Vector3(0.22, 0.3, 0.22), Color(1.0, 0.7, 0.35) if rng.randf() < 0.4 else Color(0.2, 0.18, 0.15), "lit")
	kit.grime(r.grow(-0.4), 0.075, h, 0.6, 0.2)
	# 살림살이: 침대, 탁자, 옷장(숨는 곳), 벽난로(불빛) — 문 앞은 비움
	var inner := r.grow(-0.5)
	var ddir: Vector3 = [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)][door_side]
	var dpos := Vector3(spot.x, 0, spot.z) + Vector3(ddir.x * w * 0.5, 0, ddir.z * d * 0.5)
	kit.door_clear = Rect2(dpos.x - 1.4, dpos.z - 2.8, 2.8, 5.6) if door_side % 2 == 0 else Rect2(dpos.x - 2.8, dpos.z - 1.4, 5.6, 2.8)
	# 벽난로 자리는 비워 두고(가구 겹침 방지) 옛날식 살림으로
	var fire_z := inner.position.y + 0.4 if door_side != 0 else inner.end.y - 0.4
	kit.reserved = [Rect2(inner.get_center().x - 1.2, fire_z - 0.9, 2.4, 1.8)]
	kit.rustic = true
	kit.furnish(inner, 0.06, "apartment", true)
	kit.rustic = false
	kit.reserved = []
	debug_rooms.append([{"rect": r.grow(-0.3), "kind": "cabin", "name": "cabin", "door_at": dpos, "door_along_x": door_side % 2 == 0}, 0.06])
	kit._along_wall(inner, (door_side + 1) % 4, 0.45, 1.9, 0.06, func(p, yw): if kit.rng.randf() < 0.6: kit._rack(p, yw))
	kit._maybe_locker(inner, 0.06, 1.0)
	kit.door_clear = Rect2()
	var fire := Vector3(inner.get_center().x, 0.06, inner.position.y + 0.4) if door_side != 0 else Vector3(inner.get_center().x, 0.06, inner.end.y - 0.4)
	kit.part(fire + Vector3.UP * 0.6, Vector3(1.2, 1.2, 0.6), Color(0.35, 0.33, 0.32), "trim", true)
	kit.part(fire + Vector3.UP * 0.4, Vector3(0.7, 0.5, 0.62), Color(0.05, 0.03, 0.02), "trim")
	if rng.randf() < 0.6:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.5, 0.2)
		l.omni_range = 5.5
		l.light_energy = 1.6
		l.position = fire + Vector3(0, 0.5, 0.6 if door_side != 0 else -0.6)
		region.add_child(l)
		LightFX.practical(l, 30.0)
		LightFX.flicker(l, "fire")
		kit.part(fire + Vector3.UP * 0.3, Vector3(0.4, 0.2, 0.3), Color(1.0, 0.55, 0.15), "lit")
	# 오두막 옆 장작더미와 풀숲
	# 문 반대쪽 벽 바깥에 장작더미, 옆에 풀숲 (문을 막지 않게)
	var back: Vector3 = -ddir
	_crates(spot + Vector3(back.x * (w * 0.5 + 1.2), 0, back.z * (d * 0.5 + 1.2)))
	var side_v := Vector3(ddir.z, 0, -ddir.x)
	_grass(spot + Vector3(side_v.x * (w * 0.5 + 2.0), 0, side_v.z * (d * 0.5 + 2.0)), Vector2(3.0, 3.0))


## 버려진 텐트와 모닥불, 통나무 의자, 바닥에 놓인 랜턴 (몇몇은 무너지고 꺼져 있음)
func _camp_sites() -> void:
	var canvas_colors := [Color(0.34, 0.31, 0.2), Color(0.45, 0.25, 0.12), Color(0.2, 0.26, 0.33), Color(0.3, 0.12, 0.1)]
	for i in 16:
		var p := Vector3(rng.randf_range(-HALF + 6, HALF - 6), 0, rng.randf_range(-HALF + 6, HALF - 6))
		if _blocked(p, 4.0):
			continue
		var yaw := rng.randf() * TAU
		var tent := _prop(p, yaw, Vector3(2.4, 1.4, 2.8))
		var canvas: StandardMaterial3D = _mat["canvas"].duplicate()
		var cc: Color = canvas_colors[rng.randi() % canvas_colors.size()]
		canvas.albedo_color = Color(cc.r * 2.6, cc.g * 2.6, cc.b * 2.6)
		canvas.cull_mode = BaseMaterial3D.CULL_DISABLED
		var tm := PrismMesh.new()
		tm.size = Vector3(2.4, 1.5, 2.8)
		var shell := _part(tent, Vector3(0, 0.75, 0), tm, canvas)
		if rng.randf() < 0.5:
			# 한쪽이 주저앉은 텐트 + 부러진 지지대
			shell.rotation = Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(0.25, 0.45))
			shell.scale = Vector3(1.0, 0.65, 1.0)
			shell.position.y = 0.45
			var pole := CylinderMesh.new()
			pole.top_radius = 0.025
			pole.bottom_radius = 0.025
			pole.height = 1.9
			# 부러진 지지대는 땅에 떨어져 누워 있음 (비스듬히 공중에 솟은 막대처럼 보이던 것)
			var stick := _part(tent, Vector3(-1.5, 0.03, 0.6), pole, _mat["metal"])
			stick.rotation = Vector3(PI / 2.0, 0.3, 0)
		else:
			# 입구가 열린 텐트: 어두운 입구 + 지지대
			_part(tent, Vector3(0, 0.45, 1.41), _box_mesh(Vector3(0.7, 0.8, 0.02)), _mat["charred"])
			var pole2 := CylinderMesh.new()
			pole2.top_radius = 0.025
			pole2.bottom_radius = 0.025
			pole2.height = 1.52
			_part(tent, Vector3(0, 0.76, 1.38), pole2, _mat["metal"])  # 입구 기둥 (꼭대기가 지붕선에 맞게)
		# 바닥에 놓인 랜턴
		var side := Vector3(cos(yaw + 1.3), 0, sin(yaw + 1.3))
		var lant := _prop(p + side * 1.9, 0.0, Vector3(0.2, 0.3, 0.2))
		_lantern(lant, Vector3(0, 0.13, 0), rng.randf() < 0.4)
		# 모닥불과 통나무 의자
		var fire_pos := p + Vector3(cos(yaw), 0, sin(yaw)) * 3.0
		_campfire(fire_pos, rng.randf() < 0.6)
		var seat := _prop(fire_pos + Vector3(cos(yaw + 1.8), 0, sin(yaw + 1.8)) * 1.6, yaw + 1.8, Vector3(0.5, 0.45, 1.6))
		var log_mesh := CylinderMesh.new()
		log_mesh.top_radius = 0.22
		log_mesh.bottom_radius = 0.24
		log_mesh.height = 1.6
		_part(seat, Vector3(0, 0.22, 0), log_mesh, _mat["log"]).rotation.x = PI / 2.0


func _campfire(pos: Vector3, lit: bool) -> void:
	var body := _prop(pos, 0.0, Vector3(1.0, 0.4, 1.0))
	for k in 6:
		var a := TAU * k / 6.0
		var stone := SphereMesh.new()
		stone.radius = 0.16
		stone.height = 0.24
		_part(body, Vector3(cos(a) * 0.45, 0.1, sin(a) * 0.45), stone, _mat["rock"])
	# 타다 남은 장작 3개 (가운데로 모임)
	for k in 3:
		var a2 := TAU * k / 3.0 + 0.3
		var wood := CylinderMesh.new()
		wood.top_radius = 0.05
		wood.bottom_radius = 0.07
		wood.height = 0.75
		var w := _part(body, Vector3(cos(a2) * 0.18, 0.12, sin(a2) * 0.18), wood, _mat["charred"])
		w.rotation = Vector3(0, -a2, 1.25)
	if lit:
		var ember := StandardMaterial3D.new()
		ember.albedo_color = Color(1.0, 0.45, 0.1)
		ember.emission_enabled = true
		ember.emission = Color(1.0, 0.4, 0.05)
		ember.emission_energy_multiplier = 3.0
		var flame := PrismMesh.new()
		flame.size = Vector3(0.35, 0.5, 0.35)
		_part(body, Vector3(0, 0.3, 0), flame, ember)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.55, 0.25)
		light.omni_range = 9.0
		light.light_energy = 2.0
		light.light_volumetric_fog_energy = 2.0
		light.position = Vector3(0, 0.8, 0)
		body.add_child(light)
		LightFX.practical(light, 45.0)  # 가까이 가면 나무 그림자가 일렁임
		LightFX.flicker(light, "fire", [ember])
		LightFX.embers(body, Vector3(0, 0.5, 0))


## 숲: 나무 + 바위 + 풀숲을 공터와 스폰을 피해서 빽빽하게
func _forest() -> void:
	for i in 420:
		var p := Vector3(rng.randf_range(-HALF + 3, HALF - 3), 0, rng.randf_range(-HALF + 3, HALF - 3))
		if _blocked(p, 2.5):
			continue
		_tree(p)
	for i in 110:
		var p := Vector3(rng.randf_range(-HALF + 4, HALF - 4), 0, rng.randf_range(-HALF + 4, HALF - 4))
		if _blocked(p, 2.0):
			continue
		_rock(p)
	for i in 100:
		var p := Vector3(rng.randf_range(-HALF + 5, HALF - 5), 0, rng.randf_range(-HALF + 5, HALF - 5))
		if _near_spawn(p, 6.0):
			continue
		var gs := Vector2(rng.randf_range(2.5, 6.0), rng.randf_range(2.5, 6.0))
		var in_cabin := false
		for cr in _cabin_rects:  # 오두막 바닥을 뚫고 풀이 자라던 것
			if (cr as Rect2).grow(maxf(gs.x, gs.y) * 0.5 + 0.3).has_point(Vector2(p.x, p.z)):
				in_cabin = true
		if in_cabin:
			continue
		_grass(p, gs)


func _rock(pos: Vector3) -> void:
	if _rock_models():
		_real_rock(pos)
		return
	var s := rng.randf_range(0.8, 2.2)
	var body := _prop(pos, rng.randf() * TAU, Vector3(s * 1.4, s * 0.9, s))
	var mesh := SphereMesh.new()
	mesh.radius = s * 0.7
	mesh.height = s * 1.1
	_part(body, Vector3(0, s * 0.35, 0), mesh, _mat["rock"]).scale = Vector3(1.0, 1.0, 0.75)


## 진짜 이끼 바위 모델 6종 (Poly Haven rock_moss_set_01, models/rocks). 거리에 따라 자동으로 단순해짐(LOD)
var _rocks: Array = []
var _rock_uv_mat: StandardMaterial3D

func _rock_models() -> bool:
	if _rocks.is_empty() and ResourceLoader.exists("res://models/rocks/rock01.obj"):
		for i in range(1, 7):
			_rocks.append(load("res://models/rocks/rock0%d.obj" % i))
		_rock_uv_mat = StandardMaterial3D.new()
		_rock_uv_mat.albedo_texture = _tex("rock_moss_set_01", "diff")
		var n := _tex("rock_moss_set_01", "nor")
		if n:
			_rock_uv_mat.normal_enabled = true
			_rock_uv_mat.normal_texture = n
		_rock_uv_mat.roughness_texture = _tex("rock_moss_set_01", "rough")
		_rock_uv_mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	return not _rocks.is_empty()


func _real_rock(pos: Vector3) -> void:
	var mesh: Mesh = _rocks[rng.randi() % _rocks.size()]
	var s := rng.randf_range(0.7, 1.6)
	var sc := Vector3(s, s * rng.randf_range(0.8, 1.2), s)
	var box := mesh.get_aabb()
	var size := box.size * sc
	size.y = maxf(0.3, box.end.y * sc.y)  # 땅 위로 나온 높이만 막기
	var body := _prop(pos, rng.randf() * TAU, Vector3(size.x * 0.85, size.y, size.z * 0.85))
	body.get_child(0).position += Vector3(box.get_center().x * sc.x, 0, box.get_center().z * sc.z)
	_part(body, Vector3.ZERO, mesh, _rock_uv_mat).scale = sc


## 공터, 길 근처, 스폰 근처면 true (나무·바위를 두지 않음)
var _cabin_rects: Array = []  # 오두막 자리 (나무·바위·텐트가 안이나 문 앞에 생기지 않게)

func _blocked(p: Vector3, margin: float) -> bool:
	if _near_spawn(p, 7.0 + margin):
		return true
	for cr in _cabin_rects:
		if (cr as Rect2).grow(margin + 1.5).has_point(Vector2(p.x, p.z)):
			return true
	for c in CLEARINGS:
		if Vector2(p.x, p.z).distance_to(Vector2(c.x, c.z)) < CLEARING_RADIUS + margin:
			return true
	return false
