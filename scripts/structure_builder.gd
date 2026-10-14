extends RefCounted
## 추격전 구조물 배치: 지붕 없는 폐가(문·창문·사물함)와 무너진 담장(창문·판자)
## 1) build_shells: 길 계산(navmesh) 전에 벽을 세움 → 술래·봇이 벽을 피해 다님
## 2) spawn_props:  길 계산 뒤에 문·판자·사물함·창문을 놓음 (문이 열린 상태로 길이 계산되도록)

const PropScript := preload("res://scripts/prop.gd")

const WALL_H := 2.6
const T := 0.25

var _props: Array = []   # [kind, 위치, 회전]
var _taken: Array = []   # 이미 쓴 자리 [중심, 반지름]
var _builder: LevelBuilder


func build_shells(main: Node3D, builder: LevelBuilder, rng: RandomNumberGenerator) -> void:
	_builder = builder
	var half := LevelBuilder.HALF - 9.0
	var avoid: Array = []
	for g in main.generators:
		avoid.append([g.global_position, 8.0])
	for p in LevelBuilder.SURVIVOR_SPAWNS:
		avoid.append([p, 10.0])
	for p in LevelBuilder.SEEKER_SPAWNS:
		avoid.append([p, 6.0])
	var space := main.get_world_3d().direct_space_state
	var plan := []
	for i in int(GameConfig.num("structure", "shacks", 6)):
		plan.append("shack")
	for i in int(GameConfig.num("structure", "walls", 10)):
		plan.append("wall")
	for kind in plan:
		var size := Vector3(7.0, 2.0, 6.0) if kind == "shack" else Vector3(11.0, 2.0, 2.4)
		var center_off := Vector3.ZERO if kind == "shack" else Vector3(1.3, 0, 0)
		for tries in 60:
			var pos := Vector3(rng.randf_range(-half, half), 0, rng.randf_range(-half, half))
			var yaw := (rng.randi() % 4) * PI / 2.0
			var c := pos + Basis(Vector3.UP, yaw) * center_off
			if not _free(space, c, size, yaw, avoid):
				continue
			if kind == "shack":
				_shack(pos, yaw)
			else:
				_wall(pos, yaw)
			_taken.append([c, size.x * 0.6 + 2.0])
			break
	_builder._flush_batches()


func spawn_props(main: Node3D) -> void:
	for p in _props:
		var node := Node3D.new()
		node.set_script(PropScript)
		main.add_child(node)
		node.global_position = p[1]
		node.rotation.y = p[2]
		node.call("setup", p[0], _builder._mat)


## 그 자리가 비어 있는지 (건물·차·나무와 겹치지 않고, 봉인석·시작 지점과 떨어져 있음)
func _free(space: PhysicsDirectSpaceState3D, c: Vector3, size: Vector3, yaw: float, avoid: Array) -> bool:
	for a in avoid + _taken:
		if Vector2(c.x, c.z).distance_to(Vector2(a[0].x, a[0].z)) < a[1] + size.x * 0.5:
			return false
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = size + Vector3(1.0, 0, 1.0)
	q.shape = box
	q.transform = Transform3D(Basis(Vector3.UP, yaw), c + Vector3.UP * 1.4)
	return space.intersect_shape(q, 1).is_empty()


func _to_world(origin: Vector3, yaw: float, local: Vector3) -> Vector3:
	return origin + Basis(Vector3.UP, yaw) * local


func _piece(origin: Vector3, yaw: float, local: Vector3, size: Vector3, mat_name: String, collide := true) -> void:
	_builder._box(_to_world(origin, yaw, local), size, _builder._mat[mat_name], collide, yaw)


## 장식 부품 (폐가 기준 로컬 좌표). key = 재질 종류 ("trim" 나무색, "metal" 녹슨 철, "glass", "web")
func _d(o: Vector3, yaw: float, local: Vector3, size: Vector3, key: String, col: Color, roll := 0.0, pitch := 0.0) -> void:
	var n := Basis(Vector3.UP, yaw) * Vector3.BACK
	_builder._bx(key, _to_world(o, yaw, local), Vector3.UP.cross(n), n, size, col, roll, pitch)


