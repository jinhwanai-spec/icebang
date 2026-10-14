extends CharacterBody3D
## 새끼 거미: 맵을 돌아다니다 생존자를 보면 거미줄을 쏨 (쿨 20초, 사거리 10m)
## 새끼에게 묶이면 거미 여왕이 그 위치를 알게 됨. 생존자를 잡지는 못함
## 이동속도: 사람 달리기보다 8% 느림. 제거하기 전까지 계속 있음 (E로 제거, 대가 없음)

var queen: Node3D = null
var _agent: NavigationAgent3D
var _model: Node3D
var _web_cd := 3.0
var _wander_timer := 0.0
var _phase := 0.0
var _legs: Array[Node3D] = []


func setup(owner_queen: Node3D) -> void:
	queen = owner_queen
	add_to_group("rat_minion")
	set_meta("prompt", "[E] 새끼 거미 잡기")
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.35, 0.6)
	shape.shape = box
	shape.position.y = 0.2
	add_child(shape)
	_agent = NavigationAgent3D.new()
	_agent.radius = 0.3
	_agent.path_desired_distance = 0.5
	_agent.target_desired_distance = 0.6
	add_child(_agent)
	_build_model()


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color(0.1, 0.08, 0.1)
	shell.roughness = 0.4
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color(1, 0.1, 0.1)
	eye.emission_enabled = true
	eye.emission = Color(1, 0.05, 0.05)
	eye.emission_energy_multiplier = 3.0
	_sphere(Vector3(0, 0.25, 0.12), 0.18, Vector3(1.0, 0.8, 1.2), shell)
	_sphere(Vector3(0, 0.22, -0.14), 0.11, Vector3.ONE, shell)
	for x in [-0.04, 0.04]:
		_sphere(Vector3(x, 0.27, -0.24), 0.025, Vector3.ONE, eye)
	for i in 4:
		for side in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(side * 0.1, 0.24, -0.1 + i * 0.08)
			_model.add_child(pivot)
			var leg := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.012
			c.bottom_radius = 0.012
			c.height = 0.35
			leg.mesh = c
			leg.material_override = shell
			leg.position = Vector3(side * 0.15, -0.08, 0)
			leg.rotation.z = side * 1.0
			pivot.add_child(leg)
			_legs.append(pivot)


func _sphere(pos: Vector3, r: float, s: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = s
	_model.add_child(mi)


## 생존자가 E로 잡음 (대가 없음)
func kill(_by: Node) -> void:
	queue_free()


func _physics_process(delta: float) -> void:
	if queen == null or not is_instance_valid(queen) or not queen.call("is_active"):
		queue_free()
		return
	_web_cd = max(0.0, _web_cd - delta)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0

	var target := _find_target()
	var speed := GameConfig.num("player", "run_speed", 7.5) * GameConfig.num("spider", "baby_speed_vs_run", 0.92)
	if target:
		var d := global_position.distance_to(target.global_position)
		if _web_cd <= 0.0 and d <= GameConfig.num("spider", "baby_web_range", 10.0):
			var dir := target.global_position - global_position
			dir.y = 0.0
			queen.call("shoot_web_from", self, global_position + Vector3.UP * 0.4 + dir.normalized() * 0.5, dir,
					GameConfig.num("spider", "baby_web_range", 10.0))
			_web_cd = GameConfig.num("spider", "baby_web_cooldown", 20.0)
		# 잡지는 못하니 거리를 두고 따라다님
		_agent.target_position = target.global_position if d > 5.0 else global_position
	else:
		speed *= 0.6
		_wander_timer -= delta
		if _wander_timer <= 0.0 or _agent.is_navigation_finished():
			_wander_timer = 5.0
			var p := global_position + Vector3(randf_range(-16, 16), 0, randf_range(-16, 16))
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
	# 다리 바둥바둥
	_phase += delta * Vector2(velocity.x, velocity.z).length() * 4.0
	for i in _legs.size():
		_legs[i].rotation.x = sin(_phase + i * 1.3) * 0.5


## 거미줄에 맞힘 → 여왕이 위치를 앎
func _on_projectile_hit(kind: String, s: Survivor) -> void:
	if kind == "web" and is_instance_valid(queen):
		queen.call("web_hit", s, true)


func _find_target() -> Survivor:
	var sight := GameConfig.num("spider", "baby_sight", 12.0)
	for node in get_tree().get_nodes_in_group("survivor"):
		var s := node as Survivor
		if s == null or s.is_dead or s.is_frozen or s.is_hidden_from_seeker() or s.chained_by:
			continue
		var to := s.global_position - global_position
		var limit := sight * 0.4 if s.is_in_grass() else sight
		if to.length() > limit:
			continue
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.4, s.global_position + Vector3.UP * 0.8)
		q.exclude = [get_rid(), s.get_rid()]
		if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			return s
	return null
