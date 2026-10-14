extends Seeker
## 술래: 유령
## - (패시브) 벽 통과: 건물과 장애물을 그냥 지나감. 벽 속에 있는 동안은 유저에게 안 보임
## - 대쉬: 생존자를 보면 잠시 멈춰 노려보다가(1.5초) 앞으로 쭉 돌진. 돌진 중 닿으면 잡힘 (쿨 30초)

var _dest := Vector3.ZERO
var _dash_cd := 0.0
var _dash_pending := false
var _dash_left := 0.0
var _dash_dir := Vector3.ZERO
var _dash_target: Survivor = null


func _ready() -> void:
	super._ready()
	collision_mask = 0  # 아무것과도 부딪히지 않음 → 벽 통과
	step_audio.volume_db = -8.0  # 둥둥 떠다니는 조용한 소리
	_dash_cd = GameConfig.num("ghost", "dash_cooldown", 30.0) * 0.5


# ---------------------------------------------------------------- 이동: 길 찾기 없이 직선으로

func _apply_gravity(_delta: float) -> void:
	velocity.y = 0.0


## 높이도 목적지를 따라감 (층을 뚫고 위아래로 스르륵 떠다님 → 학교·병원 2층·지하도 순찰)
func _set_destination(pos: Vector3) -> void:
	_dest = Vector3(pos.x, _snap_floor(pos.y), pos.z)


## 목적지 높이를 가장 가까운 층 바닥 높이로 맞춤
func _snap_floor(y: float) -> float:
	var game := get_tree().get_first_node_in_group("game")
	var best := 0.0
	if game == null or game.get("_builder") == null:
		return best
	var levels: Array = game._builder.floor_levels
	var bd := INF
	for lv in levels:
		var d: float = absf(float(lv) - y)
		if d < bd:
			bd = d
			best = float(lv)
	return best


func _random_level() -> float:
	var game := get_tree().get_first_node_in_group("game")
	if game == null or game.get("_builder") == null:
		return 0.0
	var levels: Array = game._builder.floor_levels
	return float(levels[randi() % levels.size()])


func _flat_dist() -> float:
	return Vector2(global_position.x, global_position.z).distance_to(Vector2(_dest.x, _dest.z))


func _destination_reached() -> bool:
	return _flat_dist() < 0.8 and absf(global_position.y - _dest.y) < 0.4


func _move_to_destination(delta: float, speed: float) -> void:
	if _destination_reached():
		_stop()
		return
	if _flat_dist() < 0.8:
		_stop()  # 바로 위/아래 층에 도착 중: 제자리에서 떠오르거나 가라앉기만
		return
	_move_dir(_dest - global_position, delta, speed)


## 순찰은 건물 속이든 어디든 랜덤으로
func _pick_patrol_point() -> void:
	var hunt := _hunt_point()
	if hunt != Vector3.INF:
		_set_destination(hunt)
		return
	if randf() < GameConfig.num("seeker", "patrol_generator_chance", 0.4):
		var gens := get_tree().get_nodes_in_group("generator").filter(func(g): return not g.completed)
		if not gens.is_empty():
			var g: Node3D = gens[randi() % gens.size()]
			_set_destination(g.global_position + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)))
			return
	_set_destination(Vector3(randf_range(-map_half_size, map_half_size), _random_level(), randf_range(-map_half_size, map_half_size)))


func _after_move(delta: float) -> void:
	if _dash_left > 0.0:
		# 돌진 중
		_dash_left -= delta
		velocity = _dash_dir * GameConfig.num("ghost", "dash_speed", 22.0)
		_catch_nearby_survivors(GameConfig.num("seeker", "catch_distance", 1.3) + 0.3)
	var p := global_position + velocity * delta
	# 층 이동: 목적지 가까이(12m) 오면 목표 층 높이로 천천히 떠오르거나 가라앉음
	if _dash_left <= 0.0 and absf(_dest.y - p.y) > 0.02 and _flat_dist() < 12.0:
		p.y = move_toward(p.y, _dest.y, 1.6 * delta)
	p.x = clampf(p.x, -map_half_size, map_half_size)
	p.z = clampf(p.z, -map_half_size, map_half_size)
	global_position = p
	# 벽 속에 있으면 유저에게 안 보임
	body.visible = state == State.DISABLED or not _inside_wall()


func _inside_wall() -> bool:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = global_position + Vector3.UP * 1.4
	q.exclude = [get_rid()]
	for hit in get_world_3d().direct_space_state.intersect_point(q, 4):
		if hit["collider"] is StaticBody3D:
			return true
	return false


# ---------------------------------------------------------------- 대쉬

func _ability_update(delta: float) -> void:
	_dash_cd = max(0.0, _dash_cd - delta)

	if _dash_pending:
		# 노려보는 중: 대상 쪽으로 몸을 돌림
		if _dash_target and is_instance_valid(_dash_target):
			_face(_dash_target.global_position - global_position, delta, 10.0)
		if _lock_left <= 0.0:
			_dash_pending = false
			_dash_dir = -global_basis.z
			_dash_dir.y = 0.0
			_dash_dir = _dash_dir.normalized()
			_dash_left = GameConfig.num("ghost", "dash_distance", 12.0) / GameConfig.num("ghost", "dash_speed", 22.0)
			_dash_cd = GameConfig.num("ghost", "dash_cooldown", 30.0)
		return

	if _dash_cd > 0.0 or _dash_left > 0.0:
		return
	var target := _best_target_in_view(GameConfig.num("ghost", "dash_max_range", 11.0))
	if target and global_position.distance_to(target.global_position) >= GameConfig.num("ghost", "dash_min_range", 4.0):
		_dash_pending = true
		_dash_target = target
		_lock_left = GameConfig.num("ghost", "dash_windup", 1.5)


func _on_stunned() -> void:
	_dash_pending = false
	_dash_left = 0.0
	_lock_left = 0.0


func _on_knocked_back() -> void:
	_on_stunned()
