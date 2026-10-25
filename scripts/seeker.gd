class_name Seeker
extends CharacterBody3D
## 술래 AI (공통 부분)
## 실제 술래는 이 스크립트를 물려받은 3종 중 하나가 매 판 랜덤으로 나옵니다.
##   seeker_ghost.gd   유령     (벽 통과, 대쉬)
##   seeker_butcher.gd 도살자   (쇠사슬 그랩, 도끼 던지기)
##   seeker_rat.gd     역병의 쥐 (쥐 소환, 플라스크)
##
## "상태 머신" 방식: 지금 상태(state)에 따라 하는 행동이 달라집니다.
##   PATROL(순찰)  ─소리를 들음→  INVESTIGATE(소리 난 곳으로)  ─도착→  SEARCH(두리번)  ─시간 끝→ PATROL
##      └──────────── 생존자가 눈에 보임 → CHASE(추격)
##   CHASE 중 대상이 얼음 → 10초 동안 20% 빨라져서 PATROL (다른 생존자 찾기)
##   CHASE 중 대상을 놓침 → INVESTIGATE(마지막으로 본 곳)
##   피 흘리는 생존자가 있으면 → 그 위치로 따라감
##   강펀치 맞음 → KNOCKBACK(날아감) → PATROL
##   봉인석 3개 완료 → DISABLED(작동 정지)
##
## 얼음 상태 생존자는 무적이라 잡거나 맞힐 수 없고,
## 카멜레온 능력을 쓴 생존자는 보지도 듣지도 못합니다 (부딪히면 잡힘).

## 히든 캐릭터의 붕괴에 맞아 죽었을 때
signal killed(sk: Seeker)

enum State { PATROL, INVESTIGATE, SEARCH, CHASE, CAMP, KNOCKBACK, DISABLED }

## 정전 중 시야 배율 (main.gd 가 바꿈)
static var dark_sight := 1.0

## 술래 이름 (화면 표시용)
const TYPE_NAMES := {"rat": "역병의 쥐", "ghost": "유령", "butcher": "도살자", "puppeteer": "인형사", "hound": "케르베로스",
		"spider": "거미 여왕", "diet": "하마", "psycho": "사이코", "executioner": "처형인", "mannequin": "마네킹", "witch": "안개 마녀"}
## 사람이 조종할 때 알려 주는 패시브
const TYPE_PASSIVES := {"ghost": "벽 속에 있으면 안 보여요", "mannequin": "누가 쳐다보면 굳어서 못 움직이고 못 잡아요",
		"psycho": "잡으면 쇠사슬에 묶어 끌고 다녀요 · 피 흘리는 생존자가 있으면 광란",
		"executioner": "도끼: 잡는 거리가 길고 무적·갑옷도 무시", "diet": "잡은 생존자의 능력을 빼앗아요",
		"witch": "안개 중엔 내 발소리가 웃음소리로 들려요", "hound": "분신도 생존자를 잡을 수 있어요",
		"rat": "쥐에게 물린 생존자는 피를 흘려 위치가 드러나요", "spider": "새끼 거미가 묶으면 위치가 보여요",
		"butcher": "", "puppeteer": "저주 인형이 비명을 지르면 위치가 보여요"}

const STEP_SOUNDS := [
	preload("res://audio/step_heavy_1.wav"),
	preload("res://audio/step_heavy_2.wav"),
	preload("res://audio/step_heavy_3.wav"),
]
## 머리 위 상태 표시가 보이는 거리 (이보다 멀면 안 보임)
const LABEL_VISIBLE_DISTANCE := 12.0

## 술래 종류 (main.gd 가 정해 줌): "ghost" / "butcher" / "rat"
var seeker_type := "ghost"
## 순찰할 맵 범위 (main.gd 가 맵 크기에 맞게 정해 줌)
var map_half_size := 46.0
var state: State = State.PATROL
## 붕괴에 맞아 죽었는지
var is_killed := false
var chase_target: Survivor = null

var _timer := 0.0
var _lost_sight_time := 0.0
var _last_seen_pos := Vector3.ZERO
var _speed_mult := 1.0
var _stun_left := 0.0
var _reveal_left := 0.0
## 능력 사용 중(대쉬 준비, 던지기 등) 멈춰 있는 시간
var _lock_left := 0.0
var _step_timer := 0.0
var _step_index := 0
var _bleed_check_timer := 0.0
## 중력술사 무중력: 공중에 떠 있는 남은 시간
var _float_left := 0.0
## 사냥꾼 화살: 피 흘리는 중
var is_bleeding := false
var _drip_timer := 0.0
## 똑똑한 수색·추격용 기억
var _search_points: Array = []
var _searching_spots := false
var _target_vel := Vector3.ZERO
## 감속 (무중력 구슬): 남은 시간과 비율
var _slow_left := 0.0
var _slow_factor := 0.0
## 어딘가에 끼어서 못 움직이는지 확인용
var _attack_left := 0.0
## 멀티: 다른 컴퓨터에서는 방장이 보낸 위치·상태만 따라감
var net_puppet := false
var attack_seq := 0
var _net_pos := Vector3.ZERO
var _smooth := NetSmooth.new()
var _net_rot := 0.0
var _net_vel := Vector3.ZERO
var _net_has := false
var _net_attack_seq := 0
## 폭주 중 (판 시작 10분 뒤, 또는 탈출 단계)
var enraged := false
var _attack_target: Survivor = null
var _attack_audio: AudioStreamPlayer3D

var _stuck_timer := 0.0
var _stuck_pos := Vector3.ZERO
## 쫓던 생존자가 얼음하면 잠깐 빨라짐 (다른 생존자를 찾으러)
var _freeze_boost_left := 0.0
## 두리번거릴 때 기준 방향
var _search_yaw := 0.0
var _search_t := 0.0

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var body: SeekerBody = $Body
@onready var state_label: Label3D = $StateLabel
@onready var reveal_label: Label3D = $RevealLabel
@onready var step_audio: AudioStreamPlayer3D = $Footstep
@onready var collision: CollisionShape3D = $Collision


func _ready() -> void:
	add_to_group("seeker")
	collision_mask |= 16  # 넘어진 판자(prop.gd PALLET_LAYER)에 막힘
	NoiseBus.noise_made.connect(_on_noise_made)
	body.build(seeker_type)
	body.scale *= GameConfig.num("seeker", "body_scale", 1.0)  # 오늘의 규칙 '꼬마 술래'
	# 종류별 속도 (기본은 모두 1.0 = 같은 속도. 스테이지가 올라도 빨라지지 않음)
	_speed_mult = GameConfig.num(seeker_type, "speed_multiplier", 1.0) * GameConfig.num("seeker", "move_speed", 1.1)
	step_audio.max_distance = GameConfig.num("view", "seeker_step_hear_distance", 32.0)
	# 술래 발소리 크기 (balance.cfg [view] seeker_step_volume_db / seeker_step_loudness)
	step_audio.volume_db = GameConfig.num("view", "seeker_step_volume_db", 6.0)
	step_audio.max_db = maxf(step_audio.volume_db, 6.0)
	step_audio.unit_size = GameConfig.num("view", "seeker_step_loudness", 10.0)
	# 술래마다 다른 공격 소리 (audio/attack_<종류>.wav, 필요할 때 불러옴)
	_attack_audio = AudioStreamPlayer3D.new()
	_attack_audio.max_distance = 30.0
	_attack_audio.unit_size = 4.0
	var path := "res://audio/attack_%s.wav" % seeker_type
	if ResourceLoader.exists(path):
		_attack_audio.stream = load(path)
	add_child(_attack_audio)
	reveal_label.visible = false
	_enter_patrol()


