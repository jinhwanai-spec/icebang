class_name SchoolBuilder
extends LevelBuilder
## 세 번째 맵: 밤의 폐교
## - 2층짜리 본관(교실·교무실·보건실·과학실·음악실·도서실·화장실, 양 끝 계단)
## - 체육관(농구 코트·관람석·무대·체육 창고), 넓은 운동장(트랙·축구 골대·스탠드·놀이터·국기 게양대)
## - 학교 담장과 정문. 생존자는 정문에서 시작

const FH := 4.0
const MAIN := Rect2(-44.0, -66.0, 88.0, 28.0)
const GYM := Rect2(48.0, -66.0, 24.0, 26.0)


func build(target: Node3D, map_seed: int) -> void:
	region = target
	rng.seed = map_seed
	half = 74.0
	survivor_spawns = [Vector3(-2, 0.3, 64), Vector3(2, 0.3, 64), Vector3(-2, 0.3, 67), Vector3(2, 0.3, 67)]
	seeker_spawns = [Vector3(-39, 0.3, -52), Vector3(60, 0.3, -50), Vector3(-62, 0.3, -20)]
	floor_levels = [0.0, FH]
	debug_views = [[Vector3(1, 1.8, -39.5), Vector3(1, 1.5, -52)], [Vector3(-6, 1.8, -51.2), Vector3(-6.0, 2.4, -54)], [Vector3(64, 1.7, -42), Vector3(58, 2.5, -60)], [Vector3(-38, 5.7, -50), Vector3(-20, 5.0, -52)], [Vector3(0, 1.7, -18), Vector3(0, 4, -50)], [Vector3(28, 1.7, -22), Vector3(0, 4, -50)], [Vector3(40, 1.7, -30), Vector3(60, 4, -53)], [Vector3(-20, 1.7, 10), Vector3(0, 1, 30)], [Vector3(45, 1.7, 20), Vector3(55, 1, 12)]]
	_make_materials()
	_mat["dirt_field"] = _noise_mat(Color(0.42, 0.33, 0.24), 0.35, 1.0, 5.0)
	_mat["school_wall"] = _pattern_mat("plaster", Color(0.78, 0.74, 0.62), 3.0)
	_mat["school_in"] = _pattern_mat("plaster", Color(0.72, 0.74, 0.7), 3.0)
	_mat["hall_floor"] = _pattern_mat("tile", Color(0.55, 0.55, 0.5), 1.2)
	_mat["gym_floor"] = _pattern_mat("planks", Color(0.62, 0.45, 0.28), 1.6)
	_mat["grass_ground"] = _noise_mat(Color(0.16, 0.24, 0.12), 0.5, 1.0, 3.0)
	_mat["school_in"] = _pattern_mat("paint", Color(0.74, 0.71, 0.62), 2.5)
	_mat["wains"] = _pattern_mat("paint", Color(0.42, 0.55, 0.45), 2.5)
	_mat["hall_floor"] = _pattern_mat("terrazzo", Color(0.58, 0.57, 0.53), 1.5)
	_mat["ceil"] = _pattern_mat("ceiling", Color(0.66, 0.66, 0.63), 1.2)
	_mat["wood"] = _pattern_mat("woodfloor", Color(0.55, 0.4, 0.26), 2.0)
	_mat["lino"] = _pattern_mat("lino", Color(0.5, 0.5, 0.48), 1.2)
	_mat["wtile_floor"] = _pattern_mat("wtile", Color(0.6, 0.62, 0.62), 0.6)
	_mat["gym_pad"] = _pattern_mat("paint", Color(0.2, 0.32, 0.6), 2.0)
	kit = BuildingKit.new(self)
	_mark_indestructible(_box(Vector3(0, -0.5, 0), Vector3(half * 2, 1, half * 2), _mat["grass_ground"]))
	_school_fence()
	_playground()
	_main_building()
	_gym()
	_yard_props()
	_flush_batches()


# ================================================================ 담장·정문

func _school_fence() -> void:
	var h := 2.6
	var brick: Material = _mat["wall"]
	for s in [[Vector3(0, h / 2, -half), Vector3(half * 2 + 1, h, 0.6)], [Vector3(-half, h / 2, 0), Vector3(0.6, h, half * 2 + 1)], [Vector3(half, h / 2, 0), Vector3(0.6, h, half * 2 + 1)]]:
		_mark_indestructible(_box(s[0], s[1], brick))
	# 정문이 있는 남쪽 담장 (가운데 6m 열림 → 바깥은 막힌 길, 문 기둥)
	for x in [-1.0, 1.0]:
		var w := half - 3.0
		_mark_indestructible(_box(Vector3(x * (3.0 + w / 2.0), h / 2, half), Vector3(w, h, 0.6), brick))
		_box(Vector3(x * 3.3, 1.7, half), Vector3(0.9, 3.4, 0.9), _mat["concrete"])
		_box(Vector3(x * 3.3, 3.5, half), Vector3(1.1, 0.25, 1.1), _mat["concrete"], false)
	_mark_indestructible(_box(Vector3(0, h / 2, half + 4.0), Vector3(8, h, 0.6), brick))  # 정문 바깥 (나갈 수 없음)
	# 녹슨 철문 반쯤 열림
	_box(Vector3(-1.5, 1.1, half + 0.2), Vector3(3.0, 2.2, 0.08), _mat["metal"], true, 0.6)
	# 담장 따라 나무와 풀숲 (숨을 곳)
	for i in 34:
		var t := rng.randf_range(-half + 4, half - 4)
		var p: Vector3 = [Vector3(t, 0, -half + 3), Vector3(-half + 3, 0, t), Vector3(half - 3, 0, t), Vector3(t, 0, half - 3)][rng.randi() % 4]
		if p.distance_to(Vector3(0, 0, half)) < 10.0 or _in_building(p, 3.0):
			continue
		if rng.randf() < 0.55:
			_tree(p)
		else:
			_grass(p, Vector2(rng.randf_range(2.5, 4.5), rng.randf_range(2.5, 4.5)))


func _in_building(p: Vector3, margin: float) -> bool:
	return MAIN.grow(margin).has_point(Vector2(p.x, p.z)) or GYM.grow(margin).has_point(Vector2(p.x, p.z))


# ================================================================ 운동장