var _web_quad: QuadMesh
const DARK_WOOD := Color(0.2, 0.14, 0.1)
const RUST := Color(0.42, 0.26, 0.17)


## 지붕이 무너진 판잣집 (6 x 5m): 앞쪽 문, 뒤쪽 창문, 안쪽 구석에 사물함(숲은 옷장)
func _shack(o: Vector3, yaw: float) -> void:
	var h := WALL_H
	var m := "planks"
	# 앞 벽 (가운데 문 구멍 1.4m)
	_piece(o, yaw, Vector3(-1.85, h / 2, -2.5), Vector3(2.3, h, T), m)
	_piece(o, yaw, Vector3(1.85, h / 2, -2.5), Vector3(2.3, h, T), m)
	_piece(o, yaw, Vector3(0, 2.35, -2.5), Vector3(1.4, 0.5, T), m)
	# 뒤 벽 (가운데 창문 구멍 1.6m, 창틀은 넘을 수 있게 충돌 없음)
	_piece(o, yaw, Vector3(-1.9, h / 2, 2.5), Vector3(2.2, h, T), m)
	_piece(o, yaw, Vector3(1.9, h / 2, 2.5), Vector3(2.2, h, T), m)
	_piece(o, yaw, Vector3(0, 2.2, 2.5), Vector3(1.6, 0.8, T), m)
	_piece(o, yaw, Vector3(0, 0.45, 2.5), Vector3(1.6, 0.9, T * 0.6), "crate", false)
	# 옆 벽
	_piece(o, yaw, Vector3(-3.0, h / 2, 0), Vector3(T, h, 5.25), m)
	_piece(o, yaw, Vector3(3.0, h / 2, 0), Vector3(T, h, 5.25), m)
	# 나무 바닥
	_piece(o, yaw, Vector3(0, 0.02, 0), Vector3(5.75, 0.04, 4.75), "crate", false)
	# 모서리 기둥과 벽 위 들보
	for cx in [-3.05, 3.05]:
		for cz in [-2.55, 2.55]:
			_d(o, yaw, Vector3(cx, h / 2 + 0.1, cz), Vector3(0.34, h + 0.3, 0.34), "trim", DARK_WOOD)
	for cz in [-2.55, 2.55]:
		_d(o, yaw, Vector3(0, h + 0.05, cz), Vector3(6.3, 0.2, 0.36), "trim", DARK_WOOD)
	for cx in [-3.05, 3.05]:
		_d(o, yaw, Vector3(cx, h + 0.05, 0), Vector3(0.36, 0.2, 5.3), "trim", DARK_WOOD)
	# 문틀
	for x in [-0.76, 0.76]:
		_d(o, yaw, Vector3(x, 1.08, -2.5), Vector3(0.14, 2.16, 0.38), "trim", DARK_WOOD.lightened(0.1))
	_d(o, yaw, Vector3(0, 2.18, -2.5), Vector3(1.7, 0.16, 0.4), "trim", DARK_WOOD.lightened(0.1))
	# 창틀 + 깨진 유리 조각
	for x in [-0.86, 0.86]:
		_d(o, yaw, Vector3(x, 1.36, 2.5), Vector3(0.12, 0.95, 0.36), "trim", DARK_WOOD.lightened(0.1))
	_d(o, yaw, Vector3(0, 0.92, 2.5), Vector3(1.95, 0.1, 0.46), "trim", DARK_WOOD.lightened(0.1))
	_d(o, yaw, Vector3(0, 1.82, 2.5), Vector3(1.85, 0.12, 0.38), "trim", DARK_WOOD.lightened(0.1))
	_d(o, yaw, Vector3(-0.6, 1.62, 2.5), Vector3(0.35, 0.3, 0.02), "glass", Color(0.3, 0.38, 0.42), 0.5)
	_d(o, yaw, Vector3(0.62, 1.66, 2.5), Vector3(0.28, 0.22, 0.02), "glass", Color(0.3, 0.38, 0.42), -0.7)
	# 지붕 서까래 (하나는 부러져 처짐) + 녹슨 양철 지붕 조각
	_d(o, yaw, Vector3(0, h + 0.22, -1.4), Vector3(6.2, 0.16, 0.16), "trim", DARK_WOOD)
	_d(o, yaw, Vector3(0, h + 0.22, 1.4), Vector3(6.2, 0.16, 0.16), "trim", DARK_WOOD)
	_d(o, yaw, Vector3(-1.4, h - 0.25, 0.1), Vector3(3.4, 0.16, 0.16), "trim", DARK_WOOD, 0.32)
	_d(o, yaw, Vector3(0.9, h + 0.35, 1.25), Vector3(4.2, 0.05, 2.9), "metal", RUST, 0.04, 0.1)
	for i in 6:
		_d(o, yaw, Vector3(-1.1 + i * 0.8, h + 0.39, 1.25), Vector3(0.08, 0.04, 2.9), "metal", RUST.darkened(0.25), 0.04, 0.1)
	_d(o, yaw, Vector3(-1.9, h + 0.05, -1.3), Vector3(2.1, 0.05, 1.5), "metal", RUST.lightened(0.1), 0.28, -0.12)
	# 안쪽 살림살이: 탁자(부딪힘), 넘어진 의자, 선반과 병, 비뚤어진 액자, 술통(부딪힘), 거미줄
	_piece(o, yaw, Vector3(-1.8, 0.78, 1.25), Vector3(1.3, 0.08, 0.8), "crate")
	for lx in [-0.55, 0.55]:
		for lz in [-0.32, 0.32]:
			_d(o, yaw, Vector3(-1.8 + lx, 0.37, 1.25 + lz), Vector3(0.08, 0.74, 0.08), "trim", DARK_WOOD)
	_d(o, yaw, Vector3(-1.2, 0.25, -1.2), Vector3(0.45, 0.05, 0.45), "trim", DARK_WOOD.lightened(0.15), 1.2)
	_d(o, yaw, Vector3(-1.45, 0.12, -1.0), Vector3(0.45, 0.05, 0.5), "trim", DARK_WOOD.lightened(0.15), 0.2, 1.4)
	_d(o, yaw, Vector3(-2.8, 1.5, 0.0), Vector3(0.32, 0.05, 1.5), "trim", DARK_WOOD.lightened(0.05))
	for i in 3:
		var bc: Color = [Color(0.15, 0.35, 0.18), Color(0.35, 0.2, 0.1), Color(0.5, 0.5, 0.55)][i]
		_builder._pipe(_to_world(o, yaw, Vector3(-2.8, 1.66, -0.5 + i * 0.4)), 0.05, 0.28, bc)
	_d(o, yaw, Vector3(2.85, 1.55, -0.6), Vector3(0.05, 0.6, 0.5), "trim", Color(0.45, 0.32, 0.15), 0.0, 0.18)
	_d(o, yaw, Vector3(2.82, 1.55, -0.6), Vector3(0.02, 0.48, 0.38), "trim", Color(0.32, 0.27, 0.22), 0.0, 0.18)
	# 탁자 위 촛불 (반은 꺼져 있음): 어두운 폐가 안이 희미하게 보이게
	var candle := _to_world(o, yaw, Vector3(-1.6, 0.9, 1.3))
	_builder._pipe(candle, 0.035, 0.16, Color(0.9, 0.86, 0.75))
	if randf() < 0.6:
		var fl := OmniLight3D.new()
		fl.light_color = Color(1.0, 0.62, 0.3)
		fl.omni_range = 4.5
		fl.light_energy = 0.9
		fl.shadow_enabled = false
		_builder.region.add_child(fl)
		fl.position = candle + Vector3.UP * 0.2
		var flame := MeshInstance3D.new()
		var fm := SphereMesh.new()
		fm.radius = 0.025
		fm.height = 0.07
		flame.mesh = fm
		var fmat := StandardMaterial3D.new()
		fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fmat.albedo_color = Color(1.0, 0.75, 0.35)
		flame.material_override = fmat
		_builder.region.add_child(flame)
		flame.position = candle + Vector3.UP * 0.12
	var barrel := _to_world(o, yaw, Vector3(2.2, 0, -1.75))
	_builder._prop(barrel, yaw, Vector3(0.65, 0.95, 0.65))
	_builder._pipe(barrel + Vector3.UP * 0.47, 0.33, 0.94, Color(0.33, 0.22, 0.13))
	for by in [0.18, 0.76]:
		_builder._pipe(barrel + Vector3.UP * by, 0.345, 0.07, Color(0.2, 0.2, 0.2))
	var n := Basis(Vector3.UP, yaw) * Vector3.BACK
	var t := Vector3.UP.cross(n)
	for corner in [Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var cpos: Vector3 = _to_world(o, yaw, Vector3(corner.x * 2.62, h - 0.35, corner.y * 2.12))
		var dn: Vector3 = (t * -corner.x + n * -corner.y).normalized()
		if _web_quad == null:
			_web_quad = QuadMesh.new()
		var xf := Transform3D(Basis(Vector3.UP.cross(dn), Vector3.UP, dn) * Basis.from_scale(Vector3(1.1, 1.0, 1.0)), cpos)
		_builder._batch("b_web", _web_quad, _builder._deco_mat("web"), xf, Color(0.85, 0.85, 0.92, 0.35), false)
	_props.append(["door", _to_world(o, yaw, Vector3(0, 0, -2.5)), yaw])
	_props.append(["window", _to_world(o, yaw, Vector3(0, 0, 2.5)), yaw])
	_props.append(["locker", _to_world(o, yaw, Vector3(2.3, 0, 1.95)), yaw])


## 무너진 담장: 가운데 창문 구멍, 오른쪽 끝과 기둥 사이에 판자
func _wall(o: Vector3, yaw: float) -> void:
	_piece(o, yaw, Vector3(-2.15, 1.1, 0), Vector3(2.7, 2.2, 0.3), "wall")
	_piece(o, yaw, Vector3(2.15, 1.1, 0), Vector3(2.7, 2.2, 0.3), "wall")
	_piece(o, yaw, Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 0.18), "crate", false)
	_piece(o, yaw, Vector3(6.0, 1.0, 0), Vector3(1.0, 2.0, 1.0), "crate")
	# 위가 들쭉날쭉 부서진 벽 + 벽돌 부스러기 + 창문 구멍 위 녹슨 철근
	var brick := Color(0.36, 0.3, 0.27)
	for i in 8:
		var x := -3.3 + i * 0.42 if i < 4 else 1.2 + (i - 4) * 0.55
		var hh := randf_range(0.1, 0.45)
		_d(o, yaw, Vector3(x, 2.2 + hh / 2.0, 0), Vector3(0.4, hh, 0.3), "trim", brick.darkened(randf() * 0.2))
	for i in 7:
		var side := -1.0 if i % 2 == 0 else 1.0
		_d(o, yaw, Vector3(randf_range(-3.4, 3.4), 0.08, side * randf_range(0.35, 0.9)), Vector3(randf_range(0.2, 0.4), 0.14, randf_range(0.15, 0.3)), "trim", brick.darkened(randf() * 0.3), randf() * 0.4, randf() * 0.4)
	for x in [-0.6, -0.2, 0.25, 0.6]:
		_d(o, yaw, Vector3(x, 2.05, 0), Vector3(0.03, 0.5, 0.03), "metal", RUST, randf_range(-0.4, 0.4))
	# 기둥 옆 나무 상자 테두리
	for y in [0.05, 1.95]:
		_d(o, yaw, Vector3(6.0, y, 0), Vector3(1.06, 0.1, 1.06), "trim", DARK_WOOD)
	for cx in [-0.5, 0.5]:
		for cz in [-0.5, 0.5]:
			_d(o, yaw, Vector3(6.0 + cx, 1.0, cz), Vector3(0.1, 2.0, 0.1), "trim", DARK_WOOD)
	_props.append(["window", _to_world(o, yaw, Vector3(0, 0, 0)), yaw])
	_props.append(["pallet", _to_world(o, yaw, Vector3(4.5, 0, 0)), yaw])
