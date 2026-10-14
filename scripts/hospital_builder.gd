class_name HospitalBuilder
extends LevelBuilder
## 네 번째 맵: 버려진 병원
## - 지하 1층(영안실·보일러실·창고·지하 주차장) + 1층(로비·응급실·약제실·영상의학과) + 2층(병실·수술실·간호사실·중환자실)
## - 양 끝 계단실에 계단 2개씩 (지하↔1층, 1층↔2층)
## - 바깥은 주차장(구급차·자동차), 정문 차양과 빨간 십자 간판, 담장

const FH := 4.0
const BLD := Rect2(-42.0, -36.0, 84.0, 30.0)
const Y0 := 0.05
const YB := -3.95


func build(target: Node3D, map_seed: int) -> void:
	region = target
	rng.seed = map_seed
	half = 64.0
	survivor_spawns = [Vector3(-2, 0.3, 56), Vector3(2, 0.3, 56), Vector3(-2, 0.3, 59), Vector3(2, 0.3, 59)]
	seeker_spawns = [Vector3(-20, YB + 0.3, -21), Vector3(20, Y0 + FH + 0.3, -21), Vector3(0, 0.3, -52)]
	floor_levels = [YB, Y0, Y0 + FH]
	debug_views = [[Vector3(0, 1.7, 14), Vector3(0, 4, -15)], [Vector3(-30, 1.7, 8), Vector3(-10, 4, -15)], [Vector3(30, 1.7, -50), Vector3(10, 3, -30)], [Vector3(-2, 1.7, 1), Vector3(0, 2.5, -8)]]
	_make_materials()
	_mat["hosp_wall"] = _pattern_mat("plaster", Color(0.82, 0.84, 0.82), 3.0)
	_mat["hosp_in"] = _pattern_mat("paint", Color(0.72, 0.78, 0.74), 2.5)
	_mat["hosp_floor"] = _pattern_mat("lino", Color(0.62, 0.66, 0.64), 1.6)
	_mat["hosp_room_floor"] = _pattern_mat("terrazzo", Color(0.6, 0.62, 0.6), 1.4)
	_mat["wtile"] = _pattern_mat("wtile", Color(0.55, 0.7, 0.66), 0.6)
	_mat["wtile_floor"] = _pattern_mat("wtile", Color(0.62, 0.64, 0.64), 0.6)
	_mat["ceil"] = _pattern_mat("ceiling", Color(0.66, 0.68, 0.66), 1.2)
	_mat["base_wall"] = _pattern_mat("concrete", Color(0.5, 0.5, 0.48), 3.0)
	_mat["base_floor"] = _pattern_mat("concrete", Color(0.42, 0.42, 0.4), 3.0)
	_mat["base_band"] = _pattern_mat("paint", Color(0.55, 0.52, 0.32), 2.5)
	_mat["grass_ground"] = _noise_mat(Color(0.15, 0.22, 0.12), 0.5, 1.0, 3.0)
	kit = BuildingKit.new(self)
	_grounds()
	_outer_walls()
	_hospital()
	_parking_lot()
	_flush_batches()


## 땅: 건물 자리만 비우고(지하가 있으니까) 나머지를 덮음. 앞쪽은 주차장 아스팔트
func _grounds() -> void:
	var whole := Rect2(-half, -half, half * 2, half * 2)
	for piece in kit._subtract(whole, BLD):
		var pr: Rect2 = piece
		var lot := Rect2(-half, -6.0, half * 2, half + 6.0)
		var subs: Array = [pr.intersection(lot)] + kit._subtract(pr, lot)
		for si in subs.size():
			var r: Rect2 = subs[si]
			if r.size.x < 0.05 or r.size.y < 0.05:
				continue
			var mat: Material = _mat["asphalt"] if si == 0 else _mat["grass_ground"]
			_mark_indestructible(_box(Vector3(r.get_center().x, -0.5, r.get_center().y), Vector3(r.size.x, 1.0, r.size.y), mat))