func _playground() -> void:
	var field := Rect2(-46, -26, 80, 70)
	_box(Vector3(field.get_center().x, 0.02, field.get_center().y), Vector3(field.size.x, 0.04, field.size.y), _mat["dirt_field"])
	# 트랙: 직선 2개 + 반원 2개 (흰 선 여러 줄)
	var line := _flat_mat(Color(0.85, 0.85, 0.8), 0.9)
	var cx := field.get_center().x
	var cz := field.get_center().y
	for lane in 3:
		var rx := 14.0 + lane * 1.4
		var straight := 22.0
		for s in [-1.0, 1.0]:
			_box(Vector3(cx + s * rx, 0.045, cz), Vector3(0.12, 0.01, straight), line, false)
		for end in [-1.0, 1.0]:
			for k in 24:
				var a0 := PI * k / 24.0
				var a1 := PI * (k + 1) / 24.0
				var p0 := Vector3(cx + cos(a0) * rx, 0.045, cz + end * (straight * 0.5 + sin(a0) * rx))
				var p1 := Vector3(cx + cos(a1) * rx, 0.045, cz + end * (straight * 0.5 + sin(a1) * rx))
				var mid := (p0 + p1) * 0.5
				_box(mid, Vector3(0.12, 0.01, p0.distance_to(p1) + 0.05), line, false, atan2(p1.x - p0.x, p1.z - p0.z))
	# 축구 골대 (양 끝)
	for end in [-1.0, 1.0]:
		var gz: float = cz + end * 31.0
		for s in [-1.0, 1.0]:
			_box(Vector3(cx + s * 3.6, 1.2, gz), Vector3(0.12, 2.4, 0.12), _mat["paint"])
		_box(Vector3(cx, 2.4, gz), Vector3(7.3, 0.12, 0.12), _mat["paint"], false)
		var net := StandardMaterial3D.new()
		net.albedo_color = Color(0.9, 0.9, 0.9, 0.16)
		net.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		net.cull_mode = BaseMaterial3D.CULL_DISABLED
		# 뒤쪽 틀 (기둥·윗막대·옆 윗막대) + 뒤·옆·위 그물 (예전엔 그물판 한 장만 공중에 떠 있었음)
		var bz: float = gz + end * 1.2
		for s in [-1.0, 1.0]:
			_box(Vector3(cx + s * 3.6, 1.2, bz), Vector3(0.08, 2.4, 0.08), _mat["paint"], false)
			_box(Vector3(cx + s * 3.6, 2.4, (gz + bz) * 0.5), Vector3(0.08, 0.08, 1.2), _mat["paint"], false)
			_box(Vector3(cx + s * 3.6, 0.04, (gz + bz) * 0.5), Vector3(0.06, 0.06, 1.2), _mat["paint"], false)
			_box(Vector3(cx + s * 3.6, 1.2, (gz + bz) * 0.5), Vector3(0.02, 2.3, 1.2), net, false)
		_box(Vector3(cx, 2.4, bz), Vector3(7.3, 0.08, 0.08), _mat["paint"], false)
		_box(Vector3(cx, 0.04, bz), Vector3(7.2, 0.06, 0.06), _mat["paint"], false)
		_box(Vector3(cx, 1.2, bz), Vector3(7.2, 2.3, 0.02), net, false)
		_box(Vector3(cx, 2.4, (gz + bz) * 0.5), Vector3(7.2, 0.02, 1.2), net, false)
	# 스탠드 (서쪽, 계단식 콘크리트)
	for k in 4:
		_box(Vector3(field.position.x - 1.5 - k * 0.9, 0.25 + k * 0.45, cz), Vector3(0.9, 0.5 + k * 0.9, 40.0), _mat["concrete"])
	# 국기 게양대 (본관 앞)
	_box(Vector3(-12, 4.5, -33), Vector3(0.12, 9.0, 0.12), _mat["metal"])
	_box(Vector3(-12, 0.25, -33), Vector3(1.2, 0.5, 1.2), _mat["concrete"])
	var flag := _flat_mat(Color(0.85, 0.85, 0.82), 0.9)
	flag.cull_mode = BaseMaterial3D.CULL_DISABLED
	_box(Vector3(-11.3, 8.3, -33), Vector3(1.4, 0.9, 0.02), flag, false)
	# 조회대 (본관 앞 단상)
	_box(Vector3(12, 0.5, -32), Vector3(6, 1.0, 3), _mat["concrete"])
	generator_spots.append(Vector3(cx, 0.05, cz))
	generator_spots.append(Vector3(cx - 15, 0.05, cz + 24))
	generator_spots.append(Vector3(cx + 15, 0.05, cz - 24))


# ================================================================ 본관 (2층)

