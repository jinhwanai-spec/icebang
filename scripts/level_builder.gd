class_name LevelBuilder
extends RefCounted
## 맵 만들기: 풀이 자란 버려진 도시 거리
## - 160m x 160m. 가로 4개, 세로 4개 도로가 바둑판처럼 지나가고
##   그 사이 25개 블록에 건물 / 공원 / 공터(폐차장)가 들어갑니다.
## - map_seed 가 같으면 항상 같은 맵이 나옵니다.
## - 나중에 3D 에셋을 구하면 _building, _car 같은 함수 안의 상자를 모델로 바꾸면 됩니다.

const HALF := 80.0
## 도로 중심 위치와 도로 폭의 절반
const ROAD_CENTERS := [-48.0, -16.0, 16.0, 48.0]
const ROAD_HALF := 4.0
## 블록이 차지하는 구간 (x와 z 모두 같은 구간 사용)
const BLOCK_RANGES := [Vector2(-78.0, -52.0), Vector2(-44.0, -20.0), Vector2(-12.0, 12.0), Vector2(20.0, 44.0), Vector2(52.0, 78.0)]
## 보도/공원/공터 바닥 높이 (너무 높으면 캐릭터가 턱에 걸림)
const CURB := 0.05
const PARK_COUNT := 4
const LOT_COUNT := 4

const SURVIVOR_SPAWNS := [Vector3(-16, 0.3, -72), Vector3(-14, 0.3, -70), Vector3(-18, 0.3, -70), Vector3(-16, 0.3, -68)]
## 술래 시작 위치 (술래 수만큼 앞에서부터 사용)
const SEEKER_SPAWNS := [Vector3(16, 0.3, 72), Vector3(72, 0.3, 16), Vector3(-72, 0.3, 48)]
const SEEKER_SPAWN := Vector3(16, 0.3, 72)

var region: Node3D
var rng := RandomNumberGenerator.new()
## 맵 물들이기(카멜레온)로 색을 바꿀 대상
var paintable: Array[GeometryInstance3D] = []
## 봉인석을 둘 수 있는 자리
var generator_spots: Array[Vector3] = []

var _mat := {}
## 문·사물함·넘는 창문 소품 [종류, 위치, 회전] (길 계산 뒤에 main 이 만듦)
var props: Array = []
## 걸을 수 있는 층 높이들 (술래·봇이 순찰할 층을 고를 때)
var floor_levels: Array = [0.0]
## 시작 위치·맵 크기 (맵마다 다르게 덮어씀)
var survivor_spawns: Array = SURVIVOR_SPAWNS
var seeker_spawns: Array = SEEKER_SPAWNS
var half := HALF
## 작은 폐가·담장(structure_builder)을 놓을지. 이제는 큰 건물 안에 문·사물함이 있어서 쓰지 않음
var use_shacks := false
## (테스트용) 복도식 건물의 방 목록 [방 정보, 바닥 높이]
var debug_rooms: Array = []
## (테스트용) 복도 한쪽 끝 위치 (x, z). 없으면 Vector3.INF
var corridor_probe := Vector3.INF
## 창문으로 들어오는 달빛 (볼류메트릭 안개에서 빛줄기로 보임). at = 창 중심, inward = 방 안쪽 방향
var _moon_count := 0
func _moon_shaft(at: Vector3, inward: Vector3) -> void:
	if _moon_count >= 14:
		return
	_moon_count += 1
	var sl := SpotLight3D.new()
	sl.light_color = Color(0.55, 0.65, 1.0)
	sl.light_energy = 2.6
	sl.light_volumetric_fog_energy = 3.5
	sl.spot_range = 9.0
	sl.spot_angle = 24.0
	sl.spot_attenuation = 0.6
	sl.spot_angle_attenuation = 0.4
	sl.light_specular = 0.2
	sl.shadow_enabled = false
	sl.light_projector = LightFX.window_cookie()  # 창살 모양 빛 무늬
	sl.distance_fade_enabled = true
	sl.distance_fade_begin = 35.0
	sl.distance_fade_length = 10.0
	sl.set_meta("lit_design", true)
	# (맵을 만드는 중엔 아직 씬 트리 밖이라 global_* 대신 직접 변환을 계산)
	var from := at - inward * 1.2 + Vector3.UP * 1.0
	var to := at + inward * 3.0 + Vector3.DOWN * 1.8
	sl.transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from)
	region.add_child(sl)


## 층 표시 (계단실 벽에 큰 글자 + 판)
func _floor_sign(p: Vector3, facing: Vector3, text: String, col := Color(0.2, 0.45, 0.4)) -> void:
	var yaw := atan2(facing.x, facing.z)
	if kit:
		kit.part(p, Vector3(1.0, 0.7, 0.04), col, "trim", false, yaw)
	var l := Label3D.new()
	l.text = text
	l.font_size = 128
	l.pixel_size = 0.004
	l.modulate = Color(0.95, 0.95, 0.9)
	l.position = p + facing * 0.04
	l.rotation.y = yaw
	l.visibility_range_end = 25.0
	region.add_child(l)


## (테스트용) 바깥 풍경 확인 위치 [[카메라, 보는 곳], ...]
var debug_views: Array = []
var kit: BuildingKit
const LightFX := preload("res://scripts/light_fx.gd")
## 조명 전용 난수 (맵 모양을 정하는 rng 와 따로 써서, 조명을 바꿔도 맵 배치가 그대로)
var light_rng := RandomNumberGenerator.new()
var _building_mats: Array[StandardMaterial3D] = []
var _rust_mats: Array[StandardMaterial3D] = []


func build(target: Node3D, map_seed: int) -> void:
	region = target
	rng.seed = map_seed
	_make_materials()
	kit = BuildingKit.new(self)
	floor_levels = [0.0, CURB + 3.5]
	debug_views = [[Vector3(-16, 1.7, -66), Vector3(-16, 2, -30)], [Vector3(-12, 1.7, -16), Vector3(20, 3, -16)], [Vector3(16, 1.7, 10), Vector3(16, 3, 40)], [Vector3(-48, 1.7, 30), Vector3(-30, 4, 30)]]
	_ground()
	_outer_walls()
	_blocks()
	_road_props()
	_flush_batches()


# ================================================================ 재질 (질감)

