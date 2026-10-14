class_name Survivor
extends CharacterBody3D
## 생존자 공통 기능 (플레이어와 동료 봇이 함께 사용)
## - 얼음(무조건 무적) / 땡(10초 해동) / 탈락
## - 3D 발소리 (헤드셋으로 방향과 거리를 알 수 있음) + 술래에게 들리는 소리
## - 풀숲 숨기, 카멜레온 동화·물들이기 상태
## - 술래 능력에 맞았을 때: 피 흘림(위치 노출), 감속, 쇠사슬에 끌려감
## player.gd 와 ally.gd 는 이 스크립트를 "물려받아(extends)" 씁니다.

signal frozen_changed(is_frozen: bool)
signal died
signal rescued(rescuer: Survivor, target: Survivor)

const GRAVITY := 20.0

const STEP_SOUNDS := [
	preload("res://audio/step_light_1.wav"),
	preload("res://audio/step_light_2.wav"),
	preload("res://audio/step_light_3.wav"),
]
const SFX_FREEZE := preload("res://audio/freeze.wav")
const SFX_THAW := preload("res://audio/thaw.wav")
const SFX_TELEPORT := preload("res://audio/teleport.wav")
const SFX_HIT := preload("res://audio/punch.wav")

## 어떤 캐릭터인지 (characters.gd 의 id). main.gd 가 정해 줌
var character_id := "chameleon"
## 착용한 치장 (cosmetics.gd): {"eyes": 아이디, "hair": ..., "outfit": ..., "acc": ...}
var cosmetics := {}
## 화면에 보여줄 이름
var display_name := "생존자"

var is_frozen := false
var is_dead := false
var freeze_cooldown_left := 0.0
## 해동(땡) 진행 시간. thaw_time 만큼 차면 풀림. 동료가 떨어지면 0으로
var thaw_progress := 0.0
## 들어가 있는 풀숲 개수 (0보다 크면 풀숲 안)
var grass_count := 0
## 카멜레온 능력1 동화 남은 시간 (움직일 수 없음)
var blend_time_left := 0.0
## 카멜레온 능력2 물들이기 남은 시간 (움직일 수 있지만 상호작용 불가)
var paint_time_left := 0.0
## 피 흘림 남은 시간 (도끼, 쥐) → 술래가 위치를 알고 따라옴
var bleed_time_left := 0.0
## 도끼 감속 남은 시간
var axe_slow_left := 0.0
## 들어가 있는 플라스크 감속 구역 개수
var slow_zone_count := 0
## 쇠사슬에 끌려가는 중 (조작 불가)
var pulled_time_left := 0.0
## 이동속도 증가 (악사 응원가, 의사 진통제): 남은 시간과 증가량
var boost_left := 0.0
var boost_amount := 0.0
## 의사 진통제: 피 흘림·감속 무시
var painkiller_left := 0.0
## 그림자 무음 걸음: 발소리가 전혀 안 남
var silent_left := 0.0
## 감속 (사냥개 울부짖음 등): 남은 시간과 비율
var slow_left := 0.0
var slow_amount := 0.0
## 그림자 속으로: 남은 시간, 붙어 있는 대상(없으면 제자리)
var shadow_left := 0.0
var shadow_host: Node3D = null
## 인형사 조종: 남은 시간 동안 조종하는 술래 쪽으로 끌려 걸어감
var controlled_left := 0.0
var controller: Node3D = null

var _step_timer := 0.0
var _step_index := 0
var _drip_timer := 0.0
var _was_blended := false

@onready var body: ClayBody = $Body
@onready var ice_mesh: MeshInstance3D = $Ice
@onready var emote_label: Label3D = $EmoteLabel
@onready var collision: CollisionShape3D = $Collision
@onready var step_audio: AudioStreamPlayer3D = $Footstep
@onready var sfx_audio: AudioStreamPlayer3D = $Sfx


func _ready() -> void:
	add_to_group("survivor")
	ice_mesh.visible = false
	emote_label.visible = false
	step_audio.max_distance = GameConfig.num("view", "survivor_step_hear_distance", 22.0)
	body.build(character_id, cosmetics)
	# 얼음: 각진 얼음 덩어리 + 서리 셰이더 (땡 받는 동안 금이 감)
	ice_mesh.mesh = IceFx.chunk_mesh()
	_ice_mat = IceFx.material()
	ice_mesh.material_override = _ice_mat
	frozen_changed.connect(func(on: bool) -> void:
		if on:
			IceFx.form(self, ice_mesh)
		else:
			IceFx.shatter(self, global_position))
	# 은은한 주변 조명: 밤이라 캐릭터가 너무 어둡지 않게 (내 캐릭터는 조금 더 밝게)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.92, 0.8)
	glow.position = Vector3(0, 2.0, 0)
	glow.omni_range = 6.5 if is_in_group("player") else 3.0
	glow.light_energy = 0.5 if is_in_group("player") else 0.3
	glow.light_volumetric_fog_energy = 0.0  # 캐릭터 조명은 안개를 밝히지 않게 (뿌옇게 번지지 않도록)
	add_child(glow)


func _process(delta: float) -> void:
	if dance_left > 0.0:
		dance_left -= delta
		if is_frozen or is_dead or escaped or in_locker or is_shadowed():
			dance_left = 0.0
	body.emote = emote_id if dance_left > 0.0 else ""
	if is_frozen and _ice_mat:
		var cr := clampf(thaw_progress / maxf(0.1, GameConfig.num("player", "thaw_time", 10.0)), 0.0, 1.0)
		_ice_mat.set_shader_parameter("crack", cr)
		ice_mesh.position.x = sin(Time.get_ticks_msec() * 0.05) * 0.012 * cr  # 깨지기 직전 덜덜

	body.animate(delta, Vector2(velocity.x, velocity.z).length(), is_frozen)