func _main_building() -> void:
	var r := MAIN
	var y0 := 0.05
	var inner := r.grow(-BuildingKit.WALL_T)
	var corr_z := r.get_center().y
	corridor_probe = Vector3(inner.position.x + 3.5, 0, corr_z)
	var corr_w := 4.0
	var bay := 7.5  # 양 끝 계단실 칸 길이
	# 계단: 양 끝 칸. 북쪽에서 복도 쪽(+z)으로 올라감 (폭 2.4m)
	var run := 7.0
	var zs := corr_z - corr_w * 0.5 - 1.4 - run
	var stair_w := Rect2(inner.position.x + 0.6, zs, 2.4, run)
	var stair_e := Rect2(inner.end.x - 3.0, zs, 2.4, run)
	var trim := Color(0.55, 0.5, 0.42)
	# 외벽 (안쪽 면에는 실내 마감)
	var sides := [
		[Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0, r.position.y), Vector3(0, 0, -1)],
		[Vector3(r.end.x, 0, r.position.y), Vector3(r.end.x, 0, r.end.y), Vector3(1, 0, 0)],
		[Vector3(r.end.x, 0, r.end.y), Vector3(r.position.x, 0, r.end.y), Vector3(0, 0, 1)],
		[Vector3(r.position.x, 0, r.end.y), Vector3(r.position.x, 0, r.position.y), Vector3(-1, 0, 0)],
	]
	_school_finish()
	for si in 4:
		var a: Vector3 = sides[si][0]
		var b: Vector3 = sides[si][1]
		var n: Vector3 = sides[si][2]
		var L := Vector2(b.x - a.x, b.z - a.z).length()
		var dir := (b - a).normalized()
		var in_side := -1 if dir.cross(Vector3.UP).dot(n) > 0.0 else 1
		for k in 2:
			var y := y0 + k * FH
			var ops := []
			var doors := []
			if k == 0:
				if si == 2:
					doors = [L * 0.5 - 1.0, L * 0.5 + 1.0]  # 중앙 현관 (두 짝)
				elif si == 1 or si == 3:
					doors = [L - (corr_z - r.position.y) if si == 3 else (corr_z - r.position.y)]  # 복도 끝 문
			for du in doors:
				ops.append([du - 0.9, du + 0.9, 0.0, BuildingKit.DOOR_H])
				var dc: Vector3 = a + dir * du
				dc.y = y
				kit._door_frame(dc, dir, trim.darkened(0.4))
				_exit_sign(dc + Vector3.UP * (BuildingKit.DOOR_H + 0.35) - n * 0.2, -n)
				if rng.randf() < 0.5:
					props.append(["door", dc, atan2(dir.z, -dir.x) + PI, 1.7, "school"])
			var count := int((L - 1.0) / 2.4)
			var gap := (L - 1.0) / count
			for i in count:
				var u := 0.5 + gap * (i + 0.5)
				var near_door := false
				for du in doors:
					if absf(u - du) < 1.6:
						near_door = true
				if near_door:
					continue
				ops.append([u - 0.8, u + 0.8, 0.95, 2.95])
				var gc := a + dir * u
				gc.y = y + 1.95
				var lit := rng.randf() < 0.05
				kit.block(gc, Vector3(1.6, 2.0, 0.04), _deco_mat("lit" if lit else "glass"), "b_" + ("lit" if lit else "glass"), true, Basis(dir, Vector3.UP, dir.cross(Vector3.UP).normalized()), false, Color(0.9, 0.85, 0.6, 0.5) if lit else Color(0.1, 0.13, 0.2))
				var fn := gc + n * (BuildingKit.WALL_T * 0.5)
				var tt := Vector3.UP.cross(n)
				_bx("trim", fn + n * 0.03, tt, n, Vector3(0.06, 2.0, 0.05), Color(0.2, 0.2, 0.22))
				_bx("trim", fn + n * 0.03 + Vector3.UP * 0.35, tt, n, Vector3(1.6, 0.05, 0.05), Color(0.2, 0.2, 0.22))
				_bx("trim", fn + Vector3.UP * -1.05 + n * 0.08, tt, n, Vector3(1.8, 0.08, 0.2), trim)
				# 안쪽 창턱
				var fi := gc - n * (BuildingKit.WALL_T * 0.5)
				_bx("trim", fi + Vector3.UP * -1.0 - n * 0.08, tt, -n, Vector3(1.7, 0.05, 0.18), Color(0.75, 0.72, 0.65))
				# 안쪽 창틀 (가운데 세로살 + 가로살)
				_bx("trim", fi - n * 0.03, tt, -n, Vector3(0.06, 2.0, 0.05), Color(0.55, 0.55, 0.52))
				_bx("trim", fi - n * 0.03 + Vector3.UP * 0.35, tt, -n, Vector3(1.6, 0.05, 0.05), Color(0.55, 0.55, 0.52))
				if rng.randf() < 0.12:
					_moon_shaft(gc, -n)
				# 바깥벽 빗물 자국 (창턱 아래로 흘러내린 얼룩)
				if rng.randf() < 0.35:
					kit.decal(fn + n * 0.01 + Vector3.UP * -1.7, n, rng.randf_range(0.9, 1.5), "stain", PI * 0.5)
			kit.wall(a, b, y, FH, _mat["school_wall"], "w_school", ops, BuildingKit.WALL_T, in_side)
		# 층 띠·처마
		var face := (a + b) * 0.5 + n * (BuildingKit.WALL_T * 0.5)
		var tt := Vector3.UP.cross(n)
		_bx("trim", face + n * 0.08 + Vector3.UP * (y0 + FH), tt, n, Vector3(L, 0.25, 0.18), trim)
		_bx("trim", face + n * 0.14 + Vector3.UP * (y0 + FH * 2 + 0.2), tt, n, Vector3(L + 0.4, 0.45, 0.3), trim.darkened(0.1))
		_bx("trim", face + n * 0.06 + Vector3.UP * (y0 + 0.3), tt, n, Vector3(L, 0.6, 0.12), Color(0.35, 0.33, 0.3))
	# 현관 차양 + 학교 이름·시계
	_bx("trim", Vector3(0, y0 + 3.4, r.end.y + 1.8), Vector3.RIGHT, Vector3.BACK, Vector3(7.0, 0.25, 3.6), Color(0.5, 0.47, 0.42))
	for x in [-3.2, 3.2]:
		kit.part(Vector3(x, y0 + 1.7, r.end.y + 3.4), Vector3(0.3, 3.4, 0.3), Color(0.55, 0.52, 0.47), "trim", true)
	kit.part(Vector3(0, y0 + 6.6, r.end.y + 0.2), Vector3(1.2, 1.2, 0.15), Color(0.95, 0.95, 0.9))
	kit.part(Vector3(0, y0 + 6.7, r.end.y + 0.29), Vector3(0.05, 0.45, 0.02), Color(0.1, 0.1, 0.1))
	kit.part(Vector3(0.12, y0 + 6.6, r.end.y + 0.29), Vector3(0.3, 0.05, 0.02), Color(0.1, 0.1, 0.1))
	# 바닥·천장·지붕
	kit.slab(inner, y0 + 0.06, _mat["hall_floor"], "w_hall", [], false, 0.06)
	kit.slab(inner, y0 + FH, _mat["hall_floor"], "w_hall", [stair_w, stair_e])
	kit.slab(r.grow(0.3), y0 + FH * 2 + 0.2, _mat["concrete"], "w_concrete", [], true, 0.3)
	kit.ceiling(inner, y0 + FH - BuildingKit.FLOOR_T, _mat["ceil"], [stair_w, stair_e], y0 + 0.12)
	kit.ceiling(inner, y0 + FH * 2 - 0.1, _mat["ceil"], [], y0 + FH + 0.01)
	for st in [stair_w, stair_e]:
		kit.stairs(st, false, true, y0, FH, Color(0.55, 0.53, 0.5))
		kit.hole_rail(st, y0 + FH, "z+")
		# 계단 옆 벽 (난간 대신 막힌 벽 + 손잡이)
		var sx: float = st.end.x + 0.15 if st.position.x < 0.0 else st.position.x - 0.15
		kit.wall(Vector3(sx, 0, st.position.y), Vector3(sx, 0, st.end.y), y0, 1.0, _mat["school_in"], "w_inner", [], 0.12, 2)
	# 층별 방 (복도 양쪽)
	var core := Rect2(inner.position.x + bay, inner.position.y, inner.size.x - bay * 2.0, inner.size.y)
	var floors := [
		[[12, "teachers", "교무실"], [8, "nurse", "보건실"], [7, "toilet", "화장실"], [11, "classroom", "1-1"], [11, "classroom", "1-2"], [12, "lab", "과학실"], [12, "classroom", "1-3"]],
		[[10, "office", "행정실"], [12, "computer", "컴퓨터실"], [11.5, "music", "음악실"], [7.5, "", ""], [11, "classroom", "1-4"], [11, "classroom", "1-5"], [10, "broadcast", "방송실"]],
		[[11, "classroom", "2-1"], [11, "classroom", "2-2"], [7, "toilet", "화장실"], [11, "classroom", "2-3"], [12, "art", "미술실"], [11, "classroom", "2-4"], [10, "office", "교장실"]],
		[[11, "classroom", "2-5"], [14, "library", "도서실"], [11, "classroom", "3-1"], [11, "classroom", "3-2"], [10, "teachers", "연구실"], [12, "classroom", "3-3"]],
	]
	for k in 2:
		var y := y0 + k * FH
		var rooms: Array = kit.wing(core, y, FH, true, corr_w, floors[k * 2], floors[k * 2 + 1], _mat["school_in"], [], 0.45)
		for rm in rooms:
			var rr: Rect2 = rm["rect"]
			var kind: String = rm["kind"]
			kit.floor_overlay(rr, y + (0.06 if k == 0 else 0.0), _mat["wood"] if kind in ["classroom", "music", "library", "teachers", "art"] else (_mat["wtile_floor"] if kind == "toilet" else _mat["lino"]))
			var keep := kind in ["classroom", "library", "teachers", "music", "art"] and rng.randf() < 0.4
			kit.furnish_room(rm, y, keep)
			debug_rooms.append([rm, y])
			kit.grime(rr, y + (0.07 if k == 0 else 0.01), FH, 0.8, 0.12)
			if keep:
				generator_spots.append(Vector3(rr.get_center().x, y, rr.get_center().y))  # 가운데를 비워 둔 방에만 봉인석
			for li in maxi(1, int(rr.size.x / 6.0)):
				var lx := rr.position.x + (li + 0.5) * rr.size.x / maxi(1, int(rr.size.x / 6.0))
				kit.ceiling_light(Vector3(lx, y + FH - 0.25, rr.get_center().y), Color(0.85, 0.95, 1.0), 0.75, 0.3)
			var dn := Vector3(0, 0, 1) if rr.get_center().y < corr_z else Vector3(0, 0, -1)
			var da: Vector3 = rm["door_at"]
		# 복도 끝 칸과 계단실 사이 벽 (복도 쪽은 열림)
		for xw in [core.position.x, core.end.x]:
			for side in [-1.0, 1.0]:
				var z0: float = corr_z + side * corr_w * 0.5
				var z1 := inner.position.y if side < 0 else inner.end.y
				kit.wall(Vector3(xw, 0, z0), Vector3(xw, 0, z1), y, FH - 0.2, _mat["school_in"], "w_inner", [[1.0, 2.5, 0.0, BuildingKit.DOOR_H]] if side > 0 else [], 0.18)
		var fy := y + (0.07 if k == 0 else 0.01)
		_corridor_dressing(core, inner, corr_z, corr_w, y, fy, rooms)
		if k == 0:
			_entrance_hall(Rect2(core.position.x + 33.5, corr_z + corr_w * 0.5, 7.5, inner.end.y - corr_z - corr_w * 0.5), fy)
		for sx in [-1.0, 1.0]:
			var wx: float = core.position.x - 0.1 if sx < 0 else core.end.x + 0.1
			_floor_sign(Vector3(wx, y + 2.5, corr_z - corr_w * 0.5 - 2.2), Vector3(sx, 0, 0), "%dF" % (k + 1))
		# 끝 칸(계단실)에 사물함 하나씩 + 청소도구
		props.append(["locker", Vector3(inner.end.x - 0.5, y, corr_z + corr_w * 0.5 + 2.2), -PI / 2.0])
		props.append(["locker", Vector3(inner.position.x + 0.5, y, corr_z + corr_w * 0.5 + 2.2), PI / 2.0])
		for ex in [inner.position.x, inner.end.x - bay]:
			kit.grime(Rect2(ex, corr_z + corr_w * 0.5, bay, inner.end.y - corr_z - corr_w * 0.5), fy, FH, 0.6, 0.1, [0, 1, 3])
	kit.wainscot_mat = null
	kit.lining_mat = null
	kit.corridor_windows = false
	# 옥상: 난간·물탱크·실외기 + 학교 이름 글자 (정면 2층 위)
	_rooftop(r, y0 + FH * 2 + 0.2)
	_rooftop(r.grow(-6.0), y0 + FH * 2 + 0.2)
	# 정면 큰 시계 (학교 이름 대신)
	var ck := Vector3(-14, y0 + FH * 2 - 0.55, r.end.y + 0.12)
	kit.part(ck, Vector3(1.5, 1.5, 0.08), Color(0.85, 0.82, 0.7), "trim")
	kit.part(ck + Vector3(0, 0, 0.05), Vector3(1.25, 1.25, 0.02), Color(0.92, 0.9, 0.84), "lit")
	kit.part(ck + Vector3(0, 0.22, 0.07), Vector3(0.06, 0.45, 0.02), Color(0.08, 0.08, 0.08))
	kit.part(ck + Vector3(0.15, -0.1, 0.07), Vector3(0.05, 0.35, 0.02), Color(0.08, 0.08, 0.08), "trim", false, 1.0)