func _hospital() -> void:
	var r := BLD
	var inner := r.grow(-BuildingKit.WALL_T)
	var corr_z := r.get_center().y
	corridor_probe = Vector3(inner.position.x + 4.0, 0, corr_z)
	var corr_w := 4.2
	var bay := 8.0
	var run := 7.0
	var zs := corr_z - corr_w * 0.5 - 1.4 - run
	var stA := Rect2(inner.position.x + 0.4, zs, 2.4, run)   # 지하 → 1층 (서쪽)
	var stB := Rect2(inner.position.x + 3.6, zs, 2.4, run)   # 1층 → 2층 (서쪽)
	var stC := Rect2(inner.end.x - 2.8, zs, 2.4, run)        # 지하 → 1층 (동쪽)
	var stD := Rect2(inner.end.x - 6.0, zs, 2.4, run)        # 1층 → 2층 (동쪽)
	var trim := Color(0.6, 0.62, 0.62)
	var sides := [
		[Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0, r.position.y), Vector3(0, 0, -1)],
		[Vector3(r.end.x, 0, r.position.y), Vector3(r.end.x, 0, r.end.y), Vector3(1, 0, 0)],
		[Vector3(r.end.x, 0, r.end.y), Vector3(r.position.x, 0, r.end.y), Vector3(0, 0, 1)],
		[Vector3(r.position.x, 0, r.end.y), Vector3(r.position.x, 0, r.position.y), Vector3(-1, 0, 0)],
	]
	kit.room_h = FH
	for si in 4:
		var a: Vector3 = sides[si][0]
		var b: Vector3 = sides[si][1]
		var n: Vector3 = sides[si][2]
		var L := Vector2(b.x - a.x, b.z - a.z).length()
		var dir := (b - a).normalized()
		var in_side := -1 if dir.cross(Vector3.UP).dot(n) > 0.0 else 1
		# 지하 외벽 (창문 없음, 콘크리트 + 아래쪽 노란 띠)
		_basement_finish()
		kit.wall(a, b, YB, Y0 - YB, _mat["base_wall"], "w_base", [], 0.4, in_side)
		_hosp_finish()
		for k in 2:
			var y := Y0 + k * FH
			var ops := []
			var doors := []
			if k == 0:
				if si == 2:
					doors = [L * 0.5 - 1.0, L * 0.5 + 1.0]
				elif si == 1:
					doors = [corr_z - r.position.y]
				elif si == 3:
					doors = [L - (corr_z - r.position.y)]
			for du in doors:
				ops.append([du - 0.9, du + 0.9, 0.0, BuildingKit.DOOR_H])
				var dc: Vector3 = a + dir * du
				dc.y = y
				kit._door_frame(dc, dir, Color(0.35, 0.37, 0.4))
				_exit_sign(dc + Vector3.UP * (BuildingKit.DOOR_H + 0.35) - n * 0.2, -n)
			var count := int((L - 1.0) / 2.6)
			var gap := (L - 1.0) / count
			for i in count:
				var u := 0.5 + gap * (i + 0.5)
				var skip := false
				for du in doors:
					if absf(u - du) < 1.6:
						skip = true
				if skip:
					continue
				ops.append([u - 0.65, u + 0.65, 1.0, 2.8])
				var gc := a + dir * u
				gc.y = y + 1.9
				var lit := rng.randf() < 0.06
				kit.block(gc, Vector3(1.3, 1.8, 0.04), _deco_mat("lit" if lit else "glass"), "b_" + ("lit" if lit else "glass"), true, Basis(dir, Vector3.UP, dir.cross(Vector3.UP).normalized()), false, Color(0.6, 0.95, 0.75) if lit else Color(0.1, 0.13, 0.2))
				var tt := Vector3.UP.cross(n)
				var fn := gc + n * (BuildingKit.WALL_T * 0.5)
				_bx("trim", fn + Vector3.UP * -0.95 + n * 0.08, tt, n, Vector3(1.5, 0.08, 0.2), trim)
				_bx("trim", fn + n * 0.03, tt, n, Vector3(0.06, 1.8, 0.05), Color(0.25, 0.27, 0.3))
				if rng.randf() < 0.35:
					kit.decal(fn + n * 0.01 + Vector3.UP * -1.6, n, rng.randf_range(0.9, 1.5), "stain", PI * 0.5)
				var fi := gc - n * (BuildingKit.WALL_T * 0.5)
				_bx("trim", fi + Vector3.UP * -0.9 - n * 0.08, tt, -n, Vector3(1.4, 0.05, 0.16), Color(0.85, 0.86, 0.85))
			kit.wall(a, b, y, FH, _mat["hosp_wall"], "w_hosp", ops, BuildingKit.WALL_T, in_side)
		var face := (a + b) * 0.5 + n * (BuildingKit.WALL_T * 0.5)
		var tt2 := Vector3.UP.cross(n)
		_bx("trim", face + n * 0.08 + Vector3.UP * (Y0 + FH), tt2, n, Vector3(L, 0.3, 0.2), Color(0.3, 0.55, 0.6))
		_bx("trim", face + n * 0.14 + Vector3.UP * (Y0 + FH * 2 + 0.2), tt2, n, Vector3(L + 0.4, 0.45, 0.3), trim.darkened(0.1))
	# 정문 차양 + 빨간 십자 간판 + 병원 이름
	_bx("trim", Vector3(0, Y0 + 3.3, r.end.y + 2.2), Vector3.RIGHT, Vector3.BACK, Vector3(9.0, 0.3, 4.4), Color(0.75, 0.77, 0.78))
	for x in [-4.1, 4.1]:
		kit.part(Vector3(x, Y0 + 1.65, r.end.y + 4.2), Vector3(0.3, 3.3, 0.3), Color(0.7, 0.7, 0.72), "trim", true)
	var cross := StandardMaterial3D.new()
	cross.albedo_color = Color(0.6, 0.05, 0.05)
	cross.emission_enabled = true
	cross.emission = Color(1.0, 0.1, 0.1)
	cross.emission_energy_multiplier = 1.8
	var roof_y := Y0 + FH * 2 + 0.2
	_box(Vector3(0, roof_y + 0.3, r.end.y - 0.4), Vector3(3.0, 0.6, 0.6), _mat["metal"], false)
	_box(Vector3(0, roof_y + 1.9, r.end.y - 0.4), Vector3(0.8, 2.4, 0.25), cross, false)
	_box(Vector3(0, roof_y + 1.9, r.end.y - 0.4), Vector3(2.4, 0.8, 0.25), cross, false)
	var cl := OmniLight3D.new()
	cl.light_color = Color(1.0, 0.15, 0.15)
	cl.omni_range = 12.0
	cl.light_energy = 1.5
	cl.position = Vector3(0, roof_y + 1.9, r.end.y + 1.0)
	cl.set_script(preload("res://scripts/flicker_light.gd"))
	region.add_child(cl)
	var lbl := Label3D.new()
	lbl.text = "성 모 병 원"
	lbl.font_size = 96
	lbl.pixel_size = 0.007
	lbl.modulate = Color(0.85, 0.85, 0.85)
	lbl.position = Vector3(0, Y0 + 3.95, r.end.y + 4.47)
	region.add_child(lbl)
	_box(Vector3(0, Y0 + 3.95, r.end.y + 4.35), Vector3(8.0, 0.9, 0.2), _flat_mat(Color(0.12, 0.25, 0.3), 0.6), false)
	# 바닥판·천장
	kit.slab(inner, YB + 0.05, _mat["base_floor"], "w_bfloor", [], false, 0.3)
	kit.slab(inner, Y0, _mat["hosp_floor"], "w_hfloor", [stA, stC], false, 0.25)
	kit.slab(inner, Y0 + FH, _mat["hosp_floor"], "w_hfloor", [stB, stD])
	kit.slab(r.grow(0.3), Y0 + FH * 2 + 0.2, _mat["concrete"], "w_concrete", [], true, 0.3)
	kit.ceiling(inner, Y0 + FH - BuildingKit.FLOOR_T, _mat["ceil"], [stB, stD], Y0 + 0.01)
	kit.ceiling(inner, Y0 + FH * 2 - 0.1, _mat["ceil"], [], Y0 + FH + 0.01)
	kit.ceiling(inner, Y0 - 0.25, _mat["base_wall"], [stA, stC])
	for st in [stA, stC]:
		kit.stairs(st, false, true, YB + 0.05, Y0 - YB - 0.05, Color(0.5, 0.5, 0.48))
		kit.hole_rail(st, Y0, "z+")
	for st in [stB, stD]:
		kit.stairs(st, false, true, Y0, FH, Color(0.62, 0.64, 0.63))
		kit.hole_rail(st, Y0 + FH, "z+")
	# 층별 방
	var core := Rect2(inner.position.x + bay, inner.position.y, inner.size.x - bay * 2.0, inner.size.y)
	var plans := {
		YB: [[[16, "morgue", "영안실"], [12, "boiler", "보일러실"], [8, "storage", "창고"], [10, "storage", "세탁실"], [12, "boiler", "발전기실"]],
			[[34, "parking", "지하 주차장"], [11, "storage", "의료폐기물"], [12, "office", "시설관리실"]]],
		Y0: [[[14, "ward", "응급실"], [9, "nurse", "처치실"], [10, "pharmacy", "약제실"], [7, "toilet", "화장실"], [12, "lab", "영상의학과"], [10, "office", "원무과"]],
			[[10, "office", "진료실 1"], [10, "office", "진료실 2"], [11, "lobby", "외래 대기실"], [12, "", ""], [10, "pharmacy", "매점"], [10, "nurse", "주사실"]]],
		Y0 + FH: [[[10, "ward", "201호"], [10, "ward", "202호"], [14, "operating", "수술실"], [7, "toilet", "화장실"], [10, "ward", "203호"], [10, "ward", "204호"]],
			[[12, "nurse_station", "간호사실"], [10, "ward", "205호"], [15, "ward", "중환자실"], [10, "ward", "206호"], [11, "office", "의사실"]]],
	}
	for y in plans.keys():
		var fy: float = y
		var plan: Array = plans[y]
		var base := fy < 0.0
		var ry := fy + (0.05 if base else 0.0)
		var h := (Y0 - YB) if base else FH
		if base:
			_basement_finish()
		else:
			_hosp_finish()
		var rooms: Array = kit.wing(core, ry, h, true, corr_w, plan[0], plan[1], _mat["base_wall"] if base else _mat["hosp_in"], [], 0.4)
		for rm in rooms:
			var rr: Rect2 = rm["rect"]
			var kind: String = rm["kind"]
			var keep: bool = kind in ["ward", "lobby", "morgue", "operating", "parking", "boiler"] and rng.randf() < 0.5
			if not base:
				kit.floor_overlay(rr, ry, _mat["wtile_floor"] if kind in ["toilet", "operating"] else _mat["hosp_room_floor"])
			kit.furnish_room(rm, ry, keep)
			debug_rooms.append([rm, ry])
			kit.grime(rr, ry + 0.005, h, 0.9, 0.35 if kind in ["ward", "operating", "morgue", "nurse"] else 0.15)
			if keep:
				generator_spots.append(Vector3(rr.get_center().x, ry, rr.get_center().y))
			for li in maxi(1, int(rr.size.x / 6.0)):
				var lx := rr.position.x + (li + 0.5) * rr.size.x / maxi(1, int(rr.size.x / 6.0))
				kit.ceiling_light(Vector3(lx, ry + h - 0.28, rr.get_center().y), Color(0.75, 0.95, 0.85) if not base else Color(1.0, 0.8, 0.55), 0.8, 0.35)
			var dn := Vector3(0, 0, 1) if rr.get_center().y < corr_z else Vector3(0, 0, -1)
			var da: Vector3 = rm["door_at"]
			kit.room_sign(Vector3(da.x + 1.25, ry + 2.6, da.z), rm["name"], dn)
		# 1층 로비 (현관 앞 빈 칸): 접수대·대기 의자·안내판
		if fy == Y0:
			var lob := Rect2(-2.75 + core.position.x + 33.75 - 0.0, corr_z + corr_w * 0.5, 12.0, inner.end.y - corr_z - corr_w * 0.5)
			_lobby(lob, ry)
		# 계단실과 복도 끝 벽
		for xw in [core.position.x, core.end.x]:
			for side in [-1.0, 1.0]:
				var z0: float = corr_z + side * corr_w * 0.5
				var z1 := inner.position.y if side < 0 else inner.end.y
				kit.wall(Vector3(xw, 0, z0), Vector3(xw, 0, z1), ry, h - 0.2, _mat["base_wall"] if base else _mat["hosp_in"], "w_inner", [[1.2, 2.7, 0.0, BuildingKit.DOOR_H]] if side > 0 else [], 0.18)
		_hosp_corridor(core, corr_z, corr_w, ry, h, rooms, base)
		for sx in [-1.0, 1.0]:
			var wx: float = core.position.x - 0.1 if sx < 0 else core.end.x + 0.1
			_floor_sign(Vector3(wx, ry + 2.5, corr_z - corr_w * 0.5 - 2.2), Vector3(sx, 0, 0), "B1" if base else ("1F" if fy < 1.0 else "2F"), Color(0.55, 0.12, 0.1) if base else Color(0.15, 0.35, 0.45))
		# 계단실 끝에 사물함 (숨는 곳) + 엘리베이터
		props.append(["locker", Vector3(inner.end.x - 0.5, ry, corr_z + corr_w * 0.5 + 2.5), -PI / 2.0])
		props.append(["locker", Vector3(inner.position.x + 0.5, ry, corr_z + corr_w * 0.5 + 2.5), PI / 2.0])
		_elevator(Vector3(inner.position.x + bay * 0.5, ry, inner.end.y - 0.15), Vector3(0, 0, -1))
		_elevator(Vector3(inner.end.x - bay * 0.5, ry, inner.end.y - 0.15), Vector3(0, 0, -1))
		for ex in [inner.position.x, inner.end.x - bay]:
			kit.grime(Rect2(ex, corr_z + corr_w * 0.5, bay, inner.end.y - corr_z - corr_w * 0.5), ry + 0.005, h, 0.6, 0.2)
	kit.wainscot_mat = null
	kit.lining_mat = null
	_rooftop(r, Y0 + FH * 2 + 0.2)
	_rooftop(r.grow(-8.0), Y0 + FH * 2 + 0.2)
	# 옥상 헬리포트 표시
	kit.part(Vector3(-24, Y0 + FH * 2 + 0.21, r.get_center().y), Vector3(9, 0.02, 9), Color(0.3, 0.32, 0.3))
	for v in [[Vector3(-25.5, 0, 0), Vector3(0.5, 0.02, 4.0)], [Vector3(-22.5, 0, 0), Vector3(0.5, 0.02, 4.0)], [Vector3(-24, 0, 0), Vector3(3.0, 0.02, 0.5)]]:
		kit.part(Vector3(v[0].x, Y0 + FH * 2 + 0.23, r.get_center().y), v[1], Color(0.9, 0.9, 0.85))