## 추격 속도 = 유저 달리기 속도 × chase_vs_run (기본 1.375 = 37.5% 빠름)
func chase_speed() -> float:
	return GameConfig.num("player", "run_speed", 7.5) * GameConfig.num("seeker", "chase_vs_run", 1.375)


func _process(delta: float) -> void:
	body.animate(delta, Vector2(velocity.x, velocity.z).length())


## 폭주: 이동속도·공격 속도 증가, 눈이 붉게
func enrage() -> void:
	if enraged or is_killed:
		return
	enraged = true
	_speed_mult *= 1.0 + GameConfig.num("seeker", "rage_move_speed", 0.15)
	body.set_rage()


## 생존자로 변신 중인지 (안개 마녀)
func is_disguised() -> bool:
	return false


func is_active() -> bool:
	return state != State.DISABLED


## 유저 화면에 보이는 상태인지 (유령이 벽 속에 있으면 false)
func visible_to_players() -> bool:
	return body.visible


## 봉인석이 모두 가동되면 main.gd가 불러 줍니다.
func disable() -> void:
	state = State.DISABLED
	chase_target = null
	velocity = Vector3.ZERO
	body.visible = true
	body.set_tint(Color(0.35, 0.35, 0.4))
	_update_label()


## 히든 캐릭터 붕괴에 맞음: 술래가 죽음 (봉인과 같이 더 이상 움직이지 않고 사라짐)
func kill() -> void:
	if is_killed:
		return
	is_killed = true
	state = State.DISABLED
	chase_target = null
	velocity = Vector3.ZERO
	remove_from_group("seeker")
	collision.set_deferred("disabled", true)
	visible = false
	set_physics_process(false)
	killed.emit(self)


## 카메라맨 플래시: seconds 동안 스턴 (못 움직이고 못 봄, 능력도 못 씀)
func stun(seconds: float) -> void:
	_attack_left = 0.0  # 스턴되면 공격도 취소
	_stun_left = max(_stun_left, seconds)
	_on_stunned()
	if state == State.CHASE and chase_target:
		_last_seen_pos = chase_target.global_position


## 카메라맨 설치 카메라에 찍혔을 때: 모두에게 위치 표시
func reveal(seconds: float) -> void:
	_reveal_left = max(_reveal_left, seconds)


## 술래가 어떤 위치를 알게 됨 (쥐 부하가 죽은 곳 등)
func alert_to(pos: Vector3) -> void:
	if state == State.DISABLED or state == State.KNOCKBACK or state == State.CHASE:
		return
	_investigate(pos)


## 사나이 강펀치: dir 방향으로 맵 끝까지 날아감 (떨어진 뒤 land_stun 메타만큼 기절)
func knockback(dir: Vector3) -> void:
	if state == State.DISABLED or state == State.KNOCKBACK:
		return
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = -global_basis.z
	dir = dir.normalized()
	# 맵 경계까지 얼마나 갈 수 있는지 계산
	var t: float = INF
	if absf(dir.x) > 0.001:
		t = min(t, ((map_half_size if dir.x > 0.0 else -map_half_size) - global_position.x) / dir.x)
	if absf(dir.z) > 0.001:
		t = min(t, ((map_half_size if dir.z > 0.0 else -map_half_size) - global_position.z) / dir.z)
	var end: Vector3 = global_position + dir * maxf(t, 0.0)
	end = NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), Vector3(end.x, 0.0, end.z))

	state = State.KNOCKBACK
	chase_target = null
	velocity = Vector3.ZERO
	_lock_left = 0.0
	_on_knocked_back()
	collision.set_deferred("disabled", true)
	var start := global_position
	var duration := clampf(start.distance_to(end) / 40.0, 0.3, 2.5)
	# 낮게 깔려서 맵 끝까지 쭉 날아감 (장애물은 뚫고 지나감)
	var fly := func(p: float) -> void: global_position = start.lerp(end, p) + Vector3.UP * sin(p * PI) * 1.5
	var tw := create_tween()
	tw.tween_method(fly, 0.0, 1.0, duration)
	tw.tween_callback(_on_knockback_landed)


func _on_knockback_landed() -> void:
	collision.set_deferred("disabled", false)
	if state == State.KNOCKBACK:
		_enter_patrol()
	if has_meta("land_stun"):  # 사나이 강펀치: 떨어진 뒤 잠깐 기절
		stun(float(get_meta("land_stun")))
		remove_meta("land_stun")


# ---------------------------------------------------------------- 매 프레임

func _physics_process(delta: float) -> void:
	if dormant:
		return
	if net_puppet:
		_net_puppet_update(delta)
		return
	if possessed_by:
		_possessed_update(delta)
		return
	_stun_left = max(0.0, _stun_left - delta)
	_reveal_left = max(0.0, _reveal_left - delta)
	_lock_left = max(0.0, _lock_left - delta)
	_slow_left = max(0.0, _slow_left - delta)
	_freeze_boost_left = max(0.0, _freeze_boost_left - delta)
	reveal_label.visible = _reveal_left > 0.0
	if is_bleeding and state != State.DISABLED:
		_drip(delta)

	# 무중력: 공중에 둥둥 떠서 내려오지도, 잡지도 못함
	if _float_left > 0.0 and state != State.DISABLED:
		_float_left -= delta
		_stop()
		velocity.y = 0.0
		body.position.y = lerpf(body.position.y, 3.0 + sin(Time.get_ticks_msec() / 300.0) * 0.2, 4.0 * delta)
		body.rotate_y(1.2 * delta)
		body.rotation.z = sin(Time.get_ticks_msec() / 500.0) * 0.3
		state_label.text = "~ 둥둥 ~"
		return
	if body.position.y > 0.01:
		body.position.y = lerpf(body.position.y, 0.0, 8.0 * delta)
		body.rotation.z = lerpf(body.rotation.z, 0.0, 8.0 * delta)
	# 무중력으로 빙글빙글 돈 몸 방향을 원래대로 (안 그러면 뒤로 달리는 것처럼 보임)
	if absf(body.rotation.y) > 0.001:
		body.rotation.y = lerp_angle(body.rotation.y, 0.0, 10.0 * delta)
		if absf(body.rotation.y) < 0.01:
			body.rotation.y = 0.0

	if state == State.KNOCKBACK:
		_update_label()
		return

	_apply_gravity(delta)

	if state == State.DISABLED or _stun_left > 0.0:
		_stop()
		_after_move(delta)
		_update_label()
		return

	_update_attack(delta)
	_catch_nearby_survivors()
	if state != State.CHASE:
		_look_for_survivors()
		_follow_blood(delta)

	_ability_update(delta)

	if _lock_left > 0.0:
		# 팔을 휘두르는 동안에는 노린 생존자를 계속 쫓아감 (멈추면 달리는 생존자가 사거리 밖으로 빠져나감)
		if _attack_left > 0.0 and _attack_target and is_instance_valid(_attack_target):
			_move_dir(_attack_target.global_position - global_position, delta, chase_speed())
		else:
			_stop()  # 능력 쓰는 중 (대쉬 준비 등)
	else:
		match state:
			State.PATROL:
				if _destination_reached():
					_pick_patrol_point()
				_move_to_destination(delta, GameConfig.num("seeker", "patrol_speed", 3.0))
			State.INVESTIGATE:
				if _destination_reached():
					_enter_search()
				else:
					_move_to_destination(delta, GameConfig.num("seeker", "investigate_speed", 4.8))
			State.SEARCH:
				# 수색: 멈춰 서 있지 않고 주변(풀숲·사물함·구석)을 빠르게 돌며 살핌
				_search_t += delta
				_timer -= delta
				if _destination_reached() or _timer <= 0.0:
					if not _search_points.is_empty() and _timer > -4.0:
						_set_destination(_search_points.pop_front())
					else:
						_enter_patrol()
				_move_to_destination(delta, GameConfig.num("seeker", "investigate_speed", 4.8) * 0.9)
				# 걸으면서 좌우로 고개를 돌려 봄
				body.rotation.y = sin(_search_t * 3.0) * 0.45
			State.CAMP:
				_stop()
				_timer -= delta
				if _timer <= 0.0:
					_enter_patrol()
			State.CHASE:
				_update_chase(delta)

	_after_move(delta)
	_check_stuck(delta)
	_footsteps(delta)
	_update_label()


