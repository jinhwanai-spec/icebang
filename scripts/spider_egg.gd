extends Node3D
## 거미 여왕의 알: 30초 뒤 새끼 거미가 나옴. 생존자가 E로 제거할 수 있음 (대가 없음)

const SpiderlingScript := preload("res://scripts/spiderling.gd")

var queen: Node3D = null
var _left := 30.0
var _pulse := 0.0


func setup(owner_queen: Node3D) -> void:
	queen = owner_queen
	add_to_group("rat_minion")  # 쥐처럼 E로 제거 (봇도 제거)
	set_meta("prompt", "[E] 거미 알 부수기")
	_left = GameConfig.num("spider", "egg_hatch_time", 30.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.88, 0.8)
	mat.roughness = 0.3
	mat.subsurf_scatter_enabled = false
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.3, 0.15)
	for i in 6:
		var m := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.16
		s.height = 0.32
		m.mesh = s
		m.material_override = mat
		var a := i * TAU / 6.0
		m.position = Vector3(cos(a) * 0.18, 0.16 + (i % 2) * 0.12, sin(a) * 0.18)
		add_child(m)
	var web := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.3
	t.outer_radius = 0.42
	web.mesh = t
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.9, 0.9, 0.95, 0.6)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	web.material_override = wm
	web.position.y = 0.03
	add_child(web)


func kill(_by: Node) -> void:
	queue_free()


func _process(delta: float) -> void:
	if queen == null or not is_instance_valid(queen) or not queen.call("is_active"):
		queue_free()
		return
	_left -= delta
	# 부화가 가까워지면 꿈틀거림
	if _left < 5.0:
		_pulse += delta * 12.0
		scale = Vector3.ONE * (1.0 + sin(_pulse) * 0.06)
	if _left <= 0.0 and queen.call("can_hatch"):
		var b := CharacterBody3D.new()
		b.set_script(SpiderlingScript)
		get_tree().current_scene.add_child(b)
		b.global_position = global_position + Vector3.UP * 0.1
		b.call("setup", queen)
		queen.babies.append(b)
		queue_free()
