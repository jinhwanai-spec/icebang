extends Seeker
## 술래: 내일부터 다이어트 (뭐든 먹어 치울 것 같은 거대한 하마)
## - (패시브) 먹은 능력: 자기가 잡은 생존자의 능력 1을 빼앗아 술래용으로 씀
##     카멜레온: 6초 투명 / 공간: 생존자 근처로 순간이동 / 카메라맨: 앞쪽 플래시 (눈부심 + 감속)
##     사나이: (패시브) 기절 시간 절반 / 의사: 붕대로 10m 안 생존자를 끌어옴 / 그림자: (패시브) 발소리 없음
##     사냥꾼: 밟으면 묶이는 덫 / 악사: 비명으로 가까운 생존자 위치 파악 / 정비공: (패시브) 문·판자 2배 빨리 부숨
##     등불지기: 가장 가까운 생존자 위치로 곧장 감 / 중력술사: 앞쪽 생존자를 2초 동안 띄워 못 움직이게 함
## - 블랙홀: 입을 쩍 벌려 앞쪽 12m(부채꼴 90°)를 5초 동안 빨아들임. 그동안 하마는 못 움직임 (쿨 30초)
##     달리면 제자리걸음, 걸으면 서서히, 가만히 있으면 더 빨리 빨려 들어감. 입까지 오면 잡힘. 얼음은 무적

var stolen: Array[String] = []
var _stolen_cd := {}
var _hole_cd := 0.0
var _hole_left := 0.0
var _invisible_left := 0.0
var _boost_left := 0.0
var _hole_audio: AudioStreamPlayer3D
var _swirl: CPUParticles3D


func _ready() -> void:
	super._ready()
	_hole_cd = GameConfig.num("diet", "blackhole_cooldown", 30.0) * 0.4
	_hole_audio = AudioStreamPlayer3D.new()
	_hole_audio.max_distance = 40.0
	_hole_audio.unit_size = 6.0
	if ResourceLoader.exists("res://audio/vortex.wav"):
		_hole_audio.stream = load("res://audio/vortex.wav")
	add_child(_hole_audio)


func is_sucking() -> bool:
	return _hole_left > 0.0


func _move_dir(dir: Vector3, delta: float, speed: float) -> void:
	if _boost_left > 0.0:
		speed *= 1.3
	super._move_dir(dir, delta, speed)


func stun(seconds: float) -> void:
	super.stun(seconds * (0.5 if stolen.has("brute") else 1.0))


func _footsteps(delta: float) -> void:
	if stolen.has("shadow") or _invisible_left > 0.0:
		return
	super._footsteps(delta)


## 잡으면 그 생존자의 능력을 빼앗음
func _kill_survivor(s: Survivor) -> void:
	super._kill_survivor(s)
	if s.is_dead and not stolen.has(s.character_id):
		stolen.append(s.character_id)
		_stolen_cd[s.character_id] = 5.0
		if s.character_id == "mechanic":
			set_meta("break_mult", 0.5)
		var info := CharacterDB.get_info(s.character_id)
		for node in get_tree().get_nodes_in_group("survivor"):
			if node is Survivor:
				_notify(node as Survivor, "하마가 %s의 '%s' 능력을 삼켰어요!" % [info["name"], info["ability_1"]])


func _ability_update(delta: float) -> void:
	_hole_cd = max(0.0, _hole_cd - delta)
	_boost_left = max(0.0, _boost_left - delta)
	if _invisible_left > 0.0:
		_invisible_left -= delta
		body.visible = _invisible_left <= 0.0
	for k in _stolen_cd.keys():
		_stolen_cd[k] = max(0.0, _stolen_cd[k] - delta)

	if _hole_left > 0.0:
		_update_blackhole(delta)
		return
	if _lock_left > 0.0 or possessed_by:
		return
	if _hole_cd <= 0.0 and not _targets_in_cone().is_empty():
		_start_blackhole()
		return
	_use_stolen()


# ---------------------------------------------------------------- 블랙홀

func _mouth_pos() -> Vector3:
	return global_position + Vector3.UP * 1.2 - global_basis.z * 1.3


func _targets_in_cone() -> Array:
	var out: Array = []
	var r := GameConfig.num("diet", "blackhole_range", 12.0)
	var half := deg_to_rad(GameConfig.num("diet", "blackhole_angle", 90.0) / 2.0)
	var fwd := -global_basis.z
	fwd.y = 0.0
	for node in get_tree().get_nodes_in_group("survivor"):
		var s := node as Survivor
		if s.is_dead or s.is_frozen or s.in_locker or s.chained_by or s.is_shadowed():
			continue
		var to := s.global_position - global_position
		to.y = 0.0
		if to.length() > r or fwd.normalized().angle_to(to.normalized()) > half:
			continue
		if _clear_line(s):
			out.append(s)
	return out


