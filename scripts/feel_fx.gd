extends Node
## 손맛(게임 필) 연출 담당 — 내 캐릭터(player.gd)에만 붙습니다. 게임 규칙·숫자는 건드리지 않아요 (보기·듣기 효과만).
## - 카메라: 부드럽게 따라오기(살짝 늦게), 달릴 때 시야각 넓어짐, 발걸음 머리 흔들림, 옆걸음 기울기, 착지 출렁임
## - 화면 흔들림: "트라우마" 값(0~1)이 쌓이면 노이즈로 흔들고 서서히 줄어듦 (술래 공격·잡힘·펀치·유리·가까운 술래 발소리·얼음)
## - 히트스톱: 잡히거나 펀치/스턴이 맞는 순간 아주 잠깐 느려짐 (혼자 할 때만. 멀티는 짧은 줌 연출로 대신)
## - 긴장 음악: 술래가 가까울수록 낮은 맥동 레이어, 나를 쫓으면 추격 레이어 (부드럽게 교차)
## - 소리 디테일: 달리기 시작 옷 스침, 기력이 낮을 때 숨소리, 사물함 안에서는 소리가 먹먹하게
## 설정: balance.cfg [feel] 섹션 (shake_scale = 0 이면 화면 흔들림 끔 등)
## HUD 는 hud_event 신호로 화면 효과(붉은 번쩍임, 서리 등)를 받아 그림.

## HUD 로 보내는 화면 효과: "caught" / "near" / "freeze" / "thaw" / "stage" / "chase" / "punch"
signal hud_event(kind: StringName, amount: float)

const SFX_TENSION := preload("res://audio/feel_tension.wav")
const SFX_CHASE := preload("res://audio/feel_chase.wav")
const SFX_STINGER := preload("res://audio/feel_stinger.wav")
const SFX_THUNK := preload("res://audio/feel_thunk.wav")
const SFX_IMPACT := preload("res://audio/feel_impact.wav")
const SFX_CLOTH := preload("res://audio/feel_cloth.wav")
const SFX_DOOR := preload("res://audio/feel_door.wav")
const SFX_BREATH := preload("res://audio/breath.wav")
const MUSIC_BUS := "FeelMusic"
const MUFFLE_NAME := "feel_muffle"

var player: CharacterBody3D  # player.gd (Survivor)
var _pivot: Node3D
var _arm: SpringArm3D
var _cam: Camera3D

# ---- 설정값 (balance.cfg [feel])
var _shake_mult := 1.0
var _lag_rate := 25.0
var _lag_max := 0.3
var _fov_kick := 7.0
var _bob := 1.0
var _tilt := 1.6
var _dip := 1.0
var _hitstop_ms := 75.0
var _hitstop_mp := false
var _music_db := -8.0
var _tension_dist := 22.0
var _muffle_hz := 900.0
var _frozen_muffle_hz := 5000.0
var _foley := true

# ---- 카메라 상태
var _base_pivot := Vector3.ZERO
var _base_fov := 62.0
var _lag_pos := Vector3.ZERO
var _lag_ready := false
var _fov_cur := 0.0
var _fov_punch := 0.0
var _roll := 0.0
var _bob_t := 1.0
var _bob_amp := 0.0
var _bob_side := 1.0
var _dip_target := 0.0
var _dip_cur := 0.0
var _air := false
var _air_min_vy := 0.0
var _trauma := 0.0
var _t := 0.0
var _noise := FastNoiseLite.new()
var _last_h := 0.0
var _last_v := 0.0
var _ext_h := 0.0
var _ext_v := 0.0

# ---- 히트스톱
var _hitstop_on := false
var _saved_scale := 1.0

# ---- 긴장 음악 (외부에서 읽을 수 있게 공개: 테스트·HUD)
var tension_vol := 0.0
var chase_vol := 0.0
var chased := false
var nearest_seeker_dist := INF
var _chase_hold := 0.0
var _since_chase := 99.0
var _tension_player: AudioStreamPlayer
var _chase_player: AudioStreamPlayer
var _oneshot: AudioStreamPlayer
var _foley_player: AudioStreamPlayer
var _breath_player: AudioStreamPlayer