# ---------------------------------------------------------------- 이모트

## 이모트 목록: [아이디, 이름, 길이(초), 보는 방향("back"=엉덩이가 카메라 쪽, "front"=얼굴이 카메라 쪽)]
## 숫자키 1~0 순서. 소리는 audio/emote_<아이디>.wav, 효과는 emote_fx.gd
const EMOTES := [
	["butt_dance", "엉덩이 춤", 3.0, "back"],
	["fart", "방귀 뿡", 2.2, "back"],
	["disco", "디스코 (노래)", 6.4, "front"],
	["trot", "트로트 어깨춤 (노래)", 6.4, "front"],
	["poop", "응가", 3.2, "front"],
	["chicken", "닭 흉내", 3.4, "front"],
	["dead", "죽은 척", 3.5, "front"],
	["robot", "로봇 춤", 3.5, "front"],
	["gaedari", "개다리 춤", 3.6, "front"],
	["dizzy", "빙글빙글", 3.2, "front"],
]
const EmoteFx := preload("res://scripts/emote_fx.gd")
const IceFx := preload("res://scripts/ice_fx.gd")
var _ice_mat: ShaderMaterial

## 이모트 남은 시간과 종류
var dance_left := 0.0
var emote_id := ""
var _dance_audio: AudioStreamPlayer3D


func start_emote(id: String, seconds: float) -> void:
	dance_left = seconds
	emote_id = id
	if _dance_audio == null:
		_dance_audio = AudioStreamPlayer3D.new()
		_dance_audio.max_distance = 25.0
		_dance_audio.unit_size = 4.0
		_dance_audio.position.y = 1.0
		add_child(_dance_audio)
	var path := "res://audio/emote_butt.wav" if id == "butt_dance" else "res://audio/emote_%s.wav" % id
	_dance_audio.stream = load(path) if ResourceLoader.exists(path) else null
	if _dance_audio.stream:
		_dance_audio.play()
	EmoteFx.spawn(self, id)


## 예전 이름 (엉덩이 춤)
func start_dance(seconds: float) -> void:
	start_emote("butt_dance", seconds)


func stop_dance() -> void:
	dance_left = 0.0
	emote_id = ""
	if _dance_audio:
		_dance_audio.stop()
	EmoteFx.clear(self)


static func emote_info(id: String) -> Array:
	for e in EMOTES:
		if e[0] == id:
			return e
	return EMOTES[0]


# ---------------------------------------------------------------- 상태 확인

func is_in_grass() -> bool:
	return grass_count > 0


func is_blended() -> bool:
	return blend_time_left > 0.0


## 술래와 쥐가 나를 감지할 수 없는 상태 (카멜레온 능력)
func is_hidden_from_seeker() -> bool:
	return blend_time_left > 0.0 or paint_time_left > 0.0 or shadow_left > 0.0 or in_locker != null


## 그림자 속에 숨어 있는지 (감지도, 잡히지도 않음)
func is_shadowed() -> bool:
	return shadow_left > 0.0


## 봉인석 가동, 땡, 쥐 잡기 같은 상호작용을 할 수 있는지
func can_interact() -> bool:
	return not is_frozen and not is_dead and not escaped and in_locker == null and chained_by == null \
			and rooted_left <= 0.0 and paint_time_left <= 0.0 and blend_time_left <= 0.0 and shadow_left <= 0.0


## 이동 속도에 곱해지는 값 (도끼 감속, 플라스크 구역)
func speed_multiplier() -> float:
	var m := 1.0 + (boost_amount if boost_left > 0.0 else 0.0)
	if item == "shoes":
		m += GameConfig.num("mechanic", "shoes_speed", 0.1)
	if painkiller_left > 0.0:
		return m  # 진통제: 감속 무시
	if slow_left > 0.0:
		m *= 1.0 - slow_amount
	if axe_slow_left > 0.0:
		m *= 1.0 - GameConfig.num("butcher", "axe_slow", 0.5)
	if slow_zone_count > 0:
		m *= 1.0 - GameConfig.num("rat", "flask_slow", 0.4)
	return m


## 사나이 패시브: 얼음을 기다림 없이 바로 깸
func has_instant_thaw() -> bool:
	return character_id == "brute"


func play_sfx(stream: AudioStream) -> void:
	sfx_audio.stream = stream
	sfx_audio.play()


## 순간이동 / 소환에 사용
func teleport_to(pos: Vector3) -> void:
	if _net_fwd("teleport_to", [pos]):
		return
	if chained_by:
		unchain(null)  # 공간을 지배하는 자 소환: 쇠사슬에서 빼냄
	global_position = pos + Vector3.UP * 0.2
	velocity = Vector3.ZERO
	thaw_progress = 0.0
	play_sfx(SFX_TELEPORT)


# ---------------------------------------------------------------- 술래 능력에 맞음

## 피 흘리기 시작 (도끼, 쥐에 물림). 얼음은 무적
func start_bleeding(seconds: float) -> void:
	_net_fwd("start_bleeding", [seconds])
	if is_frozen or is_dead:
		return
	bleed_time_left = max(bleed_time_left, seconds)


## 도끼에 맞음: 피 흘림 + 감속
func hit_by_axe() -> void:
	_net_fwd("hit_by_axe", [])
	if is_frozen or is_dead:
		return
	var t := GameConfig.num("butcher", "axe_effect_time", 15.0)
	start_bleeding(t)
	axe_slow_left = max(axe_slow_left, t)
	play_sfx(SFX_HIT)


