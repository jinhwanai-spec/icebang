extends Survivor
## 플레이어 (내가 조작하는 캐릭터)
## 조작: WASD 이동 / Shift 달리기 / Ctrl 살금살금 / E 봉인석 가동(누르고 있기)·쥐 잡기
##       Q 얼음 / R 고유 능력1 / T 고유 능력2
##       F 소리 내기, G 이모티콘 (상점 공통 능력, 얼음 상태에서)
##       마우스 시점 회전

## 화면에 안내 문구를 띄울 때 (main.gd → HUD)
signal notice(text: String)
## 카메라맨 사진을 찍었을 때 화면을 번쩍이게
signal flashed

const MOUSE_SENSITIVITY := 0.0025
const REPAIR_REACH := 2.4
const PlacedCameraScript := preload("res://scripts/placed_camera.gd")
const SFX_SHUTTER := preload("res://audio/shutter.wav")
const SFX_PUNCH := preload("res://audio/punch.wav")
const SFX_LURE := preload("res://audio/lure.wav")
const SFX_ABILITY := preload("res://audio/ability.wav")
const MinigameScript := preload("res://scripts/minigame.gd")
## 이모트 (숫자키 1~0 순서). 앞으로 더 추가 가능
const EMOTE_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
const AbilityEffectScript := preload("res://scripts/ability_effect.gd")

var noise_cooldown_left := 0.0
## 고유 능력 쿨타임 남은 시간 [능력1, 능력2]. 충전식 능력은 "다음 충전까지 남은 시간"
var ability_cooldown_left := [0.0, 0.0, 0.0]
## 충전식 능력의 현재 충전 수 [능력1, 능력2] (카메라맨 카메라)
var ability_charges := [0, 0, 0]
## 정비공 만능 공구: 다음 미니게임 한 단계를 자동 클리어
var toolkit_ready := false
## 중력술사 붕괴 충전 중 (못 움직임)
var is_charging := false
var is_repairing := false
## HUD 안내를 띄우기 위해 저장
var nearby_generator: Generator = null
var nearby_rat: Node3D = null
var nearby_web: Node3D = null
var nearby_prop: Node3D = null
## 공간을 지배하는 자: 소환할 동료를 고르는 중인지
var summon_menu_open := false
var summon_candidates: Array[Survivor] = []
## 의사 치료: 위의 고르기 창을 치료 대상 고르기로 씀
var heal_menu := false
## 열려 있는 봉인석 미니게임 창, 그 봉인석
var minigame: Minigame = null
var _mg_gen: Generator = null
## 그림자 건너가기: 다음에 건너갈 동료 순서
var _hop_index := 0

@onready var pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D


func _ready() -> void:
	add_to_group("player")  # super._ready() 보다 먼저 (조명 밝기 구분용)
	super._ready()
	for slot in range(1, CharacterDB.slot_count(character_id) + 1):
		ability_charges[slot - 1] = CharacterDB.max_charges(character_id, slot)
	# 눈높이 정면 시점: 어깨 뒤에서 수평으로 바라봄
	spring_arm.add_excluded_object(get_rid())
	spring_arm.spring_length = GameConfig.num("view", "camera_distance", 2.6)
	spring_arm.position.x = GameConfig.num("view", "camera_shoulder_offset", 0.8)
	spring_arm.rotation.x = 0.0
	camera.fov = GameConfig.num("view", "camera_fov", 62.0)
	camera.current = true
	# 손전등: 보는 방향 앞쪽만 원뿔 모양으로 밝게
	var flashlight := SpotLight3D.new()
	flashlight.light_color = Color(1.0, 0.93, 0.8)
	flashlight.light_energy = GameConfig.num("horror", "flashlight_energy", 4.0)
	flashlight.spot_range = GameConfig.num("horror", "flashlight_range", 22.0)
	flashlight.spot_angle = GameConfig.num("horror", "flashlight_angle", 26.0)
	flashlight.spot_attenuation = 1.2
	flashlight.shadow_enabled = true
	flashlight.position = Vector3(0.3, -0.2, -0.5)
	camera.add_child(flashlight)
	# 손전등이 바로 앞의 내 캐릭터 등을 하얗게 비추지 않도록 (내 몸은 2번 레이어, 손전등은 2번 레이어 제외)
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).layers = 2
	flashlight.light_cull_mask = 0xFFFFF & ~2
	body.rotation.y = PI  # 처음에는 카메라와 같은 방향(앞)을 봄


func _unhandled_input(event: InputEvent) -> void:
	# 마우스로 시점 회전 (얼음 상태, 탈락 상태에서도 가능)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		pivot.rotate_y(-motion.relative.x * MOUSE_SENSITIVITY)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x - motion.relative.y * MOUSE_SENSITIVITY,
				deg_to_rad(-55.0), deg_to_rad(40.0))

	if is_dead or escaped:
		# 관전 중: 좌클릭 다음 / 우클릭 이전 / V 자유 시점
		if event is InputEventMouseButton and event.pressed:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_spectate_step(1)
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				_spectate_step(-1)
		if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_V:
			spectate_free = not spectate_free
			spring_arm.spring_length = 0.0 if spectate_free else GameConfig.num("view", "camera_distance", 2.6) + 1.2
		return
	# 사물함 안: E로만 나갈 수 있음. 마우스로 통풍구 틈 사이를 살짝 둘러봄
	if in_locker:
		if event is InputEventMouseMotion:
			_peek.x = clampf(_peek.x - (event as InputEventMouseMotion).relative.x * 0.003, -0.55, 0.55)
			_peek.y = clampf(_peek.y - (event as InputEventMouseMotion).relative.y * 0.003, -0.3, 0.25)
		if event.is_action_pressed("interact"):
			exit_locker()
		return

	if summon_menu_open:
		for i in 3:
			if event.is_action_pressed("pick_%d" % (i + 1)):
				if heal_menu:
					_medic_heal(i)
				else:
					_summon(i)
				return
		if event.is_action_pressed("ability_1" if heal_menu else "ability_2"):
			summon_menu_open = false  # 한 번 더 누르면 취소
			heal_menu = false
			return

	if event is InputEventKey and event.pressed and not event.echo \
			and EMOTE_KEYS.has((event as InputEventKey).physical_keycode):
		_use_emote_slot(EMOTE_KEYS.find((event as InputEventKey).physical_keycode))
		return
	if event.is_action_pressed("freeze"):
		freeze()
		summon_menu_open = false
	elif event.is_action_pressed("interact"):
		if not _try_kill_rat() and not _try_clear_web() and not use_nearby_prop():
			_try_open_minigame()
	elif event.is_action_pressed("roll"):
		if not (minigame and is_instance_valid(minigame)):
			var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
			var d := pivot.global_basis * Vector3(input.x, 0.0, input.y)
			start_roll(d if input.length() > 0.1 else look_direction())
	elif event.is_action_pressed("ability_noise"):
		use_noise_ability()
	elif event.is_action_pressed("emote"):
		use_emote()
	elif event.is_action_pressed("ability_1"):
		_try_ability(1)
	elif event.is_action_pressed("ability_2"):
		_try_ability(2)
	elif event.is_action_pressed("ability_3") and CharacterDB.slot_count(character_id) >= 3:
		_try_ability(3)