## 중앙 현관: 양옆 신발장, 거울, 교훈 액자, 우산꽂이, 발판
func _entrance_hall(r: Rect2, y: float) -> void:
	kit.floor_overlay(r, y - 0.005, _mat["hall_floor"])
	for s in [-1.0, 1.0]:
		var x: float = r.position.x + 0.35 if s < 0 else r.end.x - 0.35
		for i in 5:
			var z := r.position.y + 1.4 + i * 1.6
			if z > r.end.y - 2.2:
				break
			kit.part(Vector3(x, y + 0.9, z), Vector3(0.6, 1.8, 1.5), Color(0.45, 0.33, 0.22), "trim", true)
			for row in 5:
				kit.part(Vector3(x - s * 0.31, y + 0.25 + row * 0.33, z), Vector3(0.02, 0.02, 1.45), Color(0.3, 0.22, 0.15), "trim")
				if rng.randf() < 0.35:
					kit.part(Vector3(x - s * 0.15, y + 0.12 + row * 0.33, z + rng.randf_range(-0.5, 0.5)), Vector3(0.25, 0.09, 0.1), [Color(0.9, 0.9, 0.9), Color(0.2, 0.2, 0.25), Color(0.8, 0.2, 0.2)][rng.randi() % 3], "trim")
	# 거울 + 교훈 액자 (복도 쪽 벽 위)
	kit.part(Vector3(r.get_center().x, y + 2.9, r.position.y + 0.1), Vector3(3.0, 0.9, 0.05), Color(0.45, 0.33, 0.22), "trim")
	# 액자 속 그림 (하늘·언덕·해)
	kit.part(Vector3(r.get_center().x, y + 2.95, r.position.y + 0.13), Vector3(2.7, 0.4, 0.01), Color(0.55, 0.7, 0.8))
	kit.part(Vector3(r.get_center().x, y + 2.65, r.position.y + 0.13), Vector3(2.7, 0.3, 0.01), Color(0.4, 0.55, 0.3))
	kit.part(Vector3(r.get_center().x + 0.8, y + 3.0, r.position.y + 0.14), Vector3(0.25, 0.25, 0.01), Color(0.95, 0.8, 0.3))
	kit.part(Vector3(r.get_center().x, y + 1.5, r.end.y - 0.4), Vector3(0.9, 0.04, 0.6), Color(0.25, 0.2, 0.15), "trim")
	kit.part(Vector3(r.end.x - 0.6, y + 0.35, r.end.y - 0.8), Vector3(0.35, 0.7, 0.35), Color(0.3, 0.3, 0.32), "metal", true)
	kit.part(Vector3(r.get_center().x, y + 0.01, r.end.y - 1.2), Vector3(2.4, 0.02, 1.2), Color(0.15, 0.25, 0.18), "trim")
	kit.grime(r, y + 0.005, FH, 0.6, 0.15, [0, 1, 3])


## 학교 실내 마감: 아래쪽 연녹색 페인트 판 + 나무 몰딩, 위는 크림색 벽
func _school_finish() -> void:
	kit.wainscot_mat = _mat["wains"]
	kit.lining_mat = _mat["school_in"]
	kit.wainscot_h = 1.2
	kit.room_h = FH
	kit.corridor_windows = true
	kit.door_style = "school"
	kit.trim_col = Color(0.36, 0.27, 0.18)