## 가려고 하는데 잘 못 움직이면(차·벽에 끼임, 길이 막힘) 1초 안에 길을 다시 찾고, 그래도 안 되면 다른 곳으로
var _stuck_tries := 0
var _since_contact := 0.0

func _check_stuck(delta: float) -> void:
	if state == State.CHASE or state == State.INVESTIGATE:
		_since_contact = 0.0
	else:
		_since_contact += delta
	var trying := state == State.PATROL or state == State.INVESTIGATE or state == State.CHASE or state == State.SEARCH
	if not trying or _lock_left > 0.0 or _attack_left > 0.0:
		_stuck_timer = 0.0
		_stuck_pos = global_position
		return
	_stuck_timer += delta
	if _stuck_timer >= 1.0:
		if global_position.distance_to(_stuck_pos) < 0.5:
			_stuck_tries += 1
			if _stuck_tries == 1 and state != State.CHASE:
				# 옆으로 살짝 비켜서 다시 길 찾기
				var side := global_basis.x * (2.5 if randf() < 0.5 else -2.5)
				_set_destination(NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), global_position + side))
			elif _stuck_tries >= 2:
				_stuck_tries = 0
				if state == State.CHASE and chase_target:
					_set_destination(chase_target.global_position)
				else:
					_enter_patrol()
		else:
			_stuck_tries = 0
		_stuck_timer = 0.0
		_stuck_pos = global_position


# ---------------------------------------------------------------- 종류별로 바꿔 쓰는 부분 (자식 스크립트가 덮어씀)

## 매 프레임 능력 판단
func _ability_update(_delta: float) -> void:
	pass


func _on_stunned() -> void:
	pass


func _on_knocked_back() -> void:
	pass


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0


## 실제로 움직이기 (유령은 벽을 무시하고 움직임)
func _after_move(_delta: float) -> void:
	move_and_slide()


func _set_destination(pos: Vector3) -> void:
	agent.target_position = pos


func _destination_reached() -> bool:
	return agent.is_navigation_finished()


## 목적지까지 길 따라 이동 (속도만 정하고, 실제 이동은 _after_move)
func _move_to_destination(delta: float, speed: float) -> void:
	if agent.is_navigation_finished():
		_stop()
		if state == State.PATROL:
			_pick_patrol_point()  # 도착하면 바로 다음 곳으로 (멍하니 서 있지 않음)
		return
	var next := agent.get_next_path_position()
	if Vector2(next.x - global_position.x, next.z - global_position.z).length() < 0.3:
		next = Survivor.next_flat_point(agent, global_position)
	_move_dir(next - global_position, delta, speed)


func _move_dir(dir: Vector3, delta: float, speed: float) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		_stop()
		return
	dir = dir.normalized()
	var m := _speed_mult * _zone_slow_multiplier() * crowd_mult()
	if _slow_left > 0.0:
		m *= 1.0 - _slow_factor
	if _freeze_boost_left > 0.0:
		m *= 1.0 + GameConfig.num("seeker", "frozen_boost", 0.2)
	# 방향을 크게 꺾을 때는 먼저 몸을 돌리면서 천천히 (뒤로 달리는 것처럼 보이지 않게)
	var diff := absf(angle_difference(rotation.y, atan2(-dir.x, -dir.z)))
	if diff > 1.0:
		m *= clampf(1.0 - (diff - 1.0) / 1.6, 0.25, 1.0)
	velocity.x = dir.x * speed * m
	velocity.z = dir.z * speed * m
	_face(dir, delta, 14.0)


## 등불 결계 안에 있으면 느려짐
func _zone_slow_multiplier() -> float:
	for w in get_tree().get_nodes_in_group("ward"):
		var r: float = w.get_meta("radius", 0.0)
		if Vector2(w.global_position.x, w.global_position.z).distance_to(Vector2(global_position.x, global_position.z)) <= r:
			return 1.0 - float(w.get_meta("slow", 0.5))
	return 1.0


## 연막 안이면 true (연막 속에서는 아무도 못 봄)
func _in_smoke(p: Vector3) -> bool:
	for sm in get_tree().get_nodes_in_group("smoke"):
		var r: float = sm.get_meta("radius", 0.0)
		if Vector2(sm.global_position.x, sm.global_position.z).distance_to(Vector2(p.x, p.z)) <= r:
			return true
	return false


## 중력술사 무중력: seconds 동안 공중에 띄움
func float_up(seconds: float) -> void:
	if state == State.DISABLED or state == State.KNOCKBACK:
		return
	_float_left = maxf(_float_left, seconds)
	chase_target = null
	_lock_left = 0.0


## 무중력 구슬: seconds 동안 factor 만큼 느려짐 (0.6 = 60% 느려짐)
func slow(seconds: float, factor: float) -> void:
	_slow_left = maxf(_slow_left, seconds)
	_slow_factor = factor


## 앞(-Z 방향)이 dir 을 보도록 회전 → 시야 방향도 같이 돌아감
func _face(dir: Vector3, delta: float, turn_speed := 8.0) -> void:
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), turn_speed * delta)


func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


## 무거운 발소리: 헤드셋으로 술래가 어느 쪽에서 오는지 들을 수 있음
func _footsteps(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.5:
		_step_timer = 0.0
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = clampf(2.2 / speed, 0.28, 0.75)
		_step_index = (_step_index + 1) % STEP_SOUNDS.size()
		step_audio.stream = STEP_SOUNDS[_step_index]
		step_audio.pitch_scale = randf_range(0.9, 1.05)
		step_audio.play()


# ---------------------------------------------------------------- 감각 (소리 / 시야 / 피)

## 어디선가 소리가 났을 때 (NoiseBus가 알려 줌)
func _on_noise_made(pos: Vector3, radius: float, source: Node) -> void:
	if possessed_by:
		_poss_hear(pos, radius, source)
		return
	if state == State.DISABLED or state == State.CHASE or state == State.KNOCKBACK:
		return  # 추격 중에는 다른 소리에 한눈팔지 않음
	if source is Survivor and (source as Survivor).is_hidden_from_seeker():
		return  # 카멜레온 능력 중이면 소리도 못 들음
	if global_position.distance_to(pos) > radius * hearing_mult():
		return  # 너무 멀어서 안 들림
	_investigate(pos)


## 듣는 거리 배율 (정전 중에는 눈 대신 귀로 쫓아서 더 멀리 들음)
func hearing_mult() -> float:
	var m := GameConfig.num("seeker", "hearing_multiplier", 1.0)
	if dark_sight < 0.99:
		m *= GameConfig.num("blackout", "seeker_hearing", 1.5)
	return m


## 사람이 조종하는 술래: AI 처럼 귀로 들을 수 없으니, 들릴 만한 소리를 화면에 붉은 파동으로 보여 줌
## (오늘의 규칙 '귀 밝은 술래'·정전 중에만. 무리 소음은 main.gd 가 항상 보냄)
var _ping_at := {}
func _poss_hear(pos: Vector3, radius: float, source: Node) -> void:
	if source == possessed_by or state == State.DISABLED:
		return
	if GameConfig.num("seeker", "hear_ping", 0.0) < 0.5 and dark_sight > 0.99:
		return
	if source is Survivor and (source as Survivor).is_hidden_from_seeker():
		return
	if global_position.distance_to(pos) > radius * hearing_mult():
		return
	var key: int = source.get_instance_id() if source else int(pos.x) * 1000 + int(pos.z)
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_ping_at.get(key, -10.0)) < 0.9:
		return
	_ping_at[key] = now
	_poss_call("poss_noise_ping", [pos, false])


