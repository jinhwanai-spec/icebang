extends Light3D
## 살아 있는 불빛: 깜빡임·불꽃 흔들림·비상등 점멸·회전 경광등
## mode (set_script 뒤에 l.set("mode", "fire") 처럼 바꿈)
##   "fluorescent" = 고장 난 형광등 (가끔 지직지직)  ← 기본
##   "dying"       = 거의 나간 등 (대부분 꺼져 있다가 가끔 번쩍)
##   "fire"        = 모닥불·랜턴 (부드럽게 일렁임)
##   "strobe"      = 비상등 점멸 (짧게 두 번 번쩍)
##   "beacon"      = 회전 경광등 (SpotLight 가 빙글빙글 돎)
## mats = 같이 밝아졌다 어두워지는 발광 재질들 (형광등 판·간판·랜턴 유리)
## hum  = 형광등 웅웅 소리 (꺼지면 같이 끊김)

var mode := "fluorescent"
var mats: Array = []
var hum: AudioStreamPlayer3D
var _base := -1.0
var _mat_base: Array = []
var _hum_db := 0.0
var _t := 0.0
var _time := 0.0
var _seed := 0.0


func _ready() -> void:
	_init_base()


## set_script 를 씬 트리 안에서 하면 _ready 가 안 불릴 수 있어서 처음 _process 에서도 준비
func _init_base() -> void:
	if _base >= 0.0:
		return
	_base = light_energy
	_t = randf() * 3.0
	_seed = randf() * 100.0
	_mat_base.clear()
	for m in mats:
		_mat_base.append((m as BaseMaterial3D).emission_energy_multiplier if m is BaseMaterial3D else 1.0)
	if hum:
		_hum_db = hum.volume_db


func _set_level(k: float) -> void:
	light_energy = _base * k
	for i in mats.size():
		if mats[i] is BaseMaterial3D:
			(mats[i] as BaseMaterial3D).emission_energy_multiplier = _mat_base[i] * maxf(k, 0.04)
	if hum:
		hum.volume_db = _hum_db if k > 0.5 else -60.0


func _process(delta: float) -> void:
	_init_base()
	if not visible:
		return  # 정전 등으로 꺼진 동안은 깜빡이지 않음 (재질 밝기도 main.gd 가 맡음)
	_time += delta
	match mode:
		"fire":
			# 여러 사인파를 겹친 부드러운 일렁임
			var s := _time + _seed
			_set_level(0.82 + 0.1 * sin(s * 7.3) + 0.06 * sin(s * 13.1 + 1.7) + 0.04 * sin(s * 23.7))
		"beacon":
			rotation.y = fmod(rotation.y + delta * 3.4, TAU)
		"strobe":
			var ph := fmod(_time + _seed, 1.6)
			_set_level(1.0 if (ph < 0.07 or (ph > 0.16 and ph < 0.23)) else 0.0)
		"dying":
			_t -= delta
			if _t > 0.0:
				return
			if light_energy > 0.0:
				_set_level(0.0)
				_t = randf_range(1.5, 6.0)
			else:
				_set_level(randf_range(0.4, 1.0))
				_t = randf_range(0.04, 0.35)
		_:
			_t -= delta
			if _t > 0.0:
				return
			if randf() < 0.25:
				# 지직지직 몇 번
				_set_level(randf_range(0.0, 0.3))
				_t = randf_range(0.03, 0.12)
			else:
				_set_level(1.0)
				_t = randf_range(0.5, 4.0)
