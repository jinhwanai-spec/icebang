class_name NetSmooth
extends RefCounted
## 멀티 끊김 보정: 받은 위치를 바로 쫓지 않고 아주 조금(보통 0.06~0.15초) 늦게 "과거 두 위치 사이"를 그려서
## 패킷 간격이 들쭉날쭉해도 부드럽게 움직이게 함.
## - 받는 간격과 흔들림(지터)을 계속 재서 늦추는 시간을 자동으로 맞춤
## - 패킷이 잠깐 끊기면 마지막 속도로 최대 0.25초 앞을 예측하고, 그 뒤엔 멈춰 기다림
## - 6m 넘게 튀면(순간이동) 버퍼를 비우고 바로 그 자리로

const MAX_EXTRAPOLATE := 0.25
const SNAP_DIST := 6.0

var delay := 0.1
var _buf: Array = []  # [받은 시각, 위치, 방향]
var _interval := 0.05
var _jitter := 0.01
var _last_t := -1.0
var _vel := Vector3.ZERO


static func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0


## 새 위치를 받음. true 를 돌려주면 순간이동이니 바로 그 자리로 옮길 것
func push(pos: Vector3, yaw: float, vel := Vector3.INF) -> bool:
	var t := _now()
	var snapped := false
	if not _buf.is_empty():
		var last: Array = _buf[_buf.size() - 1]
		var lp: Vector3 = last[1]
		if lp.distance_to(pos) > SNAP_DIST:
			_buf.clear()
			snapped = true
		else:
			var dt := t - float(last[0])
			if dt > 0.0005:
				_vel = (pos - lp) / dt if vel == Vector3.INF else vel
	elif vel != Vector3.INF:
		_vel = vel
	if _last_t > 0.0:
		var gap := t - _last_t
		if gap < 1.0:  # 오래 멈췄다 온 건 통계에서 뺌
			_interval = lerpf(_interval, gap, 0.1)
			_jitter = lerpf(_jitter, absf(gap - _interval), 0.1)
	_last_t = t
	_buf.append([t, pos, yaw])
	if _buf.size() > 30:
		_buf.pop_front()
	delay = clampf(_interval * 1.2 + _jitter * 2.5, 0.05, 0.3)
	return snapped


## 지금 그려야 할 [위치, 방향]. 아직 받은 게 없으면 빈 배열
func sample() -> Array:
	if _buf.is_empty():
		return []
	var rt := _now() - delay
	while _buf.size() >= 2 and float(_buf[1][0]) <= rt:
		_buf.pop_front()
	var a: Array = _buf[0]
	if rt <= float(a[0]):
		return [a[1], a[2]]
	if _buf.size() >= 2:
		var b: Array = _buf[1]
		var k := clampf((rt - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001), 0.0, 1.0)
		return [(a[1] as Vector3).lerp(b[1], k), lerp_angle(float(a[2]), float(b[2]), k)]
	# 다음 패킷이 늦음 → 마지막 속도로 잠깐 예측
	var ahead := minf(rt - float(a[0]), MAX_EXTRAPOLATE)
	var v := _vel
	v.y = 0.0
	return [(a[1] as Vector3) + v * ahead, a[2]]
