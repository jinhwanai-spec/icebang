class_name BuildingKit
extends RefCounted
## 들어갈 수 있는 건물 만들기 도구 (도시 건물·학교·병원이 같이 씀)
## - 벽에 문·창문 구멍을 뚫고, 층마다 바닥(계단 구멍 포함), 경사로 계단, 방 나누기, 가구, 사물함·문, 조명
## - 보이는 부품은 같은 재질끼리 MultiMesh 로 모아 그리고(LevelBuilder._batch),
##   부딪히는 부분은 큰 StaticBody 하나에 상자 모양을 여러 개 붙여서 가볍게 만듭니다.
## - 좌표는 모두 월드 기준(맵 중심 0,0). 1층 바닥 높이 = y0

const WALL_T := 0.25
const FLOOR_T := 0.2
const DOOR_W := 1.7
const DOOR_H := 2.3
const WIN_SILL := 0.95
const WIN_TOP := 2.2

var lb: LevelBuilder
var rng: RandomNumberGenerator
## 길 계산에 들어가는 부딪힘 (벽·바닥·가구)
var body: StaticBody3D
## 길 계산에서 빼는 부딪힘 (지붕 위, 건물 윗부분 덩어리) → 지붕 위에 길이 생기지 않음
var roof_body: StaticBody3D
var _cube: BoxMesh
var _lights := 0
const MAX_LIGHTS := 64
const LightFX := preload("res://scripts/light_fx.gd")

## 실내 마감 (학교·병원에서 켬): 벽 아래쪽 판(타일·나무), 걸레받이·몰딩 색, 천장 재질
var wainscot_mat: Material = null
var wainscot_h := 1.1
var trim_col := Color(0.3, 0.27, 0.24)
## 바깥벽 안쪽 면에 덧바르는 실내 벽지 (바깥 재질이 안에서 보이지 않게)
var lining_mat: Material = null
## 복도식 건물(학교): 교실 복도 벽에 높은 창문을 낼지
var corridor_windows := false
## 문 모양: "" = 나무 판자문, "school" / "hospital" = 칠한 판문(창 있음)
var door_style := ""
var _lining_side := 0


func _init(builder: LevelBuilder) -> void:
	lb = builder
	rng = builder.rng
	body = StaticBody3D.new()
	body.name = "Interiors"
	body.set_meta("indestructible", true)
	lb.region.add_child(body)
	roof_body = StaticBody3D.new()
	roof_body.name = "Roofs"
	roof_body.set_meta("indestructible", true)
	roof_body.set_meta("nav_ignore", true)
	lb.region.add_child(roof_body)
	_cube = BoxMesh.new()


# ================================================================ 기본 부품

## 상자 하나 (보이는 것 + 선택적으로 부딪힘). basis 로 기울이기 가능
func block(center: Vector3, size: Vector3, mat: Material, key: String, collide := true, basis := Basis.IDENTITY, roof := false, col := Color.WHITE) -> void:
	if size.x <= 0.01 or size.y <= 0.01 or size.z <= 0.01:
		return
	# 같은 이름이라도 재질이 다르면 따로 모음 (안 그러면 처음 재질로 다 그려짐)
	var bkey := key + "#%d" % mat.get_instance_id()
	lb._batch(bkey, _cube, mat, Transform3D(basis * Basis.from_scale(size), center), col)
	if collide:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.transform = Transform3D(basis, center)
		(roof_body if roof else body).add_child(cs)
		# 창문 유리: 파쿠르로 깨고 넘을 수 있게 기록 (유리 가운데, 크기, 방향, 충돌, 그림 번호)
		if key == "b_glass" or key == "b_lit":
			lb.windows.append({"c": center, "size": size, "basis": basis, "cs": cs, "key": bkey, "idx": lb._batches[bkey][3].size() - 1})


## 가구를 놓을 때 비워 둘 문 앞 공간 (furnish_room 이 잠깐 정함). 크기 0 이면 검사 안 함
var door_clear := Rect2()


## 이 가구가 문 앞을 막는지 (바닥 평면 기준 대략적인 사각형으로 검사)
var door_clears: Array = []  # 문이 여러 개인 방 (도시 건물)

func blocks_door(center: Vector3, size: Vector3, yaw := 0.0) -> bool:
	if door_clear.size == Vector2.ZERO and door_clears.is_empty():
		return false
	var quarter := absf(fposmod(yaw + PI / 4.0, PI / 2.0) - PI / 4.0) < 0.05
	var fx := size.x
	var fz := size.z
	if not quarter:
		fx = maxf(size.x, size.z)
		fz = fx
	elif absf(sin(yaw)) > 0.7:
		fx = size.z
		fz = size.x
	var fr := Rect2(center.x - fx * 0.5, center.z - fz * 0.5, fx, fz)
	if door_clear.size != Vector2.ZERO and door_clear.intersects(fr):
		return true
	for dc in door_clears:
		if (dc as Rect2).intersects(fr):
			return true
	return false


## wing() 이 돌려준 방 하나를 꾸밈. 문 앞은 비워 두어서 문이 가구에 막히지 않게
func furnish_room(rm: Dictionary, y: float, keep_center := false) -> Vector3:
	var d: Vector3 = rm.get("door_at", Vector3.INF)
	if d != Vector3.INF:
		var along_x: bool = rm.get("door_along_x", true)
		door_clear = Rect2(d.x - 1.2, d.z - 2.6, 2.4, 5.2) if along_x else Rect2(d.x - 2.6, d.z - 1.2, 5.2, 2.4)
	door_at = d
	# 가운데(봉인석 자리)를 비우는 방: 문에서 가운데까지 ㄱ자 통로도 비워 둠 (봇이 봉인석에 갈 수 있게)
	if keep_center and d != Vector3.INF:
		var c: Vector2 = (rm["rect"] as Rect2).get_center()
		var ax: bool = rm.get("door_along_x", true)
		if ax:
			door_clears = [Rect2(d.x - 0.9, minf(d.z, c.y) - 0.9, 1.8, absf(c.y - d.z) + 1.8), Rect2(minf(d.x, c.x) - 0.9, c.y - 0.9, absf(c.x - d.x) + 1.8, 1.8)]
		else:
			door_clears = [Rect2(minf(d.x, c.x) - 0.9, d.z - 0.9, absf(c.x - d.x) + 1.8, 1.8), Rect2(c.x - 0.9, minf(d.z, c.y) - 0.9, 1.8, absf(c.y - d.z) + 1.8)]
	var out := furnish(rm["rect"], y, rm["kind"], keep_center)
	door_clear = Rect2()
	door_clears = []
	door_at = Vector3.INF
	return out


## 지금 꾸미는 방의 문 위치 (모르면 INF). 창가·칠판 방향을 정할 때 씀
var door_at := Vector3.INF
## 방 높이 (커튼·벽 장식 위치용). 건물마다 바꿈
var room_h := 3.2


## 방에서 문 반대쪽(바깥 창가) 벽: 0 = x-, 1 = x+, 2 = z-, 3 = z+. 모르면 -1
func _window_side(room: Rect2) -> int:
	if door_at == Vector3.INF:
		return -1
	var c := room.get_center()
	var dx := door_at.x - c.x
	var dz := door_at.z - c.y
	if absf(dz) / room.size.y >= absf(dx) / room.size.x:
		return 2 if dz > 0.0 else 3
	return 0 if dx > 0.0 else 1


## 보이지 않는 부딪힘만
func solid(center: Vector3, size: Vector3, basis := Basis.IDENTITY) -> void:
	if (door_clear.size != Vector2.ZERO or not door_clears.is_empty()) and blocks_door(center, size, basis.get_euler().y):
		return
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.transform = Transform3D(basis, center)
	body.add_child(cs)


## 색만 다른 작은 부품 (가구 등). key 는 LevelBuilder._deco_mat 종류 ("trim", "metal", "glass", "lit")
func part(center: Vector3, size: Vector3, col: Color, key := "trim", collide := false, yaw := 0.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	# 가구를 놓는 중: 문 앞(양쪽 1m)을 막으면 그 가구 전체를 빼 버림 (부품만 빠져서 떠 있는 일 없게)
	var hit := _furn > 0 and size.y > 0.08 and _in_doorway(center, size, yaw)
	if hit and _obj_depth == 0:
		return
	if hit:
		_obj_bad = true
	var dbg: Array = [center, size, collide, yaw, _furn_kind] if debug_record and _furn > 0 else []
	var bkey := "b_" + key
	lb._batch(bkey, _cube, lb._deco_mat(key), Transform3D(b * Basis.from_scale(size), center), col)
	var entry: Array = [bkey, lb._batches[bkey][3].size() - 1, null, dbg, center, size, yaw]
	if collide and not blocks_door(center, size, yaw):
		solid(center, size, b)
		entry[2] = body.get_child(body.get_child_count() - 1)
	if _obj_depth > 0:
		_obj_parts.append(entry)
	elif _furn > 0:
		_objects.append([entry])  # 따로 놓인 부품도 마지막 검사 대상


# ---------------------------------------------------------------- 가구 한 덩어리 (문 앞이면 통째로 뺌)

var _obj_depth := 0
var _obj_bad := false
var _obj_parts: Array = []  # [묶음 이름, 번호, 충돌 모양 또는 null]


func _obj_begin() -> void:
	if _obj_depth == 0:
		_obj_bad = false
		_obj_parts = []
	_obj_depth += 1


func _obj_end() -> void:
	_obj_depth -= 1
	if _obj_depth > 0:
		return
	if _obj_bad:
		_drop_object(_obj_parts)
	else:
		_objects.append(_obj_parts)
	_obj_parts = []
	_obj_bad = false


## 놓인 가구들 (마지막에 한 번 더 문 검사: 가구를 놓은 뒤에 뚫린 문도 있어서)
var _objects: Array = []


func _drop_object(parts: Array) -> void:
	for e in parts:
		if not lb._batches.has(e[0]):
			continue
		var arr: Array = lb._batches[e[0]][3]
		if int(e[1]) >= arr.size():
			continue
		var xf: Transform3D = arr[e[1]]
		arr[e[1]] = Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), xf.origin)
		if e[2] != null and is_instance_valid(e[2]):
			var nd := e[2] as Node
			if nd.get_parent():
				nd.get_parent().remove_child(nd)
			nd.queue_free()
	if debug_record:
		lb.set_meta("dbg_dropped", int(lb.get_meta("dbg_dropped", 0)) + 1)


## 그림을 합치기 직전(LevelBuilder._flush_batches): 모든 문이 다 뚫린 뒤 문 앞 가구를 마저 뺌
func final_door_pass() -> void:
	for parts in _objects:
		var bad := false
		for e in parts:
			var sz: Vector3 = e[5]
			if sz.y > 0.08 and _in_doorway(e[4], sz, float(e[6])):
				bad = true
				break
		if bad:
			_drop_object(parts)
		elif debug_record:
			for e in parts:
				if not (e[3] as Array).is_empty():
					lb.set_meta("dbg_furn", lb.get_meta("dbg_furn", []) + [e[3]])
	_objects = []


## 이 부품이 어떤 문(출입구) 앞 통로에 걸치는지: 문 폭 안쪽, 벽 양쪽 1m
func _in_doorway(center: Vector3, size: Vector3, yaw: float, any_floor := false) -> bool:
	if blocks_door(center, size, yaw):
		return true
	var r := maxf(size.x, size.z) * 0.5
	if absf(fposmod(yaw, PI / 2.0)) < 0.05 or absf(fposmod(yaw, PI / 2.0) - PI / 2.0) < 0.05:
		r = 0.0  # 반듯한 가구는 아래에서 축별로 정확히 계산
	for d in lb.doorways:
		var c: Vector3 = d[0]
		if not any_floor and (absf(center.y - c.y) > 2.5 or center.y - size.y * 0.5 > c.y + 1.9):
			continue
		var dir: Vector3 = d[1]
		var w: float = d[2]
		var rel := center - c
		var n := Vector3(-dir.z, 0, dir.x)
		var ha: float
		var hn: float
		if r > 0.0:
			ha = r
			hn = r
		else:
			var ax := Basis(Vector3.UP, yaw)
			var ex: Vector3 = ax.x * size.x * 0.5
			var ez: Vector3 = ax.z * size.z * 0.5
			ha = absf(ex.dot(dir)) + absf(ez.dot(dir))
			hn = absf(ex.dot(n)) + absf(ez.dot(n))
		if absf(rel.dot(dir)) < w * 0.5 - 0.1 + ha and absf(rel.dot(n)) < 1.2 + hn:
			return true
	return false


## 벽 한 면: a → b (수평 선분), y 부터 높이 h. openings = [[시작 거리, 끝 거리, 아래 높이, 위 높이], ...] (벽을 따라 a 에서 잰 거리)
## 구멍 사이·위·아래를 상자로 채움. glass=true 면 창문 구멍에 유리(부딪힘 있음)
func wall(a: Vector3, b: Vector3, y: float, h: float, mat: Material, key: String, openings: Array = [], t := WALL_T, trim_side := 0) -> void:
	var d := Vector3(b.x - a.x, 0, b.z - a.z)
	var L := d.length()
	if L < 0.05:
		return
	var dir := d / L
	var basis := Basis(dir, Vector3.UP, dir.cross(Vector3.UP).normalized())
	var ops := openings.duplicate()
	ops.sort_custom(func(p, q): return p[0] < q[0])
	_lining_side = trim_side if (lining_mat and (trim_side == 1 or trim_side == -1)) else 0
	var u := 0.0
	for o in ops:
		var o0 := clampf(float(o[0]), 0.0, L)
		var o1 := clampf(float(o[1]), 0.0, L)
		if o1 <= o0:
			continue
		if float(o[2]) <= 0.01 and float(o[3]) >= 1.9:
			# 바닥까지 뚫린 구멍 = 문 (가구가 막지 않게 기록)
			var dc := a + dir * ((o0 + o1) * 0.5)
			dc.y = y
			lb.doorways.append([dc, dir, o1 - o0])
		if o0 > u:
			_wall_piece(a, dir, basis, u, o0, y, y + h, mat, key, t)
		# 구멍 아래와 위
		_wall_piece(a, dir, basis, o0, o1, y, y + float(o[2]), mat, key, t)
		_wall_piece(a, dir, basis, o0, o1, y + float(o[3]), y + h, mat, key, t)
		u = maxf(u, o1)
	if u < L:
		_wall_piece(a, dir, basis, u, L, y, y + h, mat, key, t)
	if wainscot_mat and trim_side != 2:
		_wall_trim(a, dir, L, y, ops, t, trim_side)


## 벽 아래 마감: 판(wainscot) + 걸레받이 + 몰딩. side 0 = 양면, 1 / -1 = 한쪽 면만 (바깥벽 안쪽)
func _wall_trim(a: Vector3, dir: Vector3, L: float, y: float, ops: Array, t: float, side: int) -> void:
	var spans := []  # [u0, u1, 높이]
	var u := 0.0
	for o in ops:
		var o0 := clampf(float(o[0]), 0.0, L)
		var o1 := clampf(float(o[1]), 0.0, L)
		if o1 <= o0:
			continue
		if o0 > u:
			spans.append([u, o0, wainscot_h])
		if float(o[2]) > 0.3:
			spans.append([o0, o1, minf(wainscot_h, float(o[2]) - 0.03)])
		u = maxf(u, o1)
	if u < L:
		spans.append([u, L, wainscot_h])
	var n := dir.cross(Vector3.UP).normalized()
	var yaw := atan2(-dir.z, dir.x)
	var sides: Array = [0.0] if side == 0 else [float(side)]
	for sp in spans:
		var u0: float = sp[0]
		var u1: float = sp[1]
		var hh: float = sp[2]
		if u1 - u0 < 0.05:
			continue
		var c := a + dir * ((u0 + u1) * 0.5)
		for sd in sides:
			var th: float = t + 0.04 if sd == 0.0 else 0.02
			var off: Vector3 = n * (float(sd) * (t * 0.5 + 0.01))
			block(c + off + Vector3.UP * (y + hh * 0.5), Vector3(u1 - u0, hh, th), wainscot_mat, "w_wains%d" % wainscot_mat.get_instance_id(), false, Basis(Vector3.UP, yaw))
			var bt: float = t + 0.07 if sd == 0.0 else 0.035
			var boff: Vector3 = n * (float(sd) * (t * 0.5 + 0.02))
			part(c + boff + Vector3.UP * (y + 0.07), Vector3(u1 - u0, 0.14, bt), trim_col, "trim", false, yaw)
			if hh > 0.6:
				part(c + boff + Vector3.UP * (y + hh), Vector3(u1 - u0, 0.06, bt), trim_col.lightened(0.15), "trim", false, yaw)


## 천장 마감판 (바닥판 아래에 얇게, 보이기만). y = 천장 높이(아래면)
func ceiling(r: Rect2, y: float, mat: Material, holes: Array = [], floor_y := INF) -> void:
	var pieces := [r]
	for hole in holes:
		var next := []
		for p in pieces:
			next.append_array(_subtract(p, hole))
		pieces = next
	for p in pieces:
		var pr: Rect2 = p
		block(Vector3(pr.get_center().x, y - 0.015, pr.get_center().y), Vector3(pr.size.x, 0.03, pr.size.y), mat, "w_ceil%d" % mat.get_instance_id(), false)
		# 천장 환기구·스프링클러 (작은 부품) + 가끔 떨어진 천장판
		var cnt := int(pr.get_area() / 30.0)
		for i in cnt:
			var q := Vector3(rng.randf_range(pr.position.x + 0.5, pr.end.x - 0.5), y - 0.04, rng.randf_range(pr.position.y + 0.5, pr.end.y - 0.5))
			var rr := rng.randf()
			if rr < 0.45:
				part(q, Vector3(0.6, 0.03, 0.6), Color(0.75, 0.75, 0.73), "metal")
				for k in 3:
					part(q + Vector3(0, -0.02, -0.2 + k * 0.2), Vector3(0.5, 0.01, 0.04), Color(0.25, 0.25, 0.25), "metal")
			elif rr < 0.8:
				part(q + Vector3.DOWN * 0.04, Vector3(0.06, 0.08, 0.06), Color(0.7, 0.6, 0.3), "metal")
			elif rr < 0.92 and floor_y != INF:
				part(q + Vector3.DOWN * 0.02, Vector3(0.6, 0.02, 0.6), Color(0.04, 0.04, 0.05), "trim")  # 빠진 천장판 구멍
				part(Vector3(q.x + rng.randf_range(-0.6, 0.6), floor_y + 0.03, q.z + rng.randf_range(-0.6, 0.6)), Vector3(0.6, 0.025, 0.6), Color(0.7, 0.7, 0.68), "trim", false, rng.randf() * PI)