func _start_blackhole() -> void:
	_hole_left = GameConfig.num("diet", "blackhole_time", 5.0)
	_hole_cd = GameConfig.num("diet", "blackhole_cooldown", 30.0)
	_lock_left = _hole_left
	_hole_visual(true)
	_fx("hole", Vector3.ZERO, Vector3.ZERO, true)
	for node in get_tree().get_nodes_in_group("survivor"):
		if node is Survivor and global_position.distance_to((node as Node3D).global_position) < 25.0:
			_notify(node as Survivor, "하마가 입을 벌렸어요! 달려서 버텨요!")


## 블랙홀 모양·소리 (손님 화면에서도 같은 모양)
func _hole_visual(on: bool) -> void:
	if not on:
		body.set_mouth_open(0.0)
		_hole_audio.stop()
		if _swirl:
			_swirl.queue_free()
			_swirl = null
		return
	body.set_mouth_open(1.0)
	if _hole_audio.stream:
		_hole_audio.play()
	_swirl = CPUParticles3D.new()
	add_child(_swirl)
	_swirl.position = Vector3(0, 1.2, -1.3)
	_swirl.amount = 80
	_swirl.lifetime = 0.8
	_swirl.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_swirl.emission_sphere_radius = 5.0
	_swirl.radial_accel_min = -18.0
	_swirl.radial_accel_max = -12.0
	_swirl.tangential_accel_min = 6.0
	_swirl.tangential_accel_max = 10.0
	_swirl.gravity = Vector3.ZERO
	_swirl.scale_amount_min = 0.05
	_swirl.scale_amount_max = 0.12
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.0, 0.25)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.0, 0.6)
	m.material = mat
	_swirl.mesh = m
	_swirl.emitting = true


func _update_blackhole(delta: float) -> void:
	_hole_left -= delta
	_lock_left = maxf(_lock_left, 0.1)  # 빨아들이는 동안은 못 움직임
	body.set_mouth_open(1.0)
	var mouth := _mouth_pos()
	var pull := GameConfig.num("diet", "blackhole_pull", 7.5)
	for s in _targets_in_cone():
		var to: Vector3 = mouth - s.global_position
		to.y = 0.0
		if to.length() < GameConfig.num("diet", "swallow_distance", 1.8):
			_kill_survivor(s)
			continue
		s.add_external_pull(to.normalized() * pull)
	if _hole_left <= 0.0:
		_end_blackhole()


func _end_blackhole() -> void:
	var was := _hole_left > 0.0 or _swirl != null
	_hole_left = 0.0
	_hole_visual(false)
	if was:
		_fx("hole", Vector3.ZERO, Vector3.ZERO, false)


func _on_stunned() -> void:
	if _hole_left > 0.0:
		_end_blackhole()
	_lock_left = 0.0


func _on_knocked_back() -> void:
	_on_stunned()


# ---------------------------------------------------------------- 빼앗은 능력 (술래용)

func _use_stolen() -> void:
	for id in stolen:
		if _stolen_cd.get(id, 0.0) > 0.0:
			continue
		if _try_stolen(id):
			_stolen_cd[id] = GameConfig.num("diet", "stolen_cooldown", 30.0)
			return


func _try_stolen(id: String) -> bool:
	var chasing := state == State.CHASE
	match id:
		"chameleon":
			if chasing:
				_invisible_left = 6.0
				body.visible = false
				return true
		"space":
			if not chasing:
				var s := _nearest_targetable(80.0)
				if s:
					var a := randf() * TAU
					_teleport_to(s.global_position + Vector3(cos(a), 0, sin(a)) * 8.0)
					return true
		"cameraman":
			var t := _best_target_in_view(10.0)
			if t:
				for node in get_tree().get_nodes_in_group("survivor"):
					var s := node as Survivor
					if _can_see(s, 12.0):
						s.apply_slow(0.5, 2.0)
						if s.has_signal("flashed"):
							s.emit_signal("flashed")
				return true
		"medic":
			# 붕대: 10m 안 생존자를 하마 쪽으로 끌어옴
			var s := _nearest_targetable(GameConfig.num("diet", "stolen_bandage_range", 10.0))
			if s and _clear_line(s):
				var to := global_position - s.global_position
				to.y = 0.0
				var pull := minf(GameConfig.num("diet", "stolen_bandage_pull", 2.0), maxf(0.0, to.length() - 1.0))
				s.pull_to(s.global_position + to.normalized() * pull, 0.3)
				return true
		"gravity":
			# 무중력: 앞쪽 생존자를 띄워서 못 움직이게
			var s := _best_target_in_view(12.0)
			if s:
				s.root(GameConfig.num("diet", "stolen_float_time", 2.0))
				s.set_meta("floating", true)
				var tw := s.create_tween()
				tw.tween_property(s.body, "position:y", s.body.position.y + 1.2, 0.3)
				tw.tween_interval(maxf(0.0, GameConfig.num("diet", "stolen_float_time", 2.0) - 0.6))
				tw.tween_property(s.body, "position:y", s.body.position.y, 0.3)
				tw.tween_callback(s.remove_meta.bind("floating"))
				return true
		"hunter":
			if not chasing:
				_spawn_effect("web_trap", global_position)
				return true
		"bard":
			if not chasing:
				var s := _nearest_targetable(35.0)
				if s:
					alert_to(s.global_position)
					return true
		"keeper":
			if not chasing:
				var s := _nearest_targetable(200.0)
				if s:
					alert_to(s.global_position)
					return true
	return false