func _make_materials() -> void:
	LightFX.reset()
	light_rng.seed = 4242
	_mat["asphalt"] = _noise_mat(Color(0.16, 0.16, 0.17), 0.35, 0.95, 6.0)
	_mat["sidewalk"] = _pattern_mat("tile", Color(0.42, 0.41, 0.39), 2.0)
	_mat["concrete"] = _noise_mat(Color(0.36, 0.35, 0.33), 0.4, 0.95, 4.0)
	_mat["dirt"] = _noise_mat(Color(0.2, 0.22, 0.14), 0.4, 1.0, 4.0)
	_mat["wall"] = _pattern_mat("brick", Color(0.34, 0.31, 0.29), 1.5)
	_mat["planks"] = _pattern_mat("planks", Color(0.4, 0.31, 0.22), 2.0)
	_mat["interior"] = _pattern_mat("plaster", Color(0.62, 0.6, 0.54), 3.0)
	var kinds := ["plaster", "brick", "plaster", "brick", "brick"]
	var cols := [Color(0.5, 0.5, 0.47), Color(0.55, 0.49, 0.4), Color(0.38, 0.45, 0.44), Color(0.46, 0.3, 0.25), Color(0.42, 0.42, 0.45)]
	for i in cols.size():
		var c: Color = cols[i]
		_building_mats.append(_pattern_mat(kinds[i], c, 1.5 if kinds[i] == "brick" else 3.0))
		_building_cols.append(c)
	for c in [Color(0.35, 0.22, 0.15), Color(0.25, 0.35, 0.3), Color(0.45, 0.4, 0.3), Color(0.3, 0.32, 0.38), Color(0.5, 0.25, 0.2)]:
		_rust_mats.append(_noise_mat(c, 0.6, 0.6, 3.0))
	_mat["windows"] = _window_mat()
	_mat["shutter"] = _stripe_mat()
	_mat["glass"] = _flat_mat(Color(0.05, 0.07, 0.09), 0.2)
	_mat["metal"] = _flat_mat(Color(0.2, 0.2, 0.22), 0.5)
	_mat["trunk"] = _noise_mat(Color(0.25, 0.18, 0.12), 0.5, 1.0, 2.0)
	_mat["leaves"] = _noise_mat(Color(0.12, 0.22, 0.1), 0.6, 1.0, 2.0)
	_mat["paint"] = _flat_mat(Color(0.75, 0.75, 0.7), 0.8)
	_mat["crate"] = _pattern_mat("planks", Color(0.5, 0.36, 0.2), 1.0)
	# 실내 마감용 (건물 안 벽지·판넬·바닥재·천장)
	_mat["in_paint"] = _pattern_mat("paint", Color(0.7, 0.67, 0.6), 2.5)
	_mat["in_paint_b"] = _pattern_mat("paint", Color(0.6, 0.66, 0.68), 2.5)
	_mat["in_wains_wood"] = _pattern_mat("woodfloor", Color(0.42, 0.3, 0.2), 2.0)
	_mat["in_wains_tile"] = _pattern_mat("wtile", Color(0.6, 0.66, 0.66), 0.6)
	_mat["in_lino"] = _pattern_mat("lino", Color(0.52, 0.52, 0.5), 1.4)
	_mat["in_terrazzo"] = _pattern_mat("terrazzo", Color(0.6, 0.58, 0.55), 1.5)
	_mat["in_wood"] = _pattern_mat("woodfloor", Color(0.5, 0.36, 0.24), 2.0)
	_mat["in_ceil"] = _pattern_mat("ceiling", Color(0.64, 0.64, 0.62), 1.2)


## 노이즈 텍스처로 콘크리트/아스팔트 같은 얼룩덜룩한 질감을 만듭니다.
func _noise_mat(base: Color, contrast: float, rough: float, tile_m: float) -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	var grad := Gradient.new()
	grad.set_color(0, base.darkened(contrast))
	grad.set_color(1, base.lightened(contrast * 0.4))
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = grad
	var ntex := NoiseTexture2D.new()
	ntex.width = 256
	ntex.height = 256
	ntex.seamless = true
	ntex.noise = noise
	ntex.as_normal_map = true
	ntex.bump_strength = 3.0
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.normal_enabled = true
	m.normal_texture = ntex
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / tile_m
	return m


## 무늬 질감: "brick"(벽돌) / "plaster"(낡은 회벽) / "tile"(보도블록) / "planks"(나무 판자). tile_m 미터마다 한 번 반복
## 무늬 그림은 assets/textures/gen (회색 그림에 base 색을 곱함)
func _pattern_mat(kind: String, base: Color, tile_m: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/gen/%s_diff.png" % kind)
	m.albedo_color = Color(base.r * 1.3, base.g * 1.3, base.b * 1.3)
	m.normal_enabled = true
	m.normal_texture = load("res://assets/textures/gen/%s_nor.png" % kind)
	m.normal_scale = 1.3
	m.roughness = 0.9
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / tile_m
	return m


func _flat_mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


## 건물 창문: 3m마다 창문 2개. 일부 창문에 불이 켜져 있음
func _window_mat() -> StandardMaterial3D:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var glow := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(0.3, 0.29, 0.27))
	glow.fill(Color.BLACK)
	for wx in [14, 74]:
		img.fill_rect(Rect2i(wx - 3, 26, 46, 66), Color(0.2, 0.2, 0.2))  # 창틀
		img.fill_rect(Rect2i(wx, 29, 40, 60), Color(0.05, 0.06, 0.08))   # 유리
		if wx == 74:
			glow.fill_rect(Rect2i(wx, 29, 40, 60), Color(0.9, 0.6, 0.3))  # 불 켜진 창
			img.fill_rect(Rect2i(wx, 29, 40, 60), Color(0.5, 0.35, 0.2))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.emission_enabled = true
	m.emission_texture = ImageTexture.create_from_image(glow)
	m.emission_energy_multiplier = 0.5
	m.roughness = 0.6
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 3.0
	return m