## 쇠사슬에 걸림: target 위치까지 끌려감
func pull_to(target: Vector3, seconds: float) -> void:
	if _net_fwd("pull_to", [target, seconds]):
		return
	if is_frozen or is_dead:
		return
	pulled_time_left = seconds + 0.15
	velocity = Vector3.ZERO
	play_sfx(SFX_HIT)
	var tw := create_tween()
	tw.tween_property(self, "global_position", target + Vector3.UP * 0.1, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 의사 붕대: target 까지 끌려옴 (얼음 상태도 가능, 얼음은 유지)
func bandage_pull(target: Vector3, seconds: float) -> void:
	if _net_fwd("bandage_pull", [target, seconds]):
		return
	if is_dead or escaped or in_locker:
		return
	if chained_by:
		unchain(null)
	if is_shadowed():
		shadow_host = null
	pulled_time_left = seconds + 0.1
	thaw_progress = 0.0
	velocity = Vector3.ZERO
	set_meta("bandaged", true)
	var tw := create_tween()
	tw.tween_property(self, "global_position", target + Vector3.UP * 0.1, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(remove_meta.bind("bandaged"))


# ---------------------------------------------------------------- 얼음 / 땡

func can_freeze() -> bool:
	return not is_frozen and not is_dead and not escaped and in_locker == null and chained_by == null \
			and freeze_cooldown_left <= 0.0 and pulled_time_left <= 0.0


## 얼음! 움직일 수 없지만 무엇에도 당하지 않아요(무적). 스스로는 풀 수 없어요.
func freeze() -> void:
	if not can_freeze():
		return
	is_frozen = true
	rooted_left = 0.0  # 거미줄에 묶여 있어도 얼음하면 풀림
	thaw_progress = 0.0
	blend_time_left = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	ice_mesh.visible = true
	# 얼음 규칙: 한 판에 4번째 얼음부터는 1분 안에 땡을 못 받으면 깨짐 (탈출 단계에서는 무제한)
	freeze_count += 1
	var game := get_tree().get_first_node_in_group("game")
	var escaping: bool = game != null and bool(game.get("escape_phase"))
	if freeze_count >= int(GameConfig.num("freeze_rule", "limit_from", 4)) and not escaping:
		ice_left = GameConfig.num("freeze_rule", "shatter_time", 60.0)
		if has_signal("notice"):
			emit_signal("notice", "%d번째 얼음! %d초 안에 땡을 못 받으면 얼음이 깨져요" % [freeze_count, int(ice_left)])
	if item == "shoes":  # 정비공 신발은 얼음하면 사라짐 (다시 뽑을 수 있음)
		set_item("")
	play_sfx(SFX_FREEZE)
	frozen_changed.emit(true)


## 땡! 해동이 끝났을 때 호출됩니다.
func unfreeze(rescuer: Survivor) -> void:
	_net_fwd("unfreeze", [])
	if net_puppet and Net.is_host():
		_net_ignore_freeze = 1.5  # 땡 결과가 그 사람에게 닿기 전 상태는 무시
	if not is_frozen or is_dead:
		return
	is_frozen = false
	thaw_progress = 0.0
	ice_mesh.visible = false
	clear_ice_timer()
	if rescuer and rescuer != self:
		rescuer.stat_rescues += 1
	emote_label.visible = false
	# 풀리자마자 바로 다시 얼음 하는 걸 막는 짧은 쿨타임
	freeze_cooldown_left = GameConfig.num("player", "freeze_cooldown", 3.0)
	play_sfx(SFX_THAW)
	frozen_changed.emit(false)
	rescued.emit(rescuer, self)
	# 누군가 살아나면 술래들이 알아채고 그곳으로 감
	for node in get_tree().get_nodes_in_group("seeker"):
		(node as Seeker).alert_to(global_position)


## 술래에게 잡혔을 때. 얼음은 무적
func die() -> void:
	if _net_fwd("die", []):
		return
	if is_dead or is_frozen or is_shadowed() or is_invulnerable():
		return
	# 정비공 보급품: 갑옷·헬멧이 공격을 1번 막고 깨짐
	if item == "armor" or item == "helmet":
		var broken: String = ITEM_NAMES[item]
		set_item("")
		invuln_left = GameConfig.num("mechanic", "block_invuln", 1.0)
		play_sfx(preload("res://audio/punch.wav"))
		if has_signal("notice"):
			emit_signal("notice", "%s이(가) 공격을 막고 깨졌어요!" % broken)
		return
	_kill()


## 막을 수 없는 탈락 (얼음이 깨짐, 탈출 시간 초과 등)
func _kill() -> void:
	if _net_fwd("_kill", []):
		return
	if is_dead:
		return
	if in_locker:
		exit_locker()
	if is_frozen:
		IceFx.shatter(self, global_position)  # 얼음이 깨지며 탈락
	is_dead = true
	is_frozen = false
	ice_mesh.visible = false
	clear_ice_timer()
	visible = false
	collision.set_deferred("disabled", true)
	died.emit()


## 얼음 제한 시간이 다 됨: 얼음이 깨지고 탈락
func _shatter() -> void:
	if has_signal("notice"):
		emit_signal("notice", "얼음이 깨졌어요...")
	play_sfx(preload("res://audio/mg_fail.wav"))
	_kill()


func clear_ice_timer() -> void:
	ice_left = 0.0
	if _ice_label:
		_ice_label.visible = false


func _update_ice_timer(delta: float) -> void:
	if not is_frozen or ice_left <= 0.0:
		return
	ice_left -= delta
	if _ice_label == null:
		_ice_label = Label3D.new()
		_ice_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_ice_label.fixed_size = true
		_ice_label.pixel_size = 0.002
		_ice_label.font_size = 40
		_ice_label.outline_size = 10
		_ice_label.modulate = Color(0.6, 0.9, 1.0)
		_ice_label.position.y = 2.3
		add_child(_ice_label)
	_ice_label.visible = true
	_ice_label.text = "얼음 깨지기까지 %d초" % ceili(ice_left)
	if ice_left <= 10.0:
		_ice_label.modulate = Color(1.0, 0.35, 0.3)
	if ice_left <= 0.0:
		_shatter()


# ---------------------------------------------------------------- 탈출 / 사물함 / 기록

## 탈출 단계에서 탈출구에 도착: 이번 판에서 빠짐 (성공)
var escaped := false
## 이번 판 얼음 횟수, 얼음이 깨지기까지 남은 시간
var freeze_count := 0
var ice_left := 0.0
var _ice_label: Label3D
## 결과 화면 기록: 땡해준 횟수, 봉인석 단계 기여, 공격 회피, 탈락한 시각(초, -1 = 끝까지 생존)
var stat_rescues := 0
var stat_stages := 0.0
var stat_dodges := 0
var stat_out_time := -1.0
## 숨어 있는 사물함
var in_locker: Node3D = null
var _locker_time := 0.0


func escape() -> void:
	_net_fwd("escape", [])
	if escaped or is_dead:
		return
	escaped = true
	clear_ice_timer()
	visible = false
	collision.set_deferred("disabled", true)
	remove_from_group("survivor")
	velocity = Vector3.ZERO


func enter_locker(locker: Node3D) -> void:
	in_locker = locker
	_locker_time = 0.0
	velocity = Vector3.ZERO
	visible = false
	collision.set_deferred("disabled", true)
	global_position = locker.global_position + Vector3.UP * 0.1
	NoiseBus.make_noise(global_position, GameConfig.num("structure", "locker_enter_noise", 10.0), self)


func exit_locker() -> void:
	if in_locker == null:
		return
	var front: Vector3 = in_locker.call("front_point")
	in_locker.call("on_exit", self)
	in_locker = null
	visible = true
	collision.set_deferred("disabled", false)
	global_position = front


## 머리 위에 이모티콘(글자)을 2초간 띄웁니다.
func show_emote(text: String) -> void:
	emote_label.text = text
	emote_label.visible = true
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(self):
		emote_label.visible = false


# ---------------------------------------------------------------- 매 프레임 공통 처리

## 자식 스크립트의 _physics_process 맨 처음에 불러 줍니다.
func _common_physics(delta: float) -> void:
	freeze_cooldown_left = max(0.0, freeze_cooldown_left - delta)
	blend_time_left = max(0.0, blend_time_left - delta)
	paint_time_left = max(0.0, paint_time_left - delta)
	axe_slow_left = max(0.0, axe_slow_left - delta)
	pulled_time_left = max(0.0, pulled_time_left - delta)
	boost_left = max(0.0, boost_left - delta)
	silent_left = max(0.0, silent_left - delta)
	painkiller_left = max(0.0, painkiller_left - delta)
	slow_left = max(0.0, slow_left - delta)
	controlled_left = max(0.0, controlled_left - delta)
	_update_ice_timer(delta)
	rooted_left = max(0.0, rooted_left - delta)
	chain_immune_left = max(0.0, chain_immune_left - delta)
	if is_frozen:
		stamina = minf(stamina + GameConfig.num("stamina", "frozen_regen", 40.0) * delta, GameConfig.num("stamina", "max", 100.0))
	if in_locker:
		_locker_time += delta
	roll_cd = max(0.0, roll_cd - delta)
	invuln_left = max(0.0, invuln_left - delta)
	if shadow_left > 0.0:
		shadow_left -= delta
		if shadow_left <= 0.0:
			_leave_shadow()
	if painkiller_left > 0.0:
		bleed_time_left = 0.0
	if is_frozen:
		bleed_time_left = 0.0  # 얼음이면 피도 멈춤
	bleed_time_left = max(0.0, bleed_time_left - delta)

	var faded := is_hidden_from_seeker()
	if faded != _was_blended:
		_was_blended = faded
		body.set_alpha(0.2 if faded else 1.0)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	# 혹시 바닥 아래로 빠지면 가장 가까운 바닥으로 되돌림
	if global_position.y < -5.0:
		var game := get_tree().get_first_node_in_group("game")
		if game:
			global_position = game.closest_floor_point(global_position) + Vector3.UP * 0.5
			velocity = Vector3.ZERO

	if is_frozen and not is_dead:
		_update_thaw(delta)
	if bleed_time_left > 0.0 and not is_dead:
		_drip_blood(delta)


## 얼음 상태일 때: 옆에 붙어 있는 동료가 있으면 해동 게이지가 참
func _update_thaw(delta: float) -> void:
	if Net.is_client():
		return  # 땡은 방장 컴퓨터가 판정
	var reach := GameConfig.num("player", "unfreeze_distance", 1.8)
	var helpers: Array[Survivor] = []
	for node in get_tree().get_nodes_in_group("survivor"):
		var other := node as Survivor
		if other and other != self and other.can_interact() \
				and global_position.distance_to(other.global_position) <= reach:
			helpers.append(other)

	if helpers.is_empty():
		thaw_progress = 0.0  # 떨어지면 처음부터 다시
		return

	# 해동해 준 사람으로 기록할 대상 (플레이어가 있으면 플레이어 우선)
	var credit := helpers[0]
	for h in helpers:
		if h.is_in_group("player"):
			credit = h
		if h.has_instant_thaw():
			unfreeze(h)  # 사나이: 한 번에!
			return

	thaw_progress += delta
	if thaw_progress >= GameConfig.num("player", "thaw_time", 10.0):
		unfreeze(credit)


## 피 흘리는 동안 바닥에 핏자국을 남김 (누구나 볼 수 있음)
func _drip_blood(delta: float) -> void:
	_drip_timer -= delta
	if _drip_timer > 0.0:
		return
	_drip_timer = 0.35
	var drop := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	var r := randf_range(0.08, 0.18)
	disc.top_radius = r
	disc.bottom_radius = r
	disc.height = 0.01
	drop.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.02, 0.02)
	mat.roughness = 0.3
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.material_override = mat
	get_tree().current_scene.add_child(drop)
	drop.global_position = global_position + Vector3(randf_range(-0.2, 0.2), 0.03, randf_range(-0.2, 0.2))
	var tw := drop.create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(mat, "albedo_color:a", 0.0, 2.0)
	tw.tween_callback(drop.queue_free)


## 움직이는 동안 발소리를 냅니다.
## - 진짜 소리(AudioStreamPlayer3D): 헤드셋으로 방향과 거리를 들을 수 있음
## - 술래용 소리(NoiseBus): noise_radius 안의 술래가 듣고 찾아옴
func _footsteps(delta: float, moving: bool, noise_radius: float, interval: float, volume_db: float) -> void:
	if not moving or silent_left > 0.0 or is_shadowed():
		_step_timer = 0.0
		return
	if character_id == "shadow":  # 그림자 패시브: 발소리 절반
		var q := GameConfig.num("shadow", "quiet_steps", 0.5)
		noise_radius *= q
		volume_db += linear_to_db(q)
	_step_timer -= delta
	if _step_timer > 0.0:
		return
	_step_timer = interval
	_step_index = (_step_index + 1) % STEP_SOUNDS.size()
	step_audio.stream = STEP_SOUNDS[_step_index]
	step_audio.volume_db = volume_db
	step_audio.pitch_scale = randf_range(0.9, 1.1)
	step_audio.play()
	if noise_radius > 0.0:
		NoiseBus.make_noise(global_position, noise_radius, self)


## 몸을 이동 방향으로 부드럽게 돌립니다.
func _face_direction(dir: Vector3, delta: float) -> void:
	if dir.length() > 0.01:
		body.rotation.y = lerp_angle(body.rotation.y, atan2(dir.x, dir.z), 10.0 * delta)


## 가장 가까운 "아직 안 끝난" 봉인석 (max_dist 안에 있을 때만)
func _nearest_generator(max_dist: float) -> Generator:
	var best: Generator = null
	var best_d := max_dist
	for node in get_tree().get_nodes_in_group("generator"):
		var g := node as Generator
		if g == null or g.completed:
			continue
		var d := global_position.distance_to(g.global_position)
		if d <= best_d:
			best = g
			best_d = d
	return best


## 감속 받기 (얼음 상태는 무적)
func apply_slow(amount: float, seconds: float) -> void:
	_net_fwd("apply_slow", [amount, seconds])
	if is_frozen or is_dead:
		return
	slow_amount = maxf(amount, slow_amount if slow_left > 0.0 else 0.0)
	slow_left = maxf(slow_left, seconds)


## 그림자 속으로 들어감 (host 가 있으면 그 그림자를 따라다님)
func enter_shadow(seconds: float, host: Node3D) -> void:
	shadow_left = seconds
	shadow_host = host
	body.visible = false
	_shadow_blob(true)


func _leave_shadow() -> void:
	shadow_left = 0.0
	shadow_host = null
	body.visible = true
	_shadow_blob(false)


## 그림자 상태일 때 바닥에 보이는 검은 얼룩
var _blob: MeshInstance3D
func _shadow_blob(on: bool) -> void:
	if on and _blob == null:
		_blob = MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.6
		disc.bottom_radius = 0.6
		disc.height = 0.01
		_blob.mesh = disc
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0, 0, 0, 0.75)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blob.material_override = m
		_blob.position.y = 0.04
		add_child(_blob)
	if _blob:
		_blob.visible = on


