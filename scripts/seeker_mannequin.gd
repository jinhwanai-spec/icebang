extends Seeker
## 술래: 마네킹
## - (패시브) 누군가 쳐다보고 있으면 그 자리에서 굳어 움직이지도 잡지도 못함.
##   아무도 안 볼 때는 2배 빠르게 움직임
##   (유저: 화면에 마네킹이 보이면 '쳐다보는 중' / 동료 봇: 15m 안에서 마네킹 쪽을 보고 있으면)
## - 기습: 30m 안의 생존자 등 뒤로 순간이동. 나타난 뒤 0.5초 못 움직임 (쿨 balance.cfg ambush_cooldown)
##   누가 쳐다보는 중에도 watched_escape_time 초 동안 계속 보이면 기습을 써서 그 시선을 벗어날 수 있음

var watched := false
var _ambush_cd := 0.0
var _watched_for := 0.0


func _ready() -> void:
	super._ready()
	_ambush_cd = GameConfig.num("mannequin", "ambush_cooldown", 40.0) * 0.5


## 잡는 거리: 기본 술래보다 50% 김 (balance.cfg [mannequin] catch_reach)
func _catch_reach() -> float:
	return GameConfig.num("mannequin", "catch_reach", 1.95)


func _ability_update(delta: float) -> void:
	watched = _is_watched()
	_watched_for = _watched_for + delta if watched else 0.0
	_ambush_cd = max(0.0, _ambush_cd - delta)
	# 쳐다보는 중: 잠깐(watched_escape_time) 버틴 뒤 기습으로 시선 밖(생존자 등 뒤)으로 빠져나감
	var escape := watched and _watched_for >= GameConfig.num("mannequin", "watched_escape_time", 1.0)
	if (watched and not escape) or _lock_left > 0.0 or _ambush_cd > 0.0 or (state == State.CHASE and not escape):
		return
	var s := _nearest_targetable(GameConfig.num("mannequin", "ambush_range", 30.0))
	if s == null or (not escape and global_position.distance_to(s.global_position) < 8.0):
		return
	_watched_for = 0.0
	var behind := s.global_position - _forward_of(s) * 2.6
	_teleport_to(behind)
	rotation.y = atan2(-(s.global_position.x - global_position.x), -(s.global_position.z - global_position.z))
	_ambush_cd = GameConfig.num("mannequin", "ambush_cooldown", 40.0)
	_lock_left = GameConfig.num("mannequin", "ambush_freeze", 0.5)  # 나타나서 잠깐 멈칫 → 돌아볼 기회
	_start_chase(s)


## 쳐다보면 굳음
func _move_dir(dir: Vector3, delta: float, speed: float) -> void:
	if watched:
		_stop()
		return
	super._move_dir(dir, delta, speed * GameConfig.num("mannequin", "unseen_speed", 2.0))


func _catch_nearby_survivors(reach := -1.0) -> void:
	if not watched:
		super._catch_nearby_survivors(reach)


## 공격 모션 중에 누가 쳐다보면 공격도 멈춤
func _update_attack(delta: float) -> void:
	if watched and _attack_left > 0.0:
		_attack_left = 0.0
		return
	super._update_attack(delta)


func _forward_of(s: Survivor) -> Vector3:
	if s.has_method("look_direction"):
		return s.call("look_direction")
	var f := s.body.global_basis.z
	f.y = 0.0
	return f.normalized()


func _is_watched() -> bool:
	if state == State.DISABLED:
		return false
	var chest := global_position + Vector3.UP * 1.6
	for node in get_tree().get_nodes_in_group("survivor"):
		var s := node as Survivor
		if s == null or s.is_dead:
			continue
		var cam := s.get("camera") as Camera3D
		if cam and cam.current:
			# 유저: 카메라 화면 안에 보이고 벽에 안 가려졌으면
			if cam.global_position.distance_to(chest) > 45.0 or not cam.is_position_in_frustum(chest):
				continue
			if _ray_clear(cam.global_position, chest, s):
				return true
		else:
			# 동료 봇: 가까이서 이쪽을 보고 있으면
			var to_me := global_position - s.global_position
			to_me.y = 0.0
			if to_me.length() > 15.0:
				continue
			if _forward_of(s).angle_to(to_me.normalized()) < deg_to_rad(50.0) \
					and _ray_clear(s.global_position + Vector3.UP * 1.4, chest, s):
				return true
	return false


func _ray_clear(from: Vector3, to: Vector3, viewer: Survivor) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid(), viewer.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _on_stunned() -> void:
	_lock_left = 0.0
