extends Node3D
## 추격전 구조물 (폐가·담장에 붙는 것들)
##   "door"   문: E로 열고 닫음. 닫힌 문은 술래가 부수는 데 2초 (유령은 통과)
##   "window" 창문: 지나가면 넘음. 생존자는 빠르게(0.35초), 술래는 느리게(1.3초)
##   "pallet" 판자: E로 넘어뜨림. 그때 맞은 술래는 기절. 넘어진 판자는 생존자만 넘을 수 있고 술래는 부숴야 함 (한 번 쓰면 끝)
##   "locker" 사물함: E로 숨기/나가기. 30초 넘게 숨어 있으면 고양이가 나와서 울음 → 술래가 그 소리를 들음
##            술래가 근처를 수색하다 열면 안에 숨은 생존자는 잡힘
## 이 노드의 로컬 x축이 구멍(문·창문·판자)의 가로 방향, z축이 벽을 뚫고 지나가는 방향입니다.

## 넘어진 판자의 충돌 레이어 (술래만 부딪힘. seeker.gd 가 이 레이어를 collision_mask 에 넣음)
const PALLET_LAYER := 16

var kind := "door"
var reach := 2.0

var _hinge: Node3D
var _door_body: StaticBody3D
var _open := true
var _broken := false
var _break_by: Seeker = null
var _break_left := 0.0

var _plank: Node3D
var _plank_body: StaticBody3D
var _dropped := false

var occupant: Survivor = null
var _cat: Node3D = null
var _cat_timer := 0.0
var _audio: AudioStreamPlayer3D


func setup(prop_kind: String, mats: Dictionary) -> void:
	kind = prop_kind
	_audio = AudioStreamPlayer3D.new()
	_audio.max_distance = 50.0
	_audio.unit_size = 5.0
	add_child(_audio)
	match kind:
		"door":
			add_to_group("prop")
			_hinge = Node3D.new()
			_hinge.position = Vector3(-0.7, 0, 0)
			add_child(_hinge)
			_door_body = _static_box(_hinge, Vector3(0.7, 1.05, 0), Vector3(1.4, 2.1, 0.1), mats.get("crate"), 1)
			var style := str(get_meta("door_style", ""))
			if style != "":
				_modern_door(style)
			# 나무 문: 가로 띠 2개 + Z자 버팀목 + 경첩 + 손잡이
			var brace := _mat_col(Color(0.24, 0.16, 0.1))
			for z in ([] if style != "" else [-0.065, 0.065]):
				for y in [-0.7, 0.7]:
					_deco(_door_body, Vector3(0, y, z), Vector3(1.3, 0.16, 0.04), brace)
				var diag := _deco(_door_body, Vector3(0, 0, z), Vector3(1.5, 0.14, 0.04), brace)
				diag.rotation.z = 0.78
				for y in [-0.7, 0.7]:
					_deco(_door_body, Vector3(-0.6, y, z * 1.25), Vector3(0.28, 0.07, 0.02), _mat_col(Color(0.15, 0.15, 0.15)))
				_deco(_door_body, Vector3(0.55, 0.0, z * 1.6), Vector3(0.06, 0.06, 0.08), _mat_col(Color(0.55, 0.45, 0.2), 0.6))
			# 문틀이 넓으면 문짝도 넓게 (경첩은 문틀 한쪽 끝)
			var dw := float(get_meta("door_w", 1.4))
			if absf(dw - 1.4) > 0.01:
				_hinge.position.x = -dw * 0.5
				_hinge.scale.x = dw / 1.4
			_set_door(true, false)
		"pallet":
			add_to_group("prop")
			reach = 2.2
			_plank = Node3D.new()
			_plank.position = Vector3(1.0, 0, 0)  # 담장 끝에 기대어 세워 둠
			add_child(_plank)
			var wood := StandardMaterial3D.new()
			wood.albedo_color = Color(0.55, 0.38, 0.2)
			_plank_body = _static_box(_plank, Vector3(-1.0, 0.45, 0), Vector3(2.0, 0.9, 0.14), wood, 0)
			# 판자 여러 장 + 뒤쪽 가로대 (사이사이 틈이 보이게)
			_plank_body.get_child(1).visible = false
			for i in 6:
				var c := Color(0.55, 0.38, 0.2).darkened(randf() * 0.25)
				_deco(_plank_body, Vector3(-0.83 + i * 0.333, randf_range(-0.03, 0.03), 0.03), Vector3(0.29, 0.9 + randf_range(-0.06, 0.04), 0.05), _mat_col(c))
			for y in [-0.3, 0.3]:
				_deco(_plank_body, Vector3(0, y, -0.035), Vector3(2.0, 0.12, 0.07), _mat_col(Color(0.36, 0.24, 0.13)))
			_plank.rotation.z = -(PI / 2.0 - 0.15)  # 세워진 상태 (충돌 없음)
		"locker":
			add_to_group("prop")
			reach = 1.7
			_wardrobe = mats.has("forest_floor")
			_build_locker(mats)
		"window":
			pass