## 그림자 상태 이동: 대상이 있으면 그 뒤에 붙어 따라감 (자식 스크립트에서 호출)
func _follow_shadow_host() -> bool:
	if shadow_left <= 0.0:
		return false
	velocity.x = 0.0
	velocity.z = 0.0
	if shadow_host and is_instance_valid(shadow_host):
		var target := shadow_host.global_position + (global_position - shadow_host.global_position).normalized() * 0.9
		global_position = global_position.lerp(Vector3(target.x, global_position.y, target.z), 0.25)
	return true


## 인형사에게 조종당하는 중이면 조종하는 쪽으로 걸어갈 방향 (아니면 Vector3.ZERO)
func _controlled_direction() -> Vector3:
	if controlled_left <= 0.0 or controller == null or not is_instance_valid(controller) or is_frozen:
		return Vector3.ZERO
	var d := controller.global_position - global_position
	d.y = 0.0
	return d.normalized()


## 이동속도 증가 효과 받기 (더 큰 효과가 우선)
func give_boost(amount: float, seconds: float) -> void:
	boost_amount = maxf(amount, boost_amount if boost_left > 0.0 else 0.0)
	boost_left = maxf(boost_left, seconds)


## 가장 가까운 살아있는(작동 중인) 술래. 없으면 null
# ---------------------------------------------------------------- 정비공 보급품