## 생존자를 노릴 수 있는 상태인지 (얼음 무적, 카멜레온 감지 불가)
func _is_targetable(s: Survivor) -> bool:
	return s != null and not s.is_dead and not s.is_frozen and not s.is_hidden_from_seeker() and s.chained_by == null


## 생존자가 눈에 보이는지 검사 (기본: 멀리 보는 시야 12m. 추격 중 놓치지 않기용)
func _can_see(s: Survivor, max_range := -1.0) -> bool:
	if not _is_targetable(s) or _stun_left > 0.0:
		return false
	if _in_smoke(s.global_position) or _in_smoke(global_position):
		return false
	var to_target := s.global_position - global_position
	to_target.y = 0.0
	var dist := to_target.length()

	var sight := max_range if max_range > 0.0 else GameConfig.num("seeker", "far_sight_range", 12.0)
	sight *= dark_sight  # 정전 중에는 술래도 잘 못 봄
	if s.is_in_grass():
		sight = min(sight, GameConfig.num("seeker", "grass_sight_range", 2.0))
	if dist > sight:
		return false

	# 아주 가까우면 등 뒤라도 눈치챔. 그 외에는 앞쪽 시야각 안에 있어야 함
	if dist > GameConfig.num("seeker", "sense_radius", 1.8):
		var forward := -global_basis.z
		forward.y = 0.0
		var max_angle := deg_to_rad(GameConfig.num("seeker", "sight_angle", 45.0))
		if forward.normalized().angle_to(to_target.normalized()) > max_angle:
			return false
	return _clear_line(s)


## 벽에 가려져 있지 않은지 레이캐스트로 확인
func _clear_line(s: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP * 1.6, s.global_position + Vector3.UP * 1.0)
	query.exclude = [get_rid(), (s as CollisionObject3D).get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## 두 단계 시야
## - 앞쪽 부채꼴 4m 안: 바로 알아챔
## - 그 밖 12m까지: notice_time 초 동안 계속 보여야 알아챔 (머리 위 ? 가 차오름). 안 보이면 서서히 잊음
var _notice := {}
func _look_for_survivors() -> void:
	var dt := get_physics_process_delta_time()
	var near := GameConfig.num("seeker", "near_sight_range", 4.0)
	var need := GameConfig.num("seeker", "notice_time", 1.5)
	var best := 0.0
	for node in get_tree().get_nodes_in_group("survivor"):
		var s := node as Survivor
		if _can_see(s, near):
			_notice.clear()
			_start_chase(s)
			return
		if _can_see(s):
			_notice[s] = float(_notice.get(s, 0.0)) + dt
			if _notice[s] >= need:
				_notice.clear()
				_start_chase(s)
				return
		elif _notice.has(s):
			_notice[s] = maxf(0.0, _notice[s] - dt * 0.5)
		best = maxf(best, float(_notice.get(s, 0.0)) / need)
	_notice_ratio = best


## 멀리서 알아채는 중인 정도 (0~1, 머리 위 표시용)
var _notice_ratio := 0.0


## 피 흘리는 생존자가 있으면 핏자국을 보고 따라감 (1초마다 위치 갱신)
func _follow_blood(delta: float) -> void:
	_bleed_check_timer -= delta
	if _bleed_check_timer > 0.0:
		return
	_bleed_check_timer = 1.0
	var best: Survivor = null
	var best_d := GameConfig.num("bleed", "track_distance", 35.0)
	for node in get_tree().get_nodes_in_group("survivor"):
		var s := node as Survivor
		if _is_targetable(s) and s.bleed_time_left > 0.0:
			var d := global_position.distance_to(s.global_position)
			if d < best_d:
				best = s
				best_d = d
	if best:
		_investigate(best.global_position)


## 가까이 있는 "움직일 수 있는" 생존자를 잡음
## (얼음은 무적. 카멜레온 동화는 감지는 못 해도 부딪히면 잡힘)
## 보통은 공격 모션(0.25초)을 먼저 보여 주고, 그때도 범위 안에 있으면 잡힘 → 구르기로 피할 수 있음
## reach 를 직접 넣으면(유령 대쉬 등 스킬) 모션 없이 바로 잡음
func _catch_nearby_survivors(reach := -1.0) -> void:
	var instant := reach >= 0.0
	if not instant:
		if _attack_left > 0.0:
			return
		reach = _catch_reach()
	for node in get_tree().get_nodes_in_group("survivor"):
		var s := node as Survivor
		if _catchable(s) and global_position.distance_to(s.global_position) <= reach:
			if instant:
				_kill_survivor(s)
			elif _before_attack(s):
				_start_attack(s)
			return


func _catchable(s: Survivor) -> bool:
	return s != null and not s.is_frozen and not s.is_dead and not s.is_shadowed() and not s.is_invulnerable() and s.in_locker == null and s.chained_by == null


func _kill_survivor(s: Survivor) -> void:
	s.die()
	_poss_caught(s)
	if s.is_dead and s == chase_target:
		chase_target = null
		_since_contact = 99.0  # 바로 다음 생존자를 찾아 압박
		_enter_patrol()


## 멀티: 방장이 보낸 술래 상태
func net_target(pos: Vector3, rot: float, vel: Vector3, st: int, vis: bool, rage: bool, atk: int, poss: Array = []) -> void:
	poss_net = poss
	if _smooth.push(pos, rot, vel) or not _net_has:
		global_position = pos
	_net_pos = pos
	_net_rot = rot
	_net_vel = vel
	_net_has = true
	state = st as State
	body.visible = vis
	if rage and not enraged:
		enraged = true
		body.set_rage()
	if atk != _net_attack_seq:
		if _net_has and _net_attack_seq != 0 or atk > 0:
			body.attack(GameConfig.num("seeker", "attack_windup", 0.08))
			if _attack_audio.stream:
				_attack_audio.play()
		_net_attack_seq = atk


func _net_puppet_update(delta: float) -> void:
	if possessed_by and is_instance_valid(possessed_by) and not possessed_by.net_puppet and state != State.KNOCKBACK:
		# 내가 변신한 술래: 내 캐릭터 위치를 바로 따라감 (방장 응답을 기다리면 화면이 늦음)
		_follow_possessor(delta)
		_footsteps(delta)
		return
	if not _net_has:
		return
	var smp := _smooth.sample()
	var tp: Vector3 = smp[0] if not smp.is_empty() else _net_pos
	var ty: float = smp[1] if not smp.is_empty() else _net_rot
	global_position = global_position.lerp(tp, clampf(30.0 * delta, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, ty, clampf(20.0 * delta, 0.0, 1.0))
	velocity = _net_vel
	_footsteps(delta)
	_update_label()


# ---------------------------------------------------------------- 멀티 '술래 변신' 모드

## 아직 아무도 변하지 않음: 숨어 있고 아무것도 안 함
var dormant := false
## 술래로 변한 생존자 (그 사람이 직접 조종)
var possessed_by: Survivor = null
var _poss_last := Vector3.ZERO


func make_dormant() -> void:
	dormant = true
	visible = false
	collision.set_deferred("disabled", true)
	global_position = Vector3(0, -60, 0)


func possess(s: Survivor) -> void:
	possessed_by = s
	dormant = false
	visible = true
	body.visible = true
	collision.set_deferred("disabled", false)
	chase_target = null
	state = State.CHASE  # 생존자들 화면의 긴장 연출용 (실제로는 사람이 조종)
	global_position = s.global_position
	_poss_last = s.global_position
	_turn_burst(s.global_position)


## 변신하는 순간: 검붉은 연기가 바닥을 따라 확 퍼지고 붉은 빛이 번쩍 (보기만 하는 효과)
## 부드러운 연기 덩어리(가장자리가 흐린 판)라서 카메라 가까이 와도 화면을 가리지 않음
func _turn_burst(at: Vector3) -> void:
	var root := get_tree().current_scene
	var pt := CPUParticles3D.new()
	pt.one_shot = true
	pt.amount = 36
	pt.lifetime = 1.6
	pt.explosiveness = 0.85
	pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	pt.emission_sphere_radius = 0.6
	pt.direction = Vector3(0, 0.25, 0)
	pt.spread = 180.0
	pt.flatness = 0.7  # 옆으로 퍼짐
	pt.initial_velocity_min = 1.8
	pt.initial_velocity_max = 3.6
	pt.damping_min = 2.0
	pt.damping_max = 3.0
	pt.gravity = Vector3(0, 0.5, 0)
	pt.scale_amount_min = 0.7
	pt.scale_amount_max = 1.3
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.6))
	pt.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.35, 0.02, 0.03, 0.55))
	ramp.set_color(1, Color(0.06, 0.01, 0.01, 0.0))
	pt.color_ramp = ramp
	var q := QuadMesh.new()
	q.size = Vector2(1.2, 1.2)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.proximity_fade_enabled = true  # 카메라·바닥 가까이선 흐려짐
	mat.proximity_fade_distance = 0.8
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	mat.albedo_texture = tex
	q.material = mat
	pt.mesh = q
	root.add_child(pt)
	pt.global_position = at + Vector3.UP * 0.6
	pt.emitting = true
	get_tree().create_timer(2.5).timeout.connect(pt.queue_free)
	_roar_ring(at)
	# 붉은 빛이 번쩍했다가 사라짐
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.15, 0.1)
	light.omni_range = 7.0
	light.light_energy = 0.0
	root.add_child(light)
	light.global_position = at + Vector3.UP * 1.2
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 4.0, 0.08)
	tw.tween_property(light, "light_energy", 0.0, 0.9).set_ease(Tween.EASE_IN)
	tw.tween_callback(light.queue_free)