## 방 바닥재 (보이기만, 바닥판 위에 아주 얇게)
func floor_overlay(r: Rect2, y: float, mat: Material) -> void:
	block(Vector3(r.get_center().x, y + 0.006, r.get_center().y), Vector3(r.size.x - 0.02, 0.012, r.size.y - 0.02), mat, "w_flo%d" % mat.get_instance_id(), false)


## 얼룩·핏자국·종이·금 (반투명 판). normal = 붙는 면의 바깥 방향
var _decal_mats := {}
func decal(p: Vector3, normal: Vector3, size: float, kind: String, spin := -1.0) -> void:
	if not _decal_mats.has(kind):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://assets/textures/gen/decal_%s.png" % kind)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.6 if kind == "blood" else 0.95
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_decal_mats[kind] = m
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		_decal_mats[kind + "_mesh"] = q
	var nrm := normal.normalized()
	var up := Vector3.UP if absf(nrm.y) < 0.9 else Vector3.FORWARD
	var xb := up.cross(nrm).normalized()
	var yb := nrm.cross(xb)
	var bas := Basis(xb, yb, nrm) * Basis(Vector3.BACK, rng.randf() * TAU if spin < 0.0 else spin)
	lb._batch("decal_" + kind, _decal_mats[kind + "_mesh"], _decal_mats[kind], Transform3D(bas.scaled(Vector3(size, size, 1)), p + nrm * 0.012), Color.WHITE, false)


## 방 안에 지저분한 흔적 몇 개 (바닥 얼룩·종이·핏자국, 벽 금·물 얼룩)
func grime(room: Rect2, y: float, h: float, amount := 1.0, blood := 0.25, wall_sides: Array = [0, 1, 2, 3]) -> void:
	var n := int(round((room.size.x * room.size.y) / 14.0 * amount))
	for i in n:
		var p := Vector3(rng.randf_range(room.position.x + 0.4, room.end.x - 0.4), y + 0.002, rng.randf_range(room.position.y + 0.4, room.end.y - 0.4))
		var r := rng.randf()
		var kind := "blood" if r < blood else ("papers" if r < blood + 0.35 else "stain")
		decal(p, Vector3.UP, rng.randf_range(0.8, 1.8) if kind != "papers" else rng.randf_range(0.9, 1.4), kind)
	# 벽: 네 벽 중 몇 곳에 금·얼룩
	for i in (maxi(1, n / 2) if not wall_sides.is_empty() else 0):
		var s: int = wall_sides[rng.randi() % wall_sides.size()]
		var u := rng.randf_range(0.15, 0.85)
		var wy := y + rng.randf_range(0.6, h - 0.6)
		var pos: Vector3
		var nr: Vector3
		match s:
			0:
				pos = Vector3(room.position.x + 0.11, wy, lerpf(room.position.y, room.end.y, u)); nr = Vector3.RIGHT
			1:
				pos = Vector3(room.end.x - 0.11, wy, lerpf(room.position.y, room.end.y, u)); nr = Vector3.LEFT
			2:
				pos = Vector3(lerpf(room.position.x, room.end.x, u), wy, room.position.y + 0.11); nr = Vector3.BACK
			_:
				pos = Vector3(lerpf(room.position.x, room.end.x, u), wy, room.end.y - 0.11); nr = Vector3.FORWARD
		var wk := "crack" if rng.randf() < 0.5 else ("blood" if rng.randf() < blood * 0.6 else "stain")
		decal(pos, nr, rng.randf_range(0.8, 1.6), wk)


func _wall_piece(a: Vector3, dir: Vector3, basis: Basis, u0: float, u1: float, y0: float, y1: float, mat: Material, key: String, t: float) -> void:
	if u1 - u0 < 0.01 or y1 - y0 < 0.01:
		return
	var c := a + dir * ((u0 + u1) * 0.5)
	c.y = (y0 + y1) * 0.5
	block(c, Vector3(u1 - u0, y1 - y0, t), mat, key, true, basis)
	if _lining_side != 0:
		var n := dir.cross(Vector3.UP).normalized()
		block(c + n * (_lining_side * (t * 0.5 + 0.008)), Vector3(u1 - u0, y1 - y0, 0.014), lining_mat, "w_lin%d" % lining_mat.get_instance_id(), false, basis)


## 바닥판: rect(xz) 높이 y(윗면), holes = [Rect2...] 를 빼고 채움
func slab(r: Rect2, y: float, mat: Material, key: String, holes: Array = [], roof := false, t := FLOOR_T) -> void:
	var pieces := [r]
	for hole in holes:
		var next := []
		for p in pieces:
			next.append_array(_subtract(p, hole))
		pieces = next
	for p in pieces:
		var pr: Rect2 = p
		block(Vector3(pr.get_center().x, y - t * 0.5, pr.get_center().y), Vector3(pr.size.x, t, pr.size.y), mat, key, true, Basis.IDENTITY, roof)


func _subtract(r: Rect2, h: Rect2) -> Array:
	if not r.intersects(h):
		return [r]
	var out := []
	var i := r.intersection(h)
	if i.position.y > r.position.y:
		out.append(Rect2(r.position.x, r.position.y, r.size.x, i.position.y - r.position.y))
	if i.end.y < r.end.y:
		out.append(Rect2(r.position.x, i.end.y, r.size.x, r.end.y - i.end.y))
	if i.position.x > r.position.x:
		out.append(Rect2(r.position.x, i.position.y, i.position.x - r.position.x, i.size.y))
	if i.end.x < r.end.x:
		out.append(Rect2(i.end.x, i.position.y, r.end.x - i.end.x, i.size.y))
	return out


## 계단: strip(xz 직사각형) 안에서 along_x 방향으로 올라감. forward=true 면 +방향으로 올라감
## 부딪힘은 매끈한 경사로, 보이는 것은 계단 단 + 난간
var stair_list: Array = []
var entrances: Array = []  # 디버그용 [문 중심, 바깥 방향]  # 디버그용 [strip, along_x, forward, y_bottom, rise]

func stairs(strip: Rect2, along_x: bool, forward: bool, y_bottom: float, rise: float, step_col := Color(0.5, 0.48, 0.45)) -> void:
	stair_list.append([strip, along_x, forward, y_bottom, rise])
	var run := strip.size.x if along_x else strip.size.y
	var width := strip.size.y if along_x else strip.size.x
	var c := strip.get_center()
	var dir := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	if not forward:
		dir = -dir
	var side := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
	var ang := atan2(rise, run)
	var len := sqrt(run * run + rise * rise)
	# 경사로 (부딪힘만)
	var basis := Basis(dir, Vector3.UP, dir.cross(Vector3.UP).normalized())
	basis = basis * Basis(Vector3(0, 0, 1), ang)
	solid(Vector3(c.x, y_bottom + rise * 0.5 - 0.08, c.y), Vector3(len, 0.16, width - 0.05), basis)
	# 계단 단
	var steps := int(rise / 0.2)
	for i in steps:
		var k := (i + 0.5) / steps
		var p := Vector3(c.x, 0, c.y) + dir * (-run * 0.5 + k * run)
		var h := (i + 1) * rise / steps
		part(Vector3(p.x, y_bottom + h * 0.5, p.z), Vector3(run / steps + 0.02, h, width) if along_x else Vector3(width, h, run / steps + 0.02), step_col.darkened(0.08 * (i % 2)))
	# 난간 (양옆)
	for s in [-1.0, 1.0]:
		var rp: Vector3 = Vector3(c.x, 0, c.y) + side * (width * 0.5 - 0.05) * s
		var rail_basis := Basis(dir, Vector3.UP, dir.cross(Vector3.UP).normalized()) * Basis(Vector3(0, 0, 1), ang)
		lb._batch("b_metal", _cube, lb._deco_mat("metal"), Transform3D(rail_basis * Basis.from_scale(Vector3(len, 0.06, 0.06)), rp + Vector3.UP * (y_bottom + rise * 0.5 + 0.95)), Color(0.25, 0.25, 0.27))


## 바닥 구멍 둘레 난간 (open_side 쪽은 비워 둠: "x-" "x+" "z-" "z+")
func hole_rail(hole: Rect2, y: float, open_side: String) -> void:
	var col := Color(0.25, 0.25, 0.27)
	var sides := {
		"z-": [Vector3(hole.position.x, y, hole.position.y), Vector3(hole.end.x, y, hole.position.y)],
		"z+": [Vector3(hole.position.x, y, hole.end.y), Vector3(hole.end.x, y, hole.end.y)],
		"x-": [Vector3(hole.position.x, y, hole.position.y), Vector3(hole.position.x, y, hole.end.y)],
		"x+": [Vector3(hole.end.x, y, hole.position.y), Vector3(hole.end.x, y, hole.end.y)],
	}
	for k in sides:
		if k == open_side:
			continue
		var a: Vector3 = sides[k][0]
		var b: Vector3 = sides[k][1]
		var mid := (a + b) * 0.5
		var size := Vector3(absf(b.x - a.x) + 0.06, 1.0, 0.06) if absf(b.x - a.x) > 0.01 else Vector3(0.06, 1.0, absf(b.z - a.z) + 0.06)
		part(mid + Vector3.UP * 0.95, Vector3(size.x, 0.06, size.z), col, "metal")
		solid(mid + Vector3.UP * 0.5, Vector3(size.x, 1.0, size.z))
		var n := int(maxf(size.x, size.z) / 0.5)
		for i in n + 1:
			var p := a.lerp(b, float(i) / maxf(1, n))
			part(p + Vector3.UP * 0.48, Vector3(0.04, 0.96, 0.04), col, "metal")


## 천장 조명. 상태 4가지: 켜짐 / 깜빡임(웅웅 소리) / 희미하게 켜짐 / 고장(꺼진 등)
## (맵 배치용 rng 는 예전과 똑같이 부르고, 나머지 조명 선택은 lb.light_rng 로 → 조명을 바꿔도 가구 배치가 그대로)
func ceiling_light(p: Vector3, color := Color(1.0, 0.9, 0.7), energy := 0.9, rng_on := 0.45) -> void:
	var on := false
	var flick := false
	if _lights < MAX_LIGHTS and rng.randf() <= rng_on:
		_lights += 1
		on = true
		flick = rng.randf() < 0.3
	var dim := false
	var lr := lb.light_rng
	if not on and lr.randf() < 0.3:
		on = true
		dim = true  # 꺼진 줄 알았던 등 일부는 힘없이 희미하게
		flick = lr.randf() < 0.35
	# 등 몸통 (회색 틀) + 형광관
	part(p + Vector3.UP * 0.0, Vector3(0.98, 0.06, 0.36), Color(0.42, 0.43, 0.45), "metal")
	var tube_pos := p + Vector3.DOWN * 0.035
	var tube_size := Vector3(0.88, 0.03, 0.26)
	if not on:
		part(tube_pos, tube_size, Color(0.32, 0.34, 0.36), "trim")
		return
	var tube_col := color.lerp(Color.WHITE, 0.35)
	var tube_mat: StandardMaterial3D = null
	if flick:
		# 깜빡이는 등은 형광관도 같이 꺼졌다 켜지도록 따로 그림
		tube_mat = LightFX.glow_mat(tube_col, 2.4 if not dim else 1.2, 0.6)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = tube_size
		mi.mesh = bm
		mi.material_override = tube_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = tube_pos
		lb.region.add_child(mi)
	else:
		part(tube_pos, tube_size, tube_col * (1.0 if not dim else 0.7), "lit")
	var l := OmniLight3D.new()
	l.light_color = color
	l.omni_range = 6.0 if not dim else 4.2
	l.omni_attenuation = 1.3
	l.light_energy = energy * (2.0 if not dim else 0.7)
	l.position = p + Vector3.DOWN * 0.3
	lb.region.add_child(l)
	# 최적화: 멀리 있는 실내등은 꺼 둠 (부드럽게 사라짐), 가까운 몇 개만 그림자
	LightFX.practical(l, 28.0, not dim and not flick)
	if flick:
		LightFX.flicker(l, "dying" if dim else "fluorescent", [tube_mat], true)


# ================================================================ 방 나누기 (BSP)

## r 을 방들로 나눔. 반환: {"rooms": [Rect2...], "walls": [[a, b, door_u]...]} (door_u = 문 중심까지 거리)
func split_rooms(r: Rect2, min_room := 3.6, max_room := 7.5, keep_out: Array = []) -> Dictionary:
	var rooms := []
	var walls := []
	_split(r, min_room, max_room, rooms, walls, 0, [], keep_out)
	return {"rooms": rooms, "walls": walls}


## doors = 이미 뚫린 문 위치(Vector2). 새 벽이 문을 가로막지 않게 피해서 자름
## keep_out = 벽을 세우면 안 되는 곳(계단 주변). 벽이 겹치면 그 부분은 비워 둠
func _split(r: Rect2, mn: float, mx: float, rooms: Array, walls: Array, depth: int, doors: Array, keep_out: Array) -> void:
	var big := maxf(r.size.x, r.size.y)
	if big <= mx or depth > 5 or (big < mn * 2.0 + 0.2):
		rooms.append(r)
		return
	var along_x := r.size.x >= r.size.y  # 긴 쪽을 자름
	var cut := -1.0
	for attempt in 10:
		var k := rng.randf_range(0.36, 0.64)
		var v := (r.position.x + r.size.x * k) if along_x else (r.position.y + r.size.y * k)
		v = clampf(v, (r.position.x if along_x else r.position.y) + mn, (r.end.x if along_x else r.end.y) - mn)
		var ok := true
		for d in doors:
			var dv: Vector2 = d
			if absf((dv.x if along_x else dv.y) - v) < DOOR_W * 0.5 + 0.6:
				ok = false
				break
		if ok:
			cut = v
			break
	if cut < 0.0:
		rooms.append(r)
		return
	var span := r.size.y if along_x else r.size.x
	var door := rng.randf_range(0.9, span - 0.9)
	var a := Vector3(cut, 0, r.position.y) if along_x else Vector3(r.position.x, 0, cut)
	var b := Vector3(cut, 0, r.end.y) if along_x else Vector3(r.end.x, 0, cut)
	walls.append([a, b, door])
	var door_pt := Vector2(cut, r.position.y + door) if along_x else Vector2(r.position.x + door, cut)
	var nd := doors.duplicate()
	nd.append(door_pt)
	if along_x:
		_split(Rect2(r.position, Vector2(cut - r.position.x, r.size.y)), mn, mx, rooms, walls, depth + 1, nd, keep_out)
		_split(Rect2(Vector2(cut, r.position.y), Vector2(r.end.x - cut, r.size.y)), mn, mx, rooms, walls, depth + 1, nd, keep_out)
	else:
		_split(Rect2(r.position, Vector2(r.size.x, cut - r.position.y)), mn, mx, rooms, walls, depth + 1, nd, keep_out)
		_split(Rect2(Vector2(r.position.x, cut), Vector2(r.size.x, r.end.y - cut)), mn, mx, rooms, walls, depth + 1, nd, keep_out)


## 계단 주변 비워 둘 영역: 계단 + 아래쪽 진입 공간 + 위쪽 도착 공간
func stair_zone(strip: Rect2, along_x: bool) -> Rect2:
	if along_x:
		return strip.grow_individual(1.4, 0.3, 1.4, 0.6)
	return strip.grow_individual(0.6, 1.4, 0.3, 1.4)


## 칸막이 벽 (문 구멍 하나). cut = 이 영역(계단 등)과 겹치는 부분은 벽을 안 세움
func partition(w: Array, y: float, h: float, mat: Material, key: String, cut: Array = [], door_prop_chance := 0.35) -> void:
	var a: Vector3 = w[0]
	var b: Vector3 = w[1]
	var L := Vector2(b.x - a.x, b.z - a.z).length()
	var du: float = w[2]
	var ops := [[du - DOOR_W * 0.5, du + DOOR_W * 0.5, 0.0, DOOR_H]]
	# 복도 쪽 높은 창 (학교 교실처럼): 문 주변은 피해서
	if corridor_windows and w.size() > 3 and w[3]:
		var dirw := (b - a).normalized()
		var basis_w := Basis(dirw, Vector3.UP, dirw.cross(Vector3.UP).normalized())
		var u := 1.0
		while u + 1.2 < L - 0.6:
			if absf(u + 0.6 - du) > DOOR_W * 0.5 + 0.9:
				ops.append([u, u + 1.2, 1.5, 2.35])
				var gc := a + dirw * (u + 0.6)
				gc.y = y + 1.925
				block(gc, Vector3(1.2, 0.85, 0.03), lb._deco_mat("glass"), "b_glass", true, basis_w, false, Color(0.12, 0.15, 0.2))
				var yaw := atan2(-dirw.z, dirw.x)
				part(gc + Vector3.UP * -0.44, Vector3(1.26, 0.05, 0.24), Color(0.36, 0.27, 0.18), "trim", false, yaw)
				part(gc + Vector3.UP * 0.44, Vector3(1.26, 0.05, 0.24), Color(0.36, 0.27, 0.18), "trim", false, yaw)
				part(gc, Vector3(0.04, 0.85, 0.24), Color(0.36, 0.27, 0.18), "trim", false, yaw)
			u += 1.6
	for c in cut:
		var cr: Rect2 = (c as Rect2).grow(0.15)
		# 벽 선분이 영역과 겹치는 구간을 구멍으로
		var dir := Vector2(b.x - a.x, b.z - a.z) / L
		var u0 := INF
		var u1 := -INF
		for i in 41:
			var u := L * i / 40.0
			var p := Vector2(a.x, a.z) + dir * u
			if cr.has_point(p):
				u0 = minf(u0, u)
				u1 = maxf(u1, u)
		if u1 > u0:
			ops.append([u0 - 0.3, u1 + 0.3, 0.0, h + 1.0])
	wall(a + Vector3.UP * 0, b, y, h, mat, key, ops, 0.18)
	# 문틀 + 가끔 진짜 문 (열고 닫기, 술래가 부숨)
	var dir3 := Vector3(b.x - a.x, 0, b.z - a.z) / L
	var center := a + dir3 * du
	center.y = y
	_door_frame(center, dir3, Color(0.3, 0.22, 0.15))
	if rng.randf() < door_prop_chance:
		lb.props.append(["door", center, atan2(dir3.z, -dir3.x) + PI, DOOR_W - 0.1, door_style])