## 나가는 위치 (사물함 앞)
func front_point() -> Vector3:
	return global_position - global_basis.z * 0.9 + Vector3.UP * 0.1


func can_use(s: Survivor) -> bool:
	match kind:
		"door":
			return not _broken
		"pallet":
			return not _dropped
		"locker":
			return occupant == null and s.in_locker == null
	return false


func prompt(_s: Survivor) -> String:
	match kind:
		"door":
			return "[E] 문 닫기" if _open else "[E] 문 열기"
		"pallet":
			return "[E] 판자 넘어뜨리기 (맞은 술래 기절)"
		"locker":
			return "[E] %s에 숨기 (들어갈 때 소리가 나요)" % ("옷장" if _wardrobe else "사물함")
	return ""


func use(s: Survivor) -> void:
	match kind:
		"door":
			_set_door(not _open, true)
		"pallet":
			_drop_pallet()
		"locker":
			occupant = s
			s.enter_locker(self)
			_play_load("res://audio/creak.wav", 1.3)
			_swing_locker(0.25)


func on_exit(s: Survivor) -> void:
	if occupant == s:
		occupant = null
	_remove_cat()
	_swing_locker(0.3)


# ---------------------------------------------------------------- 매 프레임

func _physics_process(delta: float) -> void:
	match kind:
		"door":
			_update_door(delta)
		"pallet":
			_update_pallet(delta)
		"locker":
			_update_locker(delta)
		"window":
			_vault_zone(0.8)


func _update_door(delta: float) -> void:
	if _broken:
		return
	if _break_by:
		_break_left -= delta
		if _break_left <= 0.0:
			_break_door()
		return
	if _open:
		return
	var center := _door_body.global_position
	for node in get_tree().get_nodes_in_group("seeker"):
		var sk := node as Seeker
		if sk.collision_mask == 0 or not sk.is_active():
			continue  # 유령은 그냥 통과
		if _flat_dist(sk.global_position, center) < 1.5:
			_break_by = sk
			_break_left = GameConfig.num("structure", "door_break_time", 2.0) * float(sk.get_meta("break_mult", 1.0))
			sk._lock_left = maxf(sk._lock_left, _break_left)
			_play_load("res://audio/punch.wav", 0.6)
			return
	# 동료 봇은 닫힌 문 앞에 오면 알아서 엶
	for node in get_tree().get_nodes_in_group("survivor"):
		if not node.is_in_group("player") and _flat_dist((node as Node3D).global_position, center) < 1.4:
			_set_door(true, true)
			return


func _set_door(open: bool, sound: bool) -> void:
	_open = open
	# 열린 문짝은 부딪히지 않음 (벽에 붙어 있는 셈이라 봇·사람이 걸리지 않게)
	if _door_body:
		_door_body.collision_layer = 0 if open else 1
	var tw := create_tween()
	tw.tween_property(_hinge, "rotation:y", -1.6 if open else 0.0, 0.25)
	if sound:
		_play_load("res://audio/creak.wav", 1.6)


func _break_door() -> void:
	_broken = true
	_break_by = null
	remove_from_group("prop")
	_play_load("res://audio/punch.wav", 0.5)
	var tw := create_tween()
	tw.tween_property(_hinge, "scale", Vector3(1, 0.05, 1), 0.2)
	tw.tween_callback(_hinge.queue_free)


