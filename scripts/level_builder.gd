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
var _building_mats: Array[StandardMaterial3D] = []
var _rust_mats: Array[StandardMaterial3D] = []


func build(target: Node3D, map_seed: int) -> void:
	region = target
	rng.seed = map_seed
	_make_materials()
	_ground()
	_outer_walls()
	_blocks()
	_road_props()


# ================================================================ 재질 (질감)

func _make_materials() -> void:
	_mat["asphalt"] = _noise_mat(Color(0.16, 0.16, 0.17), 0.35, 0.95, 6.0)
	_mat["sidewalk"] = _noise_mat(Color(0.42, 0.41, 0.39), 0.5, 0.9, 3.0)
	_mat["concrete"] = _noise_mat(Color(0.36, 0.35, 0.33), 0.4, 0.95, 4.0)
	_mat["dirt"] = _noise_mat(Color(0.2, 0.22, 0.14), 0.4, 1.0, 4.0)
	_mat["wall"] = _noise_mat(Color(0.3, 0.29, 0.28), 0.3, 0.95, 4.0)
	for c in [Color(0.5, 0.5, 0.47), Color(0.55, 0.49, 0.4), Color(0.38, 0.45, 0.44), Color(0.46, 0.3, 0.25), Color(0.42, 0.42, 0.45)]:
		_building_mats.append(_noise_mat(c, 0.25, 0.9, 5.0))
	for c in [Color(0.35, 0.22, 0.15), Color(0.25, 0.35, 0.3), Color(0.45, 0.4, 0.3), Color(0.3, 0.32, 0.38), Color(0.5, 0.25, 0.2)]:
		_rust_mats.append(_noise_mat(c, 0.6, 0.6, 3.0))
	_mat["windows"] = _window_mat()
	_mat["shutter"] = _stripe_mat()
	_mat["glass"] = _flat_mat(Color(0.05, 0.07, 0.09), 0.2)
	_mat["metal"] = _flat_mat(Color(0.2, 0.2, 0.22), 0.5)
	_mat["trunk"] = _noise_mat(Color(0.25, 0.18, 0.12), 0.5, 1.0, 2.0)
	_mat["leaves"] = _noise_mat(Color(0.12, 0.22, 0.1), 0.6, 1.0, 2.0)
	_mat["paint"] = _flat_mat(Color(0.75, 0.75, 0.7), 0.8)
	_mat["crate"] = _noise_mat(Color(0.4, 0.3, 0.18), 0.6, 1.0, 2.0)


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
	_mark_indestructible(_box(Vector3(0, h / 2, -HALF), Vector3(HALF * 2 + 1, h, 1), _mat["wall"]))
	_mark_indestructible(_box(Vector3(0, h / 2, HALF), Vector3(HALF * 2 + 1, h, 1), _mat["wall"]))
	_mark_indestructible(_box(Vector3(-HALF, h / 2, 0), Vector3(1, h, HALF * 2 + 1), _mat["wall"]))
	_mark_indestructible(_box(Vector3(HALF, h / 2, 0), Vector3(1, h, HALF * 2 + 1), _mat["wall"]))


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
	var h := rng.randf_range(6.0, 15.0)
	var base_y := CURB
	var c := b.get_center()
	_box(Vector3(c.x, base_y + h / 2.0, c.y), Vector3(b.size.x, h, b.size.y), _building_mats[rng.randi() % _building_mats.size()])
	# 옥상 테두리
	_box(Vector3(c.x, base_y + h + 0.2, c.y), Vector3(b.size.x + 0.3, 0.4, b.size.y + 0.3), _mat["concrete"], false)

	# 네 면에 창문과 1층 셔터, 가끔 간판
	var win_h := h - 4.2
	var sides := [
		[Vector3(b.end.x + 0.04, 0, c.y), Vector3(0.08, 0, b.size.y - 1.2), b.size.y],
		[Vector3(b.position.x - 0.04, 0, c.y), Vector3(0.08, 0, b.size.y - 1.2), b.size.y],
		[Vector3(c.x, 0, b.end.y + 0.04), Vector3(b.size.x - 1.2, 0, 0.08), b.size.x],
		[Vector3(c.x, 0, b.position.y - 0.04), Vector3(b.size.x - 1.2, 0, 0.08), b.size.x],
	]
	for s in sides:
		var p: Vector3 = s[0]
		var sz: Vector3 = s[1]
		var side_len: float = s[2]
		if win_h > 1.5:
			_box(Vector3(p.x, base_y + 3.6 + win_h / 2.0, p.z), Vector3(sz.x, win_h, sz.z), _mat["windows"], false)
		if side_len > 5.0:
			var w := minf(4.5, side_len - 2.0)
			var shutter_size := Vector3(w if sz.x > 1.0 else 0.1, 2.8, w if sz.z > 1.0 else 0.1)
			_box(Vector3(p.x, base_y + 1.4, p.z), shutter_size, _mat["shutter"], false)
			if rng.randf() < 0.35:
				_sign(Vector3(p.x, base_y + 3.2, p.z), sz.x > 1.0)


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
		region.add_child(light)
		light.position = pos


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
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.72, 0.4)
		light.omni_range = 9.0
		light.light_energy = 1.3
		light.position = Vector3(0, 4.8, 0)
		body.add_child(light)