func _door_frame(center: Vector3, dir: Vector3, col: Color) -> void:
	var n := dir.cross(Vector3.UP).normalized()
	var yaw := atan2(-dir.z, dir.x)
	for s in [-1.0, 1.0]:
		part(center + dir * (DOOR_W * 0.5 + 0.04) * s + Vector3.UP * DOOR_H * 0.5, Vector3(0.08, DOOR_H, 0.3), col, "trim", false, yaw)
	part(center + Vector3.UP * (DOOR_H + 0.05), Vector3(DOOR_W + 0.16, 0.1, 0.3), col, "trim", false, yaw)


# ================================================================ 가구

## 방 종류에 맞는 가구 놓기. 방 가운데는 비워서(봉인석 자리) 반환
## (테스트) 가구 기록용
static var debug_record := false
var _furn := 0
var _furn_kind := ""

func furnish(room: Rect2, y: float, kind: String, keep_center := false) -> Vector3:
	_furn += 1
	_furn_kind = kind
	var out := _furnish_inner(room, y, kind, keep_center)
	_furn -= 1
	return out


func _furnish_inner(room: Rect2, y: float, kind: String, keep_center := false) -> Vector3:
	var c := room.get_center()
	var inner := room.grow(-0.35)
	_keep = Rect2(c - Vector2(1.6, 1.6), Vector2(3.2, 3.2)) if keep_center else Rect2()
	if kind in RICH_KINDS:
		_furnish_rich(room, y, kind)
		return Vector3(c.x, y, c.y)
	match kind:
		"apartment":
			_bed(_against(inner, rng.randi() % 4, 2.0, 1.4), y)
			if rng.randf() < 0.7:
				_sofa(_against(inner, rng.randi() % 4, 1.9, 0.8), y)
			var tp := Vector3(c.x + rng.randf_range(-0.6, 0.6), y, c.y + rng.randf_range(-0.6, 0.6))
			if keep_center:
				tp = Vector3(inner.position.x + 1.0, y, inner.position.y + 1.0)
			_table(tp, Vector2(1.1, 0.7))
			if rng.randf() < 0.5:
				_tv(_against(inner, rng.randi() % 4, 1.2, 0.45), y)
			_maybe_locker(inner, y, 0.4, "wardrobe")
		"office":
			for i in rng.randi_range(2, 4):
				var p := Vector3(rng.randf_range(inner.position.x + 0.9, inner.end.x - 0.9), y, rng.randf_range(inner.position.y + 0.8, inner.end.y - 0.8))
				if _keep.has_point(Vector2(p.x, p.z)):
					continue
				_desk(p, rng.randf() * PI)
			_cabinet(_against(inner, rng.randi() % 4, 0.9, 0.5), y)
			_maybe_locker(inner, y, 0.45)
		"shop":
			var n := int(inner.size.x / 2.2)
			for i in n:
				var x := inner.position.x + (i + 0.5) * inner.size.x / n
				_shelf(Vector3(x, y, c.y), inner.size.y > inner.size.x)
			_counter(_against(inner, rng.randi() % 4, 2.2, 0.7), y)
		"storage":
			for i in rng.randi_range(3, 6):
				var p := Vector3(rng.randf_range(inner.position.x + 0.5, inner.end.x - 0.5), y, rng.randf_range(inner.position.y + 0.5, inner.end.y - 0.5))
				_crate(p, rng.randf_range(0.5, 0.9))
			_maybe_locker(inner, y, 0.6)
		"classroom":
			_classroom(room, y)
		"ward":
			_ward(room, y)
		"teachers":
			for i in rng.randi_range(4, 7):
				var p := Vector3(rng.randf_range(inner.position.x + 0.9, inner.end.x - 0.9), y, rng.randf_range(inner.position.y + 0.8, inner.end.y - 0.8))
				if not _keep.has_point(Vector2(p.x, p.z)):
					_desk(p, (rng.randi() % 4) * PI / 2.0)
			_cabinet(_against(inner, 0, 0.9, 0.5), y)
			_cabinet(_against(inner, 1, 0.9, 0.5), y)
			_maybe_locker(inner, y, 0.8)
		"nurse":
			_bed(_against(inner, 0, 2.0, 1.0), y)
			_bed(_against(inner, 1, 2.0, 1.0), y)
			_cabinet(_against(inner, 2, 0.9, 0.5), y)
			part(Vector3(c.x, y + 0.45, c.y + 1.0), Vector3(0.6, 0.9, 0.5), Color(0.95, 0.95, 0.95), "trim", true)  # 약장
			part(Vector3(c.x, y + 0.75, c.y + 1.26), Vector3(0.25, 0.08, 0.02), Color(0.9, 0.15, 0.15))
		"toilet":
			_toilets(room, y)
		"library":
			var rows := int(inner.size.y / 2.0) if inner.size.x > inner.size.y else int(inner.size.x / 2.0)
			for i in rows:
				var p := Vector3(inner.position.x + inner.size.x * 0.5, y, inner.position.y + (i + 0.5) * inner.size.y / rows) if inner.size.x > inner.size.y else Vector3(inner.position.x + (i + 0.5) * inner.size.x / rows, y, inner.position.y + inner.size.y * 0.5)
				if _keep.has_point(Vector2(p.x, p.z)):
					continue
				_bookshelf(p, inner.size.x <= inner.size.y)
			_table(Vector3(inner.position.x + 1.4, y, inner.position.y + 1.4), Vector2(1.6, 0.9))
		"music":
			_piano(Vector3(inner.position.x + 1.2, y, inner.position.y + 1.0))
			for i in 8:
				var p := Vector3(rng.randf_range(inner.position.x + 1, inner.end.x - 1), y, rng.randf_range(inner.position.y + 2, inner.end.y - 0.8))
				if not _keep.has_point(Vector2(p.x, p.z)):
					_yawbox(p + Vector3.UP * 0.44, Vector3(0.4, 0.04, 0.4), rng.randf() * TAU, Color(0.55, 0.45, 0.32), false)
			part(Vector3(inner.end.x - 0.6, y + 0.3, inner.end.y - 0.6), Vector3(0.7, 0.6, 0.7), Color(0.6, 0.15, 0.12), "trim", true)  # 북
		"lab":
			for i in 2:
				for j in 2:
					var p := Vector3(inner.position.x + inner.size.x * (0.27 + j * 0.46), y, inner.position.y + inner.size.y * (0.3 + i * 0.4))
					if _keep.has_point(Vector2(p.x, p.z)):
						continue
					part(p + Vector3.UP * 0.45, Vector3(2.2, 0.9, 1.1), Color(0.2, 0.22, 0.25), "trim", true)
					part(p + Vector3.UP * 0.93, Vector3(2.25, 0.06, 1.15), Color(0.12, 0.12, 0.14), "metal")
					part(p + Vector3(0.6, 1.1, 0), Vector3(0.12, 0.3, 0.12), Color(0.5, 0.9, 0.6), "glass")
					part(p + Vector3(-0.5, 1.05, 0.2), Vector3(0.1, 0.2, 0.1), Color(0.9, 0.5, 0.6), "glass")
			_skeleton(Vector3(inner.end.x - 0.6, y, inner.position.y + 0.6))
		"computer":
			var n := int(inner.size.x / 1.4)
			for i in n:
				for j in 2:
					var p := Vector3(inner.position.x + (i + 0.5) * inner.size.x / n, y, inner.position.y + inner.size.y * (0.3 + j * 0.4))
					if not _keep.has_point(Vector2(p.x, p.z)):
						_desk(p, 0.0)
		"lobby":
			_counter(_against(inner, 2, 3.0, 0.8), y)
			for i in 3:
				for j in 4:
					var p := Vector3(inner.position.x + inner.size.x * (0.25 + j * 0.17), y, inner.position.y + inner.size.y * (0.45 + i * 0.16))
					if _keep.has_point(Vector2(p.x, p.z)):
						continue
					_yawbox(p + Vector3.UP * 0.42, Vector3(0.5, 0.06, 0.5), 0.0, Color(0.3, 0.45, 0.6), true, "metal")
					_yawbox(p + Vector3(0, 0.7, 0.23), Vector3(0.5, 0.5, 0.05), 0.0, Color(0.3, 0.45, 0.6), false, "metal")
			_vending(_against(inner, 0, 1.0, 0.8), y)
			_plant(Vector3(inner.end.x - 0.5, y, inner.end.y - 0.5))
		"pharmacy":
			_counter(_against(inner, 2, 3.0, 0.8), y)
			for i in 3:
				_shelf(Vector3(inner.position.x + (i + 0.5) * inner.size.x / 3.0, y, inner.end.y - 0.5), false)
		"operating":
			var p := Vector3(c.x, y, c.y + 0.3)
			part(p + Vector3.UP * 0.5, Vector3(0.7, 1.0, 0.3), Color(0.6, 0.62, 0.65), "metal", true)
			part(p + Vector3.UP * 0.95, Vector3(0.8, 0.12, 2.0), Color(0.5, 0.7, 0.68))
			part(Vector3(p.x, y + 2.7, p.z), Vector3(0.9, 0.12, 0.9), Color(0.9, 0.9, 0.95), "lit")
			part(Vector3(p.x + 1.2, y + 0.45, p.z), Vector3(0.6, 0.9, 0.4), Color(0.65, 0.65, 0.68), "metal", true)  # 수술 도구 카트
			for k in 4:
				part(Vector3(p.x + 1.05 + k * 0.1, y + 0.92, p.z), Vector3(0.02, 0.02, 0.18), Color(0.85, 0.85, 0.9), "metal")
			part(Vector3(p.x - 1.3, y + 0.8, p.z - 0.6), Vector3(0.5, 1.6, 0.4), Color(0.3, 0.32, 0.35), "metal", true)  # 모니터 기계
			part(Vector3(p.x - 1.3, y + 1.3, p.z - 0.39), Vector3(0.4, 0.3, 0.02), Color(0.2, 0.9, 0.4), "lit")
		"nurse_station":
			_counter(_against(inner, 2, 3.5, 0.8), y)
			_cabinet(_against(inner, 3, 0.9, 0.5), y)
			_desk(Vector3(c.x - 1.0, y, c.y + 0.6), 0.0)
		"morgue":
			# 냉장 보관함 벽 (서랍 3단 x 여러 칸) + 해부대
			var n := int(inner.size.x / 0.9)
			for i in n:
				for k in 3:
					var p := Vector3(inner.position.x + (i + 0.5) * inner.size.x / n, y + 0.4 + k * 0.7, inner.position.y + 0.4)
					part(p, Vector3(0.82, 0.62, 0.8), Color(0.62, 0.64, 0.66), "metal", k == 0)
					part(p + Vector3(0, 0.15, 0.41), Vector3(0.25, 0.05, 0.03), Color(0.3, 0.3, 0.3), "metal")
			for k in 2:
				var tp := Vector3(c.x - 1.4 + k * 2.8, y, c.y + 1.0)
				if _keep.has_point(Vector2(tp.x, tp.z)):
					continue
				part(tp + Vector3.UP * 0.45, Vector3(0.3, 0.9, 0.3), Color(0.5, 0.52, 0.55), "metal", true)
				part(tp + Vector3.UP * 0.92, Vector3(0.8, 0.06, 2.0), Color(0.75, 0.77, 0.8), "metal")
				if rng.randf() < 0.6:
					part(tp + Vector3.UP * 1.05, Vector3(0.55, 0.2, 1.7), Color(0.9, 0.9, 0.92))  # 흰 천 덮인 무언가
		"boiler":
			for i in 2:
				var p := Vector3(inner.position.x + 1.4 + i * 2.6, y, inner.position.y + 1.4)
				if _keep.has_point(Vector2(p.x, p.z)):
					continue
				lb._pipe(p + Vector3.UP * 1.2, 0.9, 2.4, Color(0.45, 0.32, 0.22))
				solid(p + Vector3.UP * 1.2, Vector3(1.7, 2.4, 1.7))
			for k in 3:
				part(Vector3(c.x, y + 2.5 - k * 0.25, inner.end.y - 0.3), Vector3(inner.size.x - 0.4, 0.14, 0.14), Color(0.35, 0.35, 0.33), "metal")
			_crate(Vector3(inner.end.x - 0.8, y, inner.end.y - 1.2), 0.8)
		"parking":
			var n := int(inner.size.x / 3.0)
			for i in n:
				for side in [0, 1]:
					var p := Vector3(inner.position.x + (i + 0.5) * inner.size.x / n, y, inner.position.y + 2.6 if side == 0 else inner.end.y - 2.6)
					part(Vector3(p.x - 1.4, y + 0.01, p.z), Vector3(0.1, 0.01, 4.6), Color(0.85, 0.85, 0.8))
					if rng.randf() < 0.45 and not _keep.has_point(Vector2(p.x, p.z)):
						_car_inside(p)
			for i in int(inner.size.x / 6.0):
				var px := inner.position.x + (i + 0.5) * inner.size.x / int(inner.size.x / 6.0)
				part(Vector3(px, y + 1.6, c.y), Vector3(0.5, 3.2, 0.5), Color(0.45, 0.45, 0.43), "trim", true)  # 기둥
				for k in 4:
					part(Vector3(px, y + 0.15 + k * 0.2, c.y), Vector3(0.52, 0.1, 0.52), Color(0.85, 0.7, 0.1) if k % 2 == 0 else Color(0.08, 0.08, 0.08), "trim")
				var pl := Label3D.new()
				pl.text = "B1-%s" % char(65 + i)
				pl.font_size = 64
				pl.pixel_size = 0.005
				pl.modulate = Color(0.95, 0.85, 0.3)
				pl.position = Vector3(px, y + 2.0, c.y + 0.27)
				pl.visibility_range_end = 20.0
				lb.region.add_child(pl)
			# 바닥 화살표·주차면 번호, 기름 얼룩
			for k in int(inner.size.x / 4.0):
				decal(Vector3(rng.randf_range(inner.position.x + 1, inner.end.x - 1), y + 0.01, rng.randf_range(inner.position.y + 1, inner.end.y - 1)), Vector3.UP, rng.randf_range(1.2, 2.4), "stain")
		"gym_storage":
			for i in 4:
				_crate(Vector3(rng.randf_range(inner.position.x + 0.5, inner.end.x - 0.5), y, rng.randf_range(inner.position.y + 0.5, inner.end.y - 0.5)), 0.6)
			part(Vector3(c.x, y + 0.15, c.y), Vector3(2.0, 0.3, 1.0), Color(0.2, 0.35, 0.65), "trim", true)  # 매트
			_maybe_locker(inner, y, 1.0)
		"empty":
			pass
	return Vector3(c.x, y, c.y)


var _keep := Rect2()

## 벽에 붙는 가구 자리: side 0..3 (x-, x+, z-, z+), 가구 크기(길이, 깊이) → [중심, 회전]
## 벽에 붙이는 가구 자리. 문 앞이면 다른 자리·다른 벽을 다시 고름 (최대 10번)
func _against(r: Rect2, side: int, length: float, depth: float) -> Array:
	var first: Array = []
	for tries in 10:
		var sd := side if tries < 3 else rng.randi() % 4
		var spot := _against_once(r, sd, length, depth)
		if first.is_empty():
			first = spot
		var p: Vector3 = spot[0]
		var sz := Vector3(depth, 1.0, length) if sd < 2 else Vector3(length, 1.0, depth)
		if not _in_doorway(p, sz, 0.0, true):
			return spot
	return first


func _against_once(r: Rect2, side: int, length: float, depth: float) -> Array:
	var c := r.get_center()
	match side:
		0: return [Vector3(r.position.x + depth * 0.5, 0, rng.randf_range(r.position.y + length * 0.5, maxf(r.position.y + length * 0.5, r.end.y - length * 0.5))), PI / 2.0]
		1: return [Vector3(r.end.x - depth * 0.5, 0, rng.randf_range(r.position.y + length * 0.5, maxf(r.position.y + length * 0.5, r.end.y - length * 0.5))), -PI / 2.0]
		2: return [Vector3(rng.randf_range(r.position.x + length * 0.5, maxf(r.position.x + length * 0.5, r.end.x - length * 0.5)), 0, r.position.y + depth * 0.5), 0.0]
		_: return [Vector3(rng.randf_range(r.position.x + length * 0.5, maxf(r.position.x + length * 0.5, r.end.x - length * 0.5)), 0, r.end.y - depth * 0.5), PI]


func _yawbox(center: Vector3, size: Vector3, yaw: float, col: Color, collide := true, key := "trim") -> void:
	part(center, size, col, key, collide, yaw)


func _local(base: Vector3, yaw: float, off: Vector3) -> Vector3:
	return base + Basis(Vector3.UP, yaw) * off


# ================================================================ 자세한 방 꾸미기 (학교·병원·도시 공통)

const RICH_KINDS := ["laundry", "broadcast", "art", "teachers", "nurse", "toilet", "library", "music", "lab", "computer", "office", "nurse_station", "pharmacy", "operating", "morgue", "boiler", "storage"]


## 벽을 따라 u(0~1) 위치, 벽에서 depth/2 떨어진 곳. 반환 [위치, yaw(앞=방 안쪽)]
func _wall_item(r: Rect2, side: int, u: float, depth: float) -> Array:
	match side:
		0: return [Vector3(r.position.x + depth * 0.5, 0, lerpf(r.position.y, r.end.y, u)), PI / 2.0]
		1: return [Vector3(r.end.x - depth * 0.5, 0, lerpf(r.position.y, r.end.y, u)), -PI / 2.0]
		2: return [Vector3(lerpf(r.position.x, r.end.x, u), 0, r.position.y + depth * 0.5), 0.0]
		_: return [Vector3(lerpf(r.position.x, r.end.x, u), 0, r.end.y - depth * 0.5), PI]