func _physics_process(delta: float) -> void:
	_common_physics(delta)
	noise_cooldown_left = max(0.0, noise_cooldown_left - delta)
	_update_cooldowns(delta)
	is_repairing = false
	nearby_generator = null
	nearby_rat = null
	nearby_web = null
	nearby_prop = null

	# 얼음·끌려감·탈락 등으로 상호작용을 못 하게 되면 미니게임 창을 닫음
	if minigame and is_instance_valid(minigame):
		if _mg_gen and is_instance_valid(_mg_gen) and _mg_gen.completed:
			minigame.close(true)  # 봉인석이 완료되면 창을 바로 닫음
			notice.emit("봉인석 가동 완료!")
		elif not can_interact():
			minigame.close()
	if is_dead or escaped:
		_locker_view(false)
		_spectate()
		return
	if in_locker:
		velocity = Vector3.ZERO
		_locker_view(true)
		return
	_locker_view(false)
	_update_song(delta)
	if _follow_chain(delta):
		return
	if rooted_left > 0.0:  # 거미줄에 묶임
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if _follow_shadow_host():
		move_and_slide()
		return
	# 얼음 / 동화(제자리) / 쇠사슬에 끌려가는 중에는 못 움직임
	if is_frozen or is_blended() or pulled_time_left > 0.0 or is_charging:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# 구르는 중
	if _update_roll(delta):
		return

	# 1) 키보드 입력 → 카메라가 보는 방향 기준 이동 방향
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := pivot.global_basis * Vector3(input.x, 0.0, input.y)
	dir.y = 0.0
	dir = dir.normalized() * min(input.length(), 1.0)
	# 인형사에게 조종당하면 강제로 그쪽으로 걸어감
	var forced := _controlled_direction()
	if forced != Vector3.ZERO:
		dir = forced
		if minigame and is_instance_valid(minigame):
			minigame.close()

	# 2) 상호작용: 쥐 잡기 안내, 봉인석 가동 (누르고 있으면 진행, 그동안 못 움직임)
	if can_interact():
		nearby_rat = _nearest_rat(GameConfig.num("rat", "minion_kill_reach", 2.0))
		nearby_web = nearest_web(GameConfig.num("spider", "web_clear_reach", 2.2))
		nearby_prop = nearest_prop()
		nearby_generator = _nearest_generator(REPAIR_REACH)
	# 미니게임 중: 못 움직임. 얼음·끌려감·상호작용 불가 상태가 되면 창이 닫힘
	if minigame and is_instance_valid(minigame):
		is_repairing = true
		dir = Vector3.ZERO
	# 이모트 춤: 움직이면 멈춤. 추는 동안은 엉덩이가 카메라 쪽을 향함
	if dance_left > 0.0:
		if dir.length() > 0.1:
			stop_dance()
		else:
			var f := look_direction()
			f.y = 0.0
			if f.length() > 0.01:
				var back: bool = emote_info(emote_id)[3] == "back"
				body.look_at(body.global_position + (-f if back else f), Vector3.UP)

	# 3) 속도와 발소리 크기 결정
	var speed := GameConfig.num("player", "walk_speed", 4.5)
	var noise := GameConfig.num("player", "walk_noise", 9.0)
	var interval := 0.45
	var volume := -6.0
	if Input.is_action_pressed("sneak"):
		speed = GameConfig.num("player", "sneak_speed", 2.2)
		noise = GameConfig.num("player", "sneak_noise", 2.0)
		interval = 0.65
		volume = -18.0
	elif Input.is_action_pressed("run") and can_run() and dir.length() > 0.1:
		speed = GameConfig.num("player", "run_speed", 7.5)
		noise = GameConfig.num("player", "run_noise", 22.0)
		interval = 0.3
		volume = 0.0
	speed *= speed_multiplier()

	var running := speed >= GameConfig.num("player", "run_speed", 7.5) * 0.99
	_update_stamina(delta, "run" if running else ("walk" if dir.length() > 0.1 else "idle"))
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity += take_external_pull()
	_face_direction(dir, delta)
	_footsteps(delta, dir.length() > 0.1, noise, interval, volume)
	move_and_slide()


## 쿨타임 감소. 충전식 능력은 시간이 다 되면 1개 충전
func _update_cooldowns(delta: float) -> void:
	for slot in range(1, CharacterDB.slot_count(character_id) + 1):
		var i: int = slot - 1
		var max_c := CharacterDB.max_charges(character_id, slot)
		if max_c > 0:
			if ability_charges[i] < max_c:
				ability_cooldown_left[i] -= delta
				if ability_cooldown_left[i] <= 0.0:
					ability_charges[i] += 1
					ability_cooldown_left[i] = CharacterDB.cooldown(character_id, slot) if ability_charges[i] < max_c else 0.0
		else:
			ability_cooldown_left[i] = max(0.0, ability_cooldown_left[i] - delta)


## 탈락·탈출 뒤: 살아 있는 동료를 따라가며 관전 (클릭하면 다음 동료)
## 사물함·옷장 안에서 보는 시점: 문 통풍구 틈 사이로 바깥을 봄
var _peek := Vector2.ZERO
var _vent_overlay: CanvasLayer
var _vent_cam: Camera3D

