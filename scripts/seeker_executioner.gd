extends Seeker
## 술래: 처형인 (망태기를 뒤집어쓴 거구)
## - (패시브) 도끼: 평타 대신 큰 도끼. 공격 거리가 길고(2.2m), 맞으면 즉사
##   (정비공 갑옷·헬멧과 구르기 무적도 무시. 얼음은 무적이라 제외)
## - 처형 (쿨 150초): 얼음 상태 생존자를 녹여 꺼낸 뒤 5초 동안 무릎 꿇리고 목을 벰
##   그 사이 동료가 플래시·강펀치·판자로 처형인을 기절시키면 처형이 끊기고 생존자가 풀려남
##   처형당한 생존자의 머리와 몸은 판이 끝날 때까지 남음

var _exec_cd := 0.0
var _exec_target: Survivor = null
var _exec_left := 0.0
var _swung := false
var _sfx: AudioStreamPlayer3D


func _ready() -> void:
	super._ready()
	_exec_cd = GameConfig.num("executioner", "execute_cooldown", 150.0) * 0.3
	_sfx = AudioStreamPlayer3D.new()
	_sfx.max_distance = 45.0
	_sfx.unit_size = 6.0
	add_child(_sfx)


func _catch_reach() -> float:
	return GameConfig.num("executioner", "axe_reach", 2.2)


## 도끼는 무적·갑옷을 무시 (얼음·그림자·사물함·쇠사슬은 그대로 제외)
func _catchable(s: Survivor) -> bool:
	return s != null and not s.is_frozen and not s.is_dead and not s.is_shadowed() \
			and s.in_locker == null and s.chained_by == null and not s.has_meta("executing")


func _kill_survivor(s: Survivor) -> void:
	s._kill()
	if s == chase_target:
		chase_target = null
		_enter_search()


func _ability_update(delta: float) -> void:
	_exec_cd = max(0.0, _exec_cd - delta)
	if _exec_target:
		_update_execution(delta)
		return
	if _lock_left > 0.0 or _exec_cd > 0.0:
		return
	var frozen := _nearest_frozen(GameConfig.num("executioner", "frozen_search", 15.0))
	if frozen == null:
		return
	if _frozen_reachable(frozen, global_position.distance_to(frozen.global_position)):
		_start_execution(frozen)
	elif state != State.CHASE and agent.target_position.distance_to(frozen.global_position) > 1.0:
		_investigate(frozen.global_position)


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
		if s.is_frozen and not s.is_dead and _ignore_frozen.get(s, 0.0) < Time.get_ticks_msec() / 1000.0 and not s.has_meta("executing"):
			var d := global_position.distance_to(s.global_position)
			if d < best_d:
				best = s
				best_d = d
	return best


func _start_execution(s: Survivor) -> void:
	_exec_target = s
	_exec_left = GameConfig.num("executioner", "execute_time", 5.0)
	_exec_cd = GameConfig.num("executioner", "execute_cooldown", 150.0)
	_swung = false
	_lock_left = _exec_left
	# 얼음을 깨서 꺼냄
	s.is_frozen = false
	s.ice_mesh.visible = false
	s.clear_ice_timer()
	s.frozen_changed.emit(false)
	s.set_meta("executing", true)
	_play("res://audio/mg_fail.wav", 0.7)
	if s.has_signal("notice"):
		s.emit_signal("notice", "처형인이 얼음을 깨고 나를 끌어냈어요! 동료가 기절시켜야 살 수 있어요!")
	for node in get_tree().get_nodes_in_group("survivor"):
		if node != s and node.has_signal("notice"):
			node.emit_signal("notice", "%s이(가) 처형당하려 해요! 5초 안에 처형인을 기절시켜요!" % s.display_name)


func _update_execution(delta: float) -> void:
	var s := _exec_target
	if not is_instance_valid(s) or s.is_dead:
		_exec_target = null
		return
	_exec_left -= delta
	_lock_left = maxf(_lock_left, 0.2)
	# 생존자는 무릎 꿇고 못 움직임
	s.pulled_time_left = maxf(s.pulled_time_left, 0.3)
	s.rooted_left = maxf(s.rooted_left, 0.3)
	s.velocity = Vector3.ZERO
	s.body.rotation.x = lerpf(s.body.rotation.x, 0.6, 5.0 * delta)
	_face(s.global_position - global_position, delta, 8.0)
	# 1.8초 전부터 도끼를 치켜듦
	if not _swung and _exec_left <= 1.8:
		_swung = true
		body.attack(1.0)
	if _exec_left <= 0.0:
		_behead(s)
		_exec_target = null