func _follow_possessor(_delta: float) -> void:
	var p := possessed_by.global_position
	var mv := p - _poss_last
	mv.y = 0.0
	velocity = mv / maxf(get_physics_process_delta_time(), 0.001)
	if mv.length() > 0.004:
		rotation.y = lerp_angle(rotation.y, atan2(-mv.x, -mv.z), 0.35)
	global_position = p
	_poss_last = p


## 사람이 조종하는 술래 (방장 컴퓨터): 위치는 변한 사람을 따라가고, 닿으면 잡는 건 원래처럼
func _possessed_update(delta: float) -> void:
	if not is_instance_valid(possessed_by):
		possessed_by = null
		return
	_stun_left = max(0.0, _stun_left - delta)
	_reveal_left = max(0.0, _reveal_left - delta)
	_lock_left = max(0.0, _lock_left - delta)
	_slow_left = max(0.0, _slow_left - delta)
	reveal_label.visible = _reveal_left > 0.0
	if state == State.KNOCKBACK:
		_update_label()
		return
	if state != State.DISABLED:
		state = State.CHASE
	_follow_possessor(delta)
	for i in 2:
		_pcd[i] = maxf(0.0, _pcd[i] - delta)
	if state != State.DISABLED and _stun_left <= 0.0 and _float_left <= 0.0:
		_ability_update(delta)  # 계속되는 능력·패시브만 (자동으로 쓰는 부분은 종류 스크립트가 possessed_by 면 건너뜀)
		_possessed_skill_tick(delta)
		_update_attack(delta)
		_catch_nearby_survivors()
	_float_left = max(0.0, _float_left - delta)
	_footsteps(delta)
	_update_label()


## 변신한 사람이 지금 못 움직이는 상태 (기절·날아가는 중·무중력·봉인·능력 쓰는 중)
func possessed_frozen() -> bool:
	return state == State.DISABLED or state == State.KNOCKBACK or _stun_left > 0.0 or _float_left > 0.0 or poss_lock() > 0.05


## 인원 보정 배율: 술래 1마리가 맡는 생존자 수가 많을수록 빨라짐 (balance.cfg [seeker] crowd_*)
## 판에 들어온 생존자 수 기준이라 누가 잡혀도 줄지 않음. 1초마다만 다시 셈
var _crowd := 1.0
var _crowd_at := -10.0
func crowd_mult() -> float:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _crowd_at < 1.0:
		return _crowd
	_crowd_at = now
	var game := get_tree().get_first_node_in_group("game")
	if game == null:
		return _crowd
	var surv := 0
	for s in game.get("survivors"):
		if is_instance_valid(s) and s.turned_seeker == null:
			surv += 1
	var hunters := 0
	for k in game.get("seekers"):
		if is_instance_valid(k) and not k.dormant and not k.is_killed:
			hunters += 1
	var per := float(surv) / maxf(1.0, hunters)
	var extra := clampf(per - GameConfig.num("seeker", "crowd_base", 4.0), 0.0, GameConfig.num("seeker", "crowd_max", 4.0))
	_crowd = 1.0 + extra * GameConfig.num("seeker", "crowd_step", 0.04)
	return _crowd


## 변신한 사람의 최고 속도 (변신한 마녀는 생존자처럼 걸어야 함). 기본은 제한 없음
func possessed_max_speed() -> float:
	return INF


## 변신한 사람의 이동 속도 배율 (술래 종류 속도·결계·무중력 구슬 감속)
func possessed_speed_mult() -> float:
	var m := _speed_mult * _zone_slow_multiplier() * crowd_mult()
	if _slow_left > 0.0:
		m *= 1.0 - _slow_factor
	return m


# ---------------------------------------------------------------- 사람이 조종하는 술래의 능력 ([R] / [T])
## 방장 컴퓨터가 술래를 움직이므로 능력도 방장이 씀 (손님은 Net.seeker_skill 로 부탁)
## 종류 스크립트가 poss_skills() / _poss_do() 를 바꿔서 자기 능력을 넣음

## 남은 쿨타임 [R, T] (방장이 셈)
var _pcd := [0.0, 0.0]
## 다른 컴퓨터: 방장이 보내 준 [R 쿨, T 쿨, 멈춤 시간, R 덧붙임 글자, T 덧붙임 글자]
var poss_net: Array = []


## [이름, 설명] × 2 (기본: 사냥 본능 / 포효)
func poss_skills() -> Array:
	return [["사냥 본능", "25m 안 생존자가 4초 동안 벽 너머로 보여요"],
			["포효", "8m 안 생존자가 겁에 질려 2.5초 동안 40% 느려져요"]]


## 능력 이름 옆에 붙는 글자 (충전 개수·켜짐 등)
func poss_note(_n: int) -> String:
	return ""


## 남은 쿨타임 (손님 컴퓨터는 방장이 보내 준 값)
func poss_cd(n: int) -> float:
	if not poss_net.is_empty():
		return float(poss_net[n])
	return _pcd[n]


func poss_note_any(n: int) -> String:
	if not poss_net.is_empty():
		return str(poss_net[3 + n])
	return poss_note(n)


## 능력을 쓰느라(던지기·블랙홀·처형 등) 또는 기절해서 못 움직이는 남은 시간
func poss_lock() -> float:
	if not poss_net.is_empty():
		return float(poss_net[2])
	return maxf(maxf(_lock_left - 0.2, _stun_left), _float_left)


## 방장 → 스냅샷에 실어 보낼 값
func poss_pack() -> Array:
	return [snappedf(_pcd[0], 0.1), snappedf(_pcd[1], 0.1), snappedf(poss_lock(), 0.05), poss_note(0), poss_note(1)]


