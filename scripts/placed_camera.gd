extends Node3D
## 카메라맨 능력2: 바닥에 설치하는 카메라
## - 카메라 앞을 술래가 지나가면 모두에게 술래 위치를 보여줌 (유인 기능 없음)
## - 정해진 시간이 지나면 사라짐 (최대 3개까지 설치 가능, player.gd 에서 충전 관리)

const SFX_ALERT := preload("res://audio/shutter.wav")

var owner_player: Node = null
var _life := 20.0
var _check_timer := 0.0
var _announce_cooldown := 0.0
var _audio: AudioStreamPlayer3D
var _lamp: OmniLight3D


func setup(by: Node) -> void:
	owner_player = by
	_life = GameConfig.num("cameraman", "camera_duration", 20.0)
	_build_look()


func _build_look() -> void:
	# 삼각대 + 카메라 몸통 + 렌즈 + 빨간 녹화등
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.15, 0.17)
	var legs := MeshInstance3D.new()
	var leg_mesh := CylinderMesh.new()
	leg_mesh.top_radius = 0.03
	leg_mesh.bottom_radius = 0.25
	leg_mesh.height = 1.0
	legs.mesh = leg_mesh
	legs.position.y = 0.5
	legs.material_override = mat
	add_child(legs)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.35, 0.25, 0.25)
	body.mesh = body_mesh
	body.position.y = 1.1
	body.material_override = mat
	add_child(body)
	var lens := MeshInstance3D.new()
	var lens_mesh := CylinderMesh.new()
	lens_mesh.top_radius = 0.08
	lens_mesh.bottom_radius = 0.08
	lens_mesh.height = 0.2
	lens.mesh = lens_mesh
	lens.rotation.x = PI / 2.0
	lens.position = Vector3(0, 1.1, -0.2)
	lens.material_override = mat
	add_child(lens)
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1, 0.1, 0.1)
	_lamp.omni_range = 1.5
	_lamp.light_energy = 1.5
	_lamp.position = Vector3(0, 1.3, 0)
	add_child(_lamp)
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = SFX_ALERT
	_audio.max_distance = 30.0
	_audio.position.y = 1.1
	add_child(_audio)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	_lamp.visible = fmod(_life, 1.0) > 0.5  # 녹화등 깜빡깜빡
	_announce_cooldown = max(0.0, _announce_cooldown - delta)

	# 술래가 찍혔는지 확인 (0.2초마다)
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = 0.2
		for node in get_tree().get_nodes_in_group("seeker"):
			var s := node as Seeker
			if s and s.is_active() and s.visible_to_players() and _sees(s):
				s.reveal(1.0)
				if _announce_cooldown <= 0.0 and owner_player and is_instance_valid(owner_player):
					_announce_cooldown = 6.0
					_audio.play()
					if owner_player.has_signal("notice"):  # 봇이 설치한 카메라면 안내 없음
						owner_player.emit_signal("notice", "카메라에 술래가 찍혔어요! 위치가 표시됩니다")


func _sees(s: Node3D) -> bool:
	var to := s.global_position - global_position
	to.y = 0.0
	if to.length() > GameConfig.num("cameraman", "camera_view_range", 16.0):
		return false
	var forward := -global_basis.z
	forward.y = 0.0
	if forward.normalized().angle_to(to.normalized()) > deg_to_rad(GameConfig.num("cameraman", "camera_view_angle", 40.0)):
		return false
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.1, s.global_position + Vector3.UP * 1.5)
	q.exclude = [s.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()
