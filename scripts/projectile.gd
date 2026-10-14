extends Node3D
## 술래가 던지는 것: 도살자의 쇠사슬 / 도끼 / 거미 여왕의 거미줄
## 앞으로 날아가다가 벽에 막히거나 최대 거리에 닿으면 사라지고,
## 생존자에게 맞으면 던진 술래에게 알려줍니다. (얼음 상태 생존자는 무적이라 통과)

var kind := "axe"          # "chain" 또는 "axe"
var thrower: Node3D = null
var direction := Vector3.FORWARD
var speed := 10.0
var max_distance := 10.0
var hit_radius := 0.5

var _travelled := 0.0
var _visual: Node3D
var _chain_line: MeshInstance3D
var _exclude: Array[RID] = []


func setup(by: Node3D, from: Vector3, dir: Vector3, spd: float, max_dist: float, radius: float, projectile_kind: String) -> void:
	thrower = by
	kind = projectile_kind
	direction = Vector3(dir.x, 0.0, dir.z).normalized()
	speed = spd
	max_distance = max_dist
	hit_radius = radius
	global_position = from
	# 벽 판정에서 술래와 생존자는 빼고 (생존자는 거리로 따로 판정)
	_exclude.append((by as CollisionObject3D).get_rid())
	for node in get_tree().get_nodes_in_group("survivor"):
		_exclude.append((node as CollisionObject3D).get_rid())
	_build_visual()


func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.6, 0.6, 0.65)
	metal.metallic = 0.7
	metal.roughness = 0.35
	if kind == "axe":
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.4, 0.26, 0.14)
		var handle := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.04
		hm.bottom_radius = 0.04
		hm.height = 0.8
		handle.mesh = hm
		handle.material_override = wood
		_visual.add_child(handle)
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.06, 0.3, 0.38)
		blade.mesh = bm
		blade.position = Vector3(0, 0.3, 0.18)
		blade.material_override = metal
		_visual.add_child(blade)
	elif kind == "sickle":
		# 사이코의 사슬낫: 휘어진 날 + 손까지 이어지는 쇠사슬
		var blade := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.2
		tm.outer_radius = 0.26
		blade.mesh = tm
		blade.scale = Vector3(1, 0.4, 1)
		blade.material_override = metal
		_visual.add_child(blade)
		_chain_line = MeshInstance3D.new()
		var cl := BoxMesh.new()
		cl.size = Vector3(0.04, 0.04, 1.0)
		_chain_line.mesh = cl
		_chain_line.material_override = metal
		_chain_line.top_level = true
		add_child(_chain_line)
	elif kind == "web":
		# 거미줄 뭉치: 하얗게 빛나는 공 + 가닥들
		var silk := StandardMaterial3D.new()
		silk.albedo_color = Color(0.95, 0.95, 1.0, 0.8)
		silk.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		silk.emission_enabled = true
		silk.emission = Color(0.7, 0.7, 0.8)
		var ball := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.25
		sm.height = 0.5
		ball.mesh = sm
		ball.material_override = silk
		_visual.add_child(ball)
		for i in 3:
			var strand := MeshInstance3D.new()
			var st := BoxMesh.new()
			st.size = Vector3(0.9, 0.02, 0.02)
			strand.mesh = st
			strand.material_override = silk
			strand.rotation = Vector3(0, i * PI / 3.0, 0.3)
			_visual.add_child(strand)
	else:
		# 쇠사슬 끝의 갈고리 + 술래까지 이어지는 사슬
		var hook := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.08
		tm.outer_radius = 0.16
		hook.mesh = tm
		hook.material_override = metal
		_visual.add_child(hook)
		_chain_line = MeshInstance3D.new()
		var line := BoxMesh.new()
		line.size = Vector3(0.05, 0.05, 1.0)
		_chain_line.mesh = line
		_chain_line.material_override = metal
		_chain_line.top_level = true
		add_child(_chain_line)


func _physics_process(delta: float) -> void:
	var step := speed * delta
	var from := global_position
	var to := from + direction * step

	# 벽에 막히면 끝
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = _exclude
	var wall := get_world_3d().direct_space_state.intersect_ray(q)
	if not wall.is_empty():
		queue_free()
		return

	# 생존자에게 맞았는지 (이번 프레임 이동 구간과 생존자 몸의 거리)
	for node in get_tree().get_nodes_in_group("survivor"):
		var s := node as Survivor
		if s == null or s.is_dead or s.is_frozen or s.is_invulnerable():
			continue
		var center := s.global_position + Vector3.UP * 0.9
		var closest := Geometry3D.get_closest_point_to_segment(center, from, to)
		if closest.distance_to(center) <= hit_radius + 0.35:
			if is_instance_valid(thrower):
				thrower.call("_on_projectile_hit", kind, s)
			queue_free()
			return

	global_position = to
	_travelled += step
	if kind == "axe":
		_visual.rotate_object_local(Vector3.RIGHT, -14.0 * delta)  # 빙글빙글
	elif kind == "web":
		_visual.rotate_y(8.0 * delta)
	elif kind == "sickle":
		_visual.rotate_y(18.0 * delta)
	if _chain_line and is_instance_valid(thrower):
		var hand := thrower.global_position + Vector3.UP * 1.5
		var mid := (hand + global_position) / 2.0
		_chain_line.global_position = mid
		if hand.distance_to(global_position) > 0.05:
			_chain_line.look_at(global_position, Vector3.UP)
		_chain_line.scale = Vector3(1, 1, hand.distance_to(global_position))
	if _travelled >= max_distance:
		queue_free()