func _locker_view(on: bool) -> void:
	if on:
		if _vent_overlay == null:
			_peek = Vector2.ZERO
			_vent_overlay = _make_vent_overlay(in_locker.get("_wardrobe") == true)
			add_child(_vent_overlay)
			_vent_cam = Camera3D.new()
			_vent_cam.top_level = true
			_vent_cam.fov = camera.fov
			_vent_cam.near = 0.05
			add_child(_vent_cam)
			_vent_cam.make_current()
		var lk := in_locker as Node3D
		var fwd := -lk.global_basis.z
		var basis := Basis.looking_at(fwd, Vector3.UP).rotated(Vector3.UP, _peek.x)
		basis = basis * Basis(Vector3.RIGHT, _peek.y)
		_vent_cam.global_transform = Transform3D(basis, lk.global_position + Vector3.UP * 1.62 + fwd * 0.42)
	elif _vent_overlay:
		_vent_overlay.queue_free()
		_vent_overlay = null
		_vent_cam.queue_free()
		_vent_cam = null
		camera.make_current()


func _make_vent_overlay(wood: bool) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 5
	var col := Color(0.09, 0.06, 0.04) if wood else Color(0.07, 0.09, 0.085)
	# 위·아래는 문짝, 가운데 6줄 틈 사이로만 보임
	var bands := [[0.0, 0.3], [0.7, 1.0]]
	for i in 7:
		var y := 0.3 + i * (0.4 / 6.0)
		bands.append([y - 0.022, y + 0.022])
	for b in bands:
		var r := ColorRect.new()
		r.color = col
		r.anchor_left = 0.0
		r.anchor_right = 1.0
		r.anchor_top = b[0]
		r.anchor_bottom = b[1]
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(r)
	for x in [[0.0, 0.12], [0.88, 1.0]]:
		var r := ColorRect.new()
		r.color = col
		r.anchor_left = x[0]
		r.anchor_right = x[1]
		r.anchor_top = 0.0
		r.anchor_bottom = 1.0
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(r)
	var tip := Label.new()
	tip.text = "숨는 중... [E] 나가기 · 마우스로 틈 사이 보기"
	tip.anchor_left = 0.5
	tip.anchor_right = 0.5
	tip.anchor_top = 0.84
	tip.anchor_bottom = 0.84
	tip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tip.add_theme_font_size_override("font_size", 20)
	tip.modulate = Color(1, 1, 1, 0.75)
	layer.add_child(tip)
	return layer


var _spectate_index := 0
## 관전: 지금 보고 있는 대상 (HUD 가 이름·상태를 보여 줌), 자유 시점 여부
var spectate_target: Node3D = null
var spectate_free := false
var _spec_excluded: RID


## 볼 수 있는 대상: 살아 있는 동료 먼저, 그다음 술래들
func spectate_targets() -> Array:
	var out: Array = []
	for s in _game().survivors:
		if s != self and not s.is_dead and not s.escaped:
			out.append(s)
	for k in _game().seekers:
		if is_instance_valid(k) and not k.is_killed and k.visible:
			out.append(k)
	return out


func _spectate_step(dir: int) -> void:
	var list := spectate_targets()
	if list.is_empty():
		return
	var cur := list.find(spectate_target)
	_spectate_index = posmod((cur if cur >= 0 else 0) + dir, list.size())
	spectate_free = false
	spring_arm.spring_length = GameConfig.num("view", "camera_distance", 2.6) + 1.2


func _spectate() -> void:
	var delta := get_physics_process_delta_time()
	if spectate_free:
		# 자유 시점: WASD 이동, Space/Ctrl 위아래, Shift 빠르게
		var basis_y := Basis(Vector3.UP, pivot.global_rotation.y)
		var mv := Vector3.ZERO
		mv.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		mv.z = Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
		mv = basis_y * mv
		if Input.is_key_pressed(KEY_SPACE):
			mv.y += 1.0
		if Input.is_key_pressed(KEY_CTRL):
			mv.y -= 1.0
		var spd := 18.0 if Input.is_key_pressed(KEY_SHIFT) else 8.0
		pivot.global_position += mv.normalized() * spd * delta if mv.length() > 0.01 else Vector3.ZERO
		pivot.global_position.y = clampf(pivot.global_position.y, -6.0, 40.0)
		return
	var list := spectate_targets()
	if list.is_empty():
		spectate_target = null
		return
	# 보던 대상이 잡히거나 탈출하면 목록이 줄어 자연스럽게 다음 대상으로
	spectate_target = list[_spectate_index % list.size()]
	var rid: RID = (spectate_target as CollisionObject3D).get_rid() if spectate_target is CollisionObject3D else RID()
	if rid != _spec_excluded:
		if _spec_excluded.is_valid():
			spring_arm.remove_excluded_object(_spec_excluded)
		if rid.is_valid():
			spring_arm.add_excluded_object(rid)
		_spec_excluded = rid
	var want := spectate_target.global_position + Vector3.UP * (2.2 if spectate_target is Seeker else 1.5)
	var k := 1.0 - exp(-10.0 * delta)
	pivot.global_position = want if pivot.global_position.distance_to(want) > 25.0 else pivot.global_position.lerp(want, k)


## 카메라가 보는 수평 방향
func look_direction() -> Vector3:
	var f := -camera.global_basis.z
	f.y = 0.0
	return f.normalized()


func _try_kill_rat() -> bool:
	if not can_interact():
		return false
	var rat := _nearest_rat(GameConfig.num("rat", "minion_kill_reach", 2.0))
	if rat:
		var is_rat := not rat.has_meta("prompt")
		rat.call("kill", self)
		notice.emit("쥐를 잡았어요! (술래가 이 위치를 알게 됐어요)" if is_rat else "제거했어요!")
		return true
	return false


## 거미줄 덫 앞에서 E: 걷어냄
func _try_clear_web() -> bool:
	if not can_interact():
		return false
	var web := nearest_web(GameConfig.num("spider", "web_clear_reach", 2.2))
	if web:
		web.call("clear_web")
		notice.emit("거미줄을 걷어냈어요")
		return true
	return false