## 문이 있는 벽 (모르면 -1)
func _door_side(room: Rect2) -> int:
	var ws := _window_side(room)
	if ws < 0:
		return -1
	return [1, 0, 3, 2][ws]


## 벽을 따라 같은 가구를 여러 개 (문 앞은 건너뜀)
func _along_wall(r: Rect2, side: int, depth: float, step: float, y: float, fn: Callable) -> void:
	var L := r.size.y if side < 2 else r.size.x
	var n := maxi(1, int((L - 0.4) / step))
	for i in n:
		var u := (0.2 + (i + 0.5) * (L - 0.4) / n) / L
		var it := _wall_item(r, side, u, depth)
		var p: Vector3 = it[0]
		p.y = y
		if blocks_door(p, Vector3(step, 1, depth + 0.6)) or _keep.has_point(Vector2(p.x, p.z)):
			continue
		_obj_begin()
		fn.call(p, float(it[1]))
		_obj_end()


func _furnish_rich(room: Rect2, y: float, kind: String) -> void:
	var c := room.get_center()
	var inner := room.grow(-0.3)
	var ds := _door_side(room)
	var ws := _window_side(room)
	# 문·창가가 아닌 옆벽 두 개
	var sides: Array = [0, 1, 2, 3].filter(func(s): return s != ds and s != ws)
	var big := inner.grow(-1.3)
	match kind:
		"laundry":
			# 세탁기 줄 (둥근 문) + 빨래 바구니 + 걸린 흰 시트
			for sd in sides:
				_along_wall(inner, sd, 0.7, 0.85, y, func(p, yw):
					_yawbox(_local(p, yw, Vector3(0, 0.5, 0)), Vector3(0.75, 1.0, 0.7), yw, Color(0.88, 0.88, 0.86), true)
					_yawbox(_local(p, yw, Vector3(0, 0.55, 0.36)), Vector3(0.42, 0.42, 0.02), yw, Color(0.1, 0.12, 0.14), false, "glass")
					var on := rng.randf() < 0.3
					_yawbox(_local(p, yw, Vector3(-0.22, 0.92, 0.36)), Vector3(0.2, 0.06, 0.02), yw, Color(0.3, 0.9, 0.4) if on else Color(0.2, 0.2, 0.2), false, "lit" if on else "metal"))
			for k in 3:
				var bp := Vector3(rng.randf_range(big.position.x, big.end.x), y, rng.randf_range(big.position.y, big.end.y))
				if not _keep.has_point(Vector2(bp.x, bp.z)) and not blocks_door(bp, Vector3(0.7, 1, 0.7)):
					part(bp + Vector3.UP * 0.3, Vector3(0.6, 0.6, 0.45), Color(0.35, 0.5, 0.65), "trim", true)
					part(bp + Vector3.UP * 0.62, Vector3(0.5, 0.1, 0.4), Color(0.92, 0.92, 0.9), "trim")
			# 천장에 매단 빨랫줄 (양 끝 고리) + 줄에 걸쳐 접힌 시트·수건 + 집게
			for k in 4:
				var lp := Vector3(c.x - 2.0 + k * 1.3, y + room_h - 1.2, c.y)
				var wy := lp.y + 0.75
				part(Vector3(lp.x, wy, lp.z), Vector3(0.03, 0.03, 3.2), Color(0.75, 0.75, 0.72), "metal")
				for e in [-1.6, 1.6]:
					part(Vector3(lp.x, (wy + y + room_h) * 0.5, lp.z + e), Vector3(0.025, y + room_h - wy, 0.025), Color(0.5, 0.5, 0.52), "metal")
				var z := lp.z - 1.3
				while z < lp.z + 1.2:
					var w := rng.randf_range(0.5, 1.0)
					var hgt := rng.randf_range(0.6, 1.4)
					var col: Color = [Color(0.92, 0.92, 0.9), Color(0.75, 0.85, 0.92), Color(0.78, 0.9, 0.84), Color(0.93, 0.88, 0.8)][rng.randi() % 4].darkened(rng.randf() * 0.12)
					var sw := rng.randf_range(-0.06, 0.06)
					# 앞뒤 두 장 (줄에 걸쳐 반으로 접힌 모양)
					part(Vector3(lp.x + 0.035, wy - hgt * 0.5, z + w * 0.5), Vector3(0.015, hgt, w), col, "trim", false, sw)
					part(Vector3(lp.x - 0.035, wy - hgt * 0.42, z + w * 0.5), Vector3(0.015, hgt * 0.84, w), col.darkened(0.08), "trim", false, -sw)
					part(Vector3(lp.x, wy + 0.01, z + w * 0.5), Vector3(0.09, 0.03, w), col, "trim")
					for pz in [z + 0.08, z + w - 0.08]:
						part(Vector3(lp.x, wy + 0.03, pz), Vector3(0.04, 0.09, 0.025), [Color(0.9, 0.3, 0.3), Color(0.3, 0.6, 0.9), Color(0.95, 0.8, 0.2)][rng.randi() % 3], "trim")
					z += w + rng.randf_range(0.08, 0.3)
		"broadcast":
			# 방송 장비 책상 + 마이크 + 스피커 + 방음벽(벽 아래 계란판) + 모니터
			var dp := _wall_item(inner, sides[0] if not sides.is_empty() else 2, 0.5, 0.8)
			var dpp: Vector3 = dp[0]
			dpp.y = y
			if not blocks_door(dpp, Vector3(2.4, 1, 1)):
				_yawbox(_local(dpp, dp[1], Vector3(0, 0.45, 0)), Vector3(2.4, 0.9, 0.8), dp[1], Color(0.2, 0.2, 0.22), true, "metal")
				for k in 12:
					_yawbox(_local(dpp, dp[1], Vector3(-1.0 + k * 0.18, 0.92, 0.1)), Vector3(0.05, 0.03, 0.3), dp[1], Color(0.7, 0.7, 0.7), false, "metal")
				_yawbox(_local(dpp, dp[1], Vector3(0.6, 1.2, 0.1)), Vector3(0.03, 0.5, 0.03), dp[1], Color(0.15, 0.15, 0.15), false, "metal")
				_yawbox(_local(dpp, dp[1], Vector3(0.6, 1.47, 0.12)), Vector3(0.08, 0.12, 0.08), dp[1], Color(0.1, 0.1, 0.1), false, "metal")
				_yawbox(_local(dpp, dp[1], Vector3(-0.6, 1.15, -0.2)), Vector3(0.6, 0.4, 0.04), dp[1], Color(0.3, 0.5, 0.9) if rng.randf() < 0.4 else Color(0.05, 0.05, 0.06), false, "lit")
				_chair(_local(dpp, dp[1], Vector3(0, 0, 0.9)), dp[1] + PI, Color(0.15, 0.15, 0.18))
			for sd in sides:
				_along_wall(inner, sd, 0.08, 0.6, y, func(p, yw):
					_yawbox(_local(p, yw, Vector3(0, 2.0, 0)), Vector3(0.55, 0.55, 0.06), yw, Color(0.25, 0.25, 0.28), false))
			part(Vector3(inner.end.x - 0.5, y + 0.5, inner.end.y - 0.5), Vector3(0.5, 1.0, 0.45), Color(0.08, 0.08, 0.09), "trim", true)
		"art":
			# 이젤 + 그림판, 석고상, 물감 선반, 바닥에 튄 물감
			for i in 8:
				var a := TAU * i / 8.0
				var p := Vector3(c.x + cos(a) * minf(3.2, inner.size.x * 0.35), y, c.y + sin(a) * minf(3.2, inner.size.y * 0.35))
				if blocks_door(p, Vector3(0.8, 1, 0.8)) or _keep.has_point(Vector2(p.x, p.z)):
					continue
				var face := atan2(c.x - p.x, c.y - p.z) + PI
				if rng.randf() < 0.15:
					_yawbox(_local(p, face, Vector3(0, 0.1, 0)), Vector3(0.7, 0.05, 1.5), face + 0.5, Color(0.45, 0.32, 0.2), false)
					continue
				for s in [-1.0, 1.0]:
					_yawbox(_local(p, face, Vector3(0.28 * s, 0.8, 0.1)), Vector3(0.04, 1.6, 0.04), face, Color(0.45, 0.32, 0.2), false)
				_yawbox(_local(p, face, Vector3(0, 0.75, -0.25)), Vector3(0.04, 1.5, 0.04), face, Color(0.45, 0.32, 0.2), false)
				_yawbox(_local(p, face, Vector3(0, 1.25, 0.12)), Vector3(0.7, 0.55, 0.03), face, Color(0.92, 0.9, 0.85), false)
				for k in 3:
					_yawbox(_local(p, face, Vector3(rng.randf_range(-0.25, 0.25), 1.25 + rng.randf_range(-0.18, 0.18), 0.14)), Vector3(rng.randf_range(0.08, 0.25), rng.randf_range(0.05, 0.2), 0.005), face, Color.from_hsv(rng.randf(), 0.7, 0.8), false)
				_chair(_local(p, face, Vector3(0, 0, 0.75)), face + PI, Color(0.45, 0.32, 0.2), rng.randf() < 0.15)
			var bust := Vector3(c.x, y, c.y)
			if not _keep.has_point(Vector2(c.x, c.y)):
				part(bust + Vector3.UP * 0.45, Vector3(0.5, 0.9, 0.5), Color(0.85, 0.85, 0.82), "trim", true)
				part(bust + Vector3.UP * 1.05, Vector3(0.3, 0.3, 0.25), Color(0.95, 0.95, 0.92), "trim")
				part(bust + Vector3.UP * 1.32, Vector3(0.2, 0.26, 0.22), Color(0.95, 0.95, 0.92), "trim")
			for sd in sides:
				_along_wall(inner, sd, 0.45, 1.9, y, func(p, yw): if rng.randf() < 0.5: _rack(p, yw))
			for k in 8:
				part(Vector3(rng.randf_range(inner.position.x + 0.5, inner.end.x - 0.5), y + 0.005, rng.randf_range(inner.position.y + 0.5, inner.end.y - 0.5)), Vector3(rng.randf_range(0.2, 0.6), 0.005, rng.randf_range(0.2, 0.6)), Color.from_hsv(rng.randf(), 0.75, 0.7), "trim", false, rng.randf() * PI)
			_curtains(room, y, ws)
		"teachers", "office":
			# 책상 섬 (2줄로 마주 보는 책상 + 칸막이), 벽에는 서류함
			var cols := maxi(1, int(big.size.x / 1.5))
			var rows := maxi(1, int(big.size.y / 3.2))
			for i in cols:
				for j in rows:
					var p := Vector3(big.position.x + (i + 0.5) * big.size.x / cols, y, big.position.y + (j + 0.5) * big.size.y / rows)
					if _keep.has_point(Vector2(p.x, p.z)) or blocks_door(p, Vector3(1.5, 1, 3.0)) or (kind == "office" and rng.randf() < 0.3):
						continue
					_desk(p + Vector3(0, 0, -0.45), PI)
					_desk(p + Vector3(0, 0, 0.45), 0.0)
					part(p + Vector3.UP * 0.95, Vector3(1.35, 0.4, 0.03), Color(0.55, 0.6, 0.62), "trim")
					for k in rng.randi_range(0, 3):
						decal(p + Vector3(rng.randf_range(-0.5, 0.5), 0.775, rng.randf_range(-0.6, 0.6)), Vector3.UP, 0.35, "papers")
			for sd in sides:
				_along_wall(inner, sd, 0.5, 1.0, y, func(p, yw): if rng.randf() < 0.6: _cabinet([p, yw], y))
			_whiteboard(inner, y, sides[0] if not sides.is_empty() else 0)
			_maybe_locker(inner, y, 0.7)
			if rng.randf() < 0.6:
				_plant(Vector3(inner.end.x - 0.4, y, inner.end.y - 0.4))
		"nurse":
			# 커튼 친 침대 2~3개, 약장, 체중계, 시력표
			var bs: int = sides[0] if not sides.is_empty() else 0
			_along_wall(inner, bs, 2.1, 1.7, y, func(p, yw):
				_hospital_bed(p, yw)
				_yawbox(_local(p, yw, Vector3(0.85, 1.25, 0.0)), Vector3(0.03, 2.0, 2.0), yw, Color(0.82, 0.86, 0.84), false))
			var other: int = sides[1] if sides.size() > 1 else (bs + 1) % 4
			var med := _wall_item(inner, other, 0.4, 0.45)
			var mp: Vector3 = med[0]
			mp.y = y
			if not blocks_door(mp, Vector3(1, 1, 1)):
				_yawbox(_local(mp, med[1], Vector3(0, 0.9, 0)), Vector3(0.9, 1.8, 0.4), med[1], Color(0.92, 0.92, 0.9), true)
				_yawbox(_local(mp, med[1], Vector3(0, 1.2, 0.21)), Vector3(0.8, 0.9, 0.02), med[1], Color(0.6, 0.75, 0.8), false, "glass")
				_yawbox(_local(mp, med[1], Vector3(0, 1.85, 0.21)), Vector3(0.22, 0.22, 0.02), med[1], Color(0.85, 0.1, 0.1), false)
			var chart := _wall_item(inner, other, 0.75, 0.05)
			var cp: Vector3 = chart[0]
			_yawbox(_local(cp, chart[1], Vector3(0, y + 1.5, 0.0)) + Vector3.UP * 0.0, Vector3(0.45, 0.65, 0.01), chart[1], Color(0.95, 0.95, 0.92), false)
			part(Vector3(c.x + 0.8, y + 0.04, c.y + 0.8), Vector3(0.35, 0.08, 0.35), Color(0.8, 0.8, 0.82), "metal")
			part(Vector3(c.x + 0.8, y + 0.6, c.y + 0.95), Vector3(0.05, 1.1, 0.05), Color(0.7, 0.7, 0.72), "metal")
		"toilet":
			_toilets(room, y)
		"library":
			# 책장 줄 + 열람 책상 + 쓰러진 책 더미
			var along_z := inner.size.x > inner.size.y
			var rows := int((inner.size.x if along_z else inner.size.y) / 2.4)
			for i in rows:
				var p := Vector3(inner.position.x + (i + 0.5) * inner.size.x / rows, y, inner.position.y + inner.size.y * 0.35) if along_z else Vector3(inner.position.x + inner.size.x * 0.35, y, inner.position.y + (i + 0.5) * inner.size.y / rows)
				if _keep.has_point(Vector2(p.x, p.z)) or blocks_door(p, Vector3(3.2, 1, 3.2)):
					continue
				_bookshelf(p, along_z)
			for k in 2:
				var tp := Vector3(inner.position.x + inner.size.x * (0.3 + k * 0.4), y, inner.position.y + inner.size.y * 0.78) if along_z else Vector3(inner.position.x + inner.size.x * 0.78, y, inner.position.y + inner.size.y * (0.3 + k * 0.4))
				if _keep.has_point(Vector2(tp.x, tp.z)) or blocks_door(tp, Vector3(2.2, 1, 1.8)):
					continue
				_table(tp, Vector2(2.0, 1.0))
				for s in [-1.0, 1.0]:
					for j in 2:
						_chair(tp + Vector3(-0.5 + j * 1.0, 0, 0.75 * s), 0.0 if s > 0 else PI, Color(0.45, 0.32, 0.2), rng.randf() < 0.15)
			for k in 3:
				var bp := Vector3(rng.randf_range(inner.position.x + 1, inner.end.x - 1), y, rng.randf_range(inner.position.y + 1, inner.end.y - 1))
				for j in rng.randi_range(2, 5):
					part(bp + Vector3(rng.randf_range(-0.2, 0.2), 0.03 + j * 0.05, rng.randf_range(-0.2, 0.2)), Vector3(0.22, 0.04, 0.3), [Color(0.7, 0.2, 0.2), Color(0.2, 0.4, 0.7), Color(0.85, 0.75, 0.4)][rng.randi() % 3], "trim", false, rng.randf() * PI)
		"music":
			# 피아노, 반원으로 놓인 의자·보면대, 북, 벽에 악보
			var pc := _wall_item(inner, sides[0] if not sides.is_empty() else 0, 0.3, 0.7)
			var pp: Vector3 = pc[0]
			pp.y = y
			if not blocks_door(pp, Vector3(1.6, 1, 1)):
				_yawbox(_local(pp, pc[1], Vector3(0, 0.6, 0)), Vector3(1.5, 1.2, 0.6), pc[1], Color(0.06, 0.05, 0.06))
				_yawbox(_local(pp, pc[1], Vector3(0, 0.78, 0.36)), Vector3(1.4, 0.04, 0.15), pc[1], Color(0.95, 0.95, 0.92), false)
				_chair(_local(pp, pc[1], Vector3(0, 0, 0.9)), pc[1] + PI, Color(0.1, 0.1, 0.1))
			for i in 9:
				var a := PI * (0.15 + i * 0.7 / 8.0)
				var p := Vector3(c.x + cos(a) * 3.0, y, c.y + sin(a) * 2.6 - 1.0)
				if not inner.has_point(Vector2(p.x, p.z)) or blocks_door(p, Vector3(0.6, 1, 0.6)):
					continue
				var face := atan2(c.x - p.x, c.y - 1.0 - p.z) + PI
				_chair(p, face, Color(0.25, 0.3, 0.45), rng.randf() < 0.15)
				if rng.randf() < 0.6:
					var st := _local(p, face, Vector3(0, 0, -0.6))
					part(st + Vector3.UP * 0.55, Vector3(0.03, 1.1, 0.03), Color(0.2, 0.2, 0.2), "metal")
					part(st + Vector3.UP * 1.1, Vector3(0.45, 0.32, 0.02), Color(0.15, 0.15, 0.15), "metal", false, face)
			part(Vector3(inner.end.x - 0.6, y + 0.3, inner.end.y - 0.6), Vector3(0.7, 0.6, 0.7), Color(0.6, 0.15, 0.12), "trim", true)
		"lab":
			# 실험대(싱크·수도꼭지·비커), 벽에 약품장·원소 주기율표, 해골 모형
			var along_x := inner.size.x >= inner.size.y
			for i in 2:
				for j in 2:
					var p := Vector3(inner.position.x + inner.size.x * (0.3 + j * 0.42), y, inner.position.y + inner.size.y * (0.32 + i * 0.38))
					if _keep.has_point(Vector2(p.x, p.z)) or blocks_door(p, Vector3(2.6, 1, 1.6)):
						continue
					part(p + Vector3.UP * 0.45, Vector3(2.4, 0.9, 1.2), Color(0.85, 0.85, 0.82), "trim", true)
					part(p + Vector3.UP * 0.92, Vector3(2.5, 0.05, 1.3), Color(0.1, 0.1, 0.12), "metal")
					part(p + Vector3(0, 0.95, 0), Vector3(0.45, 0.02, 0.35), Color(0.6, 0.62, 0.65), "metal")
					part(p + Vector3(0, 1.15, -0.2), Vector3(0.03, 0.35, 0.03), Color(0.7, 0.7, 0.72), "metal")
					for k in 4:
						part(p + Vector3(-0.9 + k * 0.35 + rng.randf_range(-0.05, 0.05), 1.05, rng.randf_range(-0.3, 0.3)), Vector3(0.09, 0.18, 0.09), [Color(0.5, 0.9, 0.6), Color(0.9, 0.5, 0.6), Color(0.6, 0.7, 0.95), Color(0.95, 0.9, 0.5)][k], "glass")
					for s in [-1.0, 1.0]:
						_chair(p + Vector3(rng.randf_range(-0.6, 0.6), 0, 0.95 * s), 0.0 if s > 0 else PI, Color(0.3, 0.3, 0.32), rng.randf() < 0.15)
			for sd in sides:
				_along_wall(inner, sd, 0.45, 1.1, y, func(p, yw):
					if rng.randf() < 0.55:
						_yawbox(_local(p, yw, Vector3(0, 1.0, 0)), Vector3(1.0, 2.0, 0.45), yw, Color(0.5, 0.42, 0.32), true)
						_yawbox(_local(p, yw, Vector3(0, 1.35, 0.23)), Vector3(0.9, 1.1, 0.02), yw, Color(0.55, 0.65, 0.7), false, "glass"))
			_skeleton(Vector3(inner.end.x - 0.6, y, inner.position.y + 0.6) if ds != 1 else Vector3(inner.position.x + 0.6, y, inner.position.y + 0.6))
			_whiteboard(inner, y, sides[1] if sides.size() > 1 else 2)
		"computer":
			var n := maxi(2, int(inner.size.x / 1.4))
			for j in 3:
				for i in n:
					var p := Vector3(inner.position.x + (i + 0.5) * inner.size.x / n, y, inner.position.y + inner.size.y * (0.22 + j * 0.28))
					if _keep.has_point(Vector2(p.x, p.z)) or blocks_door(p, Vector3(1.4, 1, 1.6)):
						continue
					_desk(p, 0.0)
					if rng.randf() < 0.15:
						part(p + Vector3(0, 0.95, -0.15), Vector3(0.44, 0.3, 0.02), Color(0.3, 0.5, 0.9), "lit")
		"nurse_station":
			# ㄷ자 카운터 + 모니터 (몇 개는 켜져 있음) + 서류철 + 의자, 뒤에 약품 카트
			var cp := Vector3(c.x, y, c.y)
			for s in [-1.0, 1.0]:
				part(cp + Vector3(1.6 * s, 0.55, 0), Vector3(0.6, 1.1, 2.6), Color(0.78, 0.8, 0.8), "trim", true)
			part(cp + Vector3(0, 0.55, 1.3), Vector3(3.8, 1.1, 0.6), Color(0.78, 0.8, 0.8), "trim", true)
			part(cp + Vector3(0, 1.12, 1.3), Vector3(3.9, 0.05, 0.7), Color(0.4, 0.3, 0.22), "trim")
			for i in 4:
				var mp := cp + Vector3(-1.2 + i * 0.8, 1.35, 1.25)
				var on := rng.randf() < 0.35
				part(mp, Vector3(0.45, 0.32, 0.03), Color(0.3, 0.8, 0.5) if on else Color(0.05, 0.05, 0.06), "lit" if on else "glass")
				_chair(mp + Vector3(0, -1.35, -0.6), PI, Color(0.2, 0.25, 0.3), rng.randf() < 0.2)
			for k in 6:
				part(cp + Vector3(rng.randf_range(-1.6, 1.6), 1.17, 1.3 + rng.randf_range(-0.2, 0.2)), Vector3(0.25, 0.04, 0.32), Color(0.9, 0.85, 0.6).darkened(rng.randf() * 0.3), "trim", false, rng.randf() * PI)
			for sd in sides:
				_along_wall(inner, sd, 0.5, 1.0, y, func(p, yw): if rng.randf() < 0.6: _cabinet([p, yw], y))
		"pharmacy":
			# 약 진열장 (벽 따라) + 가운데 진열대 + 조제실 창구
			for sd in sides:
				_along_wall(inner, sd, 0.5, 1.9, y, func(p, yw): _med_shelf(p, yw))
			for k in 2:
				var p := Vector3(c.x + (k - 0.5) * 2.6, y, c.y)
				if not _keep.has_point(Vector2(p.x, p.z)) and not blocks_door(p, Vector3(2.0, 1, 1.0)):
					_med_shelf(p + Vector3(0, 0, -0.26), 0.0)
					_med_shelf(p + Vector3(0, 0, 0.26), PI)
			for k in 4:
				part(Vector3(rng.randf_range(inner.position.x + 1, inner.end.x - 1), y + 0.03, rng.randf_range(inner.position.y + 1, inner.end.y - 1)), Vector3(0.18, 0.06, 0.12), Color(0.95, 0.95, 0.95), "trim", false, rng.randf() * PI)
		"operating":
			var p := Vector3(c.x, y, c.y)
			part(p + Vector3.UP * 0.45, Vector3(0.6, 0.9, 0.5), Color(0.6, 0.62, 0.65), "metal", true)
			part(p + Vector3.UP * 0.95, Vector3(0.75, 0.1, 2.1), Color(0.35, 0.6, 0.6))
			if rng.randf() < 0.5:
				part(p + Vector3(0, 1.08, 0.1), Vector3(0.6, 0.18, 1.7), Color(0.92, 0.92, 0.94))
				decal(p + Vector3(0.1, 1.18, 0.2), Vector3.UP, 0.7, "blood")
			# 수술등 (켜져 있으면 실제 빛)
			part(p + Vector3.UP * (room_h - 0.45), Vector3(0.05, 0.8, 0.05), Color(0.6, 0.6, 0.62), "metal")
			part(p + Vector3.UP * (room_h - 0.9), Vector3(1.0, 0.18, 1.0), Color(0.85, 0.85, 0.88), "metal")
			part(p + Vector3.UP * (room_h - 1.0), Vector3(0.8, 0.03, 0.8), Color(1.0, 0.98, 0.9), "lit")
			if rng.randf() < 0.6 and _lights < MAX_LIGHTS:
				_lights += 1
				var sl := SpotLight3D.new()
				sl.light_energy = 3.0
				sl.spot_range = room_h
				sl.spot_angle = 35.0
				sl.light_color = Color(1.0, 0.97, 0.9)
				sl.position = p + Vector3.UP * (room_h - 1.05)
				sl.rotation.x = -PI / 2.0
				sl.distance_fade_enabled = true
				sl.distance_fade_begin = 28.0
				sl.distance_fade_length = 8.0
				lb.region.add_child(sl)
				LightFX.practical(sl, 28.0)
				sl.spot_angle_attenuation = 0.6
				sl.light_volumetric_fog_energy = 2.0
				if rng.randf() < 0.5:
					LightFX.flicker(sl, "fluorescent", [], true)
			# 기계·카트·산소통
			part(p + Vector3(-1.5, 0.8, -0.6), Vector3(0.6, 1.6, 0.5), Color(0.3, 0.32, 0.35), "metal", true)
			part(p + Vector3(-1.5, 1.35, -0.34), Vector3(0.45, 0.32, 0.02), Color(0.2, 0.9, 0.4), "lit")
			part(p + Vector3(1.4, 0.45, 0.3), Vector3(0.7, 0.9, 0.45), Color(0.7, 0.7, 0.72), "metal", true)
			for k in 5:
				part(p + Vector3(1.2 + k * 0.1, 0.92, 0.3), Vector3(0.02, 0.02, 0.2), Color(0.85, 0.85, 0.9), "metal")
			for k in 2:
				part(p + Vector3(-2.2 + k * 0.35, 0.65, 1.5), Vector3(0.22, 1.3, 0.22), Color(0.2, 0.55, 0.3), "metal", true)
			for k in 4:
				decal(p + Vector3(rng.randf_range(-2, 2), 0.01, rng.randf_range(-2, 2)), Vector3.UP, rng.randf_range(0.6, 1.4), "blood")
		"morgue":
			# 냉장 서랍 벽 (손잡이·번호) + 해부대 + 배수구 + 매달린 전등
			var wall_s: int = ws if ws >= 0 else 2
			var L := inner.size.x if wall_s >= 2 else inner.size.y
			var n := int(L / 0.95)
			for i in n:
				for k in 3:
					var it := _wall_item(inner, wall_s, (i + 0.5) / n, 0.8)
					var p: Vector3 = it[0]
					p.y = y + 0.4 + k * 0.72
					if blocks_door(p, Vector3(0.9, 1, 0.8)):
						continue
					_yawbox(p, Vector3(0.88, 0.66, 0.8), it[1], Color(0.62, 0.64, 0.66), k == 0, "metal")
					_yawbox(_local(p, it[1], Vector3(0, 0.18, 0.41)), Vector3(0.3, 0.05, 0.04), it[1], Color(0.3, 0.3, 0.3), false, "metal")
					if rng.randf() < 0.08:
						_yawbox(_local(p, it[1], Vector3(0, 0, 0.75)), Vector3(0.7, 0.12, 0.8), it[1], Color(0.62, 0.64, 0.66), false, "metal")  # 빠져나온 서랍
			for k in 2:
				var tp := Vector3(c.x - 1.6 + k * 3.2, y, c.y + 0.8)
				if _keep.has_point(Vector2(tp.x, tp.z)) or blocks_door(tp, Vector3(1, 1, 2.2)):
					continue
				part(tp + Vector3.UP * 0.45, Vector3(0.3, 0.9, 0.3), Color(0.5, 0.52, 0.55), "metal", true)
				part(tp + Vector3.UP * 0.92, Vector3(0.85, 0.06, 2.1), Color(0.75, 0.77, 0.8), "metal")
				if rng.randf() < 0.6:
					part(tp + Vector3.UP * 1.05, Vector3(0.55, 0.2, 1.75), Color(0.9, 0.9, 0.92))
				decal(tp + Vector3(0, 0.01, 0), Vector3.UP, 1.0, "stain")
				part(tp + Vector3.UP * (room_h - 0.9), Vector3(0.02, 1.0, 0.02), Color(0.2, 0.2, 0.2), "metal")
				part(tp + Vector3.UP * (room_h - 1.45), Vector3(0.5, 0.12, 0.5), Color(0.25, 0.3, 0.28), "metal")
		"boiler":
			# 큰 보일러 탱크 2개 + 계기판 + 배관 + 밸브 + 붉은 비상등
			for i in 2:
				var p := Vector3(inner.position.x + inner.size.x * (0.3 + i * 0.4), y, inner.position.y + inner.size.y * 0.35)
				if _keep.has_point(Vector2(p.x, p.z)) or blocks_door(p, Vector3(2.2, 1, 2.2)):
					continue
				lb._pipe(p + Vector3.UP * 1.3, 1.0, 2.6, Color(0.45, 0.32, 0.22))
				solid(p + Vector3.UP * 1.3, Vector3(1.9, 2.6, 1.9))
				part(p + Vector3(0, 2.75, 0), Vector3(0.25, 0.5, 0.25), Color(0.4, 0.4, 0.38), "metal")
				part(p + Vector3(0, 1.4, 1.02), Vector3(0.3, 0.3, 0.04), Color(0.9, 0.9, 0.85), "trim")
				part(p + Vector3(0.6, 0.9, 1.0), Vector3(0.25, 0.25, 0.08), Color(0.7, 0.1, 0.1), "metal")
			for k in 4:
				part(Vector3(c.x, y + room_h - 0.45 - k * 0.24, inner.end.y - 0.3 - k * 0.15), Vector3(inner.size.x - 0.4, 0.16, 0.16), [Color(0.35, 0.35, 0.33), Color(0.55, 0.3, 0.2), Color(0.3, 0.4, 0.45), Color(0.6, 0.55, 0.2)][k], "metal")
			_crate(Vector3(inner.end.x - 0.8, y, inner.end.y - 1.2), 0.8)
			if _lights < MAX_LIGHTS:
				_lights += 1
				var rl := OmniLight3D.new()
				rl.light_color = Color(1.0, 0.15, 0.1)
				rl.light_energy = 1.2
				rl.omni_range = 7.0
				rl.position = Vector3(c.x, y + room_h - 0.5, c.y)
				rl.distance_fade_enabled = true
				rl.distance_fade_begin = 28.0
				rl.distance_fade_length = 8.0
				lb.region.add_child(rl)
				LightFX.practical(rl, 28.0, false)
				LightFX.flicker(rl, "strobe")
				part(rl.position + Vector3.UP * 0.1, Vector3(0.2, 0.15, 0.2), Color(1.0, 0.2, 0.15), "lit")
		"storage":
			# 철제 선반 (상자·통) 벽 따라 + 가운데 상자 더미
			for sd in sides:
				_along_wall(inner, sd, 0.6, 1.9, y, func(p, yw): _rack(p, yw))
			for i in rng.randi_range(2, 5):
				var p := Vector3(rng.randf_range(big.position.x, big.end.x), y, rng.randf_range(big.position.y, big.end.y))
				if _keep.has_point(Vector2(p.x, p.z)) or blocks_door(p, Vector3(1, 1, 1)):
					continue
				var s := rng.randf_range(0.5, 0.85)
				_crate(p, s)
				if rng.randf() < 0.5:
					part(p + Vector3.UP * (s + 0.25), Vector3(0.5, 0.5, 0.5), Color(0.55, 0.42, 0.25), "trim", false, rng.randf() * PI)
			_maybe_locker(inner, y, 0.6)


