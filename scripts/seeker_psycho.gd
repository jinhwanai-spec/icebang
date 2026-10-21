extends Seeker
## 술래: 사이코 (죽이지 않음 — 모두 쇠사슬에 묶으면 술래 승리)
## - (패시브) 광란: 피 흘리는 생존자가 있으면 이동속도 +20%, 공격 속도 +20%, 쿨타임 절반
## - (패시브) 눈 맞춤: 6m 안에서 서로 마주 보면 그 생존자 이동속도 80% 감소 (시선을 돌리면 원래대로)
## - (패시브) 쇠사슬: 잡은 생존자와 얼음 상태 생존자(녹여서)를 쇠사슬(6m)에 묶어 계속 끌고 다님
##   동료가 가까이 가서 E를 누르면 바로 풀림 → 사이코가 풀어 준 사람을 쫓음. 공간을 지배하는 자 소환으로도 빼낼 수 있음
## - 사슬낫 던지기: 맞으면 35초 출혈 (속도 30, 사거리 10m, 쿨 15초)

const ProjectileScript := preload("res://scripts/projectile.gd")

var chained: Array[Survivor] = []
var _sickle_cd := 0.0
var _frenzy := false
var _melt_target: Survivor = null
var _melt_left := 0.0
var _lines := {}
var _chain_mat: StandardMaterial3D


func _ready() -> void:
	super._ready()
	_sickle_cd = GameConfig.num("psycho", "sickle_cooldown", 15.0) * 0.4
	_chain_mat = StandardMaterial3D.new()
	_chain_mat.albedo_color = Color(0.45, 0.45, 0.48)
	_chain_mat.metallic = 0.8
	_chain_mat.roughness = 0.35


func _process(delta: float) -> void:
	super._process(delta)
	_update_lines()


func _attack_speed_mult() -> float:
	return 1.0 + GameConfig.num("psycho", "frenzy_attack", 0.2) if _frenzy else 1.0


func _move_dir(dir: Vector3, delta: float, speed: float) -> void:
	if _frenzy:
		speed *= 1.0 + GameConfig.num("psycho", "frenzy_speed", 0.2)
	super._move_dir(dir, delta, speed)


func _ability_update(delta: float) -> void:
	_frenzy = false
	for node in get_tree().get_nodes_in_group("survivor"):
		if (node as Survivor).bleed_time_left > 0.0 and not (node as Survivor).is_dead:
			_frenzy = true
			break
	# 광란 중에는 쿨타임이 2배 빨리 줄어듦 (= 쿨타임 50% 감소)
	_sickle_cd = max(0.0, _sickle_cd - delta * (2.0 if _frenzy else 1.0))
	chained = chained.filter(func(s): return is_instance_valid(s) and s.chained_by == self)
	_eye_contact()

	# 얼음 녹이는 중
	if _melt_target:
		if not is_instance_valid(_melt_target) or not _melt_target.is_frozen:
			_melt_target = null
		else:
			_melt_left -= delta
			_face(_melt_target.global_position - global_position, delta, 10.0)
			if _melt_left <= 0.0:
				_chain(_melt_target)
				_melt_target = null
			return
	if _lock_left > 0.0 or possessed_by:
		return

	# 얼음 상태 생존자가 가까우면 녹여서 묶음
	var frozen := _nearest_frozen(GameConfig.num("psycho", "frozen_search", 15.0))
	if frozen:
		var d := global_position.distance_to(frozen.global_position)
		if _frozen_reachable(frozen, d):
			_melt_target = frozen
			_melt_left = GameConfig.num("psycho", "melt_time", 1.5)
			_lock_left = _melt_left
			return
		if state != State.CHASE and agent.target_position.distance_to(frozen.global_position) > 1.0:
			_investigate(frozen.global_position)

	# 사슬낫 던지기
	var target := _best_target_in_view(GameConfig.num("psycho", "sickle_range", 10.0))
	if target and _sickle_cd <= 0.0 and global_position.distance_to(target.global_position) >= 3.0:
		_throw_sickle(target.global_position - global_position)
		_sickle_cd = GameConfig.num("psycho", "sickle_cooldown", 15.0)


func _throw_sickle(dir: Vector3) -> void:
	dir.y = 0.0
	rotation.y = atan2(-dir.x, -dir.z)
	_launch("sickle", self, global_position + Vector3.UP * 1.4 + dir.normalized() * 0.8, dir,
			GameConfig.num("psycho", "sickle_speed", 30.0), GameConfig.num("psycho", "sickle_range", 10.0), 0.5)
	_lock_left = 0.35


## 얼음 생존자에게 닿았는지. 길이 그 앞에서 끝나면(차·벽 옆) 조금 멀어도 닿은 것으로 침.
## 10초 넘게 못 닿으면 그 생존자는 20초 동안 무시 (제자리에서 맴도는 버그 방지)
var _ignore_frozen := {}
var _frozen_try: Survivor = null
var _frozen_try_time := 0.0
func _frozen_reachable(s: Survivor, d: float) -> bool:
	if d < 1.8 or (d < 3.2 and agent.is_navigation_finished()):
		_frozen_try = null
		return true
	if _frozen_try != s:
		_frozen_try = s
		_frozen_try_time = 0.0
	_frozen_try_time += get_physics_process_delta_time()
	if _frozen_try_time > 10.0:
		_ignore_frozen[s] = Time.get_ticks_msec() / 1000.0 + 20.0
		_frozen_try = null
		_enter_patrol()
	return false