## 봉인석 앞에서 E: 미니게임 창 열기
func _try_open_minigame() -> void:
	if not can_interact() or (minigame and is_instance_valid(minigame)):
		return
	var g := _nearest_generator(REPAIR_REACH)
	if g == null:
		return
	if toolkit_ready:
		toolkit_ready = false
		_on_minigame_cleared(g)
		notice.emit("만능 공구! 미니게임 없이 한 단계 클리어")
		return
	minigame = MinigameScript.new()
	minigame.stage = g.stages_done()
	minigame.cleared.connect(_on_minigame_cleared.bind(g))
	minigame.failed.connect(_on_minigame_failed.bind(g))
	minigame.cancelled.connect(_on_minigame_cancelled.bind(g))
	_mg_gen = g
	get_tree().current_scene.add_child(minigame)


func _on_minigame_cleared(g: Generator) -> void:
	if is_instance_valid(g) and Net.is_client():
		# 멀티: 봉인석은 방장 컴퓨터가 계산
		Net.minigame_result.rpc_id(1, _game().generators.find(g), net_slot, true)
		notice.emit("단계 클리어!")
		return
	if is_instance_valid(g):
		g.clear_stage(self)
		if not g.completed:
			notice.emit("단계 클리어! (%d / %d) E로 다음 단계" % [g.stages_done(), g.stage_count()])


## 중간에 그만두면 술래가 그 봉인석 위치를 알아챔
func _on_minigame_cancelled(g: Generator) -> void:
	if not is_instance_valid(g):
		return
	notice.emit("미니게임을 그만뒀어요... 술래가 이 위치를 알아챘어요!")
	if Net.is_client():
		Net.minigame_cancel.rpc_id(1, _game().generators.find(g))
		return
	g.cancel_stage()


func _on_minigame_failed(g: Generator) -> void:
	if is_instance_valid(g) and Net.is_client():
		Net.minigame_result.rpc_id(1, _game().generators.find(g), net_slot, false)
		return
	if is_instance_valid(g):
		g.fail_stage(self)


# ---------------------------------------------------------------- 캐릭터 고유 능력

func _try_ability(slot: int) -> void:
	var info := CharacterDB.get_info(character_id)
	var i := slot - 1
	if CharacterDB.is_passive(character_id, slot):
		notice.emit("%s: 항상 켜져 있는 능력이에요" % info["ability_%d" % slot])
		return
	# 카멜레온 동화 중 R 다시 누르면 취소
	if character_id == "chameleon" and slot == 1 and is_blended():
		blend_time_left = 0.0
		notice.emit("동화 해제")
		return
	# 그림자 속에서 R 다시 누르면 나옴
	if character_id == "shadow" and slot == 1 and is_shadowed():
		_leave_shadow()
		notice.emit("그림자에서 나왔어요")
		return
	if rooted_left > 0.0 or chained_by:
		notice.emit("묶여 있어서 능력을 쓸 수 없어요")
		return
	if is_frozen:
		notice.emit("얼음 상태에서는 고유 능력을 쓸 수 없어요")
		return
	var max_c := CharacterDB.max_charges(character_id, slot)
	if max_c > 0:
		if ability_charges[i] <= 0:
			notice.emit("%s 충전까지 %d초" % [info["ability_%d" % slot], ceili(ability_cooldown_left[i])])
			return
	elif ability_cooldown_left[i] > 0.0:
		notice.emit("%s 쿨타임 %d초" % [info["ability_%d" % slot], ceili(ability_cooldown_left[i])])
		return

	var used := false
	match character_id:
		"chameleon":
			used = _chameleon_blend() if slot == 1 else _chameleon_paint()
		"space":
			used = _space_teleport() if slot == 1 else _space_open_summon()
		"cameraman":
			used = _camera_photo() if slot == 1 else _camera_place()
		"brute":
			used = _brute_punch() if slot == 2 else false
		"medic":
			used = _medic_open_heal() if slot == 1 else _medic_bandage()
		"shadow":
			used = _shadow_dive() if slot == 1 else _shadow_hop()
		"hunter":
			used = _place_effect("trap", global_position) if slot == 1 else _hunter_arrow()
		"bard":
			used = _bard_toggle(slot)
		"mechanic":
			used = _mechanic_item() if slot == 2 else false
		"keeper":
			used = _keeper_guide() if slot == 1 else _keeper_wisps()
		"gravity":
			used = _gravity_float() if slot == 1 else _place_effect("orb", global_position + Vector3.UP * 1.2 + look_direction() * 1.0)
	if not used:
		return
	if character_id == "keeper" and slot == 2:
		ability_cooldown_left[i] = 9999.0  # 빛이 다 사라지면 on_wisp_done 이 쿨타임을 시작
		return
	if max_c > 0:
		if ability_charges[i] >= max_c:
			ability_cooldown_left[i] = CharacterDB.cooldown(character_id, slot)  # 가득 찬 상태에서 쓰면 충전 시작
		ability_charges[i] -= 1
	else:
		ability_cooldown_left[i] = CharacterDB.cooldown(character_id, slot)


func _game() -> Node:
	return get_tree().get_first_node_in_group("game")


func _seeker() -> Seeker:
	return _nearest_seeker()


