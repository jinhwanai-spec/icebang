extends Area3D
## 역병의 쥐 플라스크가 만든 감속 구역
## 안에 들어온 생존자는 느려집니다 (40%, balance.cfg [rat]). 정해진 시간이 지나면 사라짐

const SFX_SPLASH := preload("res://audio/thaw.wav")

var _life := 8.0


func setup() -> void:
	_life = GameConfig.num("rat", "flask_duration", 8.0)
	var radius := GameConfig.num("rat", "flask_radius", 3.0)
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 2.0
	shape.shape = cyl
	shape.position.y = 1.0
	add_child(shape)

	# 바닥에 퍼진 초록 웅덩이 + 피어오르는 안개
	var puddle := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	puddle.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.8, 0.2, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.6, 0.1)
	puddle.material_override = mat
	puddle.position.y = 0.04
	add_child(puddle)
	var mist := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = radius
	dome.height = 1.6
	dome.is_hemisphere = true
	mist.mesh = dome
	var mist_mat := StandardMaterial3D.new()
	mist_mat.albedo_color = Color(0.4, 0.9, 0.3, 0.12)
	mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mist.material_override = mist_mat
	add_child(mist)

	var splash := AudioStreamPlayer3D.new()
	splash.stream = SFX_SPLASH
	splash.max_distance = 20.0
	add_child(splash)
	splash.play()


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		# 사라질 때 안에 있던 생존자의 감속을 풀어줌
		for b in get_overlapping_bodies():
			_on_exit(b)
		body_exited.disconnect(_on_exit)
		queue_free()


func _on_enter(b: Node3D) -> void:
	if b is Survivor:
		(b as Survivor).slow_zone_count += 1


func _on_exit(b: Node3D) -> void:
	if b is Survivor:
		(b as Survivor).slow_zone_count = max(0, (b as Survivor).slow_zone_count - 1)