# ---- 소리 디테일
var _was_running := false
var _breath_t := 0.0
var _muffle: AudioEffectLowPassFilter
var _muffle_idx := -1
var _muffle_cur := 20000.0

# ---- 술래·창문 감시 (매 프레임 새 배열을 만들지 않도록 미리 잡아 둔 버퍼)
var _seq_seen := PackedInt32Array()
var _step_seen := PackedFloat32Array()
var _glass_seen := PackedByteArray()
var _glass_t := 0.0


func setup(p: CharacterBody3D) -> void:
	player = p
	_pivot = p.get("pivot")
	_arm = p.get("spring_arm")
	_cam = p.get("camera")
	_base_pivot = _pivot.position
	_base_fov = _cam.fov
	_shake_mult = GameConfig.num("feel", "shake_scale", GameConfig.num("feel", "shake_intensity", 1.0))
	_lag_rate = GameConfig.num("feel", "camera_lag_rate", 25.0)
	_lag_max = GameConfig.num("feel", "camera_lag_max", 0.3)
	_fov_kick = GameConfig.num("feel", "sprint_fov_kick", 7.0)
	_bob = GameConfig.num("feel", "head_bob", 1.0)
	_tilt = GameConfig.num("feel", "strafe_tilt_deg", 1.6)
	_dip = GameConfig.num("feel", "land_dip", 1.0)
	_hitstop_ms = GameConfig.num("feel", "hitstop_ms", 75.0)
	_hitstop_mp = GameConfig.flag("feel", "hitstop_in_multiplayer", false)
	_music_db = GameConfig.num("feel", "music_volume_db", -8.0)
	_tension_dist = GameConfig.num("feel", "tension_distance", 22.0)
	_muffle_hz = GameConfig.num("feel", "locker_muffle_hz", 900.0)
	_frozen_muffle_hz = GameConfig.num("feel", "frozen_muffle_hz", 5000.0)
	_foley = GameConfig.flag("feel", "foley", true)
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.frequency = 1.0
	_noise.seed = randi()


func _ready() -> void:
	# 음악 전용 버스 (Master 로 보냄) — 나중에 음악만 따로 줄이기 쉽게
	if AudioServer.get_bus_index(MUSIC_BUS) == -1:
		AudioServer.add_bus()
		var bi := AudioServer.bus_count - 1
		AudioServer.set_bus_name(bi, MUSIC_BUS)
		AudioServer.set_bus_send(bi, "Master")
	_tension_player = _make_player(SFX_TENSION, MUSIC_BUS)
	_chase_player = _make_player(SFX_CHASE, MUSIC_BUS)
	_oneshot = _make_player(null, "Master")
	_foley_player = _make_player(null, "Master")
	_breath_player = _make_player(SFX_BREATH, "Master")
	_tension_player.play()
	_chase_player.play()
	_tension_player.stream_paused = true
	_chase_player.stream_paused = true
	# 사물함 안 먹먹한 소리: Master 버스에 저역 통과 필터 (평소엔 꺼 둠, 한 번만 추가)
	for i in AudioServer.get_bus_effect_count(0):
		var e := AudioServer.get_bus_effect(0, i)
		if e is AudioEffectLowPassFilter and e.resource_name == MUFFLE_NAME:
			_muffle = e
			_muffle_idx = i
	if _muffle == null:
		_muffle = AudioEffectLowPassFilter.new()
		_muffle.resource_name = MUFFLE_NAME
		_muffle.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(0, _muffle)
		_muffle_idx = AudioServer.get_bus_effect_count(0) - 1
	AudioServer.set_bus_effect_enabled(0, _muffle_idx, false)
	# 상태 변화 신호
	player.connect("died", _on_died)
	player.connect("frozen_changed", _on_frozen_changed)