## (방장) 능력 사용. aim = 조종하는 사람의 카메라 방향. 성공하면 "" / 못 쓰면 이유
func poss_use(n: int, aim: Vector3) -> String:
	if n < 0 or n > 1 or possessed_by == null:
		return ""
	if state == State.DISABLED:
		return "봉인되어 능력을 쓸 수 없어요"
	if _stun_left > 0.0 or _float_left > 0.0 or state == State.KNOCKBACK:
		return "기절해서 능력을 쓸 수 없어요"
	if _pcd[n] > 0.0:
		return "%s 준비 중... %d초" % [poss_skills()[n][0], ceili(_pcd[n])]
	aim.y = 0.0
	aim = aim.normalized() if aim.length() > 0.01 else -global_basis.z
	var r = _poss_do(n, aim)
	if r is String:
		return r
	_pcd[n] = float(r)
	return ""


## 종류별 능력 (방장). 성공 = 쿨타임(초) / 실패 = 이유 글자
func _poss_do(n: int, _aim: Vector3):
	if n == 0:
		_poss_call("poss_sense", [25.0, 4.0])
		_poss_roar_sound(1.4)
		return 25.0
	return _poss_roar(8.0, 0.4, 2.5, 30.0)


## 포효: 가까운 생존자 감속 + 화면 흔들림·소리
func _poss_roar(radius: float, slow_amt: float, secs: float, cd: float):
	_poss_roar_sound(0.75)
	_lock_left = maxf(_lock_left, 0.6)
	body.attack(0.25)
	for node in get_tree().get_nodes_in_group("survivor"):
		var s := node as Survivor
		if s and not s.is_dead and not s.is_frozen and global_position.distance_to(s.global_position) <= radius:
			s.apply_slow(slow_amt, secs)
			_notify(s, "술래의 포효에 다리가 얼어붙었어요!")
	_roar_ring(global_position)
	_fx("roar", global_position)
	return cd


func _poss_roar_sound(pitch: float) -> void:
	if _attack_audio and _attack_audio.stream:
		_attack_audio.pitch_scale = pitch
		_attack_audio.play()
	_fx("snd", Vector3.ZERO, Vector3.ZERO, pitch)


## 조종하는 사람에게 "잡았다" 알림
func _poss_caught(s: Survivor, verb := "잡았어요") -> void:
	if possessed_by and is_instance_valid(possessed_by):
		_poss_call("net_notice", ["%s 을(를) %s!" % [s.display_name, verb]])
		_poss_call("_shake", [0.35])


## 계속되는 능력 처리 (조종 중, 방장). 종류 스크립트가 필요하면 바꿈
func _possessed_skill_tick(_delta: float) -> void:
	pass


## 조준 방향에 가장 가까운(각도) 노릴 수 있는 생존자. 벽에 가리면 제외
func _aim_target(aim: Vector3, max_d: float, cone_deg := 30.0) -> Survivor:
	var best: Survivor = null
	var best_a := deg_to_rad(cone_deg)
	for node in get_tree().get_nodes_in_group("survivor"):
		var s := node as Survivor
		if not _is_targetable(s):
			continue
		var to := s.global_position - global_position
		to.y = 0.0
		if to.length() > max_d or to.length() < 0.1:
			continue
		var a := aim.angle_to(to.normalized())
		if a < best_a and _clear_line(s):
			best = s
			best_a = a
	return best


func _face_aim(aim: Vector3) -> void:
	rotation.y = atan2(-aim.x, -aim.z)


## 조종하는 사람 캐릭터에 일 시키기 (손님이면 그 사람 컴퓨터로 보냄)
func _poss_call(method: String, args: Array) -> void:
	var p := possessed_by
	if p == null or not is_instance_valid(p):
		return
	if p.net_puppet and p.net_owner != 0 and Net.is_host():
		Net.apply_to_me.rpc_id(p.net_owner, method, args)
	elif p.has_method(method):
		p.callv(method, args)


## 생존자 화면에 알림 (방장 컴퓨터의 꼭두각시면 그 사람에게 보냄)
func _notify(s: Survivor, text: String) -> void:
	if Net.is_client():
		return  # 손님 화면 알림은 방장이 보내 줌 (두 번 뜨지 않게)
	if s.net_puppet and s.net_owner != 0 and Net.is_host():
		Net.apply_to_me.rpc_id(s.net_owner, "net_notice", [text])
	elif s.has_signal("notice"):
		s.emit_signal("notice", text)


## 던질 것 (쇠사슬·도끼·거미줄·사슬낫). 다른 사람 화면에도 보이게 같이 보냄
func _launch(kind: String, thrower: Node3D, from: Vector3, dir: Vector3, spd: float, rng: float, radius: float) -> Node3D:
	var p := Node3D.new()
	p.set_script(preload("res://scripts/projectile.gd"))
	get_tree().current_scene.add_child(p)
	p.call("setup", thrower, from, dir, spd, rng, radius, kind)
	_fx("proj", from, dir, [kind, spd, rng, radius])
	return p


## (방장) 술래 효과를 다른 사람 화면에도 (보이기만 함)
func _fx(kind: String, a := Vector3.ZERO, b := Vector3.ZERO, extra = null) -> void:
	if not Net.is_host():
		return
	var game := get_tree().get_first_node_in_group("game")
	if game == null:
		return
	var idx: int = (game.get("seekers") as Array).find(self)
	if idx >= 0:
		Net.seeker_fx.rpc(idx, kind, a, b, extra)


## (손님 컴퓨터) 방장이 보낸 효과를 보여 줌. 종류 스크립트가 자기 효과를 더함
func fx_mirror(kind: String, a: Vector3, b: Vector3, extra) -> void:
	match kind:
		"proj":
			var e: Array = extra
			var p := Node3D.new()
			p.set_script(preload("res://scripts/projectile.gd"))
			p.set("visual_only", true)
			get_tree().current_scene.add_child(p)
			p.call("setup", self, a, b, float(e[1]), float(e[2]), float(e[3]), str(e[0]))
		"eff":
			var e := Node3D.new()
			e.set_script(preload("res://scripts/ability_effect.gd"))
			get_tree().current_scene.add_child(e)
			e.call("setup", str(extra), a, b, self)
		"snd":
			if _attack_audio and _attack_audio.stream:
				_attack_audio.pitch_scale = float(extra)
				_attack_audio.play()
		"roar":
			_roar_ring(a)
			body.attack(0.25)
			var game := get_tree().get_first_node_in_group("game")
			var me = game.get("player") if game else null
			if me and is_instance_valid(me) and me.turned_seeker == null and me.global_position.distance_to(a) < 9.0 and me.has_method("_shake"):
				me.call("_shake", 0.35)


## 포효: 바닥을 따라 퍼지는 붉은 고리
func _roar_ring(at: Vector3) -> void:
	var m := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.9
	t.outer_radius = 1.0
	m.mesh = t
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.9, 0.08, 0.05, 0.7)
	mat.no_depth_test = false
	m.material_override = mat
	get_tree().current_scene.add_child(m)
	m.global_position = at + Vector3.UP * 0.15
	var tw := m.create_tween().set_parallel(true)
	tw.tween_property(m, "scale", Vector3(8, 1, 8), 0.7).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.7)
	tw.chain().tween_callback(m.queue_free)


## 잡는 거리 (처형인은 도끼라서 더 김)
func _catch_reach() -> float:
	return GameConfig.num("seeker", "catch_distance", 1.3)


## 공격 속도 배율 (사이코 광란 등)
func _attack_speed_mult() -> float:
	return 1.0


## 공격하기 직전에 부름. false 면 이번엔 공격 안 함 (변신한 마녀는 먼저 변신을 풂)
func _before_attack(_s: Survivor) -> bool:
	return true


