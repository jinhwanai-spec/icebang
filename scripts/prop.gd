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
			_plank.rotation.z = -(PI / 2.0 - 0.15)  # 세워진 상태 (충돌 없음)
		"locker":
			add_to_group("prop")
			reach = 1.7
			var metal := StandardMaterial3D.new()
			metal.albedo_color = Color(0.32, 0.36, 0.34)
			metal.metallic = 0.6
			metal.roughness = 0.5
			_static_box(self, Vector3(0, 1.0, 0), Vector3(0.85, 2.0, 0.6), metal, 1)
			var slit := StandardMaterial3D.new()
			slit.albedo_color = Color(0.05, 0.05, 0.05)
			for i in 4:
				var m := MeshInstance3D.new()
				var b := BoxMesh.new()
				b.size = Vector3(0.5, 0.03, 0.02)
				m.mesh = b
				m.material_override = slit
				m.position = Vector3(0, 1.55 + i * 0.07, -0.31)
				add_child(m)
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
			return "[E] 사물함에 숨기 (들어갈 때 소리가 나요)"
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


func on_exit(s: Survivor) -> void:
	if occupant == s:
		occupant = null
	_remove_cat()


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