func disable() -> void:
	_end_blackhole()
	body.visible = true
	super.disable()


func fx_mirror(kind: String, a: Vector3, b: Vector3, extra) -> void:
	if kind == "hole":
		_hole_visual(bool(extra))
		return
	super.fx_mirror(kind, a, b, extra)


# ---------------------------------------------------------------- 사람이 조종할 때 ([R] 블랙홀 / [T] 삼킨 능력)

const STOLEN_NAMES := {"chameleon": "투명 6초", "space": "생존자 근처로 순간이동", "cameraman": "앞쪽 플래시",
		"medic": "붕대로 끌어오기", "gravity": "무중력 띄우기", "hunter": "덫 놓기", "bard": "비명 탐지",
		"keeper": "가장 가까운 생존자 탐지"}


func poss_skills() -> Array:
	return [["블랙홀", "앞쪽 12m 부채꼴을 5초 동안 빨아들여요. 입까지 오면 잡혀요 (그동안 못 움직임)"],
			["삼킨 능력", "잡은 생존자에게서 빼앗은 능력을 써요"]]


func _usable_stolen() -> Array:
	return stolen.filter(func(id): return STOLEN_NAMES.has(id))


func poss_note(n: int) -> String:
	if n == 0 and _hole_left > 0.0:
		return "빨아들이는 중 %.1f초" % _hole_left
	if n == 1:
		var u := _usable_stolen()
		if u.is_empty():
			return "아직 없음 (생존자를 잡으면 빼앗아요)"
		return STOLEN_NAMES[u[_stolen_pick % u.size()]]
	return ""


var _stolen_pick := 0


func _poss_do(n: int, aim: Vector3):
	if n == 0:
		_face_aim(aim)
		_start_blackhole()
		return GameConfig.num("diet", "blackhole_cooldown", 30.0) * 0.7
	var u := _usable_stolen()
	if u.is_empty():
		return "아직 삼킨 능력이 없어요. 생존자를 잡으면 그 능력을 빼앗아요"
	var id: String = u[_stolen_pick % u.size()]
	_face_aim(aim)
	if not _poss_stolen(id, aim):
		return "%s: 지금은 쓸 대상이 없어요" % STOLEN_NAMES[id]
	_stolen_pick += 1  # 여러 개면 번갈아 씀
	return GameConfig.num("diet", "stolen_cooldown", 30.0) * 0.6


func _poss_stolen(id: String, aim: Vector3) -> bool:
	match id:
		"chameleon":
			_invisible_left = 6.0
			body.visible = false
			return true
		"space":
			var s := _nearest_targetable(80.0)
			if s == null:
				return false
			var a := randf() * TAU
			var p := _floor_point(s.global_position + Vector3(cos(a), 0, sin(a)) * 8.0)
			_teleport_to(p)
			_poss_call("poss_teleport", [p])
			return true
		"cameraman", "gravity", "medic":
			var t := _aim_target(aim, 12.0, 35.0)
			if t == null:
				return false
			if id == "cameraman":
				for node in get_tree().get_nodes_in_group("survivor"):
					var s := node as Survivor
					if _is_targetable(s) and global_position.distance_to(s.global_position) < 12.0 \
							and aim.angle_to(Vector3(s.global_position.x - global_position.x, 0, s.global_position.z - global_position.z).normalized()) < deg_to_rad(40.0):
						s.apply_slow(0.5, 2.0)
						if s.net_puppet and s.net_owner != 0:
							Net.apply_to_me.rpc_id(s.net_owner, "emit_signal", ["flashed"])
						elif s.has_signal("flashed"):
							s.emit_signal("flashed")
			elif id == "gravity":
				t.root(GameConfig.num("diet", "stolen_float_time", 2.0))
				_notify(t, "하마의 무중력에 떠올랐어요!")
			else:
				var to := global_position - t.global_position
				to.y = 0.0
				var pull := minf(GameConfig.num("diet", "stolen_bandage_pull", 2.0) * 2.0, maxf(0.0, to.length() - 1.2))
				t.pull_to(t.global_position + to.normalized() * pull, 0.35)
			return true
		"hunter":
			_spawn_effect("web_trap", global_position)
			return true
		"bard", "keeper":
			_poss_call("poss_sense", [35.0 if id == "bard" else 200.0, 4.0])
			return true
	return false