## 공격 모션 시작 (기본 0.08초): 팔을 치켜들고 휘두름 + 술래마다 다른 공격 소리
func _start_attack(s: Survivor) -> void:
	var windup := GameConfig.num("seeker", "attack_windup", 0.08)
	var recover := GameConfig.num("seeker", "attack_recover", 0.07)
	var k := _attack_speed_mult() * GameConfig.num("seeker", "attack_speed", 1.1)
	if enraged:  # 폭주: 공격 속도 증가
		k *= 1.0 + GameConfig.num("seeker", "rage_attack_speed", 0.3)
	windup /= k
	recover /= k
	_attack_left = windup
	attack_seq += 1
	_attack_target = s
	_lock_left = maxf(_lock_left, windup + recover)
	_face(s.global_position - global_position, 1.0, 1.0)
	body.attack(windup)
	if _attack_audio.stream:
		_attack_audio.pitch_scale = randf_range(0.95, 1.05)
		_attack_audio.play()
	s.on_attacked(self)


## 공격이 내려쳐지는 순간: 아직 범위 안(조금 넉넉하게)이면 잡힘
func _update_attack(delta: float) -> void:
	if _attack_left <= 0.0:
		return
	_attack_left -= delta
	if _attack_target and is_instance_valid(_attack_target):
		_face(_attack_target.global_position - global_position, delta, 20.0)
	if _attack_left > 0.0:
		return
	var reach := _catch_reach() + GameConfig.num("seeker", "attack_extra_reach", 0.5)
	for node in get_tree().get_nodes_in_group("survivor"):
		var s := node as Survivor
		if _catchable(s) and global_position.distance_to(s.global_position) <= reach:
			_kill_survivor(s)
	# 노린 생존자가 살아남았으면 회피 기록 (구르기·거리 벌리기)
	if _attack_target and is_instance_valid(_attack_target) and not _attack_target.is_dead:
		_attack_target.stat_dodges += 1
	_attack_target = null


# ---------------------------------------------------------------- 상태 전환

func _enter_patrol() -> void:
	state = State.PATROL
	_pick_patrol_point()


func _investigate(pos: Vector3) -> void:
	if state != State.SEARCH:
		_searching_spots = false
	state = State.INVESTIGATE
	_set_destination(pos)


func _enter_search() -> void:
	state = State.SEARCH
	_search_yaw = rotation.y
	_search_t = 0.0
	_timer = GameConfig.num("seeker", "search_time", 4.0) + 3.0
	# 근처 숨을 곳(풀숲·사물함) + 주변 3곳을 빙 돌아봄
	_search_points = _nearby_hiding_spots(GameConfig.num("seeker", "search_radius", 14.0), int(GameConfig.num("seeker", "search_spots", 2)))
	var map := agent.get_navigation_map()
	var a0 := randf() * TAU
	for i in 3:
		var a := a0 + i * TAU / 3.0
		var p := global_position + Vector3(cos(a), 0, sin(a)) * randf_range(3.5, 6.5)
		_search_points.append(NavigationServer3D.map_get_closest_point(map, p))
	_set_destination(_search_points.pop_front())


## 근처 풀숲(숨을 만한 곳) 위치들, 가까운 순서로 최대 count 개
func _nearby_hiding_spots(radius: float, count: int) -> Array:
	var spots: Array = []
	for g in get_tree().current_scene.find_children("*", "Area3D", true, false):
		if g is GrassPatch and (g as Node3D).global_position.distance_to(global_position) <= radius:
			spots.append((g as Node3D).global_position)
	for pr in get_tree().get_nodes_in_group("prop"):
		if pr.get("kind") == "locker" and (pr as Node3D).global_position.distance_to(global_position) <= radius:
			spots.append(pr.call("front_point"))
	spots.sort_custom(func(a, b): return a.distance_to(global_position) < b.distance_to(global_position))
	return spots.slice(0, count)


func _enter_camp() -> void:
	state = State.CAMP
	_timer = GameConfig.num("seeker", "camp_time", 3.5)


func _start_chase(s: Survivor) -> void:
	state = State.CHASE
	chase_target = s
	_last_seen_pos = s.global_position
	_lost_sight_time = 0.0


func _update_chase(delta: float) -> void:
	if chase_target == null or not is_instance_valid(chase_target) or chase_target.is_dead \
			or chase_target.is_hidden_from_seeker():
		chase_target = null
		_enter_search()
		return
	if chase_target.is_frozen:
		# 쫓던 생존자가 얼음: 멈춰 있지 않고 더 빨라져서(10초) 다른 생존자를 찾으러 감
		chase_target = null
		_freeze_boost_left = GameConfig.num("seeker", "frozen_boost_time", 10.0)
		_enter_patrol()
		return

	if _can_see(chase_target):
		# 도망치는 속도를 기억해 둠 (놓쳤을 때 어디로 갔을지 예측)
		if delta > 0.0:
			_target_vel = _target_vel.lerp((chase_target.global_position - _last_seen_pos) / delta, 0.2)
		_last_seen_pos = chase_target.global_position
		_lost_sight_time = 0.0
	else:
		_lost_sight_time += delta
		if _lost_sight_time > GameConfig.num("seeker", "lose_sight_time", 2.0):
			chase_target = null
			# 똑똑한 추격: 마지막으로 본 곳이 아니라 도망간 방향으로 앞질러 감
			var predict := _last_seen_pos + Vector3(_target_vel.x, 0, _target_vel.z).limit_length(7.0) * GameConfig.num("seeker", "predict_seconds", 1.5)
			_investigate(NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), predict))
			_target_vel = Vector3.ZERO
			return

	_set_destination(_last_seen_pos)
	_move_to_destination(delta, chase_speed())


# ---------------------------------------------------------------- 이동

## 순찰 지점 고르기: 가끔은 아직 안 끝난 봉인석 근처, 아니면 맵의 랜덤 지점
func _pick_patrol_point() -> void:
	var map := agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return  # 아직 길 정보가 준비 안 됨
	# 협공: 다른 술래가 누군가를 쫓고 있으면, 그 생존자가 도망가는 앞쪽으로 가서 길목을 막음
	var partner_target := _partner_chase_target()
	if partner_target:
		var ahead := partner_target.global_position + (partner_target.global_position - global_position).normalized() * -4.0 \
				+ Vector3(partner_target.velocity.x, 0, partner_target.velocity.z) * 3.0
		var ic := NavigationServer3D.map_get_closest_point(map, ahead)
		if _good_point(ic):
			_set_destination(ic)
			return
	# 감시: 누군가 가동하던(진행도가 있는) 봉인석을 우선 확인
	var working := get_tree().get_nodes_in_group("generator").filter(func(g): return not g.completed and g.progress > 0.0)
	if not working.is_empty() and randf() < GameConfig.num("seeker", "guard_working_chance", 0.5):
		var wg: Node3D = working[randi() % working.size()]
		var wc := NavigationServer3D.map_get_closest_point(map, wg.global_position + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5)))
		if _good_point(wc) and wc.distance_to(global_position) > 3.0:
			_set_destination(wc)
			return
	# 사냥 본능: 가끔 생존자가 있는 "대략적인" 방향으로 감 (정확한 위치는 모름)
	var hunt := _hunt_point()
	if hunt != Vector3.INF:
		var hc := NavigationServer3D.map_get_closest_point(map, hunt)
		if _good_point(hc):
			_set_destination(hc)
			return
	if randf() < GameConfig.num("seeker", "patrol_generator_chance", 0.4):
		var gens := get_tree().get_nodes_in_group("generator").filter(func(g): return not g.completed)
		if not gens.is_empty():
			var g: Node3D = gens[randi() % gens.size()]
			var near := g.global_position + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
			var c := NavigationServer3D.map_get_closest_point(map, near)
			if _good_point(c) and c.distance_to(global_position) > 4.0:
				_set_destination(c)
				return
	var levels: Array = [0.0]
	var game := get_tree().get_first_node_in_group("game")
	if game and game.get("_builder"):
		levels = game._builder.floor_levels
	for i in 10:
		# 건물 안 위층·지하도 순찰 (층 높이 중 하나를 골라 그 층의 가까운 바닥)
		var lv: float = levels[randi() % levels.size()]
		var p := Vector3(randf_range(-map_half_size, map_half_size), lv + 0.3, randf_range(-map_half_size, map_half_size))
		var closest := NavigationServer3D.map_get_closest_point(map, p)
		# 걸어서 갈 수 있고, 너무 가깝지 않은 곳
		if absf(closest.y - lv) < 1.2 and closest.distance_to(global_position) > 8.0 and _good_point(closest):
			_set_destination(closest)
			return
	var a := randf() * TAU
	_set_destination(NavigationServer3D.map_get_closest_point(map, global_position + Vector3(cos(a), 0, sin(a)) * 7.0))