## 술래가 내 정면(각도 안, 거리 안)에 보이는지
func _seeker_in_front(max_dist: float, max_angle_deg: float) -> bool:
	var s := _seeker()
	if s == null or not s.is_active() or not s.visible_to_players():
		return false
	var to := s.global_position - global_position
	to.y = 0.0
	if to.length() > max_dist:
		return false
	if to.length() > 0.5 and look_direction().angle_to(to.normalized()) > deg_to_rad(max_angle_deg):
		return false
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.3, s.global_position + Vector3.UP * 1.5)
	q.exclude = [get_rid(), s.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# 카멜레온 1: 동화 (제자리, 완전 감지 불가)
func _chameleon_blend() -> bool:
	blend_time_left = GameConfig.num("chameleon", "blend_duration", 7.5)
	play_sfx(SFX_ABILITY)
	notice.emit("동화! 움직일 수 없지만 술래가 감지하지 못해요 (R: 취소)")
	return true


# 카멜레온 2: 맵 물들이기 (나만 감지 불가, 이동 가능, 상호작용 불가)
func _chameleon_paint() -> bool:
	var t := GameConfig.num("chameleon", "paint_duration", 15.0)
	paint_time_left = t
	_game().paint_map(CharacterDB.get_info(character_id)["color"], t)
	play_sfx(SFX_ABILITY)
	return true


# 공간 1: 랜덤 순간이동
func _space_teleport() -> bool:
	teleport_to(_game().random_floor_point())
	notice.emit("순간이동!")
	return true


# 공간 2: 소환할 동료 고르기 창 열기 (실제 소환은 _summon)
func _space_open_summon() -> bool:
	summon_candidates.clear()
	for node in get_tree().get_nodes_in_group("survivor"):
		var s := node as Survivor
		if s and s != self and not s.is_dead:
			summon_candidates.append(s)
	if summon_candidates.is_empty():
		notice.emit("소환할 동료가 없어요")
		return false
	summon_menu_open = true
	return false  # 아직 쿨타임은 시작하지 않음 (고른 다음에 시작)


func _summon(index: int) -> void:
	summon_menu_open = false
	if index >= summon_candidates.size():
		return
	var target := summon_candidates[index]
	if not is_instance_valid(target) or target.is_dead:
		return
	var spot: Vector3 = _game().closest_floor_point(global_position + look_direction() * 2.0)
	target.teleport_to(spot)
	ability_cooldown_left[1] = CharacterDB.cooldown(character_id, 2)
	notice.emit("%s 소환!%s" % [target.display_name, " (얼음 상태 그대로)" if target.is_frozen else ""])


# 카메라맨 1: 플래시 촬영 (술래 스턴)
func _camera_photo() -> bool:
	play_sfx(SFX_SHUTTER)
	flashed.emit()
	if _seeker_in_front(GameConfig.num("cameraman", "photo_range", 14.0), GameConfig.num("cameraman", "photo_angle", 30.0)):
		_seeker().stun(GameConfig.num("cameraman", "photo_stun_time", 1.5))
		notice.emit("찰칵! 술래 스턴!")
	else:
		notice.emit("찰칵! (술래가 안 찍혔어요)")
	return true


# 카메라맨 2: 카메라 설치 (술래가 앞을 지나가면 모두에게 위치 표시)
func _camera_place() -> bool:
	var cam := Node3D.new()
	cam.set_script(PlacedCameraScript)
	get_tree().current_scene.add_child(cam)
	cam.global_position = _game().closest_floor_point(global_position + look_direction() * 1.2)
	cam.look_at(cam.global_position + look_direction(), Vector3.UP)
	cam.call("setup", self)
	play_sfx(SFX_ABILITY)
	notice.emit("카메라 설치! (%d초)" % int(GameConfig.num("cameraman", "camera_duration", 20.0)))
	return true


# 사나이 2: 강펀치 (폭 5m, 길이 3m의 거대한 주먹. 그 안의 술래는 모두 맵 끝까지)
func _brute_punch() -> bool:
	var length := GameConfig.num("brute", "punch_range", 3.0)
	var half_w := GameConfig.num("brute", "punch_width", 5.0) / 2.0
	# 자동 조준: 주먹이 닿는 거리 안에 술래가 있으면 (등 뒤라도) 그쪽으로 펀치
	var fwd := look_direction()
	var nearest := length + 1.0
	for node in get_tree().get_nodes_in_group("seeker"):
		var sk := node as Seeker
		if sk == null or not sk.is_active() or not sk.visible_to_players():
			continue
		var to := sk.global_position - global_position
		to.y = 0.0
		if to.length() < nearest and to.length() > 0.05:
			nearest = to.length()
			fwd = to.normalized()
	var side := Vector3(-fwd.z, 0.0, fwd.x)
	var hits: Array = []
	for node in get_tree().get_nodes_in_group("seeker"):
		var sk := node as Seeker
		if sk == null or not sk.is_active() or not sk.visible_to_players():
			continue
		var to := sk.global_position - global_position
		to.y = 0.0
		var ahead := to.dot(fwd)
		if ahead < -0.5 or ahead > length + 0.6 or absf(to.dot(side)) > half_w + 0.4:
			continue
		# 낮은 울타리·차 같은 데 걸리지 않게 두 높이로 확인 (둘 중 하나만 뚫려 있어도 맞음)
		for h in [1.0, 1.7]:
			var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * h, sk.global_position + Vector3.UP * h)
			q.exclude = [get_rid(), sk.get_rid()]
			if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				hits.append(sk)
				break
	play_sfx(SFX_PUNCH)
	# 몸을 펀치 방향으로 돌리고 팔을 쭉 내지름 + 주먹 이펙트
	body.look_at(body.global_position - fwd, Vector3.UP)
	body.punch(0.45)
	load("res://scripts/fist_fx.gd").spawn(self, fwd, not hits.is_empty())
	_punch_camera()
	if hits.is_empty():
		notice.emit("헛손질! (주먹 안에 술래가 없어요)")
		ability_cooldown_left[1] = GameConfig.num("brute", "punch_miss_cooldown", 3.0)
		return false
	var stun := GameConfig.num("brute", "punch_stun", 1.5)
	for sk in hits:
		if Net.is_client():
			# 멀티: 술래는 방장 컴퓨터가 움직이므로 방장에게 날려 달라고 보냄
			Net.seeker_knockback.rpc_id(1, _game().seekers.find(sk), fwd, stun)
		else:
			sk.knockback(fwd)
			sk.set_meta("land_stun", stun)
	_shake(0.25)
	notice.emit("강펀치!!")
	return true


# ---------------------------------------------------------------- 히든 캐릭터: 중력술사

const BLUE := Color(0.25, 0.55, 1.0)
const RED := Color(1.0, 0.2, 0.2)
const PURPLE := Color(0.7, 0.25, 1.0)


# 무중력: 정면의 술래를 3초 동안 공중에 띄움
func _gravity_float() -> bool:
	var reach := GameConfig.num("gravity", "float_range", 16.0)
	var target: Seeker = null
	var best := INF
	for node in get_tree().get_nodes_in_group("seeker"):
		var sk := node as Seeker
		if sk == null or not sk.is_active() or not sk.visible_to_players():
			continue
		var to := sk.global_position - global_position
		to.y = 0.0
		if to.length() > reach or (to.length() > 1.0 and look_direction().angle_to(to.normalized()) > deg_to_rad(35.0)):
			continue
		if to.length() < best:
			best = to.length()
			target = sk
	if target == null:
		notice.emit("정면에 술래가 없어요")
		return false
	target.float_up(GameConfig.num("gravity", "float_time", 3.0))
	_burst(target.global_position + Vector3.UP * 1.5, Color(0.6, 0.8, 1.0), 4.0)
	play_sfx(SFX_ABILITY)
	notice.emit("무중력! 술래가 공중에 떴어요")
	return true