## 화이트보드 (벽에)
func _whiteboard(r: Rect2, y: float, side: int) -> void:
	var it := _wall_item(r, side, 0.5, 0.06)
	var p: Vector3 = it[0]
	p.y = y + 1.55
	_yawbox(p, Vector3(2.4, 1.1, 0.04), it[1], Color(0.92, 0.93, 0.92), false)
	_yawbox(p + Vector3.DOWN * 0.6, Vector3(2.4, 0.05, 0.1), it[1], Color(0.6, 0.6, 0.62), false, "metal")
	if rng.randf() < 0.6:
		decal(_local(p, it[1], Vector3(rng.randf_range(-0.6, 0.6), 0, 0.03)), Basis(Vector3.UP, it[1]) * Vector3.BACK, 0.8, "crack")


## 약 진열장: 흰 선반 + 작은 약상자들
func _med_shelf(p: Vector3, yaw: float) -> void:
	_obj_begin()
	_med_shelf_impl(p, yaw)
	_obj_end()


func _med_shelf_impl(p: Vector3, yaw: float) -> void:
	_yawbox(_local(p, yaw, Vector3(0, 0.95, 0)), Vector3(1.8, 1.9, 0.45), yaw, Color(0.88, 0.88, 0.86), true)
	for k in 4:
		for i in 7:
			if rng.randf() < 0.3:
				continue
			var col: Color = [Color(0.95, 0.95, 0.95), Color(0.9, 0.85, 0.5), Color(0.6, 0.8, 0.9), Color(0.9, 0.6, 0.6)][rng.randi() % 4]
			_yawbox(_local(p, yaw, Vector3(-0.75 + i * 0.25, 0.3 + k * 0.45, 0.2)), Vector3(0.18, 0.2, 0.12), yaw, col, false)


## 철제 선반 (상자·통)
func _rack(p: Vector3, yaw: float) -> void:
	_obj_begin()
	_rack_impl(p, yaw)
	_obj_end()


func _rack_impl(p: Vector3, yaw: float) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_yawbox(_local(p, yaw, Vector3(0.85 * sx, 1.0, 0.25 * sz)), Vector3(0.05, 2.0, 0.05), yaw, Color(0.35, 0.37, 0.4), false, "metal")
	for k in 4:
		_yawbox(_local(p, yaw, Vector3(0, 0.15 + k * 0.6, 0)), Vector3(1.8, 0.04, 0.55), yaw, Color(0.4, 0.42, 0.45), k == 0, "metal")
		for i in 3:
			if rng.randf() < 0.4:
				continue
			_yawbox(_local(p, yaw, Vector3(-0.55 + i * 0.55, 0.38 + k * 0.6, 0)), Vector3(0.45, 0.42, 0.45), yaw + rng.randf_range(-0.1, 0.1), Color(0.55, 0.42, 0.25).darkened(rng.randf() * 0.3), false)
	solid(_local(p, yaw, Vector3(0, 1.0, 0)), Vector3(1.8, 2.0, 0.55), Basis(Vector3.UP, yaw))