## 병원 실내 마감: 아래는 연녹색 타일, 위는 밝은 민트색 벽
func _hosp_finish() -> void:
	kit.wainscot_mat = _mat["wtile"]
	kit.lining_mat = _mat["hosp_in"]
	kit.wainscot_h = 1.3
	kit.trim_col = Color(0.75, 0.77, 0.76)


## 지하: 콘크리트 벽 + 아래쪽 노란 페인트 띠
func _basement_finish() -> void:
	kit.wainscot_mat = _mat["base_band"]
	kit.lining_mat = null
	kit.wainscot_h = 0.9
	kit.trim_col = Color(0.2, 0.2, 0.2)


func _exit_sign(p: Vector3, facing: Vector3) -> void:
	var yaw := atan2(facing.x, facing.z)
	kit.part(p, Vector3(0.6, 0.22, 0.06), Color(0.1, 0.9, 0.35), "lit", false, yaw)
	var l := Label3D.new()
	l.text = "비상구"
	l.font_size = 32
	l.pixel_size = 0.005
	l.modulate = Color(0.95, 1.0, 0.95)
	l.position = p + facing * 0.04
	l.rotation.y = yaw
	l.visibility_range_end = 20.0
	region.add_child(l)


## 엘리베이터 문 (장식) + 층 표시등
func _elevator(p: Vector3, facing: Vector3) -> void:
	var yaw := atan2(facing.x, facing.z)
	kit.part(p + Vector3.UP * 1.15, Vector3(1.9, 2.3, 0.12), Color(0.45, 0.47, 0.5), "trim", false, yaw)
	for s in [-1.0, 1.0]:
		var side: Vector3 = Vector3(cos(yaw), 0, -sin(yaw)) * 0.43 * s
		kit.part(p + side + Vector3.UP * 1.05 + facing * 0.07, Vector3(0.84, 2.05, 0.04), Color(0.62, 0.64, 0.66), "metal", false, yaw)
	kit.part(p + Vector3.UP * 2.45 + facing * 0.08, Vector3(0.5, 0.14, 0.02), Color(0.9, 0.3, 0.1), "lit", false, yaw)
	kit.part(p + Vector3(cos(yaw), 0, -sin(yaw)) * 1.25 + Vector3.UP * 1.2 + facing * 0.07, Vector3(0.12, 0.25, 0.03), Color(0.85, 0.85, 0.8), "lit", false, yaw)
	kit.part(p + Vector3(cos(yaw), 0, -sin(yaw)) * 0.7 + facing * 0.3 + Vector3.UP * 0.005, Vector3(1.0, 0.01, 0.5), Color(0.8, 0.65, 0.1))