# ---------------------------------------------------------------- 새 캐릭터 능력

## 맵에 남는 능력 효과 (연막, 결계, 덫, 미끼, 바리케이드, 무중력 구슬) 놓기
func _place_effect(kind: String, pos: Vector3) -> bool:
	var e := Node3D.new()
	e.set_script(AbilityEffectScript)
	get_tree().current_scene.add_child(e)
	var floor_pos: Vector3 = pos if kind == "orb" else _game().closest_floor_point(pos)
	e.call("setup", kind, floor_pos, look_direction(), self)
	play_sfx(SFX_ABILITY)
	var names := {"smoke": "연막탄!", "ward": "등불 결계!", "trap": "덫을 숨겼어요", "decoy": "미끼 인형!", "barricade": "바리케이드!", "orb": "무중력 구슬!"}
	notice.emit(names.get(kind, ""))
	return true


# 의사 1: 치료 대상 고르기 창 열기 (실제 치료는 _medic_heal)
func _medic_open_heal() -> bool:
	summon_candidates.clear()
	for node in get_tree().get_nodes_in_group("survivor"):
		var s := node as Survivor
		if s and s != self and not s.is_dead and not s.escaped:
			summon_candidates.append(s)
	if summon_candidates.is_empty():
		notice.emit("치료할 동료가 없어요")
		return false
	summon_menu_open = true
	heal_menu = true
	return false  # 고른 다음에 쿨타임 시작


## 고른 동료: 얼음이면 해동, 아니면 이동속도 증가 (중첩 안 됨)
func _medic_heal(index: int) -> void:
	summon_menu_open = false
	heal_menu = false
	if index >= summon_candidates.size():
		return
	var t := summon_candidates[index]
	if not is_instance_valid(t) or t.is_dead or t.escaped:
		return
	if t.is_frozen:
		t.unfreeze(self)
		notice.emit("치료! %s 해동" % t.display_name)
	else:
		t.give_boost(GameConfig.num("medic", "heal_speed", 0.2), GameConfig.num("medic", "heal_time", 8.0))
		notice.emit("치료! %s 이동속도 +%d%%" % [t.display_name, int(GameConfig.num("medic", "heal_speed", 0.2) * 100)])
	_burst(t.global_position + Vector3.UP, Color(0.5, 1.0, 0.7), 2.5)
	play_sfx(SFX_ABILITY)
	ability_cooldown_left[0] = CharacterDB.cooldown(character_id, 1)


# 의사 2: 붕대 당기기 (조준한 동료를 내 앞으로, 얼음 상태도 가능)
func _medic_bandage() -> bool:
	var target: Survivor = null
	var best_angle := deg_to_rad(20.0)
	var reach := GameConfig.num("medic", "bandage_range", 15.0)
	for node in get_tree().get_nodes_in_group("survivor"):
		var s := node as Survivor
		if s == null or s == self or s.is_dead or s.escaped or s.in_locker:
			continue
		var to := s.global_position - global_position
		to.y = 0.0
		if to.length() > reach or to.length() < 1.0:
			continue
		var ang := look_direction().angle_to(to.normalized())
		if ang < best_angle:
			var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.2, s.global_position + Vector3.UP * 1.2)
			q.exclude = [get_rid(), s.get_rid()]
			if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				best_angle = ang
				target = s
	if target == null:
		notice.emit("조준한 곳에 동료가 없어요 (%dm 안)" % int(reach))
		return false
	var spot: Vector3 = _game().closest_floor_point(global_position + look_direction() * 1.5)
	target.bandage_pull(spot, GameConfig.num("medic", "bandage_pull_time", 0.5))
	_beam(global_position + Vector3.UP * 1.1, target.global_position + Vector3.UP * 1.1, Color(0.95, 0.95, 0.88), 0.12, 0.5)
	play_sfx(SFX_ABILITY)
	notice.emit("붕대 당기기! %s%s" % [target.display_name, " (얼음 상태 그대로)" if target.is_frozen else ""])
	return true


# 그림자 1: 그림자 속으로 (옆에 누가 있으면 그 그림자에 붙음, 아니면 어두운 곳에서만)
func _shadow_dive() -> bool:
	var host: Node3D = null
	var best := 3.0
	for group in ["survivor", "seeker"]:
		for node in get_tree().get_nodes_in_group(group):
			if node == self or (node is Survivor and (node as Survivor).is_dead):
				continue
			var d: float = (node as Node3D).global_position.distance_to(global_position)
			if d < best:
				best = d
				host = node
	if host == null and _in_bright_light():
		notice.emit("여기는 너무 밝아서 그림자가 없어요")
		return false
	enter_shadow(GameConfig.num("shadow", "shadow_time", 20.0), host)
	notice.emit("그림자 속으로!" + (" (%s의 그림자에 붙음)" % _host_name(host) if host else "") + "  R: 나오기 · T: 동료 그림자로")
	ability_cooldown_left[0] = 0.0
	return false  # 쿨타임은 그림자에서 나온 뒤에 시작


## 그림자에서 나오면 (시간 끝, R, 쇠사슬 등) 쿨타임 시작
func _leave_shadow() -> void:
	var was := is_shadowed()
	super._leave_shadow()
	if was and character_id == "shadow":
		ability_cooldown_left[0] = CharacterDB.cooldown(character_id, 1)


# 그림자 2: 그림자 건너가기 (그림자 속에서 다른 동료의 그림자로)
func _shadow_hop() -> bool:
	if not is_shadowed():
		notice.emit("그림자 속에 있을 때만 쓸 수 있어요 (R 먼저)")
		return false
	var mates: Array = []
	for s in _game().survivors:
		if s != self and not s.is_dead and not s.escaped and s.in_locker == null:
			mates.append(s)
	if mates.is_empty():
		notice.emit("건너갈 동료가 없어요")
		return false
	var t: Survivor = mates[_hop_index % mates.size()]
	if t == shadow_host and mates.size() > 1:
		_hop_index += 1
		t = mates[_hop_index % mates.size()]
	_hop_index += 1
	var facing := t.body.global_basis.z  # 동료가 바라보는 방향 → 그 뒤에 붙음
	facing.y = 0.0
	global_position = t.global_position - facing.normalized() * 0.9 + Vector3.UP * 0.1
	velocity = Vector3.ZERO
	shadow_host = t
	play_sfx(SFX_ABILITY)
	notice.emit("%s의 그림자로 건너갔어요" % t.display_name)
	return true