func _toilets(room: Rect2, y: float) -> void:
	var inner := room.grow(-0.2)
	var ds := _door_side(room)
	# 칸은 문과 마주 보지 않는 긴 벽을 따라, 소변기·세면대는 반대쪽 벽
	var along_x := inner.size.x >= inner.size.y
	var stall_side := 2 if along_x else 0
	if ds == stall_side:
		stall_side = 3 if along_x else 1
	var L := inner.size.x if stall_side >= 2 else inner.size.y
	var n := int((L - 0.4) / 1.25)
	var depth := 1.5
	var stall_col := Color(0.55, 0.62, 0.68)
	var locker_i := n / 2
	for i in n:
		var it := _wall_item(inner, stall_side, (0.2 + (i + 0.5) * (L - 0.4) / n) / L, depth)
		var p: Vector3 = it[0]
		p.y = y
		var yaw: float = it[1]
		if blocks_door(p, Vector3(1.3, 1, depth + 0.6)):
			continue
		# 옆 칸막이 (오른쪽) + 앞판 + 문(일부는 열림·떨어짐)
		_yawbox(_local(p, yaw, Vector3(0.62, 1.05, 0)), Vector3(0.05, 1.9, depth), yaw, stall_col, true)
		if i == 0:
			_yawbox(_local(p, yaw, Vector3(-0.62, 1.05, 0)), Vector3(0.05, 1.9, depth), yaw, stall_col, true)
		var door_state := rng.randf()
		if door_state < 0.55:
			_yawbox(_local(p, yaw, Vector3(0, 1.1, depth * 0.5)), Vector3(1.15, 1.8, 0.04), yaw, stall_col.lightened(0.08), false)
		elif door_state < 0.9:
			_yawbox(_local(p, yaw, Vector3(0.3, 1.1, depth * 0.5 + 0.45)), Vector3(0.04, 1.8, 0.9), yaw + 0.4, stall_col.lightened(0.08), false)
		else:
			_yawbox(_local(p, yaw, Vector3(0.1, 0.05, depth * 0.5 + 0.7)), Vector3(1.0, 0.04, 1.6), yaw + 0.3, stall_col.darkened(0.2), false)
		_yawbox(_local(p, yaw, Vector3(0, 0.22, -0.35)), Vector3(0.4, 0.44, 0.55), yaw, Color(0.95, 0.95, 0.95), true)
		_yawbox(_local(p, yaw, Vector3(0, 0.6, -0.68)), Vector3(0.4, 0.4, 0.16), yaw, Color(0.92, 0.92, 0.92), false)
		if i == locker_i:
			lb.props.append(["locker", _local(p, yaw, Vector3(0, 0, -0.25)), yaw + PI])  # 청소도구함 (숨는 곳)
	# 반대쪽 벽: 세면대 + 거울, 소변기
	var other: int = [1, 0, 3, 2][stall_side]
	var OL := inner.size.x if other >= 2 else inner.size.y
	var m := int((OL - 0.6) / 0.9)
	for i in m:
		var it := _wall_item(inner, other, (0.3 + (i + 0.5) * (OL - 0.6) / m) / OL, 0.5)
		var p: Vector3 = it[0]
		p.y = y
		var yaw: float = it[1]
		if blocks_door(p, Vector3(0.9, 1, 1.2)):
			continue
		if i < m / 2:
			_yawbox(_local(p, yaw, Vector3(0, 0.82, 0)), Vector3(0.6, 0.15, 0.45), yaw, Color(0.92, 0.92, 0.92), true)
			_yawbox(_local(p, yaw, Vector3(0, 1.0, -0.15)), Vector3(0.04, 0.25, 0.12), yaw, Color(0.7, 0.7, 0.72), false, "metal")
			_yawbox(_local(p, yaw, Vector3(0, 1.55, -0.24)), Vector3(0.55, 0.75, 0.02), yaw, Color(0.55, 0.62, 0.66), false, "glass")
			if rng.randf() < 0.3:
				decal(_local(p, yaw, Vector3(0, 1.55, -0.22)), Basis(Vector3.UP, yaw) * Vector3.BACK, 0.5, "crack")
		else:
			# 소변기: 벽에 붙은 둥근 그릇 + 물 내림 파이프 + 칸막이
			_yawbox(_local(p, yaw, Vector3(0, 0.62, -0.12)), Vector3(0.36, 0.55, 0.24), yaw, Color(0.95, 0.95, 0.95), false)
			_yawbox(_local(p, yaw, Vector3(0, 0.42, 0.0)), Vector3(0.3, 0.12, 0.2), yaw, Color(0.92, 0.92, 0.92), false)
			_yawbox(_local(p, yaw, Vector3(0, 1.1, -0.2)), Vector3(0.03, 0.45, 0.03), yaw, Color(0.7, 0.7, 0.72), false, "metal")
			_yawbox(_local(p, yaw, Vector3(0.42, 0.95, 0.0)), Vector3(0.03, 0.9, 0.45), yaw, Color(0.55, 0.62, 0.68), false)

func _bookshelf(p: Vector3, along_z: bool) -> void:
	_obj_begin()
	_bookshelf_impl(p, along_z)
	_obj_end()


func _bookshelf_impl(p: Vector3, along_z: bool) -> void:
	var yaw := PI / 2.0 if along_z else 0.0
	var L := 3.0
	_yawbox(p + Vector3.UP * 0.95, Vector3(L, 1.9, 0.45), yaw, Color(0.4, 0.28, 0.18))
	for k in 4:
		for i in 10:
			if rng.randf() < 0.25:
				continue
			var off := Vector3(-L * 0.5 + 0.15 + i * (L - 0.3) / 10.0, 0.3 + k * 0.45, 0.0)
			var bc: Color = [Color(0.7, 0.2, 0.2), Color(0.2, 0.4, 0.7), Color(0.85, 0.75, 0.4), Color(0.3, 0.55, 0.3), Color(0.5, 0.3, 0.5)][rng.randi() % 5]
			for side in [-1.0, 1.0]:
				_yawbox(_local(p, yaw, off + Vector3(0, 0.15, 0.2 * side)), Vector3(0.12, 0.32, 0.08), yaw, bc, false)


func _piano(p: Vector3) -> void:
	_obj_begin()
	_piano_impl(p)
	_obj_end()


func _piano_impl(p: Vector3) -> void:
	part(p + Vector3.UP * 0.6, Vector3(1.5, 1.2, 0.6), Color(0.06, 0.05, 0.06), "trim", true)
	part(p + Vector3(0, 0.78, 0.36), Vector3(1.4, 0.04, 0.15), Color(0.95, 0.95, 0.92))
	for i in 10:
		part(p + Vector3(-0.63 + i * 0.14, 0.8, 0.33), Vector3(0.05, 0.03, 0.09), Color(0.05, 0.05, 0.05))


func _skeleton(p: Vector3) -> void:
	_obj_begin()
	_skeleton_impl(p)
	_obj_end()


func _skeleton_impl(p: Vector3) -> void:
	var bone := Color(0.92, 0.9, 0.82)
	part(p + Vector3.UP * 0.05, Vector3(0.4, 0.1, 0.4), Color(0.3, 0.3, 0.3), "metal", true)
	part(p + Vector3.UP * 0.85, Vector3(0.04, 1.6, 0.04), Color(0.4, 0.4, 0.4), "metal")
	part(p + Vector3.UP * 1.65, Vector3(0.2, 0.24, 0.2), bone)
	for k in 5:
		part(p + Vector3.UP * (1.2 + k * 0.06), Vector3(0.3, 0.025, 0.15), bone)
	part(p + Vector3.UP * 0.95, Vector3(0.3, 0.12, 0.12), bone)
	for s in [-1.0, 1.0]:
		part(p + Vector3(0.1 * s, 0.5, 0), Vector3(0.04, 0.8, 0.04), bone)
		part(p + Vector3(0.22 * s, 1.15, 0), Vector3(0.035, 0.6, 0.035), bone)


func _vending(spot: Array, y: float) -> void:
	_obj_begin()
	_vending_impl(spot, y)
	_obj_end()


func _vending_impl(spot: Array, y: float) -> void:
	var p: Vector3 = spot[0]
	p.y = y
	var yaw: float = spot[1]
	_yawbox(_local(p, yaw, Vector3(0, 0.95, 0)), Vector3(1.0, 1.9, 0.8), yaw, Color(0.75, 0.15, 0.15))
	_yawbox(_local(p, yaw, Vector3(-0.1, 1.15, 0.41)), Vector3(0.65, 1.2, 0.02), yaw, Color(0.7, 0.85, 1.0), false, "lit")


func _plant(p: Vector3) -> void:
	_obj_begin()
	_plant_impl(p)
	_obj_end()


func _plant_impl(p: Vector3) -> void:
	part(p + Vector3.UP * 0.25, Vector3(0.45, 0.5, 0.45), Color(0.55, 0.35, 0.25), "trim", true)
	for i in 5:
		part(p + Vector3(rng.randf_range(-0.2, 0.2), 0.7 + i * 0.12, rng.randf_range(-0.2, 0.2)), Vector3(0.35, 0.08, 0.35), Color(0.2, 0.45, 0.2).darkened(rng.randf() * 0.4), "trim", false, rng.randf() * PI)


func _car_inside(p: Vector3) -> void:
	if blocks_door(p, Vector3(1.9, 1.0, 4.2)):
		return
	var col: Color = [Color(0.35, 0.22, 0.15), Color(0.25, 0.35, 0.3), Color(0.5, 0.5, 0.52), Color(0.15, 0.17, 0.25)][rng.randi() % 4]
	part(p + Vector3.UP * 0.6, Vector3(1.9, 0.8, 4.2), col, "metal", true)
	part(p + Vector3(0, 1.25, -0.2), Vector3(1.7, 0.6, 2.2), Color(0.05, 0.07, 0.09), "glass")
	for wx in [-0.9, 0.9]:
		for wz in [-1.4, 1.4]:
			part(p + Vector3(wx, 0.3, wz), Vector3(0.25, 0.6, 0.6), Color(0.1, 0.1, 0.1))


func _bed(spot: Array, y: float) -> void:
	_obj_begin()
	_bed_impl(spot, y)
	_obj_end()


func _bed_impl(spot: Array, y: float) -> void:
	var p: Vector3 = spot[0]
	p.y = y
	var yaw: float = spot[1]
	var frame := Color(0.35, 0.24, 0.16)
	_yawbox(_local(p, yaw, Vector3(0, 0.22, 0)), Vector3(1.4, 0.44, 2.0), yaw, frame)
	var sheet: Color = [Color(0.85, 0.85, 0.9), Color(0.7, 0.75, 0.85), Color(0.8, 0.65, 0.65)][rng.randi() % 3]
	_yawbox(_local(p, yaw, Vector3(0, 0.5, 0.05)), Vector3(1.35, 0.14, 1.85), yaw, sheet, false)
	_yawbox(_local(p, yaw, Vector3(0, 0.62, -0.72)), Vector3(0.9, 0.14, 0.4), yaw, Color(0.95, 0.95, 0.95), false)
	_yawbox(_local(p, yaw, Vector3(0, 0.7, -1.0)), Vector3(1.4, 1.0, 0.08), yaw, frame, false)


func _sofa(spot: Array, y: float) -> void:
	_obj_begin()
	_sofa_impl(spot, y)
	_obj_end()


func _sofa_impl(spot: Array, y: float) -> void:
	var p: Vector3 = spot[0]
	p.y = y
	var yaw: float = spot[1]
	var col: Color = [Color(0.45, 0.25, 0.22), Color(0.25, 0.35, 0.45), Color(0.35, 0.4, 0.3)][rng.randi() % 3]
	_yawbox(_local(p, yaw, Vector3(0, 0.25, 0)), Vector3(1.9, 0.5, 0.8), yaw, col)
	_yawbox(_local(p, yaw, Vector3(0, 0.6, -0.32)), Vector3(1.9, 0.6, 0.18), yaw, col.darkened(0.15), false)
	for s in [-1.0, 1.0]:
		_yawbox(_local(p, yaw, Vector3(0.88 * s, 0.45, 0)), Vector3(0.16, 0.4, 0.8), yaw, col.darkened(0.1), false)


func _table(p: Vector3, size: Vector2) -> void:
	_obj_begin()
	_table_impl(p, size)
	_obj_end()


func _table_impl(p: Vector3, size: Vector2) -> void:
	var col := Color(0.42, 0.3, 0.2)
	part(p + Vector3.UP * 0.74, Vector3(size.x, 0.05, size.y), col, "trim", true)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			part(p + Vector3(sx * (size.x * 0.5 - 0.06), 0.36, sz * (size.y * 0.5 - 0.06)), Vector3(0.05, 0.72, 0.05), col.darkened(0.2))
	if rng.randf() < 0.5:
		part(p + Vector3(0.15, 0.8, 0), Vector3(0.08, 0.1, 0.08), Color(0.9, 0.9, 0.85))  # 컵


func _tv(spot: Array, y: float) -> void:
	_obj_begin()
	_tv_impl(spot, y)
	_obj_end()


func _tv_impl(spot: Array, y: float) -> void:
	var p: Vector3 = spot[0]
	p.y = y
	var yaw: float = spot[1]
	_yawbox(_local(p, yaw, Vector3(0, 0.25, 0)), Vector3(1.2, 0.5, 0.4), yaw, Color(0.3, 0.22, 0.15))
	var on := rng.randf() < 0.3
	_yawbox(_local(p, yaw, Vector3(0, 0.85, 0)), Vector3(0.9, 0.55, 0.06), yaw, Color(0.4, 0.55, 0.7) if on else Color(0.03, 0.03, 0.04), false, "lit" if on else "glass")


func _desk(p: Vector3, yaw: float) -> void:
	_obj_begin()
	_desk_impl(p, yaw)
	_obj_end()


func _desk_impl(p: Vector3, yaw: float) -> void:
	var col := Color(0.5, 0.42, 0.32)
	_yawbox(_local(p, yaw, Vector3(0, 0.74, 0)), Vector3(1.3, 0.05, 0.7), yaw, col)
	_yawbox(_local(p, yaw, Vector3(0.5, 0.36, 0)), Vector3(0.3, 0.72, 0.65), yaw, col.darkened(0.15), false)
	_yawbox(_local(p, yaw, Vector3(-0.6, 0.36, 0)), Vector3(0.05, 0.72, 0.65), yaw, col.darkened(0.15), false)
	_yawbox(_local(p, yaw, Vector3(0, 0.95, -0.15)), Vector3(0.45, 0.32, 0.04), yaw, Color(0.08, 0.08, 0.1), false)  # 모니터
	# 의자 (가끔 넘어짐)
	var cp := _local(p, yaw, Vector3(0, 0, 0.65))
	if rng.randf() < 0.25:
		_yawbox(cp + Vector3.UP * 0.2, Vector3(0.45, 0.45, 0.08), yaw + 0.4, Color(0.15, 0.15, 0.18), false)
	else:
		_yawbox(cp + Vector3.UP * 0.45, Vector3(0.45, 0.06, 0.45), yaw, Color(0.15, 0.15, 0.18), false)
		_yawbox(_local(cp, yaw, Vector3(0, 0.75, 0.2)), Vector3(0.45, 0.55, 0.06), yaw, Color(0.15, 0.15, 0.18), false)
		_yawbox(cp + Vector3.UP * 0.22, Vector3(0.06, 0.44, 0.06), yaw, Color(0.3, 0.3, 0.3), false, "metal")


func _cabinet(spot: Array, y: float) -> void:
	_obj_begin()
	_cabinet_impl(spot, y)
	_obj_end()


func _cabinet_impl(spot: Array, y: float) -> void:
	var p: Vector3 = spot[0]
	p.y = y
	var yaw: float = spot[1]
	_yawbox(_local(p, yaw, Vector3(0, 0.65, 0)), Vector3(0.9, 1.3, 0.5), yaw, Color(0.55, 0.57, 0.58), true, "metal")
	for k in 3:
		_yawbox(_local(p, yaw, Vector3(0, 0.3 + k * 0.4, 0.26)), Vector3(0.12, 0.03, 0.02), yaw, Color(0.2, 0.2, 0.2), false, "metal")


func _shelf(p: Vector3, along_z: bool) -> void:
	_obj_begin()
	_shelf_impl(p, along_z)
	_obj_end()


func _shelf_impl(p: Vector3, along_z: bool) -> void:
	var yaw := PI / 2.0 if along_z else 0.0
	var col := Color(0.45, 0.47, 0.5)
	_yawbox(p + Vector3.UP * 0.8, Vector3(1.8, 1.6, 0.5), yaw, col.darkened(0.3), true, "metal")
	for k in 4:
		for i in 5:
			if rng.randf() < 0.35:
				continue  # 텅 빈 칸 (약탈당한 가게)
			var off := Vector3(-0.7 + i * 0.35, 0.2 + k * 0.4, 0.0)
			var pc: Color = [Color(0.8, 0.3, 0.25), Color(0.3, 0.6, 0.8), Color(0.9, 0.8, 0.3), Color(0.4, 0.7, 0.35)][rng.randi() % 4]
			_yawbox(_local(p, yaw, off + Vector3(0, 0.12, 0.22)), Vector3(0.22, 0.24, 0.16), yaw, pc, false)


func _counter(spot: Array, y: float) -> void:
	_obj_begin()
	_counter_impl(spot, y)
	_obj_end()


func _counter_impl(spot: Array, y: float) -> void:
	var p: Vector3 = spot[0]
	p.y = y
	var yaw: float = spot[1]
	_yawbox(_local(p, yaw, Vector3(0, 0.5, 0)), Vector3(2.2, 1.0, 0.7), yaw, Color(0.4, 0.3, 0.22))
	_yawbox(_local(p, yaw, Vector3(0.6, 1.1, 0)), Vector3(0.45, 0.2, 0.35), yaw, Color(0.2, 0.2, 0.22), false, "metal")  # 계산대


func _crate(p: Vector3, s: float) -> void:
	_obj_begin()
	_crate_impl(p, s)
	_obj_end()


func _crate_impl(p: Vector3, s: float) -> void:
	part(p + Vector3.UP * s * 0.5, Vector3(s, s, s), Color(0.5, 0.36, 0.2), "trim", true, rng.randf() * PI)


## 사물함(숨는 곳)을 벽에 붙여 놓음 (앞이 방 안쪽을 봄)
func _maybe_locker(inner: Rect2, y: float, chance: float, _style := "") -> void:
	if rng.randf() > chance:
		return
	var side := rng.randi() % 4
	var spot := _against(inner, side, 1.0, 0.65)
	var p: Vector3 = spot[0]
	p.y = y
	if _in_doorway(p + Vector3.UP * 1.0, Vector3(1.0, 2.0, 0.7), float(spot[1])):
		return
	# 사물함 앞(-Z)이 방 안쪽을 보게: 벽 방향 yaw + PI
	lb.props.append(["locker", p, float(spot[1]) + PI])