## 1층 로비: 접수대, 대기 의자 줄, 안내판, 화분, 자판기
func _lobby(r: Rect2, y: float) -> void:
	kit.floor_overlay(r, y, _mat["hosp_room_floor"])
	var c := r.get_center()
	# 접수대 (ㄱ자)
	kit.part(Vector3(r.end.x - 1.0, y + 0.55, c.y - 1.0), Vector3(0.8, 1.1, 4.0), Color(0.75, 0.75, 0.72), "trim", true)
	kit.part(Vector3(r.end.x - 1.0, y + 1.12, c.y - 1.0), Vector3(1.0, 0.05, 4.2), Color(0.45, 0.32, 0.22), "trim")
	kit.part(Vector3(r.end.x - 0.9, y + 1.35, c.y - 1.5), Vector3(0.05, 0.3, 0.45), Color(0.08, 0.08, 0.1), "glass")
	var s := Label3D.new()
	s.text = "접 수 · 수 납"
	s.font_size = 56
	s.pixel_size = 0.006
	s.position = Vector3(r.end.x - 0.15, y + 2.6, c.y - 1.0)
	s.rotation.y = -PI / 2.0
	s.visibility_range_end = 24.0
	region.add_child(s)
	kit.part(Vector3(r.end.x - 0.13, y + 2.6, c.y - 1.0), Vector3(0.04, 0.5, 2.6), Color(0.2, 0.4, 0.45))
	# 대기 의자 줄 (현관 쪽 비워 둠)
	for row in 3:
		for j in 5:
			var p := Vector3(r.position.x + 1.6 + j * 0.62, y, r.position.y + 2.0 + row * 1.6)
			kit._chair(p, PI, Color(0.3, 0.45, 0.6), rng.randf() < 0.08)
	# 안내판 + 화분 + 피 묻은 바닥
	kit.part(Vector3(c.x - 1.0, y + 1.0, r.position.y + 0.6), Vector3(1.2, 2.0, 0.08), Color(0.2, 0.35, 0.4))
	kit._plant(Vector3(r.position.x + 0.6, y, r.end.y - 0.8))
	kit._plant(Vector3(r.end.x - 0.6, y, r.end.y - 0.8))
	kit.decal(Vector3(c.x + 1.0, y + 0.01, c.y + 1.0), Vector3.UP, 2.4, "blood")