func _host_name(host: Node3D) -> String:
	if host is Survivor:
		return (host as Survivor).display_name
	return "술래"


## 가로등·간판·모닥불 같은 밝은 불빛 바로 아래인지 (캐릭터가 들고 있는 불빛은 제외)
func _in_bright_light() -> bool:
	for l in get_tree().current_scene.find_children("*", "OmniLight3D", true, false):
		var light := l as OmniLight3D
		if light.light_energy <= 0.05 or not light.is_visible_in_tree():
			continue
		var carried := false
		var n: Node = light.get_parent()
		while n:
			if n is Survivor or n is Seeker:
				carried = true
				break
			n = n.get_parent()
		if not carried and light.global_position.distance_to(global_position) < light.omni_range * 0.45:
			return true
	return false


# 사냥꾼 2: 핏빛 화살 (술래 수만큼만)
var arrows_left := -1
func _hunter_arrow() -> bool:
	if arrows_left < 0:
		arrows_left = _game().seekers.size()
	if arrows_left <= 0:
		notice.emit("화살을 모두 썼어요")
		return false
	arrows_left -= 1
	_place_effect("arrow", global_position + Vector3.UP * 1.4 + look_direction() * 0.8)
	return true


# 악사: 노래 켜기/끄기 (1 = 광란의 메탈, 2 = 질주의 비트). 둘 중 하나만 켜짐
var song := 0
var _song_player: AudioStreamPlayer3D
var _song_tick := 0.0
## 노래 파일은 필요할 때 불러옴 (파일 문제가 있어도 게임 전체가 멈추지 않게)
const SONGS := {1: "res://audio/song_metal.wav", 2: "res://audio/song_beat.wav"}

func _bard_toggle(which: int) -> bool:
	if song == which:
		_set_song(0)
		notice.emit("노래를 멈췄어요")
	else:
		_set_song(which)
		notice.emit("광란의 메탈! 술래 위치가 모두에게 보여요 (내 위치도 들켜요)" if which == 1 else "질주의 비트! 우리 팀 이동속도 +15% (내 위치가 들켜요)")
	return true


func _set_song(which: int) -> void:
	song = which
	if _song_player == null:
		_song_player = AudioStreamPlayer3D.new()
		_song_player.max_distance = GameConfig.num("bard", "song_hear_distance", 90.0)
		_song_player.unit_size = 10.0
		_song_player.position.y = 1.2
		add_child(_song_player)
		_song_player.finished.connect(_on_song_finished)
	if which == 0:
		_song_player.stop()
	else:
		_song_player.stream = load(SONGS[which])
		_song_player.play()


func _on_song_finished() -> void:
	if song != 0:
		_song_player.play()  # 켜져 있는 동안 반복


## 노래 효과 (1초마다): 술래가 내 위치를 앎 + 메탈은 술래 위치 공개 / 비트는 팀 이동속도 증가
func _update_song(delta: float) -> void:
	if song == 0:
		return
	if is_frozen or is_dead:
		_set_song(0)
		return
	_song_tick -= delta
	if _song_tick > 0.0:
		return
	_song_tick = 1.0
	for node in get_tree().get_nodes_in_group("seeker"):
		var sk := node as Seeker
		sk.alert_to(global_position)
		if song == 1:
			sk.reveal(1.3)
	if song == 2:
		for node in get_tree().get_nodes_in_group("survivor"):
			var s := node as Survivor
			if not s.is_dead:
				s.give_boost(GameConfig.num("bard", "beat_speed", 0.15), 1.3)
		give_boost(GameConfig.num("bard", "beat_self_speed", 0.3), 1.3)  # 악사 본인은 더 빠르게


# 등불지기 1: 길잡이 등불 (다시 쓰면 기존 등불은 사라지고 새로)
var _guide: Node3D = null
func _keeper_guide() -> bool:
	if _guide and is_instance_valid(_guide):
		_guide.queue_free()
	_guide = Node3D.new()
	_guide.set_script(AbilityEffectScript)
	get_tree().current_scene.add_child(_guide)
	_guide.call("setup", "guide", global_position + look_direction() * 1.5 + Vector3.UP * 1.5, look_direction(), self)
	notice.emit("길잡이 등불! 봉인석으로 안내해요 (가까이 따라가세요)")
	return true


# 등불지기 2: 붉은 탐색광 (빛이 모두 사라진 뒤에 쿨타임 시작)
var _wisps_alive := 0
func _keeper_wisps() -> bool:
	var seekers := get_tree().get_nodes_in_group("seeker")
	if seekers.is_empty():
		return false
	for node in seekers:
		var w := Node3D.new()
		w.set_script(AbilityEffectScript)
		get_tree().current_scene.add_child(w)
		w.set_meta("target", node)
		w.call("setup", "wisp", global_position + Vector3.UP * 2.0, look_direction(), self)
		_wisps_alive += 1
	notice.emit("붉은 탐색광이 술래를 찾아 나서요")
	return true


## 탐색광 하나가 사라질 때 ability_effect 가 불러 줌. 모두 사라지면 쿨타임 시작
func on_wisp_done() -> void:
	_wisps_alive = max(0, _wisps_alive - 1)
	if _wisps_alive == 0:
		ability_cooldown_left[1] = CharacterDB.cooldown(character_id, 2)


# 정비공 2: 보급품 (신발/갑옷/헬멧 중 랜덤, 1개만)
func _mechanic_item() -> bool:
	if not give_random_item():
		notice.emit("이미 %s을(를) 착용 중이에요 (깨지면 다시 쓸 수 있어요)" % ITEM_NAMES[item])
		return false
	notice.emit("보급품: %s 착용!" % ITEM_NAMES[item])
	if item == "helmet":
		_refresh_witch_fog()
	return true


## 헬멧을 쓰면 지금 깔린 마녀 안개도 바로 걷힘
func _refresh_witch_fog() -> void:
	for sk in get_tree().get_nodes_in_group("seeker"):
		if sk.has_method("_set_fog") and float(sk.get("_fog_left")) > 0.0:
			sk.call("_set_fog", false)


