class_name HospitalBuilder
extends LevelBuilder
## 네 번째 맵: 버려진 병원
## - 지하 1층(영안실·보일러실·창고·지하 주차장) + 1층(로비·응급실·약제실·영상의학과) + 2층(병실·수술실·간호사실·중환자실)
## - 양 끝 계단실에 계단 2개씩 (지하↔1층, 1층↔2층)
## - 바깥은 주차장(구급차·자동차), 정문 차양과 빨간 십자 간판, 담장

const FH := 3.6
const BLD := Rect2(-32.0, -30.0, 64.0, 24.0)
const Y0 := 0.05
const YB := -3.55


func build(target: Node3D, map_seed: int) -> void:
	region = target
	rng.seed = map_seed
	half = 64.0
	survivor_spawns = [Vector3(-2, 0.3, 56), Vector3(2, 0.3, 56), Vector3(-2, 0.3, 59), Vector3(2, 0.3, 59)]
	seeker_spawns = [Vector3(-15, YB + 0.3, -18), Vector3(15, Y0 + FH + 0.3, -18), Vector3(0, 0.3, -50)]
	floor_levels = [YB, Y0, Y0 + FH]
	_make_materials()
	_mat["hosp_wall"] = _pattern_mat("plaster", Color(0.82, 0.84, 0.82), 3.0)
	_mat["hosp_in"] = _pattern_mat("plaster", Color(0.7, 0.78, 0.76), 3.0)
	_mat["hosp_floor"] = _pattern_mat("tile", Color(0.62, 0.66, 0.66), 1.0)
	_mat["base_wall"] = _pattern_mat("plaster", Color(0.42, 0.42, 0.4), 2.5)
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
	var corr_w := 3.2
	var zs := corr_z - corr_w * 0.5 - 1.2 - 6.0
	var stA := Rect2(inner.position.x + 0.3, zs, 1.8, 6.0)  # 지하 → 1층 (서쪽)
	var stB := Rect2(inner.position.x + 2.7, zs, 1.8, 6.0)  # 1층 → 2층 (서쪽)
	var stC := Rect2(inner.end.x - 2.1, zs, 1.8, 6.0)       # 지하 → 1층 (동쪽)
	var stD := Rect2(inner.end.x - 4.5, zs, 1.8, 6.0)       # 1층 → 2층 (동쪽)
	var trim := Color(0.6, 0.62, 0.62)
	var sides := [
		[Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0, r.position.y), Vector3(0, 0, -1)],
		[Vector3(r.end.x, 0, r.position.y), Vector3(r.end.x, 0, r.end.y), Vector3(1, 0, 0)],
		[Vector3(r.end.x, 0, r.end.y), Vector3(r.position.x, 0, r.end.y), Vector3(0, 0, 1)],
		[Vector3(r.position.x, 0, r.end.y), Vector3(r.position.x, 0, r.position.y), Vector3(-1, 0, 0)],
	]
	for si in 4:
		var a: Vector3 = sides[si][0]
		var b: Vector3 = sides[si][1]
		var n: Vector3 = sides[si][2]
		var L := Vector2(b.x - a.x, b.z - a.z).length()
		var dir := (b - a).normalized()
		# 지하 외벽 (창문 없음, 흙에 묻힌 콘크리트)
		kit.wall(a, b, YB, Y0 - YB, _mat["base_wall"], "w_base", [], 0.4)
		for k in 2:
			var y := Y0 + k * FH
			var ops := []
			var doors := []
			if k == 0:
				if si == 2:
					doors = [L * 0.5 - 0.9, L * 0.5 + 0.9]
				elif si == 1:
					doors = [corr_z - r.position.y]
				elif si == 3:
					doors = [L - (corr_z - r.position.y)]
			for du in doors:
				ops.append([du - 0.75, du + 0.75, 0.0, BuildingKit.DOOR_H])
				var dc: Vector3 = a + dir * du
				dc.y = y
				kit._door_frame(dc, dir, Color(0.35, 0.37, 0.4))
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
				ops.append([u - 0.6, u + 0.6, 1.0, 2.4])
				var gc := a + dir * u
				gc.y = y + 1.7
				var lit := rng.randf() < 0.08
				kit.block(gc, Vector3(1.2, 1.4, 0.04), _deco_mat("lit" if lit else "glass"), "b_" + ("lit" if lit else "glass"), true, Basis(dir, Vector3.UP, dir.cross(Vector3.UP).normalized()), false, Color(0.6, 0.95, 0.75) if lit else Color(0.08, 0.1, 0.12))
				var tt := Vector3.UP.cross(n)
				var fn := gc + n * (BuildingKit.WALL_T * 0.5)
				_bx("trim", fn + Vector3.UP * -0.75 + n * 0.08, tt, n, Vector3(1.4, 0.08, 0.2), trim)
				_bx("trim", fn + n * 0.03, tt, n, Vector3(0.06, 1.4, 0.05), Color(0.25, 0.27, 0.3))
			kit.wall(a, b, y, FH, _mat["hosp_wall"], "w_hosp", ops)
		var face := (a + b) * 0.5 + n * (BuildingKit.WALL_T * 0.5)
		var tt2 := Vector3.UP.cross(n)
		_bx("trim", face + n * 0.08 + Vector3.UP * (Y0 + FH), tt2, n, Vector3(L, 0.3, 0.2), Color(0.3, 0.55, 0.6))
		_bx("trim", face + n * 0.14 + Vector3.UP * (Y0 + FH * 2 + 0.2), tt2, n, Vector3(L + 0.4, 0.45, 0.3), trim.darkened(0.1))
	# 정문 차양 + 빨간 십자 간판
	_bx("trim", Vector3(0, Y0 + 3.0, r.end.y + 2.0), Vector3.RIGHT, Vector3.BACK, Vector3(8.0, 0.3, 4.0), Color(0.75, 0.77, 0.78))
	for x in [-3.6, 3.6]:
		kit.part(Vector3(x, Y0 + 1.5, r.end.y + 3.8), Vector3(0.3, 3.0, 0.3), Color(0.7, 0.7, 0.72), "trim", true)
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
	lbl.position = Vector3(0, Y0 + 3.65, r.end.y + 4.07)
	_box(Vector3(0, Y0 + 3.65, r.end.y + 3.95), Vector3(7.0, 0.9, 0.2), _flat_mat(Color(0.12, 0.25, 0.3), 0.6), false)
	region.add_child(lbl)
	# 바닥판: 지하 바닥, 1층(지하 계단 구멍), 2층(1층→2층 계단 구멍), 지붕
	kit.slab(inner, YB + 0.05, _mat["hosp_floor"], "w_hfloor", [], false, 0.3)
	kit.slab(inner, Y0, _mat["hosp_floor"], "w_hfloor", [stA, stC], false, 0.25)
	kit.slab(inner, Y0 + FH, _mat["hosp_floor"], "w_hfloor", [stB, stD])
	kit.slab(r.grow(0.3), Y0 + FH * 2 + 0.2, _mat["concrete"], "w_concrete", [], true, 0.3)
	for st in [stA, stC]:
		kit.stairs(st, false, true, YB + 0.05, Y0 - YB - 0.05)
		kit.hole_rail(st, Y0, "z+")
	for st in [stB, stD]:
		kit.stairs(st, false, true, Y0, FH)
		kit.hole_rail(st, Y0 + FH, "z+")
	# 층별 방
	var core := Rect2(inner.position.x + 7.0, inner.position.y, inner.size.x - 14.0, inner.size.y)
	var plans := {
		YB: [[[14, "morgue", "영안실"], [10, "boiler", "보일러실"], [8, "storage", "창고"], [8, "storage", "세탁실"], [10, "boiler", "발전기실"]],
			[[30, "parking", "지하 주차장"], [10, "storage", "의료폐기물"], [10, "office", "시설관리실"]]],
		Y0: [[[12, "ward", "응급실"], [8, "nurse", "처치실"], [9, "pharmacy", "약제실"], [6, "toilet", "화장실"], [8, "lab", "영상의학과"], [7, "office", "원무과"]],
			[[10, "ward", "외래 진료"], [7, "office", "진료실"], [16, "lobby", "로비"], [8, "office", "접수"], [9, "pharmacy", "매점"]]],
		Y0 + FH: [[[9, "ward", "201호"], [9, "ward", "202호"], [12, "operating", "수술실"], [6, "toilet", "화장실"], [14, "ward", "203호"]],
			[[9, "nurse_station", "간호사실"], [9, "ward", "205호"], [12, "ward", "중환자실"], [9, "ward", "206호"], [11, "office", "의사실"]]],
	}
	for y in plans.keys():
		var fy: float = y
		var plan: Array = plans[y]
		var h := (Y0 - YB) if fy < 0.0 else FH
		var rooms: Array = kit.wing(core, fy + (0.05 if fy < 0.0 else 0.0), h, true, corr_w, plan[0], plan[1], _mat["hosp_in"] if fy >= 0.0 else _mat["base_wall"], [], 0.4)
		for rm in rooms:
			var rr: Rect2 = rm["rect"]
			var ry := fy + (0.05 if fy < 0.0 else 0.0)
			var keep: bool = rm["kind"] in ["ward", "lobby", "morgue", "operating", "parking", "boiler"] and rng.randf() < 0.5
			kit.furnish_room(rm, ry, keep)
			debug_rooms.append([rm, ry])
			if keep:
				generator_spots.append(Vector3(rr.get_center().x, ry, rr.get_center().y))
			kit.ceiling_light(Vector3(rr.get_center().x, ry + h - 0.25, rr.get_center().y), Color(0.75, 0.95, 0.85) if fy >= 0.0 else Color(1.0, 0.8, 0.55), 0.8, 0.4)
			var dn := Vector3(0, 0, 1) if rr.get_center().y < corr_z else Vector3(0, 0, -1)
			kit.room_sign((rm["door"] as Vector3) + Vector3(1.4, ry + 2.45, 0), rm["name"], dn)
		# 계단실과 복도 끝 벽
		for xw in [core.position.x, core.end.x]:
			for side in [-1.0, 1.0]:
				var z0: float = corr_z + side * corr_w * 0.5
				var z1 := inner.position.y if side < 0 else inner.end.y
				kit.wall(Vector3(xw, 0, z0), Vector3(xw, 0, z1), fy + (0.05 if fy < 0.0 else 0.0), h - 0.2, _mat["hosp_in"], "w_inner", [[1.2, 2.7, 0.0, BuildingKit.DOOR_H]] if side > 0 else [], 0.18)
		# 복도: 휠체어·들것·의자·소화기·안내 표시
		var ry2 := fy + (0.05 if fy < 0.0 else 0.0)
		for i in 7:
			var x := core.position.x + 3.0 + i * (core.size.x - 6.0) / 6.0
			kit.ceiling_light(Vector3(x, ry2 + h - 0.25, corr_z), Color(0.75, 0.95, 0.85) if fy >= 0.0 else Color(1.0, 0.75, 0.5), 0.6, 0.3)
			match i % 3:
				0:
					_wheelchair(Vector3(x, ry2, corr_z + corr_w * 0.5 - 0.5))
				1:
					_stretcher(Vector3(x, ry2, corr_z - corr_w * 0.5 + 0.5))
				_:
					kit.part(Vector3(x, ry2 + 0.3, corr_z - corr_w * 0.5 + 0.2), Vector3(0.18, 0.55, 0.18), Color(0.85, 0.1, 0.1), "metal")
		# 계단실 끝에 사물함 (숨는 곳)
		props.append(["locker", Vector3(inner.end.x - 0.5, ry2, corr_z + corr_w * 0.5 + 2.5), -PI / 2.0])
		props.append(["locker", Vector3(inner.position.x + 0.5, ry2, corr_z + corr_w * 0.5 + 2.5), PI / 2.0])


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
	generator_spots.append(Vector3(0, 0.05, -45))
	# 건물 뒤 공터: 폐기물 컨테이너, 산소 탱크
	for i in 4:
		_dumpster(Vector3(-20 + i * 12, 0, -36), 0.0)
	for x in [24.0, 27.0]:
		var tank := _prop(Vector3(x, 0, -40), 0.0, Vector3(1.6, 4.0, 1.6))
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