func _make_player(stream: AudioStream, bus: String) -> AudioStreamPlayer:
	var a := AudioStreamPlayer.new()
	if stream is AudioStreamWAV and (stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED \
			and (stream == SFX_TENSION or stream == SFX_CHASE):
		# 루프 정보가 빠져 있어도 반복되게 (가져오기 설정과 상관없이)
		var w := stream as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
	a.stream = stream
	a.bus = bus
	a.volume_db = -80.0
	add_child(a)
	return a


func _exit_tree() -> void:
	if _hitstop_on:
		Engine.time_scale = _saved_scale
		_hitstop_on = false
	if _muffle_idx >= 0 and _muffle_idx < AudioServer.get_bus_effect_count(0):
		AudioServer.set_bus_effect_enabled(0, _muffle_idx, false)


# ================================================================ 외부에서 부르는 것들

## 화면 흔들림 쌓기 (0~1). 실제 흔들림은 trauma² 라서 작은 값은 아주 살짝
func add_trauma(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)


## 짧은 멈칫 (히트스톱). 멀티에서는 시간을 늦추지 않고 시야를 살짝 당김
func hitstop(scale_ms := 1.0) -> void:
	_fov_punch = -4.0 * scale_ms
	var ms := _hitstop_ms * scale_ms
	if ms <= 0.0 or _hitstop_on or get_tree().paused:
		return
	if Net.in_match() and not _hitstop_mp:
		return
	_hitstop_on = true
	_saved_scale = Engine.time_scale
	Engine.time_scale = _saved_scale * 0.08
	await get_tree().create_timer(ms / 1000.0, true, false, true).timeout
	if _hitstop_on:
		Engine.time_scale = _saved_scale
		_hitstop_on = false


## 발소리가 난 순간 (player._footsteps 에서): 머리 흔들림 한 번 + 소리 크기 살짝 흔듦
func on_step(volume_db: float) -> void:
	_bob_t = 0.0
	_bob_side = -_bob_side
	_bob_amp = 0.045 if volume_db >= -1.0 else (0.025 if volume_db >= -10.0 else 0.012)


## 강펀치 / 스턴이 맞음
func on_hit_landed(strong: bool) -> void:
	add_trauma(0.45 if strong else 0.2)
	hitstop(1.0 if strong else 0.6)
	hud_event.emit(&"punch", 1.0 if strong else 0.5)


## 봉인석 미니게임 단계 성공: 묵직한 걸쇠 소리 + 살짝 흔들
func on_stage_clear() -> void:
	_play(_oneshot, SFX_THUNK, -4.0, randf_range(0.95, 1.05))
	add_trauma(0.22)
	hud_event.emit(&"stage", 1.0)


## 구조물(문·판자·사물함)을 씀
func on_prop_used(pr: Node) -> void:
	if pr == null or not is_instance_valid(pr):
		return
	match str(pr.get("kind")):
		"door":
			var opening := bool(pr.get("_open"))
			_play(_foley_player, SFX_DOOR, -8.0 if opening else -3.0, randf_range(0.85, 0.95) if opening else randf_range(0.7, 0.8))
			add_trauma(0.08 if opening else 0.16)
			_dip_target = maxf(_dip_target, 0.02)
		"pallet":
			add_trauma(0.32)
			_play(_foley_player, SFX_DOOR, -2.0, 0.6)


## 창문 넘기 시작
func on_vault() -> void:
	_play(_foley_player, SFX_CLOTH, -10.0, randf_range(0.9, 1.1))


# ================================================================ 신호 처리

func _on_died() -> void:
	add_trauma(0.75)
	_play(_oneshot, SFX_IMPACT, -2.0, 1.0)
	hud_event.emit(&"caught", 1.0)
	hitstop(1.2)
	_muffle_cur = 600.0  # 잠깐 귀가 멍해짐 → 서서히 돌아옴


func _on_frozen_changed(on: bool) -> void:
	if player.is_dead:
		return
	if on:
		add_trauma(0.22)
		hud_event.emit(&"freeze", 1.0)
	else:
		add_trauma(0.15)
		hud_event.emit(&"thaw", 1.0)


# ================================================================ 매 프레임

func _physics_process(_delta: float) -> void:
	# 착지 감지 (player 의 move_and_slide 다음에 실행됨: 부모가 먼저)
	if player.is_dead or player.get("escaped"):
		_air = false
		return
	if not player.is_on_floor():
		if not _air:
			_air = true
			_air_min_vy = 0.0
		_air_min_vy = minf(_air_min_vy, player.velocity.y)
	elif _air:
		_air = false
		var fall := -_air_min_vy
		if fall > 4.0:
			var k := clampf((fall - 4.0) / 10.0, 0.0, 1.0)
			_dip_target = maxf(_dip_target, (0.06 + 0.16 * k) * _dip)
			add_trauma(0.1 + 0.3 * k)
			if k > 0.3:
				_play(_foley_player, SFX_DOOR, -6.0, 0.55)


func _process(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.001) if _hitstop_on else delta  # 히트스톱 중에도 화면 효과는 실제 시간으로
	_t += rd
	var alive: bool = not player.is_dead and not player.get("escaped")
	var game := player.get_tree().get_first_node_in_group("game")
	_update_camera(rd, alive)
	_watch_world(rd, game, alive)
	_update_music(rd, game, alive)
	_update_foley(rd, alive)
	_update_muffle(rd, alive)


func _update_camera(delta: float, alive: bool) -> void:
	var run_speed := GameConfig.num("player", "run_speed", 7.5)
	var walk_speed := GameConfig.num("player", "walk_speed", 4.5)
	var hv := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var in_body: bool = alive and player.get("in_locker") == null and not player.get("spectate_free")
	# 1) 살짝 늦게 따라오는 카메라 (순간이동·멀리 이동하면 바로 붙음)
	if in_body:
		var target := player.global_position
		if not _lag_ready or _lag_pos.distance_to(target) > 3.0:
			_lag_pos = target
			_lag_ready = true
		var kh := 1.0 - exp(-_lag_rate * delta)
		var kv := 1.0 - exp(-_lag_rate * 0.55 * delta)
		_lag_pos.x = lerpf(_lag_pos.x, target.x, kh)
		_lag_pos.z = lerpf(_lag_pos.z, target.z, kh)
		_lag_pos.y = lerpf(_lag_pos.y, target.y, kv)
		var off := (_lag_pos - target).limit_length(_lag_max)
		_pivot.position = _base_pivot + player.global_transform.basis.inverse() * off
	else:
		_lag_ready = false
	# 2) 달리기 시야각 (부드럽게)
	var sprint := 0.0
	if in_body and player.get("turned_seeker") == null:
		sprint = clampf((hv.length() - walk_speed * 1.05) / maxf(run_speed - walk_speed * 1.05, 0.1), 0.0, 1.0)
	_fov_cur = lerpf(_fov_cur, sprint * _fov_kick, 1.0 - exp(-(6.0 if sprint > _fov_cur / maxf(_fov_kick, 0.01) else 3.5) * delta))
	_fov_punch = lerpf(_fov_punch, 0.0, 1.0 - exp(-7.0 * delta))
	_cam.fov = _base_fov + _fov_cur + _fov_punch
	# 3) 옆걸음 기울기
	var lateral := 0.0
	if in_body:
		lateral = hv.dot(_cam.global_basis.x) / maxf(run_speed, 0.1)
	_roll = lerpf(_roll, -clampf(lateral, -1.0, 1.0) * deg_to_rad(_tilt), 1.0 - exp(-6.0 * delta))
	# 4) 발걸음 머리 흔들림 (발소리에 맞춰 한 번씩 콩)
	_bob_t += delta
	var bob_v := 0.0
	var bob_h := 0.0
	if _bob_t < 0.22 and in_body:
		var s := sin(_bob_t / 0.22 * PI)
		bob_v = -s * _bob_amp * _bob
		bob_h = s * _bob_amp * 0.35 * _bob * _bob_side
	# 5) 착지 출렁임
	_dip_cur = lerpf(_dip_cur, _dip_target, 1.0 - exp(-30.0 * delta))
	_dip_target = lerpf(_dip_target, 0.0, 1.0 - exp(-7.0 * delta))
	# 6) 트라우마 흔들림 (노이즈)
	_trauma = maxf(0.0, _trauma - delta * 1.1)
	var sh := _trauma * _trauma * _shake_mult * SaveData.shake
	var sx := _noise.get_noise_2d(_t * 22.0, 0.0) * 0.14 * sh
	var sy := _noise.get_noise_2d(_t * 22.0, 50.0) * 0.12 * sh
	var sr := _noise.get_noise_2d(_t * 18.0, 100.0) * deg_to_rad(2.5) * sh
	# 다른 스크립트(붕괴 구슬 등)가 직접 넣은 흔들림은 더해서 유지
	if not is_equal_approx(_cam.h_offset, _last_h):
		_ext_h = _cam.h_offset
	if not is_equal_approx(_cam.v_offset, _last_v):
		_ext_v = _cam.v_offset
	_last_h = _ext_h + sx + bob_h
	_last_v = _ext_v + sy + bob_v - _dip_cur
	_cam.h_offset = _last_h
	_cam.v_offset = _last_v
	_arm.rotation.z = _roll + sr


## 술래 공격(가까이) / 술래 발소리(아주 가까이) / 창문 깨짐 감시
func _watch_world(delta: float, game: Node, alive: bool) -> void:
	if game == null:
		return
	var seekers: Array = game.get("seekers")
	if _seq_seen.size() != seekers.size():
		_seq_seen.resize(seekers.size())
		_step_seen.resize(seekers.size())
		for i in seekers.size():
			_seq_seen[i] = -1
			_step_seen[i] = 0.0
	var me: Vector3 = player.global_position
	nearest_seeker_dist = INF
	for i in seekers.size():
		var sk = seekers[i]
		if not is_instance_valid(sk) or sk == player.get("turned_seeker"):
			continue
		var d: float = me.distance_to(sk.global_position)
		if sk.is_active() and not sk.is_disguised():
			nearest_seeker_dist = minf(nearest_seeker_dist, d)
		var seq: int = sk.get("_net_attack_seq") if sk.net_puppet else sk.attack_seq
		if _seq_seen[i] >= 0 and seq != _seq_seen[i] and alive and d < 7.0:
			add_trauma(0.12 + 0.4 * (1.0 - d / 7.0))
			if d < 3.5:
				hud_event.emit(&"near", 1.0 - d / 3.5)
		_seq_seen[i] = seq
		var st: float = sk._step_timer
		if st > _step_seen[i] + 0.05 and alive and d < 6.0:
			add_trauma(0.07 * (1.0 - d / 6.0))  # 쿵… 쿵… (아주 살짝)
		_step_seen[i] = st
	# 창문 유리 (0.25초마다)
	_glass_t -= delta
	if _glass_t > 0.0 or not game.has_method("level_windows"):
		return
	_glass_t = 0.25
	var ws: Array = game.call("level_windows")
	var first := _glass_seen.size() != ws.size()
	if first:
		_glass_seen.resize(ws.size())
	for i in ws.size():
		var b := 1 if (ws[i] as Dictionary).get("broken", false) else 0
		if b == 1 and _glass_seen[i] == 0 and not first and alive:
			var d: float = me.distance_to((ws[i] as Dictionary)["c"])
			if d < 14.0:
				add_trauma(0.12 + 0.3 * (1.0 - d / 14.0))
		_glass_seen[i] = b


## 긴장 레이어(술래 거리) + 추격 레이어(나를 쫓는 중) 부드럽게 교차
func _update_music(delta: float, game: Node, alive: bool) -> void:
	var want_t := 0.0
	var now_chased := false
	if alive and game and player.get("turned_seeker") == null:
		var hb := GameConfig.num("horror", "heartbeat_distance", 6.0)
		if nearest_seeker_dist < _tension_dist:
			want_t = clampf(1.0 - (nearest_seeker_dist - hb * 0.5) / maxf(_tension_dist - hb * 0.5, 0.1), 0.0, 1.0)
		if not player.is_frozen:
			for sk in game.get("seekers"):
				if is_instance_valid(sk) and sk.state == Seeker.State.CHASE and _is_chasing_me(sk, game):
					now_chased = true
					break
	if now_chased:
		if not chased and _since_chase > 8.0:
			_play(_oneshot, SFX_STINGER, -6.0, 1.0)
			add_trauma(0.18)
			hud_event.emit(&"chase", 1.0)
		chased = true
		_chase_hold = 2.5  # 잠깐 놓쳐도 바로 끊기지 않게
		_since_chase = 0.0
	else:
		_chase_hold -= delta
		_since_chase += delta
		if _chase_hold <= 0.0:
			chased = false
	var want_c := 1.0 if chased else 0.0
	if chased:
		want_t = maxf(want_t * 0.5, 0.35)
	tension_vol = move_toward(tension_vol, want_t, delta * (0.8 if want_t > tension_vol else 0.35))
	chase_vol = move_toward(chase_vol, want_c, delta * (2.2 if want_c > chase_vol else 0.4))
	_set_layer(_tension_player, tension_vol, _music_db)
	_set_layer(_chase_player, chase_vol, _music_db - 1.0)


func _is_chasing_me(sk, game: Node) -> bool:
	if not sk.net_puppet:
		return sk.chase_target == player
	# 멀티 손님 컴퓨터: 쫓는 대상은 안 오므로 "추격 중 + 가장 가까운 생존자가 나" 로 판단
	var d: float = player.global_position.distance_to(sk.global_position)
	if d > 28.0:
		return false
	for s in game.get("survivors"):
		if s != player and is_instance_valid(s) and not s.is_dead and not s.escaped and not s.is_frozen \
				and s.global_position.distance_to(sk.global_position) < d:
			return false
	return true


func _set_layer(a: AudioStreamPlayer, v: float, db: float) -> void:
	if v <= 0.001:
		if not a.stream_paused:
			a.stream_paused = true
		return
	if a.stream_paused:
		a.stream_paused = false
	a.volume_db = linear_to_db(v) + db


## 달리기 시작 옷 스침, 기력이 낮을 때 숨소리, 사물함 속 숨죽인 숨소리
func _update_foley(delta: float, alive: bool) -> void:
	if not _foley or not alive:
		return
	var run_speed := GameConfig.num("player", "run_speed", 7.5)
	var hspeed := Vector2(player.velocity.x, player.velocity.z).length()
	var running := hspeed > run_speed * 0.9 and player.is_on_floor()
	if running and not _was_running:
		_play(_foley_player, SFX_CLOTH, -13.0, randf_range(0.9, 1.15))
	_was_running = running
	_breath_t -= delta
	if _breath_t > 0.0:
		return
	var mx := GameConfig.num("stamina", "max", 100.0)
	var low: bool = player.stamina < mx * 0.3 and not player.exhausted  # 완전히 지친 숨소리는 survivor.gd 가 냄
	if player.get("in_locker") != null:
		# 숨어 있을 때: 술래가 가까우면 숨이 빨라짐 (내 귀에만 들림)
		var near := clampf(1.0 - nearest_seeker_dist / 10.0, 0.0, 1.0)
		_play(_breath_player, SFX_BREATH, lerpf(-22.0, -14.0, near), randf_range(0.95, 1.05))
		_breath_t = lerpf(3.4, 1.6, near)
	elif low and not player.is_frozen:
		_play(_breath_player, SFX_BREATH, -17.0, randf_range(0.9, 1.0))
		_breath_t = 1.7
	else:
		_breath_t = 0.3


## 사물함 안: 소리가 먹먹하게. 얼음 안: 아주 살짝
func _update_muffle(delta: float, alive: bool) -> void:
	var want := 20000.0
	if alive and player.get("in_locker") != null:
		want = _muffle_hz
	elif alive and player.is_frozen:
		want = _frozen_muffle_hz
	_muffle_cur = lerpf(_muffle_cur, want, 1.0 - exp(-(6.0 if want < _muffle_cur else 1.5) * delta))
	var on := _muffle_cur < 19000.0
	if AudioServer.is_bus_effect_enabled(0, _muffle_idx) != on:
		AudioServer.set_bus_effect_enabled(0, _muffle_idx, on)
	if on:
		_muffle.cutoff_hz = _muffle_cur


func _play(a: AudioStreamPlayer, s: AudioStream, db: float, pitch: float) -> void:
	a.stream = s
	a.volume_db = db
	a.pitch_scale = pitch
	a.play()
