extends Node
## 크래시 로그 · 버그 리포트
## - 게임 중 생기는 에러/경고를 모아 user://logs/errors.log 에 바로바로 적음 (튕겨도 남음)
## - 실행 중 표시 파일(session.lock)을 두고, 정상 종료하면 지움 → 다음 실행 때 남아 있으면 "지난번에 튕김"으로 판단
## - make_report(): 버전·PC 정보·설정·현재 판 정보·최근 에러·로그 끝부분 + 스크린샷을 user://bug_reports/ 에 저장
## - 단축키 F8: 어디서든 바로 버그 리포트 만들기

const LOG_DIR := "user://logs"
const REPORT_DIR := "user://bug_reports"
const LOCK := "user://session.lock"
const KEEP := 120

## 지난번 실행이 비정상 종료였는지 (메뉴가 보고 안내를 띄움)
var crashed_last_time := false
var _recent: Array[String] = []
var _mutex := Mutex.new()
var _file: FileAccess
var _logger: _ErrorCatcher


class _ErrorCatcher extends Logger:
	var owner_log: Node

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		var kind: String = ["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"][clampi(error_type, 0, 3)]
		var msg := "%s: %s (%s:%d %s)" % [kind, rationale if rationale != "" else code, file, line, function]
		for bt in script_backtraces:
			if bt and bt.get_frame_count() > 0:
				msg += "\n    at " + bt.get_frame_file(0) + ":" + str(bt.get_frame_line(0)) + " " + bt.get_frame_function(0)
		owner_log.call("_add", msg)

	func _log_message(message: String, error: bool) -> void:
		if error:
			owner_log.call("_add", "STDERR: " + message.strip_edges())


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	crashed_last_time = FileAccess.file_exists(LOCK)
	var lock := FileAccess.open(LOCK, FileAccess.WRITE)
	if lock:
		lock.store_string(Time.get_datetime_string_from_system())
	# 지난 에러 로그는 .old 로 한 번만 보관
	if FileAccess.file_exists(LOG_DIR + "/errors.log"):
		DirAccess.rename_absolute(LOG_DIR + "/errors.log", LOG_DIR + "/errors.old.log")
	_file = FileAccess.open(LOG_DIR + "/errors.log", FileAccess.WRITE)
	if _file:
		_file.store_line("IceTag %s · %s · %s" % [version(), OS.get_name(), Time.get_datetime_string_from_system()])
		_file.flush()
	_logger = _ErrorCatcher.new()
	_logger.owner_log = self
	OS.add_logger(_logger)
	get_tree().set_auto_accept_quit(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_clean_exit()


func _exit_tree() -> void:
	_clean_exit()


func _clean_exit() -> void:
	if FileAccess.file_exists(LOCK):
		DirAccess.remove_absolute(LOCK)
	if _logger:
		OS.remove_logger(_logger)
		_logger = null


## (어느 스레드에서든 불림) 에러 한 줄 기록
func _add(msg: String) -> void:
	_mutex.lock()
	var line := "[%s] %s" % [Time.get_time_string_from_system(), msg]
	_recent.append(line)
	if _recent.size() > KEEP:
		_recent.pop_front()
	if _file:
		_file.store_line(line)
		_file.flush()
	_mutex.unlock()


func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "dev"))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		var path := make_report("F8 단축키")
		_toast("버그 리포트를 저장했어요: " + ProjectSettings.globalize_path(path))


## 버그 리포트 파일을 만들고 경로를 돌려줌. 스크린샷도 같이 저장
func make_report(note := "") -> String:
	DirAccess.make_dir_recursive_absolute(REPORT_DIR)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var base := REPORT_DIR + "/report_" + stamp
	var lines: Array[String] = []
	lines.append("=== IceTag 버그 리포트 ===")
	lines.append("시간: " + Time.get_datetime_string_from_system())
	lines.append("메모: " + note)
	lines.append("게임 버전: " + version() + " · Godot " + Engine.get_version_info()["string"])
	lines.append("OS: %s %s · CPU %s (%d코어)" % [OS.get_name(), OS.get_version(), OS.get_processor_name(), OS.get_processor_count()])
	lines.append("그래픽: %s / %s · 렌더러 %s" % [RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_name(), str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"))])
	lines.append("화면: %s · FPS %d · 메모리 %.0fMB" % [str(DisplayServer.window_get_size()), Engine.get_frames_per_second(), OS.get_static_memory_usage() / 1048576.0])
	lines.append("지난 실행 비정상 종료: " + ("예" if crashed_last_time else "아니오"))
	lines.append("설정: 그래픽 %s · 스테이지 %d · 코인 %d · 테스트 맵 '%s'" % [str(SaveData.get("graphics")), int(SaveData.get("stage")), int(SaveData.get("coins")), str(SaveData.get("test_map"))])
	var main := get_tree().get_first_node_in_group("game")
	if main:
		lines.append("판 정보: 맵 %s · 진행 %.0f초 · 봉인석 %s/%s · 멀티 %s" % [str(main.get("map_name")), float(main.get("round_time")), str(main.get("missions_done")), str(main.get("mission_total")), str(Net.in_match())])
		var p = main.get("player")
		if p and is_instance_valid(p):
			lines.append("내 위치: %s · 얼음 %s · 탈락 %s" % [str(p.global_position), str(p.is_frozen), str(p.is_dead)])
	lines.append("")
	lines.append("--- 최근 에러/경고 (%d개) ---" % _recent.size())
	_mutex.lock()
	lines.append_array(_recent)
	_mutex.unlock()
	lines.append("")
	lines.append("--- 지난 실행 에러 로그 끝부분 ---")
	lines.append_array(_tail(LOG_DIR + "/errors.old.log", 60))
	lines.append("")
	lines.append("--- godot.log 끝부분 ---")
	lines.append_array(_tail(LOG_DIR + "/godot.log", 120))
	var f := FileAccess.open(base + ".txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines))
		f.close()
	var vp := get_viewport()
	if vp and vp.get_texture():
		var img := vp.get_texture().get_image()
		if img:
			img.save_png(base + ".png")
	DisplayServer.clipboard_set(ProjectSettings.globalize_path(base + ".txt"))
	return base + ".txt"


func open_report_folder() -> void:
	DirAccess.make_dir_recursive_absolute(REPORT_DIR)
	OS.shell_open(ProjectSettings.globalize_path(REPORT_DIR))


func _tail(path: String, n: int) -> Array[String]:
	var out: Array[String] = []
	if not FileAccess.file_exists(path):
		out.append("(없음)")
		return out
	var text := FileAccess.get_file_as_string(path)
	var all := text.split("\n")
	for i in range(maxi(0, all.size() - n), all.size()):
		out.append(all[i])
	return out


## 화면 아래에 잠깐 뜨는 알림
func _toast(text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	layer.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 60)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var tw := create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(layer.queue_free)