# 정비공 1: 만능 공구 준비 (예전 능력, 지금은 안 씀)
func _mechanic_toolkit() -> bool:
	if toolkit_ready:
		notice.emit("이미 공구가 준비돼 있어요")
		return false
	toolkit_ready = true
	notice.emit("만능 공구 준비! 봉인석에서 E를 누르면 한 단계 자동 클리어")
	return true


## 강펀치 연출: 카메라가 잠깐 옆으로 돌아서 주먹이 옆에서 보이게 (balance.cfg [brute] punch_camera_swing, 0 = 끔)
func _punch_camera() -> void:
	var swing := deg_to_rad(GameConfig.num("brute", "punch_camera_swing", 40.0))
	if swing <= 0.0:
		return
	var tw := create_tween()
	tw.tween_property(spring_arm, "rotation:y", swing, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_property(spring_arm, "rotation:y", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## 화면 흔들기 (잠깐 흔들고 원래대로)
func _shake(amount: float) -> void:
	var tw := create_tween()
	for k in 6:
		var a := amount * (1.0 - k / 6.0)
		tw.tween_property(camera, "h_offset", randf_range(-a, a), 0.03)
		tw.parallel().tween_property(camera, "v_offset", randf_range(-a, a), 0.03)
	tw.tween_property(camera, "h_offset", 0.0, 0.03)
	tw.parallel().tween_property(camera, "v_offset", 0.0, 0.03)


func _glow_mat(c: Color, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 4.0
	return m


func _orb(pos: Vector3, c: Color, radius: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.material_override = _glow_mat(c)
	var light := OmniLight3D.new()
	light.light_color = c
	light.omni_range = 4.0
	light.light_energy = 2.0
	mi.add_child(light)
	get_tree().current_scene.add_child(mi)
	mi.global_position = pos
	return mi


## a 에서 b 까지 빛줄기 (폭 width), duration 동안 서서히 사라짐
func _beam(a: Vector3, b: Vector3, c: Color, width: float, duration: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, width * 0.6 if width > 2.0 else width, a.distance_to(b))
	mi.mesh = bm
	var mat := _glow_mat(c, 0.75)
	mi.material_override = mat
	get_tree().current_scene.add_child(mi)
	mi.global_position = (a + b) / 2.0
	if a.distance_to(b) > 0.05:
		mi.look_at(b, Vector3.UP)
	var light := OmniLight3D.new()
	light.light_color = c
	light.omni_range = 20.0
	light.light_energy = 4.0
	mi.add_child(light)
	var tw := mi.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, duration)
	tw.parallel().tween_property(mi, "scale", Vector3(0.2, 0.2, 1.0), duration)
	tw.tween_callback(mi.queue_free)


## 퍼지면서 사라지는 빛 구체
func _burst(pos: Vector3, c: Color, size: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	mi.mesh = sm
	var mat := _glow_mat(c, 0.7)
	mi.material_override = mat
	get_tree().current_scene.add_child(mi)
	mi.global_position = pos
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size, 0.4)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(mi.queue_free)


## 부서진 자리에서 튀어 오르는 파편
func _debris(pos: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.42, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for k in 5:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * randf_range(0.3, 0.9)
		mi.mesh = bm
		mi.material_override = mat
		get_tree().current_scene.add_child(mi)
		var start := pos + Vector3(randf_range(-1.5, 1.5), randf_range(0.5, 3.0), randf_range(-1.5, 1.5))
		mi.global_position = start
		var fly := Vector3(randf_range(-6, 6), randf_range(4, 10), randf_range(-6, 6))
		var arc := func(p: float) -> void: mi.global_position = start + fly * p + Vector3.DOWN * 9.0 * p * p
		var tw := mi.create_tween().set_parallel(true)
		tw.tween_method(arc, 0.0, 1.0, 1.2)
		tw.tween_property(mi, "rotation", Vector3(randf() * 8, randf() * 8, randf() * 8), 1.2)
		tw.tween_property(mat, "albedo_color:a", 0.0, 1.2)
		tw.chain().tween_callback(mi.queue_free)


# ---------------------------------------------------------------- 상점 공통 능력

func can_use_noise() -> bool:
	return is_frozen and not is_dead and SaveData.has_ability("noise") and noise_cooldown_left <= 0.0


## [상점 공통 능력] 소리 내기
## 화면 가운데(조준점)가 가리키는 곳에 소리를 만들어 술래를 유인합니다.
func use_noise_ability() -> void:
	if not can_use_noise():
		return
	var max_throw := GameConfig.num("ability", "noise_max_throw", 25.0)
	var from := camera.global_position
	var to := from - camera.global_basis.z * max_throw
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	var target: Vector3
	if hit.is_empty():
		target = Vector3(to.x, 0.5, to.z)  # 하늘을 조준했으면 그 아래 땅으로
	else:
		target = hit["position"]

	NoiseBus.make_noise(target, GameConfig.num("ability", "noise_range", 18.0), null)
	noise_cooldown_left = GameConfig.num("ability", "noise_cooldown", 100.0)
	_spawn_lure_sound(target)


## 이모트 (숫자키 1~0). 술래 놀리기용, 게임에는 영향 없음
func _use_emote_slot(i: int) -> void:
	if i >= EMOTES.size():
		notice.emit("%d번 이모트는 비어 있어요" % ((i + 1) % 10))
		return
	if is_frozen or is_dead or escaped or in_locker or is_shadowed() or chained_by or rooted_left > 0.0 \
			or (minigame and is_instance_valid(minigame)) or not is_on_floor():
		return
	if dance_left > 0.0:
		var same: bool = emote_id == EMOTES[i][0]
		stop_dance()
		if same:
			return  # 같은 키를 다시 누르면 멈춤
	var secs: float = EMOTES[i][2]
	if EMOTES[i][0] == "butt_dance":
		secs = GameConfig.num("emote", "dance_time", secs)
	start_emote(EMOTES[i][0], secs)


## [상점 공통 능력] 이모티콘 (술래 놀리기용, 게임에는 영향 없음)
func use_emote() -> void:
	if is_frozen and not is_dead and SaveData.has_ability("emote"):
		show_emote("메롱~ :P")


## 소리를 던진 위치에서 실제로 소리가 나게 (헤드셋으로도 들림)
func _spawn_lure_sound(pos: Vector3) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = SFX_LURE
	p.max_distance = 30.0
	get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