## 비상구 표시등 (초록 불빛)
func _exit_sign(p: Vector3, facing: Vector3) -> void:
	var yaw := atan2(facing.x, facing.z)
	kit.part(p, Vector3(0.6, 0.22, 0.06), Color(0.1, 0.9, 0.35), "lit", false, yaw)
	# 글자 대신 달리는 사람 + 문 그림
	var rt := Vector3(cos(yaw), 0, -sin(yaw))
	kit.part(p + facing * 0.04 + rt * 0.17, Vector3(0.12, 0.17, 0.01), Color(0.95, 1.0, 0.95), "lit", false, yaw)
	kit.part(p + facing * 0.04 - rt * 0.05 + Vector3.UP * 0.05, Vector3(0.04, 0.04, 0.01), Color(0.95, 1.0, 0.95), "lit", false, yaw)
	kit.part(p + facing * 0.04 - rt * 0.06 - Vector3.UP * 0.02, Vector3(0.04, 0.09, 0.01), Color(0.95, 1.0, 0.95), "lit", false, yaw + 0.4)
	kit.part(p + facing * 0.04 - rt * 0.16, Vector3(0.1, 0.02, 0.01), Color(0.95, 1.0, 0.95), "lit", false, yaw)
	# 초록 불빛이 문 둘레 벽을 은은하게 물들임 (어두워도 출구가 보이게)
	var gl := OmniLight3D.new()
	gl.light_color = Color(0.2, 1.0, 0.45)
	gl.light_energy = 0.6
	gl.omni_range = 3.5
	gl.light_volumetric_fog_energy = 1.2
	gl.position = p + facing * 0.3
	region.add_child(gl)
	LightFX.practical(gl, 30.0, false)


## 복도 꾸미기: 신발장·사물함 줄, 게시판, 소화전, 손 씻는 곳, 쓰레기통, 얼룩
func _corridor_dressing(core: Rect2, inner: Rect2, corr_z: float, corr_w: float, y: float, fy: float, rooms: Array) -> void:
	var doors := []
	for rm in rooms:
		doors.append(rm["door_at"])
	var free := func(x: float, z_side: float, half_w: float) -> bool:
		for d in doors:
			var dv: Vector3 = d
			if signf(dv.z - corr_z) == signf(z_side) and absf(dv.x - x) < half_w + 1.1:
				return false
		return true
	# 남쪽 벽: 개인 사물함 줄 (장식), 북쪽 벽: 게시판·소화전
	var x := core.position.x + 1.5
	while x < core.end.x - 1.5:
		var zs := corr_z + corr_w * 0.5 - 0.22
		if free.call(x, 1.0, 1.4):
			for i in 4:
				var lx: float = x - 0.9 + i * 0.6
				kit.part(Vector3(lx, y + 0.9, zs), Vector3(0.58, 1.8, 0.4), Color(0.36, 0.48, 0.62).darkened(rng.randf() * 0.15), "metal", true)
				kit.part(Vector3(lx, y + 1.55, zs - 0.205), Vector3(0.36, 0.1, 0.01), Color(0.08, 0.08, 0.08))
				if rng.randf() < 0.15:
					kit.part(Vector3(lx - 0.2, y + 0.95, zs - 0.45), Vector3(0.02, 1.7, 0.56), Color(0.36, 0.48, 0.62), "metal", false, 0.6)
		x += 3.2
	x = core.position.x + 2.5
	var i2 := 0
	while x < core.end.x - 2.0:
		var zn := corr_z - corr_w * 0.5 + 0.03
		if free.call(x, -1.0, 1.0):
			match i2 % 3:
				0:  # 게시판 + 종이
					kit.part(Vector3(x, y + 1.6, zn + 0.02), Vector3(1.8, 1.0, 0.04), Color(0.55, 0.4, 0.25))
					kit.part(Vector3(x, y + 1.6, zn + 0.045), Vector3(1.65, 0.85, 0.01), Color(0.25, 0.35, 0.28))
					for j in 4:
						kit.decal(Vector3(x - 0.6 + j * 0.4 + rng.randf_range(-0.05, 0.05), y + 1.6 + rng.randf_range(-0.2, 0.2), zn + 0.05), Vector3.BACK, 0.45, "papers")
				1:  # 소화전함
					kit.part(Vector3(x, y + 1.2, zn + 0.1), Vector3(0.8, 1.2, 0.2), Color(0.75, 0.1, 0.08), "metal", true)
					kit.part(Vector3(x, y + 1.2, zn + 0.205), Vector3(0.5, 0.7, 0.01), Color(0.1, 0.12, 0.14), "glass")
				_:  # 손 씻는 곳
					kit.part(Vector3(x, y + 0.8, zn + 0.25), Vector3(1.6, 0.15, 0.5), Color(0.82, 0.82, 0.8), "trim", true)
					for j in 3:
						kit.part(Vector3(x - 0.5 + j * 0.5, y + 1.0, zn + 0.08), Vector3(0.05, 0.25, 0.12), Color(0.7, 0.7, 0.72), "metal")
					kit.part(Vector3(x, y + 1.5, zn + 0.02), Vector3(1.4, 0.6, 0.02), Color(0.55, 0.6, 0.65), "glass")
			i2 += 1
		x += 6.0
	# 표어·포스터 (복도 북쪽 벽 높은 곳)
	for i in 5:
		var px := core.position.x + 6.0 + i * (core.size.x - 12.0) / 4.0
		var zn := corr_z - corr_w * 0.5 + 0.03
		var col: Color = [Color(0.85, 0.75, 0.3), Color(0.4, 0.65, 0.85), Color(0.85, 0.45, 0.4), Color(0.55, 0.75, 0.45)][i % 4]
		kit.part(Vector3(px, y + 2.75, zn + 0.01), Vector3(2.2, 0.45, 0.02), col)
		# 글자 대신 아이 그림 같은 도형 몇 개
		for d in 3:
			var dc: Color = [Color(0.95, 0.95, 0.9), Color(0.2, 0.2, 0.25), Color(0.9, 0.3, 0.25), Color(0.25, 0.45, 0.8)][(i + d + int(y)) % 4]
			kit.part(Vector3(px - 0.7 + d * 0.7, y + 2.75 + (0.05 if d % 2 == 0 else -0.05), zn + 0.03), Vector3(0.28 + 0.08 * ((i + d) % 2), 0.28, 0.01), dc, "trim", false, 0.0)
	# 복도 바닥 얼룩·종이, 천장 조명 (일부 깜빡임)
	kit.grime(Rect2(core.position.x, corr_z - corr_w * 0.5, core.size.x, corr_w), fy, FH, 0.35, 0.08, [2, 3])
	for i in 9:
		var lx := core.position.x + 3.0 + i * (core.size.x - 6.0) / 8.0
		kit.ceiling_light(Vector3(lx, y + FH - 0.25, corr_z), Color(0.8, 0.95, 1.0), 0.6, 0.3)
	# 벽 쪽에 쓰러진 의자 몇 개 (복도 가운데는 비워 둠, 문 앞도 피함)
	for i in 3:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var cx := rng.randf_range(core.position.x + 3, core.end.x - 3)
		if not free.call(cx, side, 0.8):
			continue
		var cp := Vector3(cx, fy, corr_z + side * (corr_w * 0.5 - (0.75 if side > 0 else 0.45)))
		kit._chair(cp, rng.randf() * TAU, Color(0.55, 0.45, 0.32), true)