func _update_pallet(delta: float) -> void:
	if not _dropped:
		_bot_drop_check()
		return
	if _break_by:
		_break_left -= delta
		if _break_left <= 0.0:
			_play_load("res://audio/punch.wav", 0.5)
			queue_free()
		return
	_vault_zone(1.0)
	for node in get_tree().get_nodes_in_group("seeker"):
		var sk := node as Seeker
		if sk.collision_mask == 0 or not sk.is_active() or sk._stun_left > 0.0:
			continue
		if _flat_dist(sk.global_position, global_position) < 1.4:
			_break_by = sk
			_break_left = GameConfig.num("structure", "pallet_break_time", 2.5) * float(sk.get_meta("break_mult", 1.0))
			sk._lock_left = maxf(sk._lock_left, _break_left)
			return


## 동료 봇: 쫓기는 중 판자 옆에 오면 넘어뜨림
func _bot_drop_check() -> void:
	for node in get_tree().get_nodes_in_group("survivor"):
		var s := node as Survivor
		if s.is_in_group("player") or not s.can_interact() or _flat_dist(s.global_position, global_position) > 1.8:
			continue
		for sk_node in get_tree().get_nodes_in_group("seeker"):
			var sk := sk_node as Seeker
			var d := _flat_dist(sk.global_position, global_position)
			if sk.chase_target == s and d > 1.0 and d < 6.0:
				_drop_pallet()
				return


func _drop_pallet() -> void:
	_dropped = true
	remove_from_group("prop")
	var tw := create_tween()
	tw.tween_property(_plank, "rotation:z", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_plank_body.collision_layer = PALLET_LAYER
	_play_load("res://audio/punch.wav", 0.8)
	# 넘어뜨릴 때 바로 밑에 있던 술래는 기절
	for node in get_tree().get_nodes_in_group("seeker"):
		var sk := node as Seeker
		if sk.is_active() and _flat_dist(sk.global_position, global_position) < 1.8:
			sk.stun(GameConfig.num("structure", "pallet_stun", 2.0))


func _update_locker(delta: float) -> void:
	if occupant == null:
		return
	if not is_instance_valid(occupant) or occupant.is_dead:
		occupant = null
		_remove_cat()
		return
	# 술래가 근처를 수색하다가 사물함을 열면 잡힘
	for node in get_tree().get_nodes_in_group("seeker"):
		var sk := node as Seeker
		if not sk.is_active() or _flat_dist(sk.global_position, global_position) > 1.8:
			continue
		if sk.state == Seeker.State.SEARCH or sk.state == Seeker.State.INVESTIGATE or sk.state == Seeker.State.CHASE:
			var s := occupant
			_play_load("res://audio/creak.wav", 0.8)
			s.exit_locker()
			_swing_locker(1.2)
			sk._lock_left = maxf(sk._lock_left, 0.4)
			s.die()
			return
	# 오래 숨어 있으면 고양이가 나와서 울음
	if occupant._locker_time >= GameConfig.num("structure", "locker_cat_time", 30.0):
		if _cat == null:
			_spawn_cat()
			_cat_timer = 0.0
		_cat_timer -= delta
		if _cat_timer <= 0.0:
			_cat_timer = GameConfig.num("structure", "cat_interval", 6.0)
			_play_load("res://audio/cat.wav", randf_range(0.9, 1.1))
			NoiseBus.make_noise(global_position, GameConfig.num("structure", "cat_noise", 45.0), null)
			if occupant.has_signal("notice"):
				occupant.emit_signal("notice", "고양이가 사물함을 보고 울어요! 술래가 들었어요")


func _spawn_cat() -> void:
	_cat = Node3D.new()
	add_child(_cat)
	_cat.position = Vector3(0.7, 0, -0.9)
	_cat.rotation.y = PI * 0.8  # 사물함 쪽을 봄
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color(0.12, 0.11, 0.12)
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color(1.0, 0.85, 0.2)
	eye.emission_enabled = true
	eye.emission = Color(1.0, 0.8, 0.1)
	eye.emission_energy_multiplier = 3.0
	_cat_sphere(Vector3(0, 0.22, 0.05), Vector3(0.18, 0.16, 0.28), fur)
	_cat_sphere(Vector3(0, 0.38, -0.2), Vector3(0.12, 0.11, 0.11), fur)
	for x in [-0.05, 0.05]:
		_cat_sphere(Vector3(x, 0.4, -0.3), Vector3(0.022, 0.022, 0.015), eye)
		var ear := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.06, 0.08, 0.03)
		ear.mesh = pm
		ear.material_override = fur
		ear.position = Vector3(x, 0.5, -0.2)
		_cat.add_child(ear)
	var tail := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.015
	cyl.bottom_radius = 0.03
	cyl.height = 0.35
	tail.mesh = cyl
	tail.material_override = fur
	tail.position = Vector3(0, 0.38, 0.3)
	tail.rotation.x = -0.5
	_cat.add_child(tail)


