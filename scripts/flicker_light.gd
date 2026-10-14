extends Light3D
## 고장 난 형광등처럼 가끔 지직거리며 깜빡이는 불빛

var _base := 1.0
var _t := 0.0


func _ready() -> void:
	_base = light_energy
	_t = randf() * 3.0


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	if randf() < 0.25:
		# 지직지직 몇 번
		light_energy = _base * randf_range(0.0, 0.3)
		_t = randf_range(0.03, 0.12)
	else:
		light_energy = _base
		_t = randf_range(0.5, 4.0)
