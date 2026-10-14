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


## 지붕 없는 폐가 (6 x 5m): 앞쪽 문, 뒤쪽 창문, 안쪽 구석에 사물함
func _shack(o: Vector3, yaw: float) -> void:
	var h := WALL_H
	# 앞 벽 (가운데 문 구멍 1.4m)
	_piece(o, yaw, Vector3(-1.85, h / 2, -2.5), Vector3(2.3, h, T), "wall")
	_piece(o, yaw, Vector3(1.85, h / 2, -2.5), Vector3(2.3, h, T), "wall")
	_piece(o, yaw, Vector3(0, 2.35, -2.5), Vector3(1.4, 0.5, T), "wall")
	# 뒤 벽 (가운데 창문 구멍 1.6m, 창틀은 넘을 수 있게 충돌 없음)
	_piece(o, yaw, Vector3(-1.9, h / 2, 2.5), Vector3(2.2, h, T), "wall")
	_piece(o, yaw, Vector3(1.9, h / 2, 2.5), Vector3(2.2, h, T), "wall")
	_piece(o, yaw, Vector3(0, 2.2, 2.5), Vector3(1.6, 0.8, T), "wall")
	_piece(o, yaw, Vector3(0, 0.45, 2.5), Vector3(1.6, 0.9, T * 0.6), "crate", false)
	# 옆 벽
	_piece(o, yaw, Vector3(-3.0, h / 2, 0), Vector3(T, h, 5.25), "wall")
	_piece(o, yaw, Vector3(3.0, h / 2, 0), Vector3(T, h, 5.25), "wall")
	_props.append(["door", _to_world(o, yaw, Vector3(0, 0, -2.5)), yaw])
	_props.append(["window", _to_world(o, yaw, Vector3(0, 0, 2.5)), yaw])
	_props.append(["locker", _to_world(o, yaw, Vector3(2.3, 0, 1.95)), yaw])


## 무너진 담장: 가운데 창문 구멍, 오른쪽 끝과 기둥 사이에 판자
func _wall(o: Vector3, yaw: float) -> void:
	_piece(o, yaw, Vector3(-2.15, 1.1, 0), Vector3(2.7, 2.2, 0.3), "wall")
	_piece(o, yaw, Vector3(2.15, 1.1, 0), Vector3(2.7, 2.2, 0.3), "wall")
	_piece(o, yaw, Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 0.18), "crate", false)
	_piece(o, yaw, Vector3(6.0, 1.0, 0), Vector3(1.0, 2.0, 1.0), "crate")
	_props.append(["window", _to_world(o, yaw, Vector3(0, 0, 0)), yaw])
	_props.append(["pallet", _to_world(o, yaw, Vector3(4.5, 0, 0)), yaw])