func _cat_sphere(pos: Vector3, scale_v: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	m.mesh = s
	m.material_override = mat
	m.position = pos
	m.scale = scale_v
	_cat.add_child(m)


func _remove_cat() -> void:
	if _cat:
		_cat.queue_free()
		_cat = null


# ---------------------------------------------------------------- 넘기 (창문 / 넘어진 판자)

## 구멍(가로 half_w) 안으로 들어온 몸을 반대편으로 넘김
func _vault_zone(half_w: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for group in ["survivor", "seeker"]:
		for node in get_tree().get_nodes_in_group(group):
			var b := node as CharacterBody3D
			if b == null or b.has_meta("vaulting") or float(b.get_meta("vault_cd", 0.0)) > now:
				continue
			if b is Seeker and (b.collision_mask == 0 or not (b as Seeker).is_active()):
				continue  # 유령은 그냥 통과
			if b is Survivor and ((b as Survivor).is_frozen or (b as Survivor).is_dead):
				continue
			var lp := to_local(b.global_position)
			if absf(lp.x) > half_w or absf(lp.z) > 0.5:
				continue
			var v := global_basis.inverse() * b.velocity
			if Vector2(v.x, v.z).length() < 0.5 or v.z * lp.z > 0.0:
				continue  # 멈춰 있거나 이미 빠져나가는 중
			_vault(b, lp)


func _vault(b: CharacterBody3D, lp: Vector3) -> void:
	var dur := GameConfig.num("structure", "vault_seeker", 1.3) if b is Seeker else GameConfig.num("structure", "vault_survivor", 0.35)
	var side := 1.0 if lp.z >= 0.0 else -1.0
	var target := to_global(Vector3(clampf(lp.x, -0.4, 0.4), 0, -side * 1.1))
	target.y = b.global_position.y
	b.set_meta("vaulting", true)
	if b is Seeker:
		(b as Seeker)._lock_left = maxf((b as Seeker)._lock_left, dur)
	else:
		(b as Survivor).pulled_time_left = maxf((b as Survivor).pulled_time_left, dur)
	var start := b.global_position
	var arc := func(p: float) -> void:
		if is_instance_valid(b):
			b.global_position = start.lerp(target, p) + Vector3.UP * sin(p * PI) * 0.5
	var done := func() -> void:
		if is_instance_valid(b):
			b.remove_meta("vaulting")
			b.set_meta("vault_cd", Time.get_ticks_msec() / 1000.0 + 0.6)
	var tw := b.create_tween()
	tw.tween_method(arc, 0.0, 1.0, dur)
	tw.tween_callback(done)


# ---------------------------------------------------------------- 도우미

func _static_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = mat
	body.add_child(mesh)
	parent.add_child(body)
	body.position = pos
	return body


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _play_load(path: String, pitch: float) -> void:
	if not ResourceLoader.exists(path):
		return
	_audio.stream = load(path)
	_audio.pitch_scale = pitch
	_audio.play()


# ---------------------------------------------------------------- 사물함 / 옷장 모양

var _wardrobe := false
var _ldoor: Node3D


func _build_locker(mats: Dictionary) -> void:
	var body_mat: Material
	var door_col: Color
	if _wardrobe:
		body_mat = mats.get("crate")
		door_col = Color(0.36, 0.24, 0.14)
	else:
		var metal := StandardMaterial3D.new()
		metal.albedo_color = Color(0.3, 0.38, 0.35)
		metal.metallic = 0.55
		metal.roughness = 0.55
		body_mat = metal
		door_col = Color(0.33, 0.42, 0.38)
	var w := 0.95 if _wardrobe else 0.85
	_static_box(self, Vector3(0, 1.0, 0), Vector3(w, 2.0, 0.6), body_mat, 1)
	var dark := _mat_col(Color(0.03, 0.03, 0.03))
	var edge := _mat_col(door_col.darkened(0.35), 0.5)
	# 위 뚜껑과 아래 받침
	_deco(self, Vector3(0, 2.03, 0), Vector3(w + 0.08, 0.07 if not _wardrobe else 0.14, 0.66), edge)
	if _wardrobe:
		_deco(self, Vector3(0, 2.16, -0.05), Vector3(w + 0.16, 0.08, 0.6), edge)  # 장식 처마
		for x in [-w / 2 + 0.06, w / 2 - 0.06]:
			for z in [-0.24, 0.24]:
				_deco(self, Vector3(x, 0.04, z), Vector3(0.09, 0.08, 0.09), edge)
	else:
		_deco(self, Vector3(0, 0.05, -0.005), Vector3(w + 0.01, 0.1, 0.61), _mat_col(Color(0.12, 0.13, 0.13)))
	# 문 (왼쪽 경첩 기준으로 열림)
	_ldoor = Node3D.new()
	_ldoor.position = Vector3(-w / 2 + 0.02, 0, -0.3)
	add_child(_ldoor)
	var dw := w - 0.06
	var door_mat := _mat_col(door_col, 0.6 if not _wardrobe else 0.9)
	_deco(_ldoor, Vector3(dw / 2, 1.04, -0.025), Vector3(dw, 1.86, 0.04), door_mat)
	# 통풍구 (여기로 밖을 봄)
	for i in 6:
		_deco(_ldoor, Vector3(dw / 2, 1.5 + i * 0.065, -0.048), Vector3(dw * 0.62, 0.028, 0.012), dark)
	if _wardrobe:
		# 문 테두리 장식 + 동그란 손잡이
		for y in [0.25, 1.85]:
			_deco(_ldoor, Vector3(dw / 2, y, -0.05), Vector3(dw - 0.08, 0.05, 0.02), edge)
		for x in [0.07, dw - 0.07]:
			_deco(_ldoor, Vector3(x, 1.05, -0.05), Vector3(0.05, 1.65, 0.02), edge)
		var knob := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.035
		sph.height = 0.07
		knob.mesh = sph
		knob.material_override = _mat_col(Color(0.6, 0.48, 0.2), 0.5)
		knob.position = Vector3(dw - 0.1, 1.05, -0.075)
		_ldoor.add_child(knob)
	else:
		# 손잡이, 이름표, 경첩, 녹 자국, 찌그러진 자국
		_deco(_ldoor, Vector3(dw - 0.09, 1.0, -0.065), Vector3(0.04, 0.2, 0.05), _mat_col(Color(0.65, 0.65, 0.62), 0.4))
		_deco(_ldoor, Vector3(dw / 2, 1.3, -0.047), Vector3(0.22, 0.08, 0.01), _mat_col(Color(0.85, 0.82, 0.7)))
		for y in [0.4, 1.7]:
			_deco(_ldoor, Vector3(0.0, y, -0.05), Vector3(0.03, 0.12, 0.03), _mat_col(Color(0.2, 0.2, 0.2), 0.4))
		var rust := _mat_col(door_col.lerp(Color(0.4, 0.24, 0.13), 0.55))
		for i in 4:
			_deco(_ldoor, Vector3(randf_range(0.12, dw - 0.12), randf_range(0.2, 1.0), -0.047), Vector3(randf_range(0.04, 0.1), randf_range(0.05, 0.18), 0.008), rust)
		_deco(_ldoor, Vector3(dw * 0.35, 0.75, -0.04), Vector3(0.18, 0.12, 0.012), _mat_col(door_col.darkened(0.3))).rotation.z = 0.4


## 사물함 문이 휙 열렸다가 닫힘 (hold 초 동안 열려 있음)
func _swing_locker(hold: float) -> void:
	if _ldoor == null:
		return
	var tw := create_tween()
	tw.tween_property(_ldoor, "rotation:y", 1.5, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(_ldoor, "rotation:y", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


static var _col_mats := {}
## 학교·병원 문: 칠한 판문 + 작은 유리창 + 손잡이 (+ 병원은 아래 철판)
func _modern_door(style: String) -> void:
	if style == "city":
		_panel_door()
		return
	var col := Color(0.55, 0.42, 0.3) if style == "school" else Color(0.62, 0.72, 0.68)
	for c in _door_body.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = _mat_col(col, 0.7)
	var frame := _mat_col(col.darkened(0.25), 0.7)
	for z in [-0.055, 0.055]:
		# 창 (위쪽 가운데) + 창틀
		_deco(_door_body, Vector3(0.05, 0.45, z), Vector3(0.42, 0.6, 0.01), _mat_col(Color(0.12, 0.15, 0.2), 0.1))
		_deco(_door_body, Vector3(0.05, 0.77, z * 1.1), Vector3(0.5, 0.05, 0.015), frame)
		_deco(_door_body, Vector3(0.05, 0.13, z * 1.1), Vector3(0.5, 0.05, 0.015), frame)
		# 손잡이
		_deco(_door_body, Vector3(0.55, -0.05, z * 1.6), Vector3(0.14, 0.04, 0.06), _mat_col(Color(0.7, 0.7, 0.72), 0.35))
		if style == "hospital":
			_deco(_door_body, Vector3(0, -0.85, z * 1.05), Vector3(1.38, 0.35, 0.01), _mat_col(Color(0.6, 0.62, 0.65), 0.3))
		else:
			_deco(_door_body, Vector3(0, -0.45, z * 1.05), Vector3(1.1, 0.7, 0.012), frame)


## 도시 집·가게 문: 칠한 판넬 문 (위 2칸 + 아래 2칸 도드라진 판) + 둥근 손잡이 + 경첩. 색은 몇 가지 중 하나
func _panel_door() -> void:
	var cols := [Color(0.42, 0.27, 0.17), Color(0.5, 0.48, 0.44), Color(0.25, 0.3, 0.36), Color(0.55, 0.22, 0.18), Color(0.78, 0.76, 0.7)]
	var col: Color = cols[randi() % cols.size()]
	for c in _door_body.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = _mat_col(col, 0.6)
	var panel := _mat_col(col.lightened(0.06), 0.6)
	var groove := _mat_col(col.darkened(0.35), 0.7)
	for z in [-0.055, 0.055]:
		for px in [-0.33, 0.33]:
			for py in [0.45, -0.5]:
				var ph := 0.7 if py > 0 else 0.8
				_far(_deco(_door_body, Vector3(px, py, z * 1.05), Vector3(0.5, ph, 0.012), groove))
				_far(_deco(_door_body, Vector3(px, py, z * 1.18), Vector3(0.42, ph - 0.08, 0.012), panel))
		# 둥근 손잡이 (작은 판 + 손잡이)
		_far(_deco(_door_body, Vector3(0.58, -0.02, z * 1.2), Vector3(0.07, 0.16, 0.012), _mat_col(Color(0.7, 0.6, 0.3), 0.35)))
		_far(_deco(_door_body, Vector3(0.58, -0.02, z * 1.7), Vector3(0.07, 0.07, 0.06), _mat_col(Color(0.75, 0.65, 0.3), 0.3)))
	for y in [-0.75, 0.75]:
		_far(_deco(_door_body, Vector3(-0.69, y, 0), Vector3(0.03, 0.12, 0.12), _mat_col(Color(0.3, 0.3, 0.3), 0.4)))


## 문 장식은 멀리서 안 그림 (그리기 호출 줄이기)
func _far(mi: MeshInstance3D) -> void:
	mi.visibility_range_end = 28.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _mat_col(c: Color, rough := 0.85) -> StandardMaterial3D:
	var key := "%s_%s" % [c.to_html(), rough]
	if _col_mats.has(key):
		return _col_mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	_col_mats[key] = m
	return m


## 보이기만 하는 상자 부품
func _deco(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi
