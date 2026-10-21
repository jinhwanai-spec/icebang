extends Seeker
## 술래: 안개 마녀
## - 짙은 안개: 15초 동안 생존자는 2m 앞만 보임 (쿨 40초). 술래 시야는 그대로.
##   대신 안개 동안 마녀 발소리가 웃음소리로 바뀌어서 소리로 위치를 알 수 있음
## - 변신: 생존자 모습으로 변신 (지속시간 없음). 변신 중에는 안개를 못 씀.
##   잡을 때는 변신을 풀어야 하고, 풀린 뒤 0.7초 멈춤 → 그때부터 쿨 40초
##   변신 중에는 심장 소리·붉은 화면·머리 위 표시가 안 떠서 동료처럼 보임

const LIGHT_STEPS := [
	preload("res://audio/step_light_1.wav"),
	preload("res://audio/step_light_2.wav"),
	preload("res://audio/step_light_3.wav"),
]

var _fog_cd := 0.0
var _fog_left := 0.0
var _base_fog := -1.0
var _disguise_cd := 0.0
var _disguise: ClayBody = null
var _laugh: AudioStream = null


func _ready() -> void:
	super._ready()
	_fog_cd = GameConfig.num("witch", "fog_cooldown", 40.0) * 0.3
	_disguise_cd = GameConfig.num("witch", "disguise_cooldown", 40.0) * 0.3
	step_audio.volume_db = -10.0
	_laugh = load("res://audio/witch_laugh.wav")  # 필요할 때만 불러옴


func is_disguised() -> bool:
	return _disguise != null


func _process(delta: float) -> void:
	if _disguise:
		_disguise.animate(delta, Vector2(velocity.x, velocity.z).length(), false)
	else:
		super._process(delta)


func _ability_update(delta: float) -> void:
	_fog_cd = max(0.0, _fog_cd - delta)
	if not _disguise:
		_disguise_cd = max(0.0, _disguise_cd - delta)
	if _fog_left > 0.0:
		_fog_left -= delta
		if _fog_left <= 0.0:
			_set_fog(false)
	if _lock_left > 0.0 or possessed_by:
		return

	# 짙은 안개: 생존자를 쫓거나 소리를 확인하러 갈 때 (변신 중에는 못 씀)
	if not _disguise and _fog_cd <= 0.0 and (state == State.CHASE or state == State.INVESTIGATE):
		_fog_left = GameConfig.num("witch", "fog_time", 15.0)
		_fog_cd = GameConfig.num("witch", "fog_cooldown", 40.0)
		_set_fog(true)
		_lock_left = 0.5
		return

	# 변신: 순찰 중이고 안개가 없을 때
	if not _disguise and _disguise_cd <= 0.0 and _fog_left <= 0.0 and state == State.PATROL:
		_start_disguise()


# ---------------------------------------------------------------- 변신

func _start_disguise() -> void:
	var ids: Array = []
	for node in get_tree().get_nodes_in_group("survivor"):
		ids.append((node as Survivor).character_id)
	if ids.is_empty():
		return
	var cid: String = ids[randi() % ids.size()]
	_disguise_as(cid)
	_fx("disguise", Vector3.ZERO, Vector3.ZERO, cid)


func _disguise_as(cid: String) -> void:
	if _disguise:
		_disguise.queue_free()
	_disguise = ClayBody.new()
	add_child(_disguise)
	_disguise.build(cid)
	_disguise.rotation.y = PI  # 점토 인형은 +Z가 앞, 술래는 -Z가 앞
	body.visible = false
	state_label.visible = false


func _unmask() -> void:
	if _disguise == null:
		return
	_disguise.queue_free()
	_disguise = null
	body.visible = true
	_fx("disguise", Vector3.ZERO, Vector3.ZERO, "")
	_lock_left = GameConfig.num("witch", "unmask_freeze", 0.7)
	_disguise_cd = GameConfig.num("witch", "disguise_cooldown", 40.0)


## 잡기 전에 변신을 먼저 풀어야 함 (풀린 뒤 0.7초 멈춤)
func _before_attack(_s: Survivor) -> bool:
	if _disguise:
		_unmask()
		return false
	return true


## 변신 중에는 생존자처럼 천천히 걸어서 들키지 않게
func _move_dir(dir: Vector3, delta: float, speed: float) -> void:
	if _disguise:
		speed = minf(speed, GameConfig.num("player", "walk_speed", 4.5))
	super._move_dir(dir, delta, speed)


func _update_label() -> void:
	super._update_label()
	if _disguise:
		state_label.visible = false


# ---------------------------------------------------------------- 안개

func _set_fog(on: bool) -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game == null or not ("world_env" in game):
		return
	var env: Environment = game.world_env.environment
	if _base_fog < 0.0:
		_base_fog = env.fog_density
	# 헬멧(정비공 보급품)을 쓴 유저에게는 안개가 안 통함
	var p = game.get("player")
	if on and p and is_instance_valid(p) and (p.item == "helmet" or p.get("turned_seeker") != null):
		on = false  # 술래가 된 사람(마녀 본인)의 시야는 그대로
	_fx("fog", Vector3.ZERO, Vector3.ZERO, on)
	var target := GameConfig.num("witch", "fog_density", 1.5) if on else _base_fog
	var tw := create_tween()
	tw.tween_property(env, "fog_density", target, 1.2)
	if on:
		for node in get_tree().get_nodes_in_group("survivor"):
			if node is Survivor:
				_notify(node as Survivor, "짙은 안개가 몰려옵니다... 웃음소리를 잘 들어보세요")


## 안개 중에는 발소리 대신 마녀 웃음소리, 변신 중에는 생존자 발소리
func _footsteps(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if _fog_left > 0.0 and _laugh:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = GameConfig.num("witch", "laugh_interval", 1.6)
			step_audio.stream = _laugh
			step_audio.volume_db = 2.0
			step_audio.pitch_scale = randf_range(0.92, 1.08)
			step_audio.play()
		return
	step_audio.volume_db = -10.0
	if _disguise:
		if speed < 0.5:
			return
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.45
			step_audio.stream = LIGHT_STEPS[randi() % LIGHT_STEPS.size()]
			step_audio.pitch_scale = randf_range(0.95, 1.1)
			step_audio.play()
		return
	super._footsteps(delta)


func disable() -> void:
	if _disguise:
		_unmask()
	super.disable()
	if _fog_left > 0.0:
		_fog_left = 0.0
		_set_fog(false)


func _on_stunned() -> void:
	_lock_left = 0.0


func fx_mirror(kind: String, a: Vector3, b: Vector3, extra) -> void:
	match kind:
		"fog":
			_fog_left = GameConfig.num("witch", "fog_time", 15.0) if bool(extra) else 0.0  # 웃음소리 발소리용
			_set_fog(bool(extra))
		"disguise":
			if str(extra) == "":
				if _disguise:
					_disguise.queue_free()
					_disguise = null
				body.visible = true
			else:
				_disguise_as(str(extra))
		_:
			super.fx_mirror(kind, a, b, extra)


# ---------------------------------------------------------------- 사람이 조종할 때 ([R] 안개 / [T] 변신)

func poss_skills() -> Array:
	return [["짙은 안개", "15초 동안 생존자는 2m 앞만 보여요 (내 발소리는 웃음소리로)"],
			["변신", "생존자 모습으로 변신 / 다시 누르면 풀기. 변신 중엔 걷기만, 잡으려면 먼저 풀려요"]]


func poss_note(n: int) -> String:
	if n == 0 and _fog_left > 0.0:
		return "안개 %d초" % ceili(_fog_left)
	if n == 1 and _disguise:
		return "변신 중"
	return ""


func possessed_max_speed() -> float:
	return GameConfig.num("player", "walk_speed", 4.5) if _disguise else INF


func _poss_do(n: int, aim: Vector3):
	if n == 0:
		if _disguise:
			return "변신 중에는 안개를 못 써요"
		_fog_left = GameConfig.num("witch", "fog_time", 15.0)
		_set_fog(true)
		_lock_left = 0.5
		return GameConfig.num("witch", "fog_cooldown", 40.0) * 0.6
	if _disguise:
		_unmask()
		_disguise_cd = 0.0
		return GameConfig.num("witch", "disguise_cooldown", 40.0) * 0.4
	if _fog_left > 0.0:
		return "안개 중에는 변신할 수 없어요"
	_start_disguise()
	return 1.0