const ITEM_NAMES := {"shoes": "신발", "armor": "갑옷", "helmet": "헬멧"}
## 착용 중인 보급품: "" / "shoes" / "armor" / "helmet"
var item := ""
var _item_mesh: Node3D


func set_item(id: String) -> void:
	item = id
	if _item_mesh:
		_item_mesh.queue_free()
		_item_mesh = null
	if id == "":
		return
	# 몸에 작게 보이는 표시
	_item_mesh = MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	m.emission_enabled = true
	match id:
		"shoes":
			var t := TorusMesh.new()
			t.inner_radius = 0.28
			t.outer_radius = 0.36
			(_item_mesh as MeshInstance3D).mesh = t
			_item_mesh.position.y = 0.08
			m.albedo_color = Color(0.3, 0.9, 1.0)
		"armor":
			var t := TorusMesh.new()
			t.inner_radius = 0.36
			t.outer_radius = 0.46
			(_item_mesh as MeshInstance3D).mesh = t
			_item_mesh.position.y = 0.6
			m.albedo_color = Color(0.75, 0.75, 0.8)
		"helmet":
			var sm := SphereMesh.new()
			sm.radius = 0.36
			sm.height = 0.36
			sm.is_hemisphere = true
			(_item_mesh as MeshInstance3D).mesh = sm
			_item_mesh.position.y = 1.18
			m.albedo_color = Color(0.9, 0.75, 0.2)
	m.emission = m.albedo_color * 0.4
	(_item_mesh as MeshInstance3D).material_override = m
	body.add_child(_item_mesh)