## 걸어서 갈 수 있는 곳인지 (지붕 위·막힌 곳 제외)
func _good_point(c: Vector3) -> bool:
	var path := NavigationServer3D.map_get_path(agent.get_navigation_map(), global_position, c, true)
	return path.size() > 0 and path[path.size() - 1].distance_to(c) < 1.2


## 사냥 지점: hunt_chance 확률로 랜덤 생존자 주변 hunt_radius 안의 한 곳. 아니면 Vector3.INF
func _hunt_point() -> Vector3:
	if dark_sight < 0.99:
		return Vector3.INF  # 정전 중에는 감으로 몰아가지 않음 (소리로만 찾음)
	# 한동안 아무도 못 만났으면 생존자 쪽으로 더 가까이 압박해 감
	var pressing := _since_contact > GameConfig.num("seeker", "pressure_time", 15.0)
	if not pressing and randf() >= GameConfig.num("seeker", "hunt_chance", 0.35):
		return Vector3.INF
	var targets := get_tree().get_nodes_in_group("survivor").filter(func(n): return _is_targetable(n as Survivor))
	if targets.is_empty():
		return Vector3.INF
	var t: Node3D = targets[randi() % targets.size()]
	var r := GameConfig.num("seeker", "hunt_radius", 12.0) * (0.55 if pressing else 1.0)
	var p := t.global_position + Vector3(randf_range(-r, r), 0.0, randf_range(-r, r))
	return Vector3(clampf(p.x, -map_half_size, map_half_size), t.global_position.y, clampf(p.z, -map_half_size, map_half_size))


## 다른 술래가 쫓고 있는 생존자 (없으면 null)
func _partner_chase_target() -> Survivor:
	for node in get_tree().get_nodes_in_group("seeker"):
		var other := node as Seeker
		if other != self and other.state == State.CHASE and other.chase_target and is_instance_valid(other.chase_target):
			return other.chase_target
	return null


## 사냥꾼 화살에 맞음: 이후 계속 피를 흘리고, 핏자국은 잠시 남음
func start_bleeding() -> void:
	is_bleeding = true


func _drip(delta: float) -> void:
	_drip_timer -= delta
	if _drip_timer > 0.0:
		return
	_drip_timer = 0.4
	var drop := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	var r := randf_range(0.15, 0.3)
	disc.top_radius = r
	disc.bottom_radius = r
	disc.height = 0.01
	drop.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.0, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.0, 0.0)
	mat.emission_energy_multiplier = 0.6  # 어두운 밤에도 보이게 살짝 빛남
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.material_override = mat
	get_tree().current_scene.add_child(drop)
	drop.global_position = Vector3(global_position.x + randf_range(-0.3, 0.3), 0.04, global_position.z + randf_range(-0.3, 0.3))
	var tw := drop.create_tween()
	tw.tween_interval(GameConfig.num("hunter", "blood_mark_time", 30.0) - 2.0)
	tw.tween_property(mat, "albedo_color:a", 0.0, 2.0)
	tw.tween_callback(drop.queue_free)


## ---- 새 술래들이 같이 쓰는 도우미 ----

## 아직 안 끝난 봉인석들
func _unfinished_generators() -> Array:
	return get_tree().get_nodes_in_group("generator").filter(func(g): return not g.completed)


## 길 위의 가장 가까운 바닥 지점
func _floor_point(pos: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), pos)


## 맵에 효과 놓기 (거미줄 덫, 저주 인형 등)
func _spawn_effect(kind: String, pos: Vector3) -> Node3D:
	var e := Node3D.new()
	e.set_script(preload("res://scripts/ability_effect.gd"))
	get_tree().current_scene.add_child(e)
	e.call("setup", kind, _floor_point(pos), -global_basis.z, self)
	_fx("eff", e.global_position, -global_basis.z, kind)
	return e


## 순간이동 (검은 연기와 함께)
func _teleport_to(pos: Vector3) -> void:
	var p := _floor_point(pos)
	global_position = p + Vector3.UP * 0.1
	velocity = Vector3.ZERO
	_set_destination(p)
	agent.target_position = p


## 생존자가 눈으로 보이는지와 상관없이 가장 가까운 노릴 수 있는 생존자
func _nearest_targetable(max_dist: float) -> Survivor:
	var best: Survivor = null
	var best_d := max_dist
	for node in get_tree().get_nodes_in_group("survivor"):
		var s := node as Survivor
		if _is_targetable(s):
			var d := global_position.distance_to(s.global_position)
			if d < best_d:
				best = s
				best_d = d
	return best


## 가장 가까운 노릴 수 있는 생존자와 거리 (능력 판단용)
func _best_target_in_view(max_dist: float) -> Survivor:
	if state == State.CHASE and chase_target and _is_targetable(chase_target) \
			and global_position.distance_to(chase_target.global_position) <= max_dist:
		return chase_target
	return null


# ---------------------------------------------------------------- 보이는 것

## 머리 위 표시: ? = 소리 확인 중 / ! = 추격 중 / ... = 얼음 근처 대기
## 가까이 있을 때만 보임 (멀리서 술래 위치가 드러나지 않도록)
func _update_label() -> void:
	if possessed_by and is_instance_valid(possessed_by) and not possessed_by.net_puppet and possessed_by.get("camera") != null:
		state_label.visible = false  # 내가 조종하는 술래: 내 머리 위 표시는 안 보여 줌
		return
	var cam := get_viewport().get_camera_3d()
	state_label.visible = body.visible and cam != null \
			and cam.global_position.distance_to(global_position) < LABEL_VISIBLE_DISTANCE
	if _stun_left > 0.0:
		state_label.text = "@_@"
		state_label.modulate = Color(1, 1, 1)
		return
	if _lock_left > 0.0:
		state_label.text = "!!"
		state_label.modulate = Color(1, 0.4, 0.1)
		return
	if state != State.CHASE and _notice_ratio > 0.05:
		# 멀리서 생존자를 알아채는 중: ? 가 점점 진해짐
		state_label.text = "?"
		state_label.modulate = Color(1, 0.9, 0.2, clampf(0.25 + _notice_ratio, 0.0, 1.0))
		return
	match state:
		State.PATROL:
			state_label.text = ""
		State.INVESTIGATE:
			state_label.text = "?"
			state_label.modulate = Color(1, 0.9, 0.2)
		State.SEARCH:
			state_label.text = "??"
			state_label.modulate = Color(1, 0.9, 0.2)
		State.CHASE:
			state_label.text = "!"
			state_label.modulate = Color(1, 0.2, 0.2)
		State.CAMP:
			state_label.text = "..."
			state_label.modulate = Color(0.7, 0.85, 1)
		State.KNOCKBACK:
			state_label.text = "으악!"
			state_label.modulate = Color(1, 0.6, 0.2)
		State.DISABLED:
			state_label.text = "봉인됨"
			state_label.modulate = Color(0.7, 0.7, 0.8)