## 병원 복도: 벽 손잡이, 휠체어·들것, 대기 의자, 링거대, 표지판, 조명
func _hosp_corridor(core: Rect2, corr_z: float, corr_w: float, y: float, h: float, rooms: Array, base: bool) -> void:
	for side in [-1.0, 1.0]:
		var z: float = corr_z + side * (corr_w * 0.5 - 0.06)
		kit.part(Vector3(core.get_center().x, y + 0.9, z), Vector3(core.size.x - 0.4, 0.07, 0.07), Color(0.75, 0.75, 0.7) if not base else Color(0.35, 0.35, 0.33), "trim")
	for i in 9:
		var x := core.position.x + 3.0 + i * (core.size.x - 6.0) / 8.0
		kit.ceiling_light(Vector3(x, y + h - 0.28, corr_z), Color(0.75, 0.95, 0.85) if not base else Color(1.0, 0.75, 0.5), 0.6, 0.3)
		match i % 4:
			0:
				_wheelchair(Vector3(x, y, corr_z + corr_w * 0.5 - 0.5))
			1:
				_stretcher(Vector3(x, y, corr_z - corr_w * 0.5 + 0.5))
			2:
				for j in 3:
					kit._chair(Vector3(x - 0.6 + j * 0.6, y, corr_z - corr_w * 0.5 + 0.35), PI, Color(0.3, 0.45, 0.6))
			_:
				kit.part(Vector3(x, y + 0.9, corr_z + corr_w * 0.5 - 0.4), Vector3(0.03, 1.8, 0.03), Color(0.7, 0.7, 0.72), "metal")
				kit.part(Vector3(x, y + 1.65, corr_z + corr_w * 0.5 - 0.4), Vector3(0.12, 0.2, 0.06), Color(0.8, 0.9, 1.0), "glass")
				kit.part(Vector3(x, y + 0.03, corr_z + corr_w * 0.5 - 0.4), Vector3(0.5, 0.05, 0.5), Color(0.5, 0.5, 0.52), "metal")
		# 천장에 매달린 안내판
		if i % 3 == 1 and not base:
			kit.part(Vector3(x, y + h - 0.7, corr_z), Vector3(0.06, 0.35, 1.6), Color(0.15, 0.35, 0.4))
			var l := Label3D.new()
			l.text = ["← 응급실   수술실 →", "← 병동   검사실 →", "← 비상구   엘리베이터 →"][rng.randi() % 3]
			l.font_size = 40
			l.pixel_size = 0.005
			l.position = Vector3(x + 0.04, y + h - 0.7, corr_z)
			l.rotation.y = PI / 2.0
			l.visibility_range_end = 20.0
			region.add_child(l)
	# 지하: 천장 배관
	if base:
		for k in 3:
			kit.part(Vector3(core.get_center().x, y + h - 0.45 - k * 0.22, corr_z - 1.2 + k * 0.5), Vector3(core.size.x, 0.16, 0.16), [Color(0.45, 0.32, 0.22), Color(0.35, 0.4, 0.45), Color(0.6, 0.55, 0.2)][k], "metal")
	# 핏자국 끌린 자국
	kit.grime(Rect2(core.position.x, corr_z - corr_w * 0.5, core.size.x, corr_w), y + 0.005, h, 0.3, 0.4)