## 정비공 능력2: 랜덤 보급품 착용 (이미 있으면 실패)
func give_random_item() -> bool:
	if item != "":
		return false
	var ids := ITEM_NAMES.keys()
	set_item(ids[randi() % ids.size()])
	return true


# ---------------------------------------------------------------- 멀티플레이

## 다른 사람이 조종하는 캐릭터 / 다른 컴퓨터의 봇 (위치를 받아서 따라가기만 함)
var net_puppet := false
## 조종하는 사람의 접속 번호 (0 = 봇)
var net_owner := 0
var net_slot := -1
var _net_ignore_freeze := 0.0
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _net_speed := 0.0
var _net_has_target := false


## 방장 컴퓨터에서, 다른 사람이 조종하는 캐릭터에 생긴 일은 그 사람 컴퓨터로 보냄 (true = 보냈으니 여기선 하지 말 것)
func _net_fwd(method: String, args: Array) -> bool:
	if not net_puppet or net_owner == 0 or not Net.is_host():
		return false
	var out: Array = []
	for a in args:
		if a is Seeker:
			out.append({"seeker": (a as Node).name})
		elif a is Node:
			out.append(null)
		else:
			out.append(a)
	Net.apply_to_me.rpc_id(net_owner, method, out)
	return method in ["die", "_kill", "pull_to", "teleport_to", "bandage_pull"]


## 상태를 숫자 하나로 (네트워크 전송용)
func net_flags() -> int:
	var f := 0
	if is_frozen: f |= 1
	if is_dead: f |= 2
	if escaped: f |= 4
	if chained_by: f |= 8
	if rooted_left > 0.0: f |= 16
	if bleed_time_left > 0.0: f |= 32
	if is_shadowed() or in_locker: f |= 64
	if dance_left > 0.0:
		f |= 128
		f |= (maxi(0, EMOTES.find(emote_info(emote_id))) + 1) << 8  # 어떤 이모트인지
	return f


## 네트워크로 받은 위치·상태
func net_target(pos: Vector3, yaw: float, speed: float, flags: int, thaw: float) -> void:
	if not _net_has_target or pos.distance_to(_net_pos) > 6.0:
		global_position = pos  # 처음이거나 순간이동
	_net_pos = pos
	_net_yaw = yaw
	_net_speed = speed
	_net_has_target = true
	thaw_progress = thaw
	var host := Net.is_host()
	var want_frozen := flags & 1 != 0
	if want_frozen != is_frozen and not (host and _net_ignore_freeze > 0.0 and want_frozen):
		is_frozen = want_frozen
		ice_mesh.visible = is_frozen
		frozen_changed.emit(is_frozen)
		if is_frozen:
			freeze_count += 1
	if flags & 2 != 0 and not is_dead:
		is_dead = true
		visible = false
		collision.set_deferred("disabled", true)
		if host:
			died.emit()
	if flags & 4 != 0 and not escaped:
		escaped = true
		visible = false
		collision.set_deferred("disabled", true)
		remove_from_group("survivor")
	if not host:
		bleed_time_left = 1.0 if flags & 32 != 0 else 0.0
	body.visible = flags & 64 == 0
	if flags & 128 != 0:
		var idx := ((flags >> 8) & 15) - 1
		var id: String = EMOTES[idx][0] if idx >= 0 and idx < EMOTES.size() else "butt_dance"
		if dance_left <= 0.0 or emote_id != id:
			start_emote(id, 0.3)
		dance_left = maxf(dance_left, 0.3)
	elif dance_left > 0.0:
		stop_dance()


