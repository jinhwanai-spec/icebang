extends CharacterBody3D
## 역병의 쥐가 풀어놓는 부하 쥐 (유저보다 작지만 눈에 띄는 크기)
## - 맵을 돌아다니며 생존자를 찾음. 보이면 쫓아가서 문다
## - 물린 생존자는 피를 흘려서 술래가 따라옴 (죽지는 않음)
## - 생존자가 가까이서 E를 누르면 잡힘 → 술래가 그 위치를 알게 됨
## - 일정 시간이 지나면 사라짐
## 얼음 상태, 카멜레온 능력 중인 생존자는 감지하지 못함

const STEP := preload("res://audio/step_light_1.wav")

var owner_seeker: Node3D = null

var _life := 30.0
var _target: Survivor = null
var _wander_timer := 0.0
var _bite_cooldown := {}   # 생존자 → 다시 물 수 있을 때까지 남은 시간
var _step_timer := 0.0
var _agent: NavigationAgent3D
var _model: Node3D
var _audio: AudioStreamPlayer3D
var _phase := 0.0


func setup(seeker: Node3D) -> void:
	owner_seeker = seeker
	add_to_group("rat_minion")
	_life = GameConfig.num("rat", "minion_life", 30.0)
	collision_layer = 0   # 생존자를 밀지 않음
	collision_mask = 1

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.5, 0.9)
	shape.shape = box
	shape.position.y = 0.25
	add_child(shape)

	_agent = NavigationAgent3D.new()
	_agent.radius = 0.3
	_agent.path_desired_distance = 0.5
	_agent.target_desired_distance = 0.6
	add_child(_agent)

	_audio = AudioStreamPlayer3D.new()
	_audio.stream = STEP
	_audio.max_distance = 14.0
	_audio.volume_db = -6.0
	add_child(_audio)

	_build_model()


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color(0.4, 0.38, 0.37)
	fur.roughness = 0.85
	fur.rim_enabled = true
	var pink := StandardMaterial3D.new()
	pink.albedo_color = Color(0.85, 0.6, 0.62)
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color(1, 0.15, 0.1)
	eye.emission_enabled = true
	eye.emission = Color(1, 0.1, 0.05)
	eye.emission_energy_multiplier = 3.0
	_add_sphere(Vector3(0, 0.3, 0.05), 0.28, Vector3(1.0, 0.85, 1.5), fur)   # 몸
	_add_sphere(Vector3(0, 0.38, -0.42), 0.2, Vector3(0.9, 0.85, 1.2), fur)  # 머리
	_add_sphere(Vector3(0, 0.36, -0.66), 0.05, Vector3.ONE, pink)            # 코
	for x in [-0.12, 0.12]:
		_add_sphere(Vector3(x, 0.58, -0.36), 0.09, Vector3(1.0, 1.0, 0.3), pink)  # 귀
		_add_sphere(Vector3(x * 0.8, 0.45, -0.56), 0.035, Vector3.ONE, eye)       # 눈
	var tail := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.01
	tm.bottom_radius = 0.04
	tm.height = 0.8
	tail.mesh = tm
	tail.material_override = pink
	tail.position = Vector3(0, 0.25, 0.75)
	tail.rotation.x = PI / 2.0 - 0.2
	_model.add_child(tail)


func _add_sphere(pos: Vector3, r: float, s: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = s
	_model.add_child(mi)


## 생존자가 E로 잡았을 때
func kill(_by: Node) -> void:
	if owner_seeker and is_instance_valid(owner_seeker):
		owner_seeker.call("alert_to", global_position)  # 술래가 위치를 알게 됨
	queue_free()


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0 or owner_seeker == null or not is_instance_valid(owner_seeker) \
			or not owner_seeker.call("is_active"):
		queue_free()
		return
	for k in _bite_cooldown.keys():
		_bite_cooldown[k] -= delta

	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0

	# 생존자 찾기
	if _target == null or not _can_target(_target):
		_target = _find_target()
	var speed := GameConfig.num("rat", "minion_speed", 5.0)
	if _target:
		_agent.target_position = _target.global_position
		if global_position.distance_to(_target.global_position) < 1.2:
			_bite(_target)
	else:
		speed *= 0.6
		_wander_timer -= delta
		if _wander_timer <= 0.0 or _agent.is_navigation_finished():
			_wander_timer = 4.0
			var p := global_position + Vector3(randf_range(-14, 14), 0, randf_range(-14, 14))
			_agent.target_position = NavigationServer3D.map_get_closest_point(_agent.get_navigation_map(), p)

	velocity.x = 0.0
	velocity.z = 0.0
	if not _agent.is_navigation_finished():
		var dir := _agent.get_next_path_position() - global_position
		dir.y = 0.0
		if dir.length() > 0.05:
			dir = dir.normalized()
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)
	move_and_slide()
	_animate(delta)


func _can_target(s: Survivor) -> bool:
	return s and not s.is_dead and not s.is_frozen and not s.is_hidden_from_seeker() \
			and _bite_cooldown.get(s, 0.0) <= 0.0


func _find_target() -> Survivor:
	var sight := GameConfig.num("rat", "minion_sight", 7.0)
	for node in get_tree().get_nodes_in_group("survivor"):
		var s := node as Survivor
		if not _can_target(s):
			continue
		var to := s.global_position - global_position
		if to.length() > sight:
			continue
		var limit := sight * 0.5 if s.is_in_grass() else sight
		if to.length() > limit:
			continue
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.4, s.global_position + Vector3.UP * 0.8)
		q.exclude = [get_rid(), s.get_rid()]
		if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			return s
	return null


func _bite(s: Survivor) -> void:
	s.start_bleeding(GameConfig.num("rat", "bite_bleed_time", 15.0))
	s.play_sfx(preload("res://audio/punch.wav"))
	_bite_cooldown[s] = 8.0  # 같은 사람은 잠깐 안 물고 다른 데로
	_target = null


func _animate(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	_phase += delta * speed * 3.0
	_model.position.y = absf(sin(_phase)) * 0.05
	if speed > 0.5:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.18
			_audio.pitch_scale = randf_range(1.7, 2.0)
			_audio.play()