func _wheelchair(p: Vector3) -> void:
	kit.part(p + Vector3.UP * 0.5, Vector3(0.5, 0.06, 0.5), Color(0.2, 0.25, 0.35))
	kit.part(p + Vector3(0, 0.8, -0.24), Vector3(0.5, 0.55, 0.05), Color(0.2, 0.25, 0.35))
	for s in [-1.0, 1.0]:
		kit.part(p + Vector3(0.3 * s, 0.32, 0), Vector3(0.04, 0.62, 0.62), Color(0.6, 0.6, 0.62), "metal")


func _stretcher(p: Vector3) -> void:
	kit.part(p + Vector3.UP * 0.75, Vector3(2.0, 0.08, 0.65), Color(0.85, 0.88, 0.9), "trim")
	kit.part(p + Vector3.UP * 0.4, Vector3(1.8, 0.05, 0.05), Color(0.6, 0.6, 0.62), "metal")
	if rng.randf() < 0.4:
		kit.part(p + Vector3.UP * 0.9, Vector3(1.6, 0.2, 0.5), Color(0.92, 0.92, 0.94))  # 흰 천


## 앞마당 주차장: 주차선, 버려진 차·구급차, 가로등, 나무, 버스 정류장
func _parking_lot() -> void:
	var paint: Material = _mat["paint"]
	for row in 3:
		var z := 12.0 + row * 14.0
		for i in 18:
			var x := -45.0 + i * 5.2
			if absf(x) < 5.0:
				continue
			_box(Vector3(x, 0.01, z), Vector3(0.12, 0.02, 5.0), paint, false)
			if rng.randf() < 0.35:
				if rng.randf() < 0.2:
					_ambulance(Vector3(x + 2.6, 0, z), 0.0 if rng.randf() < 0.5 else PI)
				else:
					_car(Vector3(x + 2.6, 0, z), rng.randf_range(-0.15, 0.15))
	# 정문 앞 진입로 + 회차로 화단
	_box(Vector3(0, 0.02, 4.0), Vector3(10, 0.04, 8), _mat["sidewalk"])
	for x in [-14.0, 14.0]:
		_grass(Vector3(x, 0, 2.5), Vector2(8, 3))
	for p in [Vector3(-20, 0, 5), Vector3(20, 0, 5), Vector3(-40, 0, 30), Vector3(40, 0, 30), Vector3(0, 0, 45), Vector3(-25, 0, 52), Vector3(25, 0, 52), Vector3(-45, 0, -40), Vector3(45, 0, -40)]:
		_lamp(p)
	for i in 26:
		var t := rng.randf_range(-half + 4, half - 4)
		var p: Vector3 = [Vector3(t, 0, -half + 3), Vector3(-half + 3, 0, t), Vector3(half - 3, 0, t)][rng.randi() % 3]
		if BLD.grow(4.0).has_point(Vector2(p.x, p.z)):
			continue
		if rng.randf() < 0.5:
			_tree(p)
		else:
			_grass(p, Vector2(rng.randf_range(2.5, 4.5), rng.randf_range(2.5, 4.5)))
	# 버스 정류장
	var stop := _prop(Vector3(30, 0, 58), 0.0, Vector3(4.0, 0.5, 1.2))
	_part(stop, Vector3(0, 2.4, 0), _box_mesh(Vector3(4.2, 0.1, 1.6)), _mat["metal"])
	for x in [-1.9, 1.9]:
		_part(stop, Vector3(x, 1.2, -0.6), _box_mesh(Vector3(0.1, 2.4, 0.1)), _mat["metal"])
	_part(stop, Vector3(0, 1.2, -0.65), _box_mesh(Vector3(4.0, 2.2, 0.04)), _mat["glass"])
	_part(stop, Vector3(0, 0.45, 0), _box_mesh(Vector3(3.0, 0.08, 0.5)), _mat["crate"])
	generator_spots.append(Vector3(-25, 0.05, 19))
	generator_spots.append(Vector3(25, 0.05, 33))
	generator_spots.append(Vector3(0, 0.05, -48))
	# 건물 뒤 공터: 폐기물 컨테이너, 산소 탱크
	for i in 4:
		_dumpster(Vector3(-20 + i * 12, 0, -40), 0.0)
	for x in [24.0, 27.0]:
		var tank := _prop(Vector3(x, 0, -45), 0.0, Vector3(1.6, 4.0, 1.6))
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.8
		cyl.bottom_radius = 0.8
		cyl.height = 4.0
		_part(tank, Vector3(0, 2.0, 0), cyl, _mat["paint"])