# ================================================================ 체육관

func _gym() -> void:
	var r := GYM
	var y0 := 0.05
	var h := 8.0
	var sides := [
		[Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0, r.position.y)],
		[Vector3(r.end.x, 0, r.position.y), Vector3(r.end.x, 0, r.end.y)],
		[Vector3(r.end.x, 0, r.end.y), Vector3(r.position.x, 0, r.end.y)],
		[Vector3(r.position.x, 0, r.end.y), Vector3(r.position.x, 0, r.position.y)],
	]
	for si in 4:
		var a: Vector3 = sides[si][0]
		var b: Vector3 = sides[si][1]
		var L := Vector2(b.x - a.x, b.z - a.z).length()
		var dir := (b - a).normalized()
		var ops := []
		if si == 2 or si == 3:
			var du := L * 0.5
			ops.append([du - 1.5, du + 1.5, 0.0, 2.8])
			var dc := a + dir * du
			# 문틀은 3m 출입구 크기에 맞춤 (좁은 기본 문틀이 넓은 구멍 안에 따로 서 있던 것)
			var fyaw := atan2(-dir.z, dir.x)
			for fs in [-1.0, 1.0]:
				kit.part(dc + dir * (1.5 - 0.05) * fs + Vector3.UP * (y0 + 1.4), Vector3(0.1, 2.8, 0.45), Color(0.3, 0.3, 0.32), "trim", false, fyaw)
			kit.part(dc + Vector3.UP * (y0 + 2.85), Vector3(3.1, 0.12, 0.45), Color(0.3, 0.3, 0.32), "trim", false, fyaw)
		for i in int(L / 4.0):
			var u := 2.0 + i * 4.0
			if absf(u - L * 0.5) < 2.5 and (si == 2 or si == 3):
				continue
			ops.append([u - 1.2, u + 1.2, 5.2, 7.2])
			var gc := a + dir * u
			gc.y = y0 + 6.2
			kit.block(gc, Vector3(2.4, 2.0, 0.04), _deco_mat("glass"), "b_glass", true, Basis(dir, Vector3.UP, dir.cross(Vector3.UP).normalized()), false, Color(0.08, 0.1, 0.12))
		# 체육관 안쪽: 파란 벽 보호대(매트) + 흰 벽
		kit.wainscot_mat = _mat["gym_pad"]
		kit.wainscot_h = 1.9
		kit.trim_col = Color(0.2, 0.22, 0.3)
		kit.lining_mat = _mat["school_in"]
		var gn := Vector3(0, 0, -1) if si == 0 else (Vector3(1, 0, 0) if si == 1 else (Vector3(0, 0, 1) if si == 2 else Vector3(-1, 0, 0)))
		var in_side := -1 if dir.cross(Vector3.UP).dot(gn) > 0.0 else 1
		kit.wall(a, b, y0, h, _mat["concrete"], "w_gym", ops, 0.35, in_side)
		kit.wainscot_mat = null
		kit.lining_mat = null
	kit.slab(r.grow(-0.2), y0 + 0.06, _mat["gym_floor"], "w_gymfloor", [], false, 0.06)
	kit.slab(r.grow(0.3), y0 + h + 0.3, _mat["roof"] if _mat.has("roof") else _mat["concrete"], "w_roof", [], true, 0.4)
	# 아치형 지붕 느낌 (보이기만)
	for i in 6:
		_bx("trim", Vector3(r.get_center().x, y0 + h + 0.6 + sin(PI * (i + 0.5) / 6.0) * 1.5, r.position.y + (i + 0.5) * r.size.y / 6.0), Vector3.RIGHT, Vector3.BACK, Vector3(r.size.x + 0.6, 0.3, r.size.y / 6.0 + 0.1), Color(0.35, 0.42, 0.5))
	var c := r.get_center()
	# 코트 선 + 농구 골대
	var line := Color(0.95, 0.95, 0.9)
	kit.part(Vector3(c.x, y0 + 0.07, c.y), Vector3(0.08, 0.01, 18.0), line)
	kit.part(Vector3(c.x, y0 + 0.07, c.y), Vector3(18.0, 0.01, 0.08), line)
	for s in [-1.0, 1.0]:
		var hx: float = c.x + s * 10.5
		# 골대는 벽에 단 받침대로 (바닥 기둥이 뒤쪽 출입문 앞을 막고 있었음)
		var wx: float = r.end.x if s > 0 else r.position.x
		kit.part(Vector3(hx, y0 + 3.3, c.y), Vector3(0.05, 1.05, 1.8), Color(0.95, 0.95, 0.95))
		kit.part(Vector3(hx - s * 0.03, y0 + 3.2, c.y), Vector3(0.01, 0.45, 0.6), Color(0.85, 0.3, 0.1))  # 백보드 사각 표시
		# 기둥에서 백보드까지 팔 + 버팀대 (예전엔 백보드가 기둥과 떨어져 공중에 떠 있었음)
		var arm_l: float = absf(wx - hx)
		for az in [-0.55, 0.55]:
			kit.part(Vector3((hx + wx) * 0.5, y0 + 3.55, c.y + az), Vector3(arm_l, 0.1, 0.1), Color(0.3, 0.3, 0.32), "metal")
			kit.part(Vector3((hx + wx) * 0.5, y0 + 2.95, c.y + az), Vector3(arm_l, 0.08, 0.08), Color(0.3, 0.3, 0.32), "metal")
			kit.part(Vector3(wx - s * 0.05, y0 + 3.25, c.y + az), Vector3(0.1, 0.8, 0.25), Color(0.25, 0.25, 0.27), "metal")  # 벽 고정판
		# 림: 가운데가 뚫린 고리 (막대 4개) + 늘어진 그물
		var rc := Vector3(hx - s * 0.3, y0 + 3.0, c.y)
		for k in 4:
			var a := k * PI / 2.0
			kit.part(rc + Vector3(cos(a) * 0.2, 0, sin(a) * 0.2), Vector3(0.03, 0.03, 0.42), Color(0.9, 0.4, 0.1), "metal", false, -a)
		kit.part(rc + Vector3(s * 0.21, 0, 0), Vector3(0.04, 0.03, 0.1), Color(0.9, 0.4, 0.1), "metal")
		for k in 4:
			var a := k * PI / 2.0 + PI / 4.0
			kit.part(rc + Vector3(cos(a) * 0.15, -0.2, sin(a) * 0.15), Vector3(0.012, 0.4, 0.012), Color(0.92, 0.92, 0.9))
	# 무대 (북쪽) + 커튼
	kit.part(Vector3(c.x, y0 + 0.5, r.position.y + 2.5), Vector3(14.0, 1.0, 4.4), Color(0.45, 0.32, 0.22), "trim", true)
	for i in 12:
		kit.part(Vector3(c.x - 7.0 + i * 1.27, y0 + 4.2, r.position.y + 0.6), Vector3(1.2, 6.2, 0.15), Color(0.5, 0.08, 0.1).darkened(0.1 * (i % 2)))
	# 관람석 (동쪽, 계단식)
	for k in 3:
		kit.part(Vector3(r.end.x - 1.0 - k * 0.9, y0 + 0.25 + k * 0.4, c.y), Vector3(0.9, 0.5 + k * 0.8, 14.0), Color(0.5, 0.52, 0.55), "trim", true)
	# 체육 창고 (서쪽 남단): 벽 2개 + 문
	var store := Rect2(r.position.x + 0.3, r.end.y - 6.5, 6.0, 6.2)
	kit.wall(Vector3(store.end.x, 0, store.position.y), Vector3(store.end.x, 0, store.end.y), y0, 3.4, _mat["concrete"], "w_gym", [[2.0, 3.5, 0.0, BuildingKit.DOOR_H]], 0.2)
	kit.wall(Vector3(store.position.x, 0, store.position.y), Vector3(store.end.x, 0, store.position.y), y0, 3.4, _mat["concrete"], "w_gym", [], 0.2)
	kit.slab(store, y0 + 3.4, _mat["concrete"], "w_concrete", [], true, 0.2)
	kit.furnish(store, y0, "gym_storage")
	# 공 바구니, 뜀틀, 줄넘기
	kit.part(Vector3(c.x - 6, y0 + 0.4, c.y + 6), Vector3(1.0, 0.8, 0.6), Color(0.3, 0.3, 0.32), "metal", true)
	for i in 6:  # 공 (둥근 통 모양으로, 네모 상자 대신)
		_pipe(Vector3(c.x - 6.3 + (i % 3) * 0.3, y0 + 0.92, c.y + 5.9 + (i / 3) * 0.3), 0.12, 0.22, Color(0.9, 0.45, 0.15))
	for i in 3:  # 굴러간 공 몇 개
		_pipe(Vector3(c.x + rng.randf_range(-8, 8), y0 + 0.12, c.y + rng.randf_range(-6, 6)), 0.12, 0.22, Color(0.9, 0.45, 0.15))
	for k in 4:
		kit.part(Vector3(c.x + 6, y0 + 0.2 + k * 0.25, c.y + 5), Vector3(1.6 - k * 0.1, 0.25, 0.9), Color(0.6, 0.45, 0.3).darkened(0.1 * (k % 2)), "trim", true)
	# 넓은 체육관이 텅 비어 보이지 않게: 벽 점수판 + 쌓인 매트 + 접이식 의자 더미 + 굴러다니는 콘
	var sb := Vector3(c.x, y0 + 4.2, r.end.y - 0.25)
	kit.part(sb, Vector3(3.0, 1.2, 0.15), Color(0.08, 0.08, 0.09), "metal")
	for k in 4:
		kit.part(sb + Vector3(-1.0 + k * 0.66, 0.1, -0.08), Vector3(0.45, 0.5, 0.01), Color(0.9, 0.3, 0.1) if k % 2 == 0 else Color(0.2, 0.2, 0.22), "lit" if k % 2 == 0 else "trim")
	for k in 5:
		kit.part(Vector3(r.end.x - 4.5, y0 + 0.08 + k * 0.12, r.end.y - 1.4), Vector3(2.0, 0.11, 1.0), Color(0.2, 0.35, 0.65).darkened(0.08 * (k % 2)), "trim", k == 0)
	for k in 6:  # 벽에 기대 세워 둔 접이식 의자들
		var cp := Vector3(r.position.x + 8.0 + k * 0.5, y0 + 0.45, r.end.y - 0.35)
		kit.part(cp, Vector3(0.42, 0.9, 0.06), Color(0.3, 0.32, 0.34).lightened(0.05 * (k % 3)), "metal", false, rng.randf_range(-0.08, 0.08))
		kit.part(cp + Vector3(0, 0.05, -0.08), Vector3(0.38, 0.4, 0.03), Color(0.25, 0.27, 0.3), "metal")
	for k in 5:
		var q := Vector3(c.x + rng.randf_range(-9, 9), y0, c.y + rng.randf_range(-7, 7))
		kit.part(q + Vector3.UP * 0.02, Vector3(0.3, 0.04, 0.3), Color(0.9, 0.45, 0.1))
		_pipe(q + Vector3.UP * 0.2, 0.06, 0.32, Color(0.95, 0.5, 0.12))
	for i in 4:
		kit.ceiling_light(Vector3(c.x - 7.5 + i * 5.0, y0 + h - 0.1, c.y), Color(0.9, 0.95, 1.0), 1.2, 0.5)
	generator_spots.append(Vector3(c.x, y0 + 0.06, c.y + 2.0))