## 처형 실패 (기절·넉백·봉인): 생존자가 풀려남
func _release(text: String) -> void:
	var s := _exec_target
	_exec_target = null
	if not is_instance_valid(s):
		return
	s.remove_meta("executing")
	s.pulled_time_left = 0.0
	s.rooted_left = 0.0
	s.body.rotation.x = 0.0
	if s.has_signal("notice"):
		s.emit_signal("notice", text)


func _on_stunned() -> void:
	if _exec_target:
		_release("처형인이 기절했어요! 지금 도망쳐요!")
	_lock_left = 0.0


func _on_knocked_back() -> void:
	_on_stunned()


func disable() -> void:
	if _exec_target:
		_release("처형인이 봉인됐어요!")
	super.disable()


# ---------------------------------------------------------------- 처형 연출

func _behead(s: Survivor) -> void:
	s.remove_meta("executing")
	var pos := s.global_position
	var facing := s.body.rotation.y
	var cid := s.character_id
	_play("res://audio/execute.wav", 1.0)
	s._kill()
	var game := get_tree().current_scene

	# 몸: 점토 인형을 다시 만들어 머리(높이 1m 위 부분)만 떼어 냄
	var corpse := ClayBody.new()
	game.add_child(corpse)
	corpse.global_position = pos
	corpse.rotation.y = facing
	corpse.build(cid)
	var head := Node3D.new()
	game.add_child(head)
	var torso: Node3D = corpse.get("_torso")
	var neck := pos + Vector3.UP * 1.0
	head.global_position = neck
	for child in torso.get_children():
		if child is Node3D and (child as Node3D).position.y > 1.0:
			var gt := (child as Node3D).global_transform
			torso.remove_child(child)
			head.add_child(child)
			(child as Node3D).global_transform = gt
	# 몸은 앞으로 털썩 쓰러짐
	var tw := corpse.create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(corpse, "rotation:x", PI / 2.0 - 0.1, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(corpse, "position:y", pos.y + 0.2, 0.45)
	# 머리는 튀어 올랐다가 데굴데굴 굴러감
	var away := (pos - global_position)
	away.y = 0.0
	away = away.normalized().rotated(Vector3.UP, randf_range(-0.6, 0.6))
	var land := neck + away * 1.8
	land.y = pos.y + 0.0
	var start := head.global_position
	var arc := func(p: float) -> void:
		if is_instance_valid(head):
			head.global_position = start.lerp(land, p) + Vector3.UP * sin(p * PI) * 0.9
			head.rotation = Vector3(p * 7.0, p * 2.0, p * 3.0)
	var tw2 := head.create_tween()
	tw2.tween_method(arc, 0.0, 1.0, 0.8)
	# 피: 목에서 뿜어져 나옴 + 바닥에 퍼지는 피 웅덩이 (판 끝까지 남음)
	_blood_spray(game, neck, 2.5)
	_blood_pool(game, pos + Vector3(0, 0.03, 0) + away * 0.5, 1.3)
	_blood_pool(game, land + Vector3(0, 0.03, 0), 0.5)


func _blood_spray(parent: Node, at: Vector3, seconds: float) -> void:
	var p := CPUParticles3D.new()
	parent.add_child(p)
	p.global_position = at
	p.amount = 120
	p.lifetime = 1.1
	p.explosiveness = 0.0
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.1
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.0, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.0, 0.0)
	m.material = mat
	p.mesh = m
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(seconds)
	tw.tween_callback(func() -> void: p.emitting = false)


func _blood_pool(parent: Node, at: Vector3, radius: float) -> void:
	var pool := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = 0.01
	pool.mesh = c
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.0, 0.0)
	mat.roughness = 0.15
	mat.emission_enabled = true
	mat.emission = Color(0.15, 0.0, 0.0)
	pool.material_override = mat
	parent.add_child(pool)
	pool.global_position = at
	pool.scale = Vector3(0.1, 1, 0.1)
	var tw := pool.create_tween()
	tw.tween_property(pool, "scale", Vector3.ONE, 3.0).set_ease(Tween.EASE_OUT)


func _play(path: String, pitch: float) -> void:
	if ResourceLoader.exists(path):
		_sfx.stream = load(path)
		_sfx.pitch_scale = pitch
		_sfx.play()