func _classroom(room: Rect2, y: float) -> void:
	var inner := room.grow(-0.5)
	var ws := _window_side(room)
	# 칠판은 창가도 문도 아닌 옆벽(방의 x- 쪽 또는 z- 쪽)에. 책상은 칠판을 봄
	var along_x := ws >= 2 if ws >= 0 else inner.size.x >= inner.size.y
	var front := Vector3(room.position.x + 0.14, y, inner.get_center().y) if along_x else Vector3(inner.get_center().x, y, room.position.y + 0.14)
	var yaw := PI / 2.0 if along_x else 0.0
	var depth := inner.size.x if along_x else inner.size.y
	var width := inner.size.y if along_x else inner.size.x
	# 칠판 (나무 테두리 + 분필 받침 + 낙서)
	_yawbox(front + Vector3.UP * 1.55, Vector3(minf(4.6, width - 1.0), 1.3, 0.05), yaw, Color(0.1, 0.22, 0.16), false)
	_yawbox(front + Vector3.UP * 1.55, Vector3(minf(4.6, width - 1.0) + 0.16, 1.44, 0.03), yaw, Color(0.42, 0.3, 0.18), false)
	_yawbox(front + Vector3.UP * 0.88 + (Vector3(0.06, 0, 0) if along_x else Vector3(0, 0, 0.06)), Vector3(minf(4.6, width - 1.0), 0.04, 0.1), yaw, Color(0.42, 0.3, 0.18), false)
	var board_n := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	_chalk(front + Vector3.UP * 1.6 + board_n * 0.04, board_n)
	# 태극기 액자 + 시계 (칠판 위)
	_wall_clock(front + Vector3.UP * 2.75 + board_n * 0.03 + (Vector3(0, 0, 1.4) if along_x else Vector3(1.4, 0, 0)), board_n)
	_yawbox(front + Vector3.UP * 2.75 + board_n * 0.03 - (Vector3(0, 0, 1.4) if along_x else Vector3(1.4, 0, 0)), Vector3(0.7, 0.48, 0.03), yaw, Color(0.92, 0.92, 0.9), false)
	_yawbox(front + Vector3.UP * 2.75 + board_n * 0.05 - (Vector3(0, 0, 1.4) if along_x else Vector3(1.4, 0, 0)), Vector3(0.2, 0.2, 0.01), yaw, Color(0.75, 0.15, 0.2), false)
	# 교탁 + 선생님 책상
	var podium := front + board_n * 1.6
	_yawbox(podium + Vector3.UP * 0.55, Vector3(1.0, 1.1, 0.55), yaw, Color(0.45, 0.32, 0.22))
	_yawbox(podium + Vector3.UP * 1.11, Vector3(1.1, 0.04, 0.65), yaw, Color(0.35, 0.25, 0.17), false)
	var tdesk := front + board_n * 1.4 + (Vector3(0, 0, width * 0.32) if along_x else Vector3(width * 0.32, 0, 0))
	if not blocks_door(tdesk, Vector3(1.4, 1, 0.8)):
		_desk(tdesk, yaw + PI)
	# 학생 책상 + 의자 (2개씩 짝, 가운데 통로)
	var cols := clampi(int(width / 1.35), 4, 7)
	var rows := clampi(int((depth - 3.4) / 1.25), 3, 7)
	var chairs_up := rng.randf() < 0.3
	for r in rows:
		for c in cols:
			if rng.randf() < 0.1:
				continue
			var u := 3.0 + r * 1.25
			var v := (c + 0.5) / cols
			var p := Vector3(inner.position.x + u, y, inner.position.y + width * v) if along_x else Vector3(inner.position.x + width * v, y, inner.position.y + u)
			if _keep.has_point(Vector2(p.x, p.z)) or blocks_door(p, Vector3(0.7, 1, 1.2)):
				continue
			var jy := yaw + rng.randf_range(-0.12, 0.12)
			if rng.randf() < 0.08:
				jy += rng.randf_range(0.6, 1.4)  # 삐뚤어진 책상
			_student_desk(p, jy)
			if chairs_up:
				# 청소 시간처럼 의자를 책상 위에 거꾸로 올려 둔 교실
				var cu := p + Vector3.UP * 1.18
				_yawbox(_local(cu, jy, Vector3(0, -0.4, 0)), Vector3(0.4, 0.035, 0.4), jy, Color(0.55, 0.42, 0.28), false)
				_yawbox(_local(cu, jy, Vector3(0, -0.66, 0.19)), Vector3(0.4, 0.3, 0.03), jy, Color(0.55, 0.42, 0.28), false)
				for sx in [-1.0, 1.0]:
					for sz in [-1.0, 1.0]:
						_yawbox(_local(cu, jy, Vector3(0.17 * sx, -0.17, 0.17 * sz)), Vector3(0.03, 0.44, 0.03), jy, Color(0.3, 0.3, 0.32), false, "metal")
			else:
				_chair(_local(p, jy, Vector3(0, 0, 0.55)), jy, Color(0.55, 0.42, 0.28), rng.randf() < 0.12)
	# 뒤쪽: 사물함 줄 (하나는 진짜 숨는 사물함) + 게시판
	var back := Vector3(inner.end.x - 0.32, y, inner.get_center().y) if along_x else Vector3(inner.get_center().x, y, inner.end.y - 0.32)
	var n := mini(8, int(width / 0.62) - 2)
	var real_i := rng.randi_range(1, n - 2)
	for i in n:
		var off := (i - n * 0.5 + 0.5) * 0.62
		var p := back + (Vector3(0, 0, off) if along_x else Vector3(off, 0, 0))
		if blocks_door(p, Vector3(0.6, 1, 0.6)):
			continue
		if i == real_i:
			lb.props.append(["locker", p, -PI / 2.0 if along_x else PI])
		else:
			_yawbox(p + Vector3.UP * 0.9, Vector3(0.58, 1.8, 0.5), yaw, Color(0.35, 0.45, 0.6).darkened(rng.randf() * 0.1), true, "metal")
			_yawbox(p + Vector3.UP * 1.5 + (Vector3(-0.26, 0, 0) if along_x else Vector3(0, 0, -0.26)), Vector3(0.4, 0.15, 0.02) if not along_x else Vector3(0.02, 0.15, 0.4), 0.0, Color(0.08, 0.08, 0.08), false)
	var bb := back + Vector3.UP * 2.35 + (Vector3(0.22, 0, 0) if along_x else Vector3(0, 0, 0.22))
	_yawbox(bb, Vector3(minf(4.0, width - 1.5), 0.9, 0.03), yaw, Color(0.5, 0.36, 0.22), false)
	for j in 5:
		decal(bb - board_n * 0.03 + (Vector3(0, rng.randf_range(-0.2, 0.2), -1.5 + j * 0.75) if along_x else Vector3(-1.5 + j * 0.75, rng.randf_range(-0.2, 0.2), 0)), -board_n, 0.5, "papers")
	_curtains(room, y, ws)
	# 칠판 옆 높은 곳의 TV + 천장 선풍기 2대 (날개 각도 제각각)
	var tvp := front + Vector3.UP * 2.55 + board_n * 0.3 + (Vector3(0, 0, -width * 0.42) if along_x else Vector3(-width * 0.42, 0, 0))
	_yawbox(tvp, Vector3(0.9, 0.55, 0.12), yaw, Color(0.06, 0.06, 0.07), false)
	_yawbox(tvp + Vector3.UP * 0.32, Vector3(0.2, 0.1, 0.3), yaw, Color(0.3, 0.3, 0.32), false, "metal")
	for fi in 2:
		var fc := Vector3(inner.get_center().x, y + room_h - 0.05, inner.get_center().y) + (Vector3(depth * (fi - 0.5) * 0.45, 0, 0) if along_x else Vector3(0, 0, depth * (fi - 0.5) * 0.45))
		part(fc + Vector3.DOWN * 0.25, Vector3(0.04, 0.5, 0.04), Color(0.85, 0.85, 0.82), "metal")
		part(fc + Vector3.DOWN * 0.52, Vector3(0.22, 0.1, 0.22), Color(0.88, 0.88, 0.86), "trim")
		var spin := rng.randf() * TAU
		for bl in 3:
			part(fc + Vector3.DOWN * 0.55 + Vector3(cos(spin + bl * TAU / 3.0), 0, sin(spin + bl * TAU / 3.0)) * 0.42, Vector3(0.7, 0.02, 0.14), Color(0.85, 0.85, 0.83), "trim", false, -(spin + bl * TAU / 3.0))
	if rng.randf() < 0.5:
		_yawbox(Vector3(inner.end.x - 0.8, y + 0.3, inner.position.y + 0.8) if along_x else Vector3(inner.position.x + 0.8, y + 0.3, inner.end.y - 0.8), Vector3(0.4, 0.6, 0.4), 0.0, Color(0.2, 0.3, 0.55), true, "metal")  # 쓰레기통


## 학생 책상: 상판 + 철 다리 + 책 넣는 칸 (+ 가끔 책·가방)
func _student_desk(p: Vector3, yaw: float) -> void:
	_obj_begin()
	_student_desk_impl(p, yaw)
	_obj_end()


func _student_desk_impl(p: Vector3, yaw: float) -> void:
	_yawbox(_local(p, yaw, Vector3(0, 0.72, 0)), Vector3(0.62, 0.035, 0.46), yaw, Color(0.68, 0.55, 0.38))
	_yawbox(_local(p, yaw, Vector3(0, 0.6, 0.02)), Vector3(0.56, 0.12, 0.4), yaw, Color(0.3, 0.32, 0.34), false, "metal")
	for sx in [-1.0, 1.0]:
		_yawbox(_local(p, yaw, Vector3(0.27 * sx, 0.35, 0)), Vector3(0.035, 0.7, 0.4), yaw, Color(0.35, 0.36, 0.38), false, "metal")
	if rng.randf() < 0.3:
		_yawbox(_local(p, yaw, Vector3(rng.randf_range(-0.12, 0.12), 0.76, 0)), Vector3(0.21, 0.04, 0.28), yaw + rng.randf_range(-0.5, 0.5), [Color(0.7, 0.2, 0.2), Color(0.2, 0.4, 0.7), Color(0.85, 0.75, 0.3)][rng.randi() % 3], false)


## 의자 (앉는 판 + 등받이 + 다리). knocked = 넘어진 의자
func _chair(p: Vector3, yaw: float, col: Color, knocked := false) -> void:
	_obj_begin()
	_chair_impl(p, yaw, col, knocked)
	_obj_end()


func _chair_impl(p: Vector3, yaw: float, col: Color, knocked := false) -> void:
	if knocked:
		var ky := yaw + rng.randf_range(-1.0, 1.0)
		_yawbox(_local(p, ky, Vector3(0, 0.2, 0)), Vector3(0.4, 0.4, 0.04), ky, col, false)
		_yawbox(_local(p, ky, Vector3(0, 0.03, 0.3)), Vector3(0.4, 0.04, 0.42), ky, col.darkened(0.1), false)
		return
	_yawbox(_local(p, yaw, Vector3(0, 0.44, 0)), Vector3(0.4, 0.035, 0.4), yaw, col, false)
	_yawbox(_local(p, yaw, Vector3(0, 0.7, 0.19)), Vector3(0.4, 0.32, 0.03), yaw, col, false)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_yawbox(_local(p, yaw, Vector3(0.17 * sx, 0.22, 0.17 * sz)), Vector3(0.03, 0.44, 0.03), yaw, Color(0.3, 0.3, 0.32), false, "metal")


## 칠판 낙서
func _chalk(p: Vector3, n: Vector3) -> void:
	# 글자 대신 분필 낙서: 수식 줄 · 도형 · 화살표
	var yaw := atan2(n.x, n.z)
	var rt := Vector3(cos(yaw), 0, -sin(yaw))
	var c := Color(0.88, 0.9, 0.86)
	for row in rng.randi_range(2, 4):
		var x0 := rng.randf_range(-1.3, -0.4)
		var len := rng.randf_range(0.6, 1.8)
		var q := p + n * 0.01 + Vector3.UP * (0.35 - row * 0.25) + rt * (x0 + len * 0.5)
		part(q, Vector3(len, 0.025, 0.005) if absf(n.z) > 0.5 else Vector3(0.005, 0.025, len), c, "trim")
	var sh := p + n * 0.01 + rt * rng.randf_range(0.6, 1.3) + Vector3.UP * rng.randf_range(-0.1, 0.25)
	for k in 4:
		var a := k * PI / 2.0
		var o := (rt * cos(a) + Vector3.UP * sin(a)) * 0.22
		var along: Vector3 = (rt * -sin(a) + Vector3.UP * cos(a)).abs()
		var sz := along * 0.44 + Vector3(0.025, 0.025, 0.025) - along * 0.025
		sz = Vector3(maxf(sz.x, 0.005) if absf(n.x) < 0.5 else 0.005, sz.y, maxf(sz.z, 0.005) if absf(n.z) < 0.5 else 0.005)
		part(sh + o, sz, c, "trim")


## 벽시계
func _wall_clock(p: Vector3, n: Vector3) -> void:
	var yaw := atan2(n.x, n.z)
	part(p, Vector3(0.36, 0.36, 0.05), Color(0.95, 0.95, 0.92), "trim", false, yaw)
	part(p + n * 0.03, Vector3(0.03, 0.14, 0.01), Color(0.1, 0.1, 0.1), "trim", false, yaw)
	part(p + n * 0.035 + Vector3.UP * -0.02, Vector3(0.11, 0.025, 0.01), Color(0.1, 0.1, 0.1), "trim", false, yaw + 0.0)


## 창가 커튼 (문 반대쪽 벽, 일부는 찢어져 짧음)
func _curtains(room: Rect2, y: float, ws: int) -> void:
	if ws < 0:
		return
	var along := ws >= 2
	var L := room.size.x if along else room.size.y
	var n := int(L / 1.2)
	var col: Color = [Color(0.55, 0.62, 0.5), Color(0.6, 0.5, 0.38), Color(0.5, 0.55, 0.65)][rng.randi() % 3]
	for i in n:
		if rng.randf() < 0.3:
			continue
		var u := (i + 0.5) * L / n
		var h := rng.randf_range(1.6, 2.4) if rng.randf() < 0.2 else room_h - 1.0
		var p: Vector3
		match ws:
			0: p = Vector3(room.position.x + 0.2, 0, room.position.y + u)
			1: p = Vector3(room.end.x - 0.2, 0, room.position.y + u)
			2: p = Vector3(room.position.x + u, 0, room.position.y + 0.2)
			_: p = Vector3(room.position.x + u, 0, room.end.y - 0.2)
		var top := y + room_h - 0.35
		var yaw := 0.0 if along else PI / 2.0
		part(Vector3(p.x, top - h * 0.5, p.z), Vector3(0.9, h, 0.04), col.darkened(rng.randf() * 0.2), "trim", false, yaw + rng.randf_range(-0.08, 0.08))
	var rail := Vector3(room.get_center().x, y + room_h - 0.3, room.get_center().y)
	match ws:
		0: rail.x = room.position.x + 0.2
		1: rail.x = room.end.x - 0.2
		2: rail.z = room.position.y + 0.2
		_: rail.z = room.end.y - 0.2
	part(rail, Vector3(L - 0.4, 0.04, 0.04) if along else Vector3(0.04, 0.04, L - 0.4), Color(0.6, 0.6, 0.62), "metal")

func _ward(room: Rect2, y: float) -> void:
	var inner := room.grow(-0.3)
	var ws := _window_side(room)
	# 침대 머리는 창가와 직각인 두 옆벽에 붙이고, 발끝은 가운데 통로 쪽
	var beds_along_z := ws >= 2 if ws >= 0 else inner.size.y >= inner.size.x
	var L := inner.size.y if beds_along_z else inner.size.x
	var n := maxi(1, int((L - 1.0) / 2.5))
	for side in [-1.0, 1.0]:
		for i in n:
			var u := 0.5 + (i + 0.5) * (L - 1.0) / n
			var p: Vector3
			var yaw: float
			if beds_along_z:
				p = Vector3(inner.position.x + 1.15 if side < 0 else inner.end.x - 1.15, y, inner.position.y + u)
				yaw = -PI / 2.0 if side < 0 else PI / 2.0
			else:
				p = Vector3(inner.position.x + u, y, inner.position.y + 1.15 if side < 0 else inner.end.y - 1.15)
				yaw = PI if side < 0 else 0.0
			if blocks_door(p, Vector3(2.4, 1, 2.4)) or _keep.has_point(Vector2(p.x, p.z)):
				continue
			_hospital_bed(p, yaw)
			# 침대 사이 커튼 (천장 레일에 매달림, 일부는 걷혀 있음)
			if rng.randf() < 0.6:
				var cp := _local(p, yaw, Vector3(0.75, room_h * 0.5 - 0.1, 0.0))
				_yawbox(Vector3(cp.x, y + room_h - 0.25 - (room_h - 0.6) * 0.5, cp.z), Vector3(0.03, room_h - 0.8, 2.0), yaw, Color(0.55, 0.72, 0.68).darkened(rng.randf() * 0.25), false)
			# 머리맡 협탁 + 링거대 (+ 가끔 켜진 심전도 모니터)
			_yawbox(_local(p, yaw, Vector3(-0.75, 0.4, -0.75)), Vector3(0.45, 0.8, 0.45), yaw, Color(0.82, 0.82, 0.8), true)
			if rng.randf() < 0.45:
				_yawbox(_local(p, yaw, Vector3(-0.75, 1.05, -0.8)), Vector3(0.4, 0.3, 0.12), yaw + 0.3, Color(0.18, 0.2, 0.22), false, "metal")
				var on := rng.randf() < 0.5
				_yawbox(_local(p, yaw, Vector3(-0.73, 1.05, -0.73)), Vector3(0.32, 0.22, 0.01), yaw + 0.3, Color(0.2, 0.95, 0.4) if on else Color(0.03, 0.04, 0.04), false, "lit" if on else "glass")
			if rng.randf() < 0.6:
				var iv := _local(p, yaw, Vector3(0.6, 0, -0.85))
				part(iv + Vector3.UP * 0.95, Vector3(0.03, 1.9, 0.03), Color(0.7, 0.7, 0.72), "metal")
				part(iv + Vector3.UP * 1.75, Vector3(0.14, 0.24, 0.06), Color(0.8, 0.9, 1.0), "glass")
	# 침대에서 문 쪽으로 끌린 핏자국 (가끔)
	if door_at != Vector3.INF and rng.randf() < 0.35:
		var c0 := room.get_center()
		var from := Vector3(c0.x + rng.randf_range(-2, 2), y + 0.01, c0.y + rng.randf_range(-2, 2))
		var to := Vector3(door_at.x, y + 0.01, door_at.z)
		var steps := int(from.distance_to(to) / 0.7)
		for k in steps:
			var q := from.lerp(to, float(k) / maxf(1, steps)) + Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15))
			decal(q, Vector3.UP, rng.randf_range(0.5, 0.9), "blood")
	# 가운데: 바퀴 달린 식탁 / 넘어진 링거대 / 핏자국
	if rng.randf() < 0.7:
		var c := room.get_center()
		_yawbox(Vector3(c.x + rng.randf_range(-1, 1), y + 0.85, c.y + rng.randf_range(-1, 1)), Vector3(0.8, 0.04, 0.4), rng.randf() * TAU, Color(0.8, 0.8, 0.78), false)
	if rng.randf() < 0.5:
		_maybe_locker(inner, y, 1.0)
	_curtains(room, y, ws)


## 병원 침대: 철제 틀 + 매트리스 + 베개 + 머리판·발판 + 바퀴 (+ 가끔 흰 천을 덮은 무언가)
func _hospital_bed(p: Vector3, yaw: float) -> void:
	_obj_begin()
	_hospital_bed_impl(p, yaw)
	_obj_end()


func _hospital_bed_impl(p: Vector3, yaw: float) -> void:
	_yawbox(_local(p, yaw, Vector3(0, 0.52, 0.0)), Vector3(0.95, 0.16, 2.0), yaw, Color(0.88, 0.9, 0.92))
	_yawbox(_local(p, yaw, Vector3(0, 0.38, 0.0)), Vector3(0.95, 0.1, 2.05), yaw, Color(0.6, 0.62, 0.65), false, "metal")
	_yawbox(_local(p, yaw, Vector3(0, 0.66, -0.75)), Vector3(0.6, 0.12, 0.35), yaw, Color(0.96, 0.96, 0.96), false)
	_yawbox(_local(p, yaw, Vector3(0, 0.75, -1.02)), Vector3(0.98, 0.75, 0.05), yaw, Color(0.72, 0.74, 0.78), false, "metal")
	_yawbox(_local(p, yaw, Vector3(0, 0.62, 1.02)), Vector3(0.98, 0.5, 0.05), yaw, Color(0.72, 0.74, 0.78), false, "metal")
	for sx in [-1.0, 1.0]:
		_yawbox(_local(p, yaw, Vector3(0.49 * sx, 0.72, 0.1)), Vector3(0.03, 0.12, 1.3), yaw, Color(0.7, 0.72, 0.75), false, "metal")
		for sz in [-1.0, 1.0]:
			_yawbox(_local(p, yaw, Vector3(0.42 * sx, 0.17, 0.9 * sz)), Vector3(0.05, 0.34, 0.05), yaw, Color(0.4, 0.4, 0.42), false, "metal")
	var r := rng.randf()
	if r < 0.25:
		_yawbox(_local(p, yaw, Vector3(0.05, 0.72, 0.15)), Vector3(0.55, 0.22, 1.6), yaw + rng.randf_range(-0.05, 0.05), Color(0.92, 0.92, 0.93), false)
		if rng.randf() < 0.5:
			decal(_local(p, yaw, Vector3(0.1, 0.84, 0.0)), Vector3.UP, 0.6, "blood")
	elif r < 0.6:
		_yawbox(_local(p, yaw, Vector3(0.1, 0.63, 0.35)), Vector3(0.9, 0.05, 1.2), yaw + rng.randf_range(-0.2, 0.2), Color(0.8, 0.85, 0.9), false)

func wing(r: Rect2, y: float, fh: float, along_x: bool, corridor_w: float, left: Array, right: Array, wall_mat: Material, skip: Array = [], door_chance := 0.4) -> Array:
	var out := []
	var cl := (r.get_center().y if along_x else r.get_center().x)
	var total := r.size.x if along_x else r.size.y
	var start := r.position.x if along_x else r.position.y
	for side in [-1.0, 1.0]:
		var list: Array = left if side < 0 else right
		var depth := ((r.size.y if along_x else r.size.x) - corridor_w) * 0.5
		var u := start
		for i in list.size():
			var spec: Array = list[i]
			var L: float = spec[0]
			if i == list.size() - 1:
				L = start + total - u
			if L < 1.0:
				break
			var rr: Rect2
			if along_x:
				rr = Rect2(u, cl - corridor_w * 0.5 - depth, L, depth) if side < 0 else Rect2(u, cl + corridor_w * 0.5, L, depth)
			else:
				rr = Rect2(cl - corridor_w * 0.5 - depth, u, depth, L) if side < 0 else Rect2(cl + corridor_w * 0.5, u, depth, L)
			u += L
			var blocked := false
			for sk in skip:
				if rr.intersects(sk as Rect2):
					blocked = true
			if blocked:
				continue
			if spec[1] == "":
				# 빈 칸(현관 홀 등): 방은 안 만들지만 다음 방과의 경계 벽은 세움
				if i < list.size() - 1:
					if along_x:
						wall(Vector3(rr.end.x, 0, rr.position.y), Vector3(rr.end.x, 0, rr.end.y), y, fh - FLOOR_T, wall_mat, "w_inner", [], 0.18)
					else:
						wall(Vector3(rr.position.x, 0, rr.end.y), Vector3(rr.end.x, 0, rr.end.y), y, fh - FLOOR_T, wall_mat, "w_inner", [], 0.18)
				continue
			# 복도 쪽 벽 (문 하나) + 방 사이 벽
			var wy := rr.end.y if (along_x and side < 0) else (rr.position.y if along_x else 0.0)
			var a: Vector3
			var b: Vector3
			if along_x:
				var z := rr.end.y if side < 0 else rr.position.y
				a = Vector3(rr.position.x, 0, z)
				b = Vector3(rr.end.x, 0, z)
			else:
				var x := rr.end.x if side < 0 else rr.position.x
				a = Vector3(x, 0, rr.position.y)
				b = Vector3(x, 0, rr.end.y)
			var du := clampf(L * rng.randf_range(0.25, 0.75), 1.0, L - 1.0)
			partition([a, b, du, true], y, fh - FLOOR_T, wall_mat, "w_inner", [], door_chance)
			var door_at := a + (b - a).normalized() * du
			# 방 사이 벽 (다음 방과의 경계, 문 없음)
			if i < list.size() - 1:
				var e1: Vector3
				var e2: Vector3
				if along_x:
					e1 = Vector3(rr.end.x, 0, rr.position.y)
					e2 = Vector3(rr.end.x, 0, rr.end.y)
				else:
					e1 = Vector3(rr.position.x, 0, rr.end.y)
					e2 = Vector3(rr.end.x, 0, rr.end.y)
				wall(e1, e2, y, fh - FLOOR_T, wall_mat, "w_inner", [], 0.18)
			out.append({"rect": rr, "kind": spec[1], "name": spec[2] if spec.size() > 2 else "", "door": (a + b) * 0.5, "door_at": door_at, "door_along_x": along_x})
	return out


## 방 이름표 (문 옆 벽에 붙는 작은 판 + 글자)
func room_sign(at: Vector3, text: String, normal: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 48
	l.pixel_size = 0.005
	l.modulate = Color(0.9, 0.9, 0.85)
	l.outline_size = 8
	l.visibility_range_end = 22.0  # 최적화: 멀리선 안 그림
	l.position = at + normal * 0.12
	l.rotation.y = atan2(normal.x, normal.z)  # 글자 앞면이 normal 쪽을 봄 (씬 트리 밖에서도 됨)
	lb.region.add_child(l)
	part(at + normal * 0.1, Vector3(0.9, 0.28, 0.04) if absf(normal.z) > 0.5 else Vector3(0.04, 0.28, 0.9), Color(0.2, 0.3, 0.35))


# ================================================================ 건물 한 채 (도시용 자동 배치)

## 외벽에 창문·출입구를 뚫은 여러 층 건물 + 방·계단·가구. 위쪽(interior_floors 위)은 꽉 찬 덩어리
## kind: "apartment" / "office" / "shop"
func city_building(r: Rect2, y0: float, total_h: float, wall_mat: Material, trim: Color, kind: String) -> Array:
	var fh := 3.5
	var floors := 1 if total_h < 7.8 or minf(r.size.x, r.size.y) < 6.0 else 2
	# 실내 마감: 종류마다 벽지·아래 판넬·바닥재가 다름
	var in_wall: Material = lb._mat["in_paint"] if kind != "office" else lb._mat["in_paint_b"]
	wainscot_mat = lb._mat["in_wains_tile"] if kind == "shop" else lb._mat["in_wains_wood"]
	wainscot_h = 1.0
	trim_col = Color(0.3, 0.22, 0.15)
	lining_mat = in_wall
	room_h = fh
	var interior_h := floors * fh
	var spots := []
	var c := r.get_center()
	var inner := r.grow(-WALL_T)
	# 계단 자리 (2층 건물): 긴 벽을 따라 한쪽 끝
	var stair := Rect2()
	var stair_along_x := r.size.x >= r.size.y
	if floors == 2:
		var run := 6.0
		var w := 1.8
		# 아래쪽 끝(벽 쪽)에 1.3m 여유를 둬서 계단에 오르기 쉽게, 위쪽 끝은 방 안쪽으로 내림
		if stair_along_x:
			stair = Rect2(inner.end.x - run - 1.3, inner.position.y + 0.1, run, w)
		else:
			stair = Rect2(inner.position.x + 0.1, inner.end.y - run - 1.3, w, run)
	# 외벽 (층마다)
	var sides := [
		[Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0, r.position.y), Vector3(0, 0, -1)],
		[Vector3(r.end.x, 0, r.position.y), Vector3(r.end.x, 0, r.end.y), Vector3(1, 0, 0)],
		[Vector3(r.end.x, 0, r.end.y), Vector3(r.position.x, 0, r.end.y), Vector3(0, 0, 1)],
		[Vector3(r.position.x, 0, r.end.y), Vector3(r.position.x, 0, r.position.y), Vector3(-1, 0, 0)],
	]
	var entrance_start := entrances.size()
	var entrance_sides := [rng.randi() % 4]
	if rng.randf() < 0.6:
		entrance_sides.append((entrance_sides[0] + 2) % 4)
	var vault_side := rng.randi() % 4
	for si in 4:
		var a: Vector3 = sides[si][0]
		var b: Vector3 = sides[si][1]
		var n: Vector3 = sides[si][2]
		var L := Vector2(b.x - a.x, b.z - a.z).length()
		var dir := (b - a).normalized()
		for k in floors:
			var y := y0 + k * fh
			var ops := []
			var count := maxi(1, int((L - 1.6) / 2.4))
			var gap := (L - 1.6) / count
			var entrance_u := -100.0
			if k == 0 and entrance_sides.has(si):
				entrance_u = clampf(L * rng.randf_range(0.3, 0.7), 1.2, L - 1.2)
				ops.append([entrance_u - DOOR_W * 0.5, entrance_u + DOOR_W * 0.5, 0.0, DOOR_H])
				var dc := a + dir * entrance_u
				dc.y = y
				entrances.append([dc, n])
				_door_frame(dc, dir, trim.darkened(0.4))
				if rng.randf() < 0.5:
					lb.props.append(["door", dc, atan2(dir.z, -dir.x) + PI, DOOR_W - 0.1])
			var vault_done := false
			for i in count:
				var u := 0.8 + gap * (i + 0.5)
				if absf(u - entrance_u) < 1.6:
					continue
				var wc := a + dir * u
				wc.y = y + (WIN_SILL + WIN_TOP) * 0.5
				if k == 0 and si == vault_side and not vault_done and i == count / 2:
					# 넘을 수 있는 깨진 창문 (바닥까지 뚫림, 창턱은 충돌 없음)
					vault_done = true
					ops.append([u - 0.8, u + 0.8, 0.0, WIN_TOP])
					block(Vector3(wc.x, y + 0.45, wc.z), Vector3(1.6, 0.9, WALL_T * 0.6), wall_mat, "w_vault", false, Basis(dir, Vector3.UP, dir.cross(Vector3.UP).normalized()))
					var vp := a + dir * u
					vp.y = y
					lb.props.append(["window", vp, atan2(dir.z, -dir.x) + PI])
					continue
				ops.append([u - 0.55, u + 0.55, WIN_SILL, WIN_TOP])
				# 유리 (부딪힘) + 바깥 창틀 장식
				var gc := a + dir * u
				gc.y = y + (WIN_SILL + WIN_TOP) * 0.5
				var lit := rng.randf() < 0.12
				block(gc, Vector3(1.1, WIN_TOP - WIN_SILL, 0.04), lb._deco_mat("lit" if lit else "glass"), "b_" + ("lit" if lit else "glass"), true, Basis(dir, Vector3.UP, dir.cross(Vector3.UP).normalized()), false, Color(1.0, 0.75, 0.45) if lit else Color(0.07, 0.09, 0.12))
				lb._window_frame_only(gc + n * (WALL_T * 0.5), dir, n, trim)
			var in_side := -1 if dir.cross(Vector3.UP).dot(n) > 0.0 else 1
			wall(a, b, y, fh, wall_mat, "w_build_%d" % wall_mat.get_instance_id(), ops, WALL_T, in_side)
		# 실내가 없는 윗부분: 꽉 찬 벽 + 가짜 창문
		if total_h > interior_h + 0.1:
			var face := (a + b) * 0.5 + n * (WALL_T * 0.5)
			lb._facade_side(face, dir, n, L, y0 + interior_h, total_h - interior_h, trim)
	if total_h > interior_h + 0.1:
		block(Vector3(c.x, y0 + interior_h + (total_h - interior_h) * 0.5, c.y), Vector3(r.size.x, total_h - interior_h, r.size.y), wall_mat, "w_build_%d" % wall_mat.get_instance_id(), true, Basis.IDENTITY, true)
	else:
		slab(r, y0 + total_h + 0.15, lb._mat["concrete"], "w_concrete", [], true, 0.3)
	# 층 바닥 / 천장
	var floor_mat: Material = lb._mat["crate"] if kind == "apartment" else lb._mat["sidewalk"]
	slab(inner, y0 + 0.06, floor_mat, "w_floor_%d" % floor_mat.get_instance_id(), [], false, 0.06)
	if floors == 2:
		slab(inner, y0 + fh, floor_mat, "w_floor_%d" % floor_mat.get_instance_id(), [stair])
		stairs(stair, stair_along_x, false, y0, fh)
		hole_rail(stair, y0 + fh, "x-" if stair_along_x else "z-")
		ceiling(inner, y0 + fh - FLOOR_T, lb._mat["in_ceil"], [stair])
	ceiling(inner, y0 + interior_h - (0.0 if total_h > interior_h + 0.1 else 0.0) - 0.02, lb._mat["in_ceil"])
	# 방 나누기 + 가구 (층마다)
	var zone := stair_zone(stair, stair_along_x) if floors == 2 else Rect2()
	for k in floors:
		var y := y0 + k * fh
		var layout := split_rooms(inner, 4.6, 9.0 if kind != "shop" or k > 0 else 30.0)
		var floor_doors := []  # 이 층의 모든 문 앞 공간 (가구가 막지 않게)
		for w in layout["walls"]:
			partition(w, y, fh - FLOOR_T, in_wall, "w_inner", [zone] if floors == 2 else [])
			var wa: Vector3 = w[0]
			var wb: Vector3 = w[1]
			var dc: Vector3 = wa + (wb - wa).normalized() * float(w[2])
			floor_doors.append(Rect2(dc.x - 1.2, dc.z - 2.6, 2.4, 5.2) if absf(wb.x - wa.x) > absf(wb.z - wa.z) else Rect2(dc.x - 2.6, dc.z - 1.2, 5.2, 2.4))
		if k == 0:
			for ei in range(entrance_start, entrances.size()):
				var ep: Vector3 = entrances[ei][0]
				var en: Vector3 = entrances[ei][1]
				floor_doors.append(Rect2(ep.x - 1.2, ep.z - 2.6, 2.4, 5.2) if absf(en.z) > 0.5 else Rect2(ep.x - 2.6, ep.z - 1.2, 5.2, 2.4))
		if floors == 2:
			floor_doors.append(zone.grow(0.6))
		for room in layout["rooms"]:
			var rr: Rect2 = room
			var rk := kind
			if kind == "shop":
				rk = "shop" if k == 0 else ("storage" if rng.randf() < 0.5 else "office")
			if rr.get_area() < 9.0:
				rk = "storage"
			if floors == 2 and rr.intersects(zone):
				rk = "empty"  # 계단 방은 비워 둠 (계단을 막지 않게)
			var candidate: bool = (rk == "apartment" or rk == "office") and rr.size.x > 3.8 and rr.size.y > 3.8 and not (floors == 2 and rr.intersects(zone))
			var fm: Material = lb._mat["in_wood"] if rk == "apartment" else (lb._mat["in_terrazzo"] if rk == "shop" else lb._mat["in_lino"])
			floor_overlay(rr, y + (0.06 if k == 0 else 0.0), fm)
			door_clears = floor_doors.filter(func(d): return (d as Rect2).intersects(rr.grow(0.4)))
			var sp := furnish(rr, y, rk, candidate)
			door_clears = []
			if candidate:
				spots.append(sp)
			grime(rr, y + (0.07 if k == 0 else 0.01), fh, 0.7, 0.15)
			if lb.debug_rooms.size() < 40 and rk != "empty":
				lb.debug_rooms.append([{"rect": rr, "kind": rk, "name": "city", "door_at": Vector3.INF}, y + (0.06 if k == 0 else 0.0)])
			ceiling_light(Vector3(rr.get_center().x, y + fh - FLOOR_T - 0.05, rr.get_center().y))
	wainscot_mat = null
	lining_mat = null
	return spots