# ================================================================ 운동장 소품 (놀이터·농구장·벤치·가로등·창고)

func _yard_props() -> void:
	# 정문 안쪽: 멈춰 선 학교 버스, 자전거 거치대, 안내판
	_bus(Vector3(-14, 0, 58), PI / 2.0 + 0.1)
	for i in 6:
		var bx := 9.0 + i * 0.9
		_box(Vector3(bx, 0.4, 60), Vector3(0.05, 0.8, 0.9), _mat["metal"], false)
	_box(Vector3(11.25, 0.8, 60), Vector3(5.0, 0.05, 0.05), _mat["metal"], false)
	_box(Vector3(11.25, 0.05, 60), Vector3(5.0, 0.1, 0.9), _mat["concrete"])
	var board := _prop(Vector3(5, 0, 62), PI, Vector3(2.2, 2.2, 0.3))
	_part(board, Vector3(0, 1.4, 0), _box_mesh(Vector3(2.2, 1.2, 0.08)), _flat_mat(Color(0.18, 0.3, 0.42), 0.7))
	_part(board, Vector3(0, 0.6, 0), _box_mesh(Vector3(0.1, 1.2, 0.1)), _mat["metal"])
	# 안내도: 건물 모양 블록
	_part(board, Vector3(-0.4, 1.55, -0.05), _box_mesh(Vector3(1.0, 0.35, 0.02)), _flat_mat(Color(0.8, 0.75, 0.6), 0.8))
	_part(board, Vector3(0.6, 1.5, -0.05), _box_mesh(Vector3(0.5, 0.5, 0.02)), _flat_mat(Color(0.7, 0.45, 0.35), 0.8))
	_part(board, Vector3(-0.2, 1.05, -0.05), _box_mesh(Vector3(1.3, 0.25, 0.02)), _flat_mat(Color(0.4, 0.6, 0.35), 0.8))
	# 놀이터 (동쪽)
	var pg := Vector3(55, 0.0, 12)
	_box(pg + Vector3(0, 0.02, 0), Vector3(18, 0.04, 16), _noise_mat(Color(0.42, 0.37, 0.28), 0.4, 1.0, 2.0))  # 모래
	# 정글짐
	for i in 4:
		for j in 4:
			_box(pg + Vector3(-6 + i * 0.9, 1.2, -4 + j * 0.9), Vector3(0.06, 2.4, 0.06), _mat["metal"], false)
	for k in 3:
		_box(pg + Vector3(-4.65, 0.8 + k * 0.8, -2.65), Vector3(2.8, 0.06, 2.8), _flat_mat(Color(0.8, 0.2, 0.2), 0.6), false)
	_prop(pg + Vector3(-4.65, 0, -2.65), 0.0, Vector3(2.8, 2.4, 2.8))
	# 미끄럼틀
	var slide := _prop(pg + Vector3(3, 0, -3), 0.0, Vector3(1.2, 2.2, 1.2))
	_part(slide, Vector3(0, 1.1, 0), _box_mesh(Vector3(1.2, 2.2, 1.2)), _flat_mat(Color(0.2, 0.45, 0.8), 0.6))
	var ramp := _part(slide, Vector3(0, 1.0, 2.0), _box_mesh(Vector3(0.8, 0.08, 3.2)), _flat_mat(Color(0.95, 0.75, 0.15), 0.4))
	ramp.rotation.x = 0.6
	# 그네
	for s in [-1.0, 1.0]:
		_box(pg + Vector3(s * 2.5, 1.4, 5), Vector3(0.1, 2.8, 0.1), _mat["metal"])
	_box(pg + Vector3(0, 2.8, 5), Vector3(5.2, 0.1, 0.1), _mat["metal"], false)
	for x in [-1.2, 1.2]:
		_box(pg + Vector3(x, 0.55, 5), Vector3(0.6, 0.06, 0.25), _flat_mat(Color(0.3, 0.3, 0.32), 0.6), false)
		for s in [-1.0, 1.0]:
			_box(pg + Vector3(x + s * 0.28, 1.7, 5), Vector3(0.02, 2.2, 0.02), _mat["metal"], false)
	generator_spots.append(pg + Vector3(0, 0.05, 1))
	# 야외 농구장
	var bc := Vector3(55, 0, 48)
	_box(bc + Vector3(0, 0.03, 0), Vector3(16, 0.06, 26), _mat["asphalt"])
	for s in [-1.0, 1.0]:
		_box(bc + Vector3(0, 1.6, s * 12.5), Vector3(0.2, 3.2, 0.2), _mat["metal"])
		_box(bc + Vector3(0, 3.3, s * 12.0), Vector3(1.8, 1.05, 0.06), _mat["paint"], false)
	# 벤치·가로등·쓰레기통
	for i in 10:
		var p := Vector3(rng.randf_range(-half + 8, half - 8), 0, rng.randf_range(-20, half - 10))
		if _in_building(p, 4.0) or Rect2(-46, -26, 80, 70).has_point(Vector2(p.x, p.z)):
			continue
		_yard_bench(p, rng.randf() * TAU)
	for p in [Vector3(-10, 0, -32), Vector3(10, 0, -32), Vector3(-30, 0, 50), Vector3(30, 0, 50), Vector3(0, 0, 55), Vector3(45, 0, -30), Vector3(-55, 0, 10), Vector3(40, 0, 30)]:
		_lamp(p)
	# 창고 (들어갈 수 있는 작은 건물)
	var spots := kit.city_building(Rect2(-66, 40, 9, 8), 0.05, 4.2, _mat["school_wall"], Color(0.5, 0.47, 0.42), "storage")
	for sp in spots:
		generator_spots.append(sp)
	# 화단 풀숲
	for p in [Vector3(-22, 0, -35), Vector3(22, 0, -35), Vector3(-36, 0, -35), Vector3(36, 0, -35)]:
		_grass(p, Vector2(6, 2.5))
	# 정문에서 운동장까지 보도블록 길 + 양옆 가로수·벤치 (넓은 잔디가 텅 비어 보이지 않게)
	var walk := _noise_mat(Color(0.55, 0.52, 0.48), 0.25, 0.9, 3.0)
	_box(Vector3(0, 0.03, 58.5), Vector3(4.0, 0.06, 29.0), walk, false)
	for e in [-1.0, 1.0]:
		_box(Vector3(e * 2.05, 0.08, 58.5), Vector3(0.12, 0.16, 29.0), _mat["concrete"], false)  # 연석
	for k in 5:
		var z := 47.0 + k * 5.5
		for e in [-1.0, 1.0]:
			var tp := Vector3(e * 4.2, 0, z)
			if tp.distance_to(Vector3(e * 2.0, 0, 65.5)) < 3.0 or tp.distance_to(Vector3(5, 0, 62)) < 2.8:
				continue  # 시작 지점 바로 옆은 비움
			_tree(tp)
			_box(tp + Vector3(0, 0.12, 0), Vector3(1.4, 0.24, 1.4), _mat["concrete"], false)  # 나무 둘레 화단 턱
		if k % 2 == 1:
			_yard_bench(Vector3(-3.0, 0, z + 2.6), PI / 2.0)
	# 서쪽 잔디: 생울타리 줄 + 나무 무리 + 바위
	var hedge := _noise_mat(Color(0.16, 0.3, 0.14), 0.35, 1.0, 2.0)
	for k in 4:
		var hz := -10.0 + k * 12.0
		# 생울타리: 부딪힘 상자 + 둥근 잎 덩어리를 겹쳐서 울퉁불퉁하게 (매끈한 초록 판 같던 것)
		var hb := _prop(Vector3(-58.0, 0, hz), 0.0, Vector3(1.0, 1.2, 7.0))
		_part(hb, Vector3(0, 0.45, 0), _box_mesh(Vector3(0.8, 0.9, 6.8)), hedge)
		var hedge2 := _noise_mat(Color(0.2, 0.36, 0.16), 0.4, 1.0, 1.5)
		for bk in 22:
			var bm := SphereMesh.new()
			bm.radius = rng.randf_range(0.3, 0.55)
			bm.height = bm.radius * rng.randf_range(1.5, 2.0)
			bm.radial_segments = 8
			bm.rings = 4
			var bz := rng.randf_range(-3.1, 3.1)
			_part(hb, Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.55, 1.05), bz), bm, hedge if rng.randf() < 0.6 else hedge2)
	for k in 7:
		var tp := Vector3(rng.randf_range(-70, -50), 0, rng.randf_range(-30, 35))
		if _in_building(tp, 4.0) or Rect2(-67, 39, 11, 10).has_point(Vector2(tp.x, tp.z)) or Vector2(tp.x, tp.z).distance_to(Vector2(-62, -20)) < 6.0:
			continue
		_tree(tp)
	for k in 4:
		var bp := Vector3(rng.randf_range(-68, -50), 0, rng.randf_range(-25, 30))
		if not _in_building(bp, 3.0):
			_box(bp + Vector3(0, 0.35, 0), Vector3(1.4, 0.7, 1.0), _mat["concrete"], true, rng.randf() * PI)

