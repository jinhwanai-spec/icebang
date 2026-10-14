extends Node
## [자동 로드] 소리 전달 담당
## 게임 속 모든 "소리"(발소리, 봉인석 소리, 소리 내기 능력)는 여기를 거쳐 갑니다.
## 술래는 noise_made 신호를 듣고 있다가, 자기가 들을 수 있는 거리면 그곳으로 갑니다.

## pos: 소리가 난 위치 / radius: 소리가 들리는 거리 / source: 소리를 낸 대상
signal noise_made(pos: Vector3, radius: float, source: Node)


func make_noise(pos: Vector3, radius: float, source: Node = null) -> void:
	if radius <= 0.0:
		return
	noise_made.emit(pos, radius, source)
	if GameConfig.flag("debug", "show_noise_rings", true):
		_spawn_ring(pos, radius)


## 소리 범위를 눈으로 볼 수 있게 퍼지는 노란 원을 그립니다. (디버그용)
func _spawn_ring(pos: Vector3, radius: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not (scene is Node3D):
		return
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.96
	torus.outer_radius = 1.0
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.85, 0.2, 0.7)
	ring.material_override = mat
	scene.add_child(ring)
	ring.global_position = pos + Vector3.UP * 0.1
	ring.scale = Vector3(0.2, 1.0, 0.2)

	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(radius, 1.0, radius), 0.6)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tw.chain().tween_callback(ring.queue_free)