func _nearest_frozen(max_d: float) -> Survivor:
	var best: Survivor = null
	var best_d := max_d
	for node in get_tree().get_nodes_in_group("survivor"):
		var s := node as Survivor
		if s.is_frozen and not s.is_dead and _ignore_frozen.get(s, 0.0) < Time.get_ticks_msec() / 1000.0 and s.chained_by == null and not s.has_meta("executing"):
			var d := global_position.distance_to(s.global_position)
			if d < best_d:
				best = s
				best_d = d
	return best


## 6m 안에서 서로 마주 보면 그 생존자 크게 감속
func _eye_contact() -> void:
	var r := GameConfig.num("psycho", "stare_range", 6.0)
	var fwd := -global_basis.z
	fwd.y = 0.0
	for node in get_tree().get_nodes_in_group("survivor"):
		var s := node as Survivor
		if s.is_dead or s.is_frozen or s.chained_by:
			continue
		var to_s := s.global_position - global_position
		to_s.y = 0.0
		if to_s.length() > r or fwd.normalized().angle_to(to_s.normalized()) > deg_to_rad(50.0):
			continue
		var look: Vector3
		if s.has_method("look_direction"):
			look = s.call("look_direction")
		else:
			look = s.body.global_basis.z
			look.y = 0.0
		if look.normalized().angle_to(-to_s.normalized()) > deg_to_rad(30.0):
			continue
		if not _clear_line(s):
			continue
		var first := s.slow_left <= 0.0
		s.apply_slow(GameConfig.num("psycho", "stare_slow", 0.8), 0.25)
		if first and s.has_signal("notice"):
			s.emit_signal("notice", "사이코와 눈이 마주쳤어요! 시선을 돌려요!")


## 잡으면 죽이지 않고 쇠사슬에 묶음
func _kill_survivor(s: Survivor) -> void:
	_chain(s)


func _chain(s: Survivor) -> void:
	if s.try_chain(self):
		chained.append(s)
		_poss_caught(s, "쇠사슬에 묶었어요")
		if s == chase_target:
			chase_target = null
			_enter_search()


## 동료가 쇠사슬을 풀어 줌 → 풀어 준 사람을 쫓음
func on_chain_freed(s: Survivor, by: Node) -> void:
	chained.erase(s)
	if _lines.has(s):
		(_lines[s] as Node).queue_free()
		_lines.erase(s)
	if not is_active():
		return
	if by is Survivor and by != s and _is_targetable(by):
		_start_chase(by)
	else:
		alert_to(s.global_position)


func _on_projectile_hit(kind: String, s: Survivor) -> void:
	if kind != "sickle" or not is_active() or s.is_frozen:
		return
	s.start_bleeding(GameConfig.num("psycho", "sickle_bleed", 35.0))
	if s is Survivor:
		_notify(s as Survivor, "사슬낫에 베였어요! %d초 동안 피를 흘려요" % int(GameConfig.num("psycho", "sickle_bleed", 35.0)))
	if state != State.CHASE:
		_start_chase(s)


func _on_stunned() -> void:
	_melt_target = null
	_lock_left = 0.0


func _on_knocked_back() -> void:
	_on_stunned()


func disable() -> void:
	super.disable()
	for s in chained.duplicate():
		if is_instance_valid(s):
			s.unchain(null)
	chained.clear()


## 손에서 묶인 생존자들까지 이어지는 쇠사슬
func _update_lines() -> void:
	for s in _lines.keys():
		if not chained.has(s):
			if is_instance_valid(_lines[s]):
				(_lines[s] as Node).queue_free()
			_lines.erase(s)
	for s in chained:
		if not _lines.has(s):
			var m := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.05, 0.05, 1.0)
			m.mesh = b
			m.material_override = _chain_mat
			m.top_level = true
			add_child(m)
			_lines[s] = m
		var line: MeshInstance3D = _lines[s]
		var a := global_position + Vector3.UP * 1.4
		var c := s.global_position + Vector3.UP * 0.9
		line.global_position = (a + c) / 2.0
		if a.distance_to(c) > 0.05:
			line.look_at(c, Vector3.UP)
		line.scale = Vector3(1, 1, a.distance_to(c))


# ---------------------------------------------------------------- 사람이 조종할 때 ([R] 사슬낫 / [T] 얼음 녹여 묶기)

func poss_skills() -> Array:
	return [["사슬낫 던지기", "빠른 사슬낫(10m). 맞으면 35초 출혈 → 광란 (빨라짐)"],
			["얼음 녹여 묶기", "3m 안 얼음 생존자를 1.5초 동안 녹여서 쇠사슬에 묶어요"]]


func poss_note(n: int) -> String:
	if n == 0 and _frenzy:
		return "광란! 쿨 절반"
	if n == 1:
		return "묶음 %d명" % chained.size()
	return ""


func _possessed_skill_tick(delta: float) -> void:
	# 광란 중에는 쿨타임이 2배 빨리 (기본 감소 + 한 번 더)
	if _frenzy:
		_pcd[0] = maxf(0.0, _pcd[0] - delta)


func _poss_do(n: int, aim: Vector3):
	if n == 0:
		var t := _aim_target(aim, 10.5, 10.0)
		_throw_sickle((t.global_position - global_position) if t else aim)
		return GameConfig.num("psycho", "sickle_cooldown", 15.0)
	var f := _nearest_frozen(3.2)
	if f == null:
		return "가까이(3m)에 얼음 상태 생존자가 없어요"
	_melt_target = f
	_melt_left = GameConfig.num("psycho", "melt_time", 1.5)
	_lock_left = _melt_left
	_notify(f, "사이코가 얼음을 녹이고 있어요! 쇠사슬에 묶여요!")
	return 4.0