## 받은 위치로 부드럽게 따라감 (자식 스크립트의 _physics_process 맨 앞에서 호출)
func _net_puppet_update(delta: float) -> void:
	_net_ignore_freeze = max(0.0, _net_ignore_freeze - delta)
	if Net.is_host():
		_common_physics(delta)  # 땡·피 흘림 같은 판정은 방장이 계산
	if is_dead or escaped or not _net_has_target:
		return
	var prev := global_position
	global_position = global_position.lerp(_net_pos, clampf(14.0 * delta, 0.0, 1.0))
	body.rotation.y = lerp_angle(body.rotation.y, _net_yaw, clampf(14.0 * delta, 0.0, 1.0))
	velocity = (global_position - prev) / maxf(delta, 0.001)
	# 발소리: 헤드셋으로 들리게. 술래가 듣는 소리는 방장 컴퓨터에서만 의미 있음
	var moving := _net_speed > 0.6
	var noise := 0.0
	var interval := 0.45
	var vol := -6.0
	if _net_speed > 6.0:
		noise = GameConfig.num("player", "run_noise", 22.0)
		interval = 0.3
		vol = 0.0
	elif _net_speed > 3.0:
		noise = GameConfig.num("player", "walk_noise", 9.0)
	else:
		noise = GameConfig.num("player", "sneak_noise", 2.0)
		interval = 0.65
		vol = -18.0
	_footsteps(delta, moving and not is_frozen, noise if Net.is_host() else 0.0, interval, vol)


# ---------------------------------------------------------------- 속박 / 쇠사슬 / 빨아들이기

## 거미줄에 묶임: 못 움직이고 능력도 못 씀 (얼음은 가능 → 얼음하면 풀림)
var rooted_left := 0.0
## 사이코 쇠사슬에 묶여 끌려다니는 중 (묶은 술래)
var chained_by: Node3D = null
var chain_immune_left := 0.0
## 동료가 쇠사슬을 풀어 줄 때 쓰는 거리 (구조물과 같은 방식: 그룹 "prop")
var reach := 2.2
## 하마 블랙홀처럼 바깥에서 끌어당기는 힘 (이번 프레임만)
var _external_pull := Vector3.ZERO


func root(seconds: float) -> void:
	_net_fwd("root", [seconds])
	if is_frozen or is_dead:
		return
	rooted_left = maxf(rooted_left, seconds)
	velocity = Vector3.ZERO


func add_external_pull(v: Vector3) -> void:
	if net_puppet and net_owner != 0 and Net.is_host():
		Net.pull_me.rpc_id(net_owner, v)
		return
	_external_pull += v


func take_external_pull() -> Vector3:
	var v := _external_pull
	_external_pull = Vector3.ZERO
	return Vector3(v.x, 0.0, v.z)


## 사이코에게 묶임 (갑옷·헬멧은 한 번 막아 줌)
func try_chain(by: Node3D) -> bool:
	_net_fwd("try_chain", [by])
	if is_dead or chained_by or chain_immune_left > 0.0 or is_invulnerable() or escaped:
		return false
	if item == "armor" or item == "helmet":
		var broken: String = ITEM_NAMES[item]
		set_item("")
		invuln_left = GameConfig.num("mechanic", "block_invuln", 1.0)
		if has_signal("notice"):
			emit_signal("notice", "%s이(가) 쇠사슬을 막고 깨졌어요!" % broken)
		return false
	if in_locker:
		exit_locker()
	if is_frozen:
		is_frozen = false
		ice_mesh.visible = false
		clear_ice_timer()
		frozen_changed.emit(false)
	if is_shadowed():
		_leave_shadow()
	chained_by = by
	add_to_group("prop")
	velocity = Vector3.ZERO
	play_sfx(preload("res://audio/punch.wav"))
	if has_signal("notice"):
		emit_signal("notice", "사이코의 쇠사슬에 묶였어요! 동료가 풀어 줘야 해요")
	return true


func unchain(by: Node) -> void:
	if chained_by == null:
		return
	var sk := chained_by
	chained_by = null
	remove_from_group("prop")
	chain_immune_left = GameConfig.num("psycho", "free_immune", 2.0)
	if is_instance_valid(sk) and sk.has_method("on_chain_freed"):
		sk.call("on_chain_freed", self, by)
	if has_signal("notice"):
		emit_signal("notice", "쇠사슬이 풀렸어요! 도망쳐요")


## 쇠사슬에 묶인 동료에게 E (구조물과 같은 방식)
func can_use(s: Survivor) -> bool:
	return chained_by != null and s != self


func prompt(_s: Survivor) -> String:
	return "[E] %s의 쇠사슬 풀기" % display_name


func use(s: Survivor) -> void:
	unchain(s)


## 묶여 있으면 사슬 길이(6m) 밖으로 못 가게 끌려감. 끌려다니는 중이면 true
func _follow_chain(delta: float) -> bool:
	if chained_by == null:
		return false
	if not is_instance_valid(chained_by) or not chained_by.call("is_active"):
		unchain(null)
		return false
	var to := chained_by.global_position - global_position
	to.y = 0.0
	var length := GameConfig.num("psycho", "chain_length", 6.0)
	velocity.x = 0.0
	velocity.z = 0.0
	if to.length() > length * 2.5:  # 너무 멀어지면 (순간이동 등) 바로 사슬 끝으로
		var snap := chained_by.global_position - to.normalized() * length
		global_position = Vector3(snap.x, global_position.y, snap.z)
	elif to.length() > length:
		var v := to.normalized() * (to.length() - length) / maxf(delta, 0.001)
		v = v.limit_length(14.0)
		velocity.x = v.x
		velocity.z = v.z
		_face_direction(to, delta)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	move_and_slide()
	return true


# ---------------------------------------------------------------- 스태미나

## 달리기·구르기에 쓰는 기력. 0이 되면 숨이 차서 일정량 찰 때까지 못 달림
var stamina := 100.0
var exhausted := false
var _breath_timer := 0.0


## 이번 프레임에 달릴 수 있는지
func can_run() -> bool:
	return not exhausted and stamina > 0.0


