extends Node
## 그림자 관리자: 카메라에 가장 가까운 불빛 몇 개만 그림자를 켬 (Forward+ 성능 아끼기)
## 그림자를 켤 수 있는 불빛은 그룹 "shadow_light" 에 들어 있음 (천장등·가로등·모닥불)
## 개수·거리는 balance.cfg [graphics] shadow_lights / shadow_light_range

var max_shadows := 4
var radius := 16.0
var _t := 0.0


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.25
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cam.global_position
	var r2 := radius * radius
	var cand: Array = []
	for n in get_tree().get_nodes_in_group("shadow_light"):
		var l := n as Light3D
		if l == null or not l.is_inside_tree():
			continue
		var d := l.global_position.distance_squared_to(cp)
		if d < r2 and l.visible and l.light_energy > 0.01:
			cand.append([d, l])
		elif l.shadow_enabled:
			l.shadow_enabled = false
	cand.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i in cand.size():
		var l: Light3D = cand[i][1]
		var want := i < max_shadows
		if l.shadow_enabled != want:
			l.shadow_enabled = want