func _ambulance(pos: Vector3, yaw: float) -> void:
	var body := _prop(pos, yaw, Vector3(2.2, 2.6, 5.4))
	var white := _flat_mat(Color(0.88, 0.88, 0.86), 0.6)
	var red := _flat_mat(Color(0.75, 0.1, 0.1), 0.6)
	_part(body, Vector3(0, 1.3, -0.5), _box_mesh(Vector3(2.2, 2.2, 3.8)), white)
	_part(body, Vector3(0, 0.9, 1.9), _box_mesh(Vector3(2.1, 1.4, 1.6)), white)
	_part(body, Vector3(0, 1.4, 2.4), _box_mesh(Vector3(1.9, 0.6, 0.6)), _mat["glass"])
	_part(body, Vector3(0, 1.0, -0.5), _box_mesh(Vector3(2.22, 0.25, 3.8)), red)
	var lightbar := StandardMaterial3D.new()
	lightbar.albedo_color = Color(0.5, 0.1, 0.1)
	lightbar.emission_enabled = true
	lightbar.emission = Color(1, 0.1, 0.1)
	lightbar.emission_energy_multiplier = 0.8 if rng.randf() < 0.5 else 0.0
	_part(body, Vector3(0, 2.5, 0.9), _box_mesh(Vector3(1.4, 0.15, 0.3)), lightbar)
	for wx in [-1.0, 1.0]:
		for wz in [-1.8, 1.6]:
			var wheel := CylinderMesh.new()
			wheel.top_radius = 0.38
			wheel.bottom_radius = 0.38
			wheel.height = 0.28
			_part(body, Vector3(wx, 0.38, wz), wheel, _mat["metal"]).rotation.z = PI / 2.0