## moving_state: "run" / "walk" / "idle" — 상태에 따라 줄거나 참
func _update_stamina(delta: float, moving_state: String) -> void:
	var mx := GameConfig.num("stamina", "max", 100.0)
	match moving_state:
		"run":
			stamina -= GameConfig.num("stamina", "run_drain", 5.0) * delta
			if stamina <= 0.0:
				stamina = 0.0
				exhausted = true
				if has_signal("notice"):
					emit_signal("notice", "숨이 차요! 잠깐 걸어야 해요 (숨소리가 들려요)")
		"walk":
			stamina += GameConfig.num("stamina", "walk_regen", 15.0) * delta
		_:
			stamina += GameConfig.num("stamina", "idle_regen", 25.0) * delta
	stamina = minf(stamina, mx)
	if exhausted and stamina >= GameConfig.num("stamina", "recover_at", 30.0):
		exhausted = false
	# 숨이 찬 동안: 헉헉 소리 (술래도 들음)
	if exhausted:
		_breath_timer -= delta
		if _breath_timer <= 0.0:
			_breath_timer = 1.4
			NoiseBus.make_noise(global_position, GameConfig.num("stamina", "breath_noise", 8.0), self)
			if ResourceLoader.exists("res://audio/breath.wav"):
				play_sfx(load("res://audio/breath.wav"))


# ---------------------------------------------------------------- 구르기

var roll_left := 0.0
var roll_cd := 0.0
var invuln_left := 0.0
var _roll_dir := Vector3.FORWARD


## 구르기 처음 잠깐은 무적 (술래 공격을 피할 수 있음)
func is_invulnerable() -> bool:
	return invuln_left > 0.0


func can_roll() -> bool:
	return stamina >= GameConfig.num("stamina", "roll_cost", 20.0) and rooted_left <= 0.0 and chained_by == null and roll_cd <= 0.0 and roll_left <= 0.0 and not is_frozen and not is_dead and not is_blended() \
			and pulled_time_left <= 0.0 and controlled_left <= 0.0 and not is_shadowed() and is_on_floor()


## dir 방향으로 구르기 (방향이 없으면 바라보는 쪽)
func start_roll(dir: Vector3) -> bool:
	if not can_roll():
		return false
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = body.global_basis.z
		dir.y = 0.0
	_roll_dir = dir.normalized()
	roll_left = GameConfig.num("player", "roll_time", 0.4)
	invuln_left = GameConfig.num("player", "roll_invuln", 0.25)
	roll_cd = GameConfig.num("player", "roll_cooldown", 3.0)
	stamina -= GameConfig.num("stamina", "roll_cost", 20.0)
	body.rotation.y = atan2(_roll_dir.x, _roll_dir.z)
	NoiseBus.make_noise(global_position, GameConfig.num("player", "run_noise", 22.0), self)
	var sfx: AudioStream = load("res://audio/roll.wav") if ResourceLoader.exists("res://audio/roll.wav") else null
	if sfx:
		play_sfx(sfx)
	return true


## 구르는 중이면 이동시키고 true (자식 스크립트의 _physics_process 에서 호출)
func _update_roll(delta: float) -> bool:
	if roll_left <= 0.0:
		return false
	var total := GameConfig.num("player", "roll_time", 0.4)
	roll_left -= delta
	var spd := GameConfig.num("player", "roll_distance", 3.0) / total
	velocity.x = _roll_dir.x * spd
	velocity.z = _roll_dir.z * spd
	# 몸 가운데를 중심으로 앞구르기 한 바퀴
	var p := clampf(1.0 - roll_left / total, 0.0, 1.0)
	var center := Vector3(0, 0.55, 0)
	body.rotation = Vector3(TAU * p if roll_left > 0.0 else 0.0, body.rotation.y, 0.0)
	body.position = center - body.basis * center
	move_and_slide()
	if roll_left <= 0.0:
		body.rotation.x = 0.0
		body.position = Vector3.ZERO
	return true


## 술래가 나를 공격하기 시작할 때 불림 (봇은 여기서 구를지 정함)
func on_attacked(_by: Node3D) -> void:
	pass


## 가까이에서 쓸 수 있는 구조물 (문·판자·사물함)
func nearest_prop() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("prop"):
		var d := (node as Node3D).global_position.distance_to(global_position)
		if d <= float(node.get("reach")) and d < best_d and node.call("can_use", self):
			best = node
			best_d = d
	return best


## E: 가까운 구조물 사용
func use_nearby_prop() -> bool:
	if not can_interact():
		return false
	var p := nearest_prop()
	if p == null:
		return false
	p.call("use", self)
	return true


## 가까운 거미줄 덫 (걷어내기용)
func nearest_web(reach: float) -> Node3D:
	for node in get_tree().get_nodes_in_group("web_trap"):
		if (node as Node3D).global_position.distance_to(global_position) <= reach:
			return node
	return null


func _nearest_seeker() -> Seeker:
	var best: Seeker = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("seeker"):
		var sk := node as Seeker
		if sk == null or not sk.is_active() or sk.is_disguised():
			continue  # 생존자로 변신한 마녀는 술래로 안 보임
		var d := global_position.distance_to(sk.global_position)
		if d < best_d:
			best = sk
			best_d = d
	return best


## 가장 가까운 쥐 부하 (max_dist 안에 있을 때만)
func _nearest_rat(max_dist: float) -> Node3D:
	var best: Node3D = null
	var best_d := max_dist
	for node in get_tree().get_nodes_in_group("rat_minion"):
		var d := global_position.distance_to((node as Node3D).global_position)
		if d <= best_d:
			best = node
			best_d = d
	return best