## 셔터: 가로 줄무늬 금속
func _stripe_mat() -> StandardMaterial3D:
	var img := Image.create(16, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		var v := 0.42 if (y % 8) < 6 else 0.25
		v += randf_range(-0.02, 0.02)
		for x in 16:
			img.set_pixel(x, y, Color(v, v, v * 1.05))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.metallic = 0.5
	m.roughness = 0.55
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 1.0
	return m


# ================================================================ 만들기 도우미

## 상자 하나 (collide=true 면 부딪힘). pos = 상자 중심
func _box(pos: Vector3, size: Vector3, mat: Material, collide := true, yaw := 0.0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = mat
	paintable.append(mesh)
	if collide:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		shape.shape = bs
		body.add_child(shape)
		body.add_child(mesh)
		region.add_child(body)
		body.position = pos
		body.rotation.y = yaw
	else:
		region.add_child(mesh)
		mesh.position = pos
		mesh.rotation.y = yaw
	return mesh


## 여러 부품으로 된 소품(자동차 등)의 몸통
func _prop(pos: Vector3, yaw: float, collider_size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = collider_size
	shape.shape = bs
	shape.position.y = collider_size.y / 2.0
	body.add_child(shape)
	region.add_child(body)
	body.position = pos
	body.rotation.y = yaw
	return body


func _part(parent: Node3D, local_pos: Vector3, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = local_pos
	parent.add_child(mi)
	paintable.append(mi)
	return mi


func _box_mesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _grass(center: Vector3, size: Vector2) -> void:
	var patch := GrassPatch.new()
	region.add_child(patch)
	patch.position = center
	patch.setup(size, rng)
	paintable.append(patch.grass_mesh)


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


# ================================================================ 여러 개를 한 번에 그리기 (MultiMesh)
# 나무·낙엽처럼 수천 개 있는 것은 하나씩 만들면 느려서, 같은 모양끼리 모아 한 번에 그림

var _batches := {}  # 이름 → [메시, 재질, 그림자 여부, [Transform3D...], [Color...]]


## 파쿠르로 넘을 수 있는 창문 유리 목록 (building_kit.block 이 채움). main.gd 가 깨진 유리를 처리
var windows: Array = []
## 문·출입구 목록 [가운데(바닥 높이), 벽 방향, 폭] (building_kit.wall 이 채움)
var doorways: Array = []


func _batch(key: String, mesh: Mesh, mat: Material, xf: Transform3D, color := Color.WHITE, shadow := true) -> void:
	if not _batches.has(key):
		# 유리창은 그림자를 만들지 않음 → 달빛이 창문으로 들어와 바닥에 창틀 모양으로 떨어짐
		_batches[key] = [mesh, mat, shadow and not key.begins_with("b_glass"), [], []]
	_batches[key][3].append(xf)
	_batches[key][4].append(color)


func _flush_batches() -> void:
	if kit:
		kit.final_door_pass()
	for key in _batches:
		var b: Array = _batches[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = b[0]
		mm.instance_count = b[3].size()
		for i in b[3].size():
			mm.set_instance_transform(i, b[3][i])
			mm.set_instance_color(i, b[4][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = b[1]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if b[2] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		region.add_child(mmi)
		paintable.append(mmi)
		for w in windows:
			if w["key"] == key and not w.has("mmi"):
				w["mmi"] = mmi
	_batches.clear()


## 인스턴스 색을 쓰는 재질 (낙엽처럼 같은 모양에 색만 다르게)
var _tint_cache := {}
func _tint_mat(rough: float, double_sided := false) -> StandardMaterial3D:
	var key := "%s_%s" % [rough, double_sided]
	if _tint_cache.has(key):
		return _tint_cache[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_tint_cache[key] = m
	return m


## 재질에 인스턴스 색(밝기 차이)을 곱하는 복사본
func _tinted(base: StandardMaterial3D) -> StandardMaterial3D:
	var m: StandardMaterial3D = base.duplicate()
	m.vertex_color_use_as_albedo = true
	return m


# ================================================================ 바닥 / 울타리 / 도로

func _ground() -> void:
	_mark_indestructible(_box(Vector3(0, -0.5, 0), Vector3(HALF * 2, 1, HALF * 2), _mat["asphalt"]))
	# 도로 차선 (점선)
	for c in ROAD_CENTERS:
		var z := -HALF + 2.0
		while z < HALF - 2.0:
			if _far_from_roads(z, 4.5):
				_box(Vector3(c, 0.01, z), Vector3(0.18, 0.02, 2.4), _mat["paint"], false)
				_box(Vector3(z, 0.01, c), Vector3(2.4, 0.02, 0.18), _mat["paint"], false)
			z += 5.0


## value 가 모든 도로 중심에서 margin 이상 떨어져 있는지
func _far_from_roads(value: float, margin: float) -> bool:
	for c in ROAD_CENTERS:
		if absf(value - c) < margin:
			return false
	return true


func _outer_walls() -> void:
	var h := 4.5
	_mark_indestructible(_box(Vector3(0, h / 2, -half), Vector3(half * 2 + 1, h, 1), _mat["wall"]))
	_mark_indestructible(_box(Vector3(0, h / 2, half), Vector3(half * 2 + 1, h, 1), _mat["wall"]))
	_mark_indestructible(_box(Vector3(-half, h / 2, 0), Vector3(1, h, half * 2 + 1), _mat["wall"]))
	_mark_indestructible(_box(Vector3(half, h / 2, 0), Vector3(1, h, half * 2 + 1), _mat["wall"]))


## 바닥과 바깥 울타리는 히든 캐릭터의 "붕괴"로도 부서지지 않게 표시
func _mark_indestructible(mesh: MeshInstance3D) -> void:
	mesh.get_parent().set_meta("indestructible", true)


# ================================================================ 블록

func _blocks() -> void:
	var n := BLOCK_RANGES.size()
	var types: Array = []
	for i in n * n:
		types.append("building")
	var order := range(n * n)
	_shuffle(order)
	for i in PARK_COUNT:
		types[order[i]] = "park"
	for i in LOT_COUNT:
		types[order[PARK_COUNT + i]] = "lot"

	for bx in n:
		for bz in n:
			var xr: Vector2 = BLOCK_RANGES[bx]
			var zr: Vector2 = BLOCK_RANGES[bz]
			var r := Rect2(xr.x, zr.x, xr.y - xr.x, zr.y - zr.x)
			match types[bx * n + bz]:
				"park":
					_park(r)
				"lot":
					_lot(r)
				_:
					_building_block(r)


func _building_block(r: Rect2) -> void:
	# 보도 (캐릭터가 걸려 넘어지지 않게 아주 얇게)
	_box(Vector3(r.get_center().x, CURB / 2.0, r.get_center().y), Vector3(r.size.x, CURB, r.size.y), _mat["sidewalk"])
	var full := r.grow(-1.8)
	# 블록이 크면 가운데 골목으로 두 줄로 나눔
	var rows: Array[Rect2] = [full]
	if minf(full.size.x, full.size.y) > 14.0:
		var half_w := (full.size.y - 3.2) / 2.0
		rows = [Rect2(full.position, Vector2(full.size.x, half_w)),
				Rect2(full.position + Vector2(0, half_w + 3.2), Vector2(full.size.x, half_w))]
	for inner in rows:
		_building_row(inner)


func _building_row(inner: Rect2) -> void:
	var along_x := inner.size.x >= inner.size.y
	var length := inner.size.x if along_x else inner.size.y
	var count := 1 if length < 10.0 else (2 if length < 17.0 else rng.randi_range(2, 3))
	var alley := 3.2
	var seg := (length - alley * (count - 1)) / count
	for i in count:
		var start := i * (seg + alley)
		var b: Rect2
		if along_x:
			b = Rect2(inner.position.x + start, inner.position.y, seg, inner.size.y)
		else:
			b = Rect2(inner.position.x, inner.position.y + start, inner.size.x, seg)
		_building(b)
		# 건물 사이 골목에 쓰레기통, 상자, 잡초
		if i < count - 1:
			var ac: Vector2
			if along_x:
				ac = Vector2(b.end.x + alley / 2.0, inner.get_center().y + rng.randf_range(-2, 2))
			else:
				ac = Vector2(inner.get_center().x + rng.randf_range(-2, 2), b.end.y + alley / 2.0)
			if rng.randf() < 0.6:
				_dumpster(Vector3(ac.x, CURB, ac.y), 0.0 if along_x else PI / 2.0)
			else:
				_grass(Vector3(ac.x, CURB, ac.y), Vector2(2.4, 2.4))


func _building(b: Rect2) -> void:
	var h := rng.randf_range(6.5, 15.5)
	var base_y := CURB
	var ci := rng.randi() % _building_mats.size()
	var trim: Color = _building_cols[ci].lightened(0.18)
	var kind: String = ["apartment", "office", "shop", "apartment"][rng.randi() % 4]
	# 모든 건물에 들어갈 수 있음: 외벽(창문·출입구) + 방·계단·가구 (building_kit.gd)
	var spots: Array = kit.city_building(b, base_y, h, _building_mats[ci], trim, kind)
	for sp in spots:
		if rng.randf() < 0.25:
			generator_spots.append(sp)
	# 바깥 장식: 모서리 기둥, 층 띠, 처마, 배관, 비상계단, 1층 차양·간판
	_facade_trims(b, base_y, h, _building_cols[ci], trim)
	_rooftop(b, base_y + h)


# ---------------------------------------------------------------- 건물 꾸미기 (창틀·가게·옥상)
# 작은 부품이 수천 개라서 같은 재질끼리 MultiMesh 로 모아 그림

var _building_cols: Array[Color] = []
var _cube: BoxMesh
var _cyl: CylinderMesh
var _deco := {}

func _deco_mat(key: String) -> Material:
	if _deco.has(key):
		return _deco[key]
	if key == "lit":
		_deco[key] = _lit_shader_mat()
		return _deco[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.85
	match key:
		"glass":
			m.roughness = 0.12
			m.metallic = 0.35
		"lit":
			m.emission_enabled = true
			m.emission = Color(1.0, 0.68, 0.35)
			m.emission_energy_multiplier = 1.1
		"eerie":
			m.emission_enabled = true
			m.emission = Color(0.35, 0.9, 0.6)
			m.emission_energy_multiplier = 0.7
		"metal":
			m.roughness = 0.5
			m.metallic = 0.45
		"web":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_texture = _web_tex()
	_deco[key] = m
	return m


## 빛나는 부품 ("lit"): 부품 색 그대로 빛남 (초록 모니터는 초록, 형광등은 흰빛, 비상등은 빨강)
func _lit_shader_mat() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode cull_back;
uniform float energy = 2.2;
void fragment() {
	ALBEDO = COLOR.rgb * 0.35;
	ROUGHNESS = 0.4;
	EMISSION = COLOR.rgb * COLOR.rgb * energy;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## 상자 부품 하나: 벽면 기준 (t=벽을 따라가는 방향, n=벽 바깥 방향). size=(t방향, 높이, n방향), roll=n축 기준 기울기
func _bx(key: String, center: Vector3, t: Vector3, n: Vector3, size: Vector3, col: Color, roll := 0.0, pitch := 0.0) -> void:
	if _cube == null:
		_cube = BoxMesh.new()
	var basis := Basis(t, Vector3.UP, n)
	if roll != 0.0:
		basis = basis * Basis(Vector3(0, 0, 1), roll)
	if pitch != 0.0:
		basis = basis * Basis(Vector3(1, 0, 0), pitch)
	_batch("b_" + key, _cube, _deco_mat(key), Transform3D(basis * Basis.from_scale(size), center), col)


## 거미줄 무늬 (가운데서 퍼지는 실 + 동심 다각형)
func _web_tex() -> ImageTexture:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var cpos := Vector2(64, 2)
	for k in 9:
		var ang := k / 8.0 * PI
		var dir := Vector2(cos(ang), sin(ang))
		for r in 70:
			var p := cpos + dir * r
			if p.x >= 0 and p.y >= 0 and p.x < size and p.y < size:
				img.set_pixelv(Vector2i(p), Color(1, 1, 1, 1))
	for ring in range(10, 70, 11):
		for k in 8:
			var a0 := k / 8.0 * PI
			var a1 := (k + 1) / 8.0 * PI
			var p0 := cpos + Vector2(cos(a0), sin(a0)) * ring
			var p1 := cpos + Vector2(cos(a1), sin(a1)) * ring * 0.93
			for st in 30:
				var p := p0.lerp(p1, st / 29.0)
				if p.x >= 0 and p.y >= 0 and p.x < size and p.y < size:
					img.set_pixelv(Vector2i(p), Color(1, 1, 1, 0.9))
	return ImageTexture.create_from_image(img)


func _pipe(center: Vector3, radius: float, length: float, col: Color) -> void:
	if _cyl == null:
		_cyl = CylinderMesh.new()
		_cyl.top_radius = 0.5
		_cyl.bottom_radius = 0.5
		_cyl.height = 1.0
		_cyl.radial_segments = 10
		_cyl.rings = 1
	_batch("b_pipe", _cyl, _deco_mat("metal"), Transform3D(Basis.from_scale(Vector3(radius * 2, length, radius * 2)), center), col)


## 건물 네 면: 기단, 모서리 기둥, 층 띠, 창문(창틀·창턱·살), 1층 가게, 배관, 비상계단, 꼭대기 처마
func _facade(b: Rect2, y0: float, h: float, ground: bool, wall: Color, trim: Color) -> void:
	var c := b.get_center()
	var dark := wall.darkened(0.45)
	var frame_col := Color(0.16, 0.14, 0.13).lerp(trim, 0.15)
	var floors := int((h - (3.4 if ground else 0.4) - 0.5) / 3.0)
	var first := y0 + (3.4 if ground else 0.3)
	var fire_side := rng.randi() % 4 if (floors >= 2 and rng.randf() < 0.4) else -1
	var pipe_side := rng.randi() % 4
	var sides := [
		[Vector3(1, 0, 0), b.size.y, b.size.x], [Vector3(-1, 0, 0), b.size.y, b.size.x],
		[Vector3(0, 0, 1), b.size.x, b.size.y], [Vector3(0, 0, -1), b.size.x, b.size.y],
	]
	for si in 4:
		var n: Vector3 = sides[si][0]
		var L: float = sides[si][1]
		var depth: float = sides[si][2]
		var t := Vector3.UP.cross(n)
		var face := Vector3(c.x, 0, c.y) + n * (depth / 2.0)
		# 기단(아래 어두운 띠)과 꼭대기 처마
		if ground:
			_bx("trim", face + n * 0.06 + Vector3.UP * (y0 + 0.35), t, n, Vector3(L + 0.12, 0.7, 0.14), dark)
		_bx("trim", face + n * 0.12 + Vector3.UP * (y0 + h - 0.2), t, n, Vector3(L + 0.5, 0.4, 0.26), trim)
		# 모서리 기둥
		for e in [-1.0, 1.0]:
			_bx("trim", face + t * e * (L / 2.0 - 0.15) + n * 0.08 + Vector3.UP * (y0 + h / 2.0), t, n, Vector3(0.42, h, 0.18), trim.darkened(0.08))
		# 층마다 가로 띠
		for k in floors + 1:
			var fy := first + k * 3.0 - 0.15
			if fy < y0 + h - 0.6:
				_bx("trim", face + n * 0.07 + Vector3.UP * fy, t, n, Vector3(L - 0.3, 0.16, 0.14), trim.darkened(0.15))
		# 창문
		var count := maxi(1, int((L - 1.6) / 2.4))
		var gap := (L - 1.6) / count
		for k in floors:
			var wy := first + k * 3.0 + 1.45
			for i in count:
				var u := -L / 2.0 + 0.8 + gap * (i + 0.5)
				_window(face + t * u + Vector3.UP * wy, t, n, frame_col, trim)
		# 1층 가게
		if ground and L > 5.0:
			_shopfront(face, t, n, L, y0, frame_col)
		# 배관
		if si == pipe_side:
			var e := 1.0 if rng.randf() < 0.5 else -1.0
			_pipe(face + t * e * (L / 2.0 - 0.6) + n * 0.2 + Vector3.UP * (y0 + h / 2.0), 0.07, h, Color(0.3, 0.3, 0.3))
		# 비상계단
		if si == fire_side:
			_fire_escape(face, t, n, L, first, floors)


## 들어갈 수 있는 건물의 바깥 장식 (창문은 building_kit 이 진짜 구멍으로 뚫음)
func _facade_trims(b: Rect2, y0: float, h: float, wall: Color, trim: Color) -> void:
	var c := b.get_center()
	var dark := wall.darkened(0.45)
	var pipe_side := rng.randi() % 4
	var fire_side := rng.randi() % 4 if (h > 9.0 and rng.randf() < 0.4) else -1
	var sides := [
		[Vector3(1, 0, 0), b.size.y, b.size.x], [Vector3(-1, 0, 0), b.size.y, b.size.x],
		[Vector3(0, 0, 1), b.size.x, b.size.y], [Vector3(0, 0, -1), b.size.x, b.size.y],
	]
	for si in 4:
		var n: Vector3 = sides[si][0]
		var L: float = sides[si][1]
		var depth: float = sides[si][2]
		var t := Vector3.UP.cross(n)
		var face := Vector3(c.x, 0, c.y) + n * (depth / 2.0)
		_bx("trim", face + n * 0.06 + Vector3.UP * (y0 + 0.25), t, n, Vector3(L + 0.12, 0.5, 0.14), dark)
		_bx("trim", face + n * 0.12 + Vector3.UP * (y0 + h - 0.2), t, n, Vector3(L + 0.5, 0.4, 0.26), trim)
		for e in [-1.0, 1.0]:
			_bx("trim", face + t * e * (L / 2.0 - 0.15) + n * 0.08 + Vector3.UP * (y0 + h / 2.0), t, n, Vector3(0.42, h, 0.18), trim.darkened(0.08))
		_bx("trim", face + n * 0.07 + Vector3.UP * (y0 + 3.2 - 0.1), t, n, Vector3(L - 0.3, 0.16, 0.14), trim.darkened(0.15))
		if si == pipe_side:
			var e := 1.0 if rng.randf() < 0.5 else -1.0
			_pipe(face + t * e * (L / 2.0 - 0.6) + n * 0.2 + Vector3.UP * (y0 + h / 2.0), 0.07, h, Color(0.3, 0.3, 0.3))
		if si == fire_side:
			_fire_escape(face, t, n, L, y0 + 3.2, int((h - 3.4) / 3.0))
		if L > 5.0 and rng.randf() < 0.35:
			# 줄무늬 차양 (출입구가 있든 없든 1층 위)
			var pal := [[Color(0.7, 0.15, 0.15), Color(0.9, 0.85, 0.75)], [Color(0.15, 0.4, 0.3), Color(0.85, 0.82, 0.7)], [Color(0.2, 0.3, 0.6), Color(0.9, 0.88, 0.8)]]
			var pc: Array = pal[rng.randi() % pal.size()]
			var w := minf(4.5, L - 2.0)
			var stripes := int(w / 0.45)
			var sw := w / stripes
			for j in stripes:
				var u := -w / 2.0 + sw * (j + 0.5)
				_bx("trim", face + t * u + n * 0.6 + Vector3.UP * (y0 + 2.85), t, n, Vector3(sw, 0.05, 1.2), (pc[j % 2] as Color).darkened(0.25), 0.0, 0.42)
			if rng.randf() < 0.5:
				_sign(face + n * 0.12 + Vector3.UP * (y0 + 3.6), absf(n.z) > 0.5)


## 진짜 창문 구멍 둘레의 바깥 창틀·창턱 (유리는 building_kit 이 넣음)
func _window_frame_only(at: Vector3, t: Vector3, n0: Vector3, trim: Color) -> void:
	var n := t.cross(Vector3.UP) * -1.0 if n0 == Vector3.ZERO else n0
	var tt := Vector3.UP.cross(n)
	var frame_col := Color(0.16, 0.14, 0.13).lerp(trim, 0.15)
	var w := 1.1
	var hh := 1.25
	for s in [-1.0, 1.0]:
		_bx("trim", at + tt * s * (w * 0.5 + 0.05) + n * 0.03, tt, n, Vector3(0.1, hh + 0.2, 0.08), frame_col)
	_bx("trim", at + Vector3.UP * (hh * 0.5 + 0.05) + n * 0.03, tt, n, Vector3(w + 0.2, 0.1, 0.08), frame_col)
	_bx("trim", at + Vector3.UP * (-hh * 0.5 - 0.06) + n * 0.1, tt, n, Vector3(w + 0.4, 0.09, 0.24), trim)
	_bx("trim", at + n * 0.04, tt, n, Vector3(0.05, hh, 0.03), frame_col)


## 실내가 없는 윗부분 벽면: 층 띠 + 가짜 창문 (불 켜진 창·커튼·판자 등)
func _facade_side(face: Vector3, dir: Vector3, n: Vector3, L: float, y0: float, h: float, trim: Color) -> void:
	var t := Vector3.UP.cross(n)
	var frame_col := Color(0.16, 0.14, 0.13).lerp(trim, 0.15)
	var floors := int((h - 0.6) / 3.0)
	var count := maxi(1, int((L - 1.6) / 2.4))
	var gap := (L - 1.6) / count
	for k in floors:
		var wy := y0 + k * 3.0 + 1.55
		_bx("trim", face + n * 0.07 + Vector3.UP * (y0 + k * 3.0 - 0.1), t, n, Vector3(L - 0.3, 0.16, 0.14), trim.darkened(0.15))
		for i in count:
			var u := -L / 2.0 + 0.8 + gap * (i + 0.5)
			_window(face + t * u + Vector3.UP * wy, t, n, frame_col, trim)


func _window(at: Vector3, t: Vector3, n: Vector3, frame_col: Color, trim: Color) -> void:
	var w := 1.1
	var hh := 1.55
	_bx("trim", at + n * 0.04, t, n, Vector3(w + 0.22, hh + 0.22, 0.08), frame_col)
	_bx("trim", at + n * 0.1 + Vector3.UP * (-hh / 2.0 - 0.12), t, n, Vector3(w + 0.4, 0.09, 0.24), trim)
	var r := rng.randf()
	if r < 0.08:
		# 판자로 막은 창문
		_bx("glass", at + n * 0.085, t, n, Vector3(w, hh, 0.02), Color(0.03, 0.03, 0.04))
		var wood := Color(0.42, 0.3, 0.18)
		for j in 3:
			_bx("trim", at + n * 0.12 + Vector3.UP * (j - 1) * 0.45, t, n, Vector3(w + 0.3, 0.2, 0.04), wood.darkened(rng.randf() * 0.3), rng.randf_range(-0.25, 0.25))
		return
	if r < 0.13:
		# 깨진 창문: 시커멓고 유리 조각만 남음
		_bx("glass", at + n * 0.085, t, n, Vector3(w, hh, 0.02), Color(0.0, 0.0, 0.0))
		_bx("glass", at + n * 0.09 + t * -0.3 + Vector3.UP * 0.5, t, n, Vector3(0.35, 0.5, 0.02), Color(0.2, 0.25, 0.3), 0.6)
		return
	var lit := r < 0.3
	_bx("lit" if lit else "glass", at + n * 0.085, t, n, Vector3(w, hh, 0.02),
			Color(1.0, 0.75, 0.45) if lit else Color(0.07, 0.09, 0.12))
	if lit and rng.randf() < 0.6:
		# 커튼 (불 켜진 창에 사람 없는 방 느낌)
		var cc: Color = [Color(0.6, 0.2, 0.2), Color(0.5, 0.45, 0.3), Color(0.25, 0.3, 0.5)][rng.randi() % 3]
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		_bx("trim", at + n * 0.1 + t * side * w * 0.28, t, n, Vector3(w * 0.45, hh, 0.02), cc)
	# 창살 (십자)
	_bx("trim", at + n * 0.1, t, n, Vector3(0.06, hh, 0.03), frame_col)
	_bx("trim", at + n * 0.1 + Vector3.UP * 0.2, t, n, Vector3(w, 0.06, 0.03), frame_col)
	# 가끔 실외기
	if rng.randf() < 0.07:
		var ac := at + n * 0.3 + Vector3.UP * (-hh / 2.0 - 0.45) + t * 0.2
		_bx("metal", ac, t, n, Vector3(0.75, 0.5, 0.45), Color(0.7, 0.7, 0.66))
		_bx("trim", ac + n * 0.23, t, n, Vector3(0.45, 0.38, 0.02), Color(0.12, 0.12, 0.12))


func _shopfront(face: Vector3, t: Vector3, n: Vector3, L: float, y0: float, frame_col: Color) -> void:
	var w := minf(4.8, L - 2.0)
	var at := face + Vector3.UP * (y0 + 1.4)
	if rng.randf() < 0.5:
		# 녹슨 셔터 + 셔터 박스
		_bx("metal", at + n * 0.06, t, n, Vector3(w, 2.8, 0.06), Color(0.48, 0.47, 0.46).darkened(rng.randf() * 0.3))
		for j in 9:
			_bx("trim", at + n * 0.1 + Vector3.UP * (-1.3 + j * 0.32), t, n, Vector3(w, 0.04, 0.03), Color(0.22, 0.22, 0.22))
		_bx("metal", at + n * 0.18 + Vector3.UP * 1.55, t, n, Vector3(w + 0.2, 0.35, 0.35), Color(0.35, 0.35, 0.34))
	else:
		# 유리 진열창 + 문
		_bx("trim", at + n * 0.05, t, n, Vector3(w + 0.2, 2.9, 0.1), frame_col)
		var eerie := rng.randf() < 0.15
		_bx("eerie" if eerie else "glass", at + n * 0.11, t, n, Vector3(w, 2.6, 0.02),
				Color(0.3, 0.7, 0.5) if eerie else Color(0.06, 0.08, 0.1))
		for j in [-1.0, 1.0]:
			_bx("trim", at + n * 0.13 + t * j * w * 0.18, t, n, Vector3(0.08, 2.6, 0.04), frame_col)
		_bx("trim", at + n * 0.13 + Vector3.UP * 0.35, t, n, Vector3(w, 0.08, 0.04), frame_col)
	# 줄무늬 차양
	if rng.randf() < 0.5:
		var pal := [[Color(0.7, 0.15, 0.15), Color(0.9, 0.85, 0.75)], [Color(0.15, 0.4, 0.3), Color(0.85, 0.82, 0.7)], [Color(0.2, 0.3, 0.6), Color(0.9, 0.88, 0.8)]]
		var pc: Array = pal[rng.randi() % pal.size()]
		var stripes := int(w / 0.45)
		var sw := (w + 0.4) / stripes
		var torn := rng.randi() % maxi(1, stripes)
		for j in stripes:
			if j == torn and rng.randf() < 0.5:
				continue  # 찢어진 칸
			var u := -(w + 0.4) / 2.0 + sw * (j + 0.5)
			_bx("trim", face + t * u + n * 0.6 + Vector3.UP * (y0 + 3.05), t, n, Vector3(sw, 0.05, 1.2), (pc[j % 2] as Color).darkened(0.25), 0.0, 0.42)
	# 간판
	if rng.randf() < 0.4:
		_sign(face + n * 0.12 + Vector3.UP * (y0 + 3.5), absf(n.z) > 0.5)


func _fire_escape(face: Vector3, t: Vector3, n: Vector3, L: float, first: float, floors: int) -> void:
	var col := Color(0.2, 0.17, 0.16)
	var u := -L / 2.0 + 0.8 + minf(2.0, L * 0.25)
	for k in floors:
		var fy := first + k * 3.0
		var at := face + t * u + Vector3.UP * fy
		_bx("metal", at + n * 0.6, t, n, Vector3(2.8, 0.07, 1.1), col)
		_bx("metal", at + n * 1.13 + Vector3.UP * 0.95, t, n, Vector3(2.8, 0.05, 0.05), col)
		_bx("metal", at + n * 1.13 + Vector3.UP * 0.5, t, n, Vector3(2.8, 0.03, 0.03), col)
		for e in [-1.4, 0.0, 1.4]:
			_bx("metal", at + n * 1.13 + t * e + Vector3.UP * 0.48, t, n, Vector3(0.05, 0.95, 0.05), col)
		if k > 0:
			# 아래층으로 내려가는 계단
			_bx("metal", at + n * 0.6 + t * 0.2 + Vector3.UP * -1.5, t, n, Vector3(3.3, 0.06, 0.55), col, -0.95)


func _rooftop(b: Rect2, y: float) -> void:
	var c := b.get_center()
	var con := Color(0.38, 0.37, 0.35)
	# 난간벽
	for s in [[Vector3(0, 0, 1), b.size.x, b.size.y], [Vector3(0, 0, -1), b.size.x, b.size.y], [Vector3(1, 0, 0), b.size.y, b.size.x], [Vector3(-1, 0, 0), b.size.y, b.size.x]]:
		var n: Vector3 = s[0]
		var t := Vector3.UP.cross(n)
		_bx("trim", Vector3(c.x, y + 0.35, c.y) + n * (float(s[2]) / 2.0 - 0.12), t, n, Vector3(float(s[1]), 0.7, 0.24), con)
	var inner := b.grow(-1.2)
	if inner.size.x < 1.0 or inner.size.y < 1.0:
		return
	# 물탱크
	if rng.randf() < 0.4:
		var p := Vector3(rng.randf_range(inner.position.x, inner.end.x), y, rng.randf_range(inner.position.y, inner.end.y))
		_pipe(p + Vector3.UP * 2.2, 0.9, 1.9, Color(0.42, 0.3, 0.22))
		_pipe(p + Vector3.UP * 3.25, 0.5, 0.25, Color(0.3, 0.22, 0.16))
		for d in [Vector3(0.6, 0, 0.6), Vector3(-0.6, 0, 0.6), Vector3(0.6, 0, -0.6), Vector3(-0.6, 0, -0.6)]:
			_pipe(p + d + Vector3.UP * 0.65, 0.06, 1.3, Color(0.2, 0.2, 0.2))
	# 실외기·환풍구
	for i in rng.randi_range(1, 3):
		var p := Vector3(rng.randf_range(inner.position.x, inner.end.x), y, rng.randf_range(inner.position.y, inner.end.y))
		if rng.randf() < 0.6:
			_bx("metal", p + Vector3.UP * 0.4, Vector3.RIGHT, Vector3.BACK, Vector3(1.0, 0.8, 0.7), Color(0.6, 0.6, 0.57))
		else:
			_pipe(p + Vector3.UP * 0.5, 0.18, 1.0, Color(0.45, 0.45, 0.45))
	# 안테나
	if rng.randf() < 0.3:
		var p := Vector3(rng.randf_range(inner.position.x, inner.end.x), y, rng.randf_range(inner.position.y, inner.end.y))
		_pipe(p + Vector3.UP * 1.5, 0.03, 3.0, Color(0.25, 0.25, 0.25))
		_bx("metal", p + Vector3.UP * 2.6, Vector3.RIGHT, Vector3.BACK, Vector3(1.2, 0.04, 0.04), Color(0.25, 0.25, 0.25))


## 빛나는 간판 (보내주신 이미지처럼 초록/빨강)
func _sign(pos: Vector3, along_x: bool) -> void:
	var colors := [Color(0.1, 0.9, 0.4), Color(0.95, 0.2, 0.2), Color(1.0, 0.7, 0.2), Color(0.3, 0.6, 1.0)]
	var col: Color = colors[rng.randi() % colors.size()]
	var m := StandardMaterial3D.new()
	m.albedo_color = col.darkened(0.5)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 1.6 if rng.randf() < 0.7 else 0.0  # 일부는 꺼진 간판
	var size := Vector3(2.6, 0.8, 0.2) if along_x else Vector3(0.2, 0.8, 2.6)
	_box(pos, size, m, false)
	if m.emission_energy_multiplier > 0.0:
		var light := OmniLight3D.new()
		light.light_color = col
		light.omni_range = 4.0
		light.light_energy = 0.8
		light.distance_fade_enabled = true
		light.distance_fade_begin = 30.0
		light.distance_fade_length = 8.0
		region.add_child(light)
		light.position = pos
		LightFX.practical(light, 30.0, false)
		light.light_energy = 1.1
		light.omni_range = 5.0
		if light_rng.randf() < 0.3:
			LightFX.flicker(light, "fluorescent" if light_rng.randf() < 0.6 else "dying", [m])


## 공원: 풀숲이 무성하고 나무와 벤치가 있음. 가운데에 봉인석 자리
func _park(r: Rect2) -> void:
	var c := r.get_center()
	_box(Vector3(c.x, CURB / 2.0, c.y), Vector3(r.size.x, CURB, r.size.y), _mat["dirt"])
	generator_spots.append(Vector3(c.x, CURB, c.y))
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var p: Vector2 = c + corner * r.size * 0.27
		_grass(Vector3(p.x, CURB, p.y), r.size * 0.36)
	for i in 8:
		var p := _random_point_in(r.grow(-2.0), c, 6.0)
		_tree(Vector3(p.x, CURB, p.y))
	for i in 2:
		var p := _random_point_in(r.grow(-3.0), c, 3.5)
		_box(Vector3(p.x, CURB + 0.25, p.y), Vector3(1.8, 0.5, 0.6), _mat["crate"], true, rng.randf() * PI)


## 공터(폐차장): 버려진 차, 버스, 상자. 가운데에 봉인석 자리
func _lot(r: Rect2) -> void:
	var c := r.get_center()
	_box(Vector3(c.x, CURB / 2.0, c.y), Vector3(r.size.x, CURB, r.size.y), _mat["concrete"])
	generator_spots.append(Vector3(c.x, CURB, c.y))
	if rng.randf() < 0.5:
		_bus(Vector3(c.x + r.size.x * 0.3, CURB, c.y), PI / 2.0 + rng.randf_range(-0.2, 0.2))
	for i in 6:
		var p := _random_point_in(r.grow(-2.5), c, 6.5)
		_car(Vector3(p.x, CURB, p.y), rng.randf() * TAU)
	for i in 3:
		var p := _random_point_in(r.grow(-2.0), c, 4.0)
		_crates(Vector3(p.x, CURB, p.y))
	var gp := c - r.size * 0.3
	_grass(Vector3(gp.x, CURB, gp.y), Vector2(4.5, 4.5))


## rect 안의 랜덤 지점 (avoid 중심에서 min_dist 이상 떨어진 곳)
func _random_point_in(rect: Rect2, avoid: Vector2, min_dist: float) -> Vector2:
	for i in 20:
		var p := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
		if p.distance_to(avoid) >= min_dist:
			return p
	return rect.position


# ================================================================ 도로 위 소품

func _road_props() -> void:
	# 도로에 버려진 차와 버스
	for i in 30:
		var on_x := rng.randf() < 0.5
		var c: float = ROAD_CENTERS[rng.randi() % ROAD_CENTERS.size()]
		var along := rng.randf_range(-HALF + 5.0, HALF - 5.0)
		var lane := rng.randf_range(-2.0, 2.0)
		var pos := Vector3(c + lane, 0, along) if on_x else Vector3(along, 0, c + lane)
		if _near_spawn(pos, 9.0) or not _far_from_roads(along, 6.0):
			continue
		var yaw := (0.0 if on_x else PI / 2.0) + rng.randf_range(-0.5, 0.5)
		if i < 4:
			_bus(pos, yaw)
		else:
			_car(pos, yaw)
	# 가로등 (일부는 고장나서 꺼져 있음)
	for c in ROAD_CENTERS:
		var t := -HALF + 6.0
		while t <= HALF - 6.0:
			if _far_from_roads(t, 5.0):
				_lamp(Vector3(c + ROAD_HALF - 0.6, 0, t))
				_lamp(Vector3(t, 0, c - ROAD_HALF + 0.6))
			t += 17.0
	# 도로 위 얼룩·금·종이, 비 온 뒤 물웅덩이 (밤 불빛이 반사됨)
	var puddle := StandardMaterial3D.new()
	puddle.albedo_color = Color(0.03, 0.035, 0.05)
	puddle.metallic = 0.6
	puddle.roughness = 0.05
	for i in 140:
		var c: float = ROAD_CENTERS[rng.randi() % ROAD_CENTERS.size()]
		var along := rng.randf_range(-HALF + 4.0, HALF - 4.0)
		var off := rng.randf_range(-ROAD_HALF + 0.5, ROAD_HALF - 0.5)
		var pos := Vector3(c + off, 0.012, along) if rng.randf() < 0.5 else Vector3(along, 0.012, c + off)
		var r := rng.randf()
		if r < 0.35:
			kit.decal(pos, Vector3.UP, rng.randf_range(1.0, 2.6), "crack")
		elif r < 0.7:
			kit.decal(pos, Vector3.UP, rng.randf_range(1.2, 2.8), "stain")
		elif r < 0.85:
			kit.decal(pos, Vector3.UP, rng.randf_range(0.8, 1.4), "papers")
		elif r < 0.9:
			kit.decal(pos, Vector3.UP, rng.randf_range(1.0, 2.0), "blood")
		else:
			_box(pos + Vector3.UP * 0.002, Vector3(rng.randf_range(1.2, 3.0), 0.01, rng.randf_range(0.8, 2.2)), puddle, false, rng.randf() * PI)
	# 쓰레기 봉투 더미 (건물 앞 보도)
	for i in 30:
		var c: float = ROAD_CENTERS[rng.randi() % ROAD_CENTERS.size()]
		var along := rng.randf_range(-HALF + 6.0, HALF - 6.0)
		var side := ROAD_HALF + 1.6 if rng.randf() < 0.5 else -ROAD_HALF - 1.6
		var pos := Vector3(c + side, 0.05, along) if rng.randf() < 0.5 else Vector3(along, 0.05, c + side)
		if _near_spawn(pos, 6.0) or not _far_from_roads(along, 6.0):
			continue
		for k in rng.randi_range(2, 5):
			kit.part(pos + Vector3(rng.randf_range(-0.6, 0.6), 0.25, rng.randf_range(-0.6, 0.6)), Vector3(0.55, 0.5, 0.5), Color(0.06, 0.06, 0.07), "trim", false, rng.randf() * PI)
	# 도로 가장자리에 자란 잡초
	for i in 25:
		var c: float = ROAD_CENTERS[rng.randi() % ROAD_CENTERS.size()]
		var along := rng.randf_range(-HALF + 6.0, HALF - 6.0)
		var side := ROAD_HALF - 1.0 if rng.randf() < 0.5 else -ROAD_HALF + 1.0
		var pos := Vector3(c + side, 0, along) if rng.randf() < 0.5 else Vector3(along, 0, c + side)
		if not _near_spawn(pos, 6.0):
			_grass(pos, Vector2(rng.randf_range(2.0, 3.5), rng.randf_range(3.0, 6.0)))


func _near_spawn(pos: Vector3, dist: float) -> bool:
	for s in SURVIVOR_SPAWNS:
		if Vector2(pos.x, pos.z).distance_to(Vector2(s.x, s.z)) < dist:
			return true
	for s in SEEKER_SPAWNS:
		if Vector2(pos.x, pos.z).distance_to(Vector2(s.x, s.z)) < dist:
			return true
	return false


# ================================================================ 소품 모양

func _car(pos: Vector3, yaw: float) -> void:
	var body := _prop(pos, yaw, Vector3(1.9, 1.5, 4.3))
	var paint: StandardMaterial3D = _rust_mats[rng.randi() % _rust_mats.size()]
	_part(body, Vector3(0, 0.6, 0), _box_mesh(Vector3(1.9, 0.8, 4.3)), paint)
	_part(body, Vector3(0, 1.25, -0.2), _box_mesh(Vector3(1.7, 0.6, 2.2)), _mat["glass"])
	for wx in [-0.9, 0.9]:
		for wz in [-1.4, 1.4]:
			var wheel := CylinderMesh.new()
			wheel.top_radius = 0.35
			wheel.bottom_radius = 0.35
			wheel.height = 0.25
			var w := _part(body, Vector3(wx, 0.3, wz), wheel, _mat["metal"])
			w.rotation.z = PI / 2.0


func _bus(pos: Vector3, yaw: float) -> void:
	var body := _prop(pos, yaw, Vector3(2.6, 3.1, 10.0))
	var paint: StandardMaterial3D = _rust_mats[1]
	_part(body, Vector3(0, 1.6, 0), _box_mesh(Vector3(2.6, 2.6, 10.0)), paint)
	_part(body, Vector3(0, 2.2, 0), _box_mesh(Vector3(2.65, 0.9, 9.0)), _mat["glass"])
	# 버스 옆에 잡초
	var side := body.global_basis.x * 2.2
	_grass(pos + side, Vector2(2.0, 4.0))


func _dumpster(pos: Vector3, yaw: float) -> void:
	var body := _prop(pos, yaw, Vector3(1.9, 1.3, 1.1))
	_part(body, Vector3(0, 0.65, 0), _box_mesh(Vector3(1.9, 1.3, 1.1)), _rust_mats[rng.randi() % _rust_mats.size()])


func _crates(pos: Vector3) -> void:
	var body := _prop(pos, rng.randf() * PI, Vector3(2.0, 1.1, 1.1))
	_part(body, Vector3(-0.5, 0.55, 0), _box_mesh(Vector3(1.0, 1.1, 1.1)), _mat["crate"])
	_part(body, Vector3(0.5, 0.45, 0), _box_mesh(Vector3(0.9, 0.9, 0.9)), _mat["crate"])


func _tree(pos: Vector3) -> void:
	var body := _prop(pos, 0.0, Vector3(0.5, 3.0, 0.5))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.28
	trunk.height = 3.2
	_part(body, Vector3(0, 1.6, 0), trunk, _mat["trunk"])
	var leaves := SphereMesh.new()
	leaves.radius = rng.randf_range(1.6, 2.2)
	leaves.height = leaves.radius * 1.7
	_part(body, Vector3(0, 3.9, 0), leaves, _mat["leaves"])


func _lamp(pos: Vector3) -> void:
	var body := _prop(pos, 0.0, Vector3(0.25, 5.0, 0.25))
	_part(body, Vector3(0, 2.5, 0), _box_mesh(Vector3(0.14, 5.0, 0.14)), _mat["metal"])
	_part(body, Vector3(0, 5.0, 0), _box_mesh(Vector3(0.5, 0.15, 0.3)), _mat["metal"])
	if rng.randf() < 0.55:
		# 나트륨 가로등: 아래로 퍼지는 원뿔 빛 (안개 속에서 빛기둥) + 빛나는 등갓 + 은은한 주변광
		var glow := LightFX.glow_mat(Color(1.0, 0.7, 0.4), 4.0)
		_part(body, Vector3(0, 4.9, 0), _box_mesh(Vector3(0.36, 0.04, 0.2)), glow)
		var light := SpotLight3D.new()
		light.light_color = Color(1.0, 0.66, 0.36)
		light.spot_range = 12.0
		light.spot_angle = 58.0
		light.spot_attenuation = 0.9
		light.spot_angle_attenuation = 0.7
		light.light_energy = 3.2
		light.light_volumetric_fog_energy = 2.2
		light.position = Vector3(0, 4.85, 0)
		light.rotation.x = -PI / 2.0
		body.add_child(light)
		LightFX.practical(light, 45.0)  # 최적화: 먼 가로등 빛은 생략, 가까우면 그림자
		var r := light_rng.randf()
		if r >= 0.3:
			var halo := OmniLight3D.new()
			halo.light_color = Color(1.0, 0.66, 0.36)
			halo.omni_range = 5.0
			halo.light_energy = 0.35
			halo.position = Vector3(0, 4.6, 0)
			halo.light_volumetric_fog_energy = 0.0  # 최적화
			body.add_child(halo)
			LightFX.practical(halo, 35.0, false)
		if r < 0.15:
			LightFX.flicker(light, "dying", [glow])
		elif r < 0.3:
			LightFX.flicker(light, "fluorescent", [glow])
		elif r < 0.55:
			LightFX.moths(body, Vector3(0, 4.6, 0))
	else:
		_part(body, Vector3(0, 4.9, 0), _box_mesh(Vector3(0.36, 0.04, 0.2)), _flat_mat(Color(0.12, 0.12, 0.11), 0.5))
