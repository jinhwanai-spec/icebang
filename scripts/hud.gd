class_name Hud
extends CanvasLayer
## 게임 화면 위 UI (글자, 능력 쿨타임, 해동 게이지, 화면 효과, 일시정지/결과 창)
## 노드를 코드로 만들기 때문에 에디터에서 따로 꾸밀 필요가 없습니다.

const MENU_SCENE := "res://scenes/menu.tscn"
const SFX_HEART := preload("res://audio/heartbeat.wav")

## 필름 노이즈 (지글지글한 오래된 영상 느낌)
const GRAIN_SHADER := """
shader_type canvas_item;
uniform float amount = 0.07;
float rand(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	float n = rand(UV * vec2(1280.0, 720.0) + vec2(TIME * 37.0, TIME * 91.0));
	float line = step(0.997, rand(vec2(floor(UV.y * 240.0), floor(TIME * 12.0))));
	COLOR = vec4(vec3(n), amount + line * 0.08);
}
"""

## 화면 가장자리 효과 (어두운 테두리 / 서리 / 동화 색)
const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float strength = 0.6;
uniform float inner = 0.35;
void fragment() {
	vec2 uv = (UV - 0.5) * vec2(1.6, 1.0);
	float v = smoothstep(inner, 0.95, length(uv));
	COLOR = vec4(tint.rgb, v * strength);
}
"""

var main: Node  # main.gd

var _top_label: Label
var _retro_mat: ShaderMaterial
var _stamina_bg: ColorRect
var _stamina_fill: ColorRect
var _status_label: Label
var _ability_label: Label
var _shared_label: Label
var _message_label: Label
var _summon_label: Label
var _thaw_bar: ProgressBar
var _thaw_label: Label
var _vignette: ColorRect
var _frost: ColorRect
var _camo: ColorRect
var _flash: ColorRect
var _pause_panel: PanelContainer
var _result_panel: PanelContainer
var _result_title: Label
var _result_body: Label
var _result_retry: Button
var _result_menu: Button
var _message_time := 0.0
var _grain: ColorRect
var _danger: ColorRect
var _heart: AudioStreamPlayer
var _heart_timer := 0.0


## 약한 레트로 필터: 해상도를 살짝 낮추고 색 단계를 줄여 점무늬(디더링)를 아주 옅게
const RETRO_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 pixel_res = vec2(711.0, 400.0);
uniform float color_depth = 32.0;
uniform float dither = 0.5;
float bayer(vec2 p) {
	int i = int(mod(p.x, 4.0)) + int(mod(p.y, 4.0)) * 4;
	float m[16] = float[16](0.,8.,2.,10.,12.,4.,14.,6.,3.,11.,1.,9.,15.,7.,13.,5.);
	return m[i] / 16.0 - 0.5;
}
void fragment() {
	vec2 cell = floor(SCREEN_UV * pixel_res);
	vec3 c = texture(screen_tex, (cell + 0.5) / pixel_res).rgb;
	c += bayer(cell) * dither / color_depth;
	c = floor(c * color_depth + 0.5) / color_depth;
	COLOR = vec4(c, 1.0);
}
"""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 일시정지 중에도 UI는 동작

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 레트로 필터 (약하게): 3D 화면만 살짝 거칠게. UI보다 먼저 그려서 글씨는 깨끗하게 유지
	if GameConfig.flag("retro", "enabled", false):
		var retro := ColorRect.new()
		retro.mouse_filter = Control.MOUSE_FILTER_IGNORE
		retro.set_anchors_preset(Control.PRESET_FULL_RECT)
		var rs := Shader.new()
		rs.code = RETRO_SHADER
		var rm := ShaderMaterial.new()
		rm.shader = rs
		_retro_mat = rm
		rm.set_shader_parameter("color_depth", GameConfig.num("retro", "color_depth", 32.0))
		rm.set_shader_parameter("dither", GameConfig.num("retro", "dither", 0.5))
		retro.material = rm
		root.add_child(retro)

	# 화면 효과 (가장 아래에 깔림)
	_vignette = _make_overlay(root, Color.BLACK, 0.75, 0.3)
	_camo = _make_overlay(root, Color(0.3, 0.9, 0.4), 0.0, 0.2)
	_frost = _make_overlay(root, Color(0.75, 0.92, 1.0), 0.0, 0.15)
	# 공포 연출: 필름 노이즈 + 술래가 가까울수록 붉게 조여오는 화면
	_grain = ColorRect.new()
	_grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	var gs := Shader.new()
	gs.code = GRAIN_SHADER
	var gm := ShaderMaterial.new()
	gm.shader = gs
	gm.set_shader_parameter("amount", GameConfig.num("horror", "grain", 0.07))
	_grain.material = gm
	_grain.visible = GameConfig.num("horror", "grain", 0.0) > 0.0  # 0이면 노이즈 끔 (화면이 깨끗하게)
	root.add_child(_grain)
	_danger = _make_overlay(root, Color(0.5, 0.0, 0.0), 0.0, 0.25)
	_heart = AudioStreamPlayer.new()
	_heart.stream = SFX_HEART
	add_child(_heart)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_flash)

	_top_label = _make_label(root, 20, Control.PRESET_TOP_LEFT)
	_status_label = _make_label(root, 21, Control.PRESET_CENTER_BOTTOM)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.position.y -= 90
	# 스태미나 막대 (화면 아래 가운데)
	_stamina_bg = ColorRect.new()
	_stamina_bg.color = Color(0, 0, 0, 0.55)
	_stamina_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_bg.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_stamina_bg.size = Vector2(260, 12)
	_stamina_bg.position = Vector2(-130, -42)
	root.add_child(_stamina_bg)
	_stamina_fill = ColorRect.new()
	_stamina_fill.color = Color(1.0, 0.85, 0.2)
	_stamina_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_fill.position = Vector2(2, 2)
	_stamina_fill.size = Vector2(256, 8)
	_stamina_bg.add_child(_stamina_fill)
	_ability_label = _make_label(root, 18, Control.PRESET_BOTTOM_LEFT)
	_shared_label = _make_label(root, 16, Control.PRESET_BOTTOM_RIGHT)
	_shared_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var help := _make_label(root, 14, Control.PRESET_TOP_RIGHT)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help.text = "WASD 이동 · Shift 달리기(소리 큼) · Ctrl 살금살금 · Space 구르기\nE 봉인석·문·판자·사물함·쥐·거미줄 · Q 얼음 · R/T 고유 능력\n얼음 동료 옆에 10초 붙어 있으면 땡 · Esc 일시정지\n헤드셋을 쓰면 발소리로 위치를 알 수 있어요"
	help.modulate = Color(1, 1, 1, 0.6)

	_message_label = _make_label(root, 28, Control.PRESET_CENTER_TOP)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.position.y += 110

	_summon_label = _make_label(root, 22, Control.PRESET_CENTER)
	_summon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summon_label.position.y += 80
	_summon_label.modulate = Color(0.85, 0.75, 1.0)

	var crosshair := _make_label(root, 24, Control.PRESET_CENTER)
	crosshair.text = "·"
	crosshair.modulate = Color(1, 1, 1, 0.7)

	# 해동 게이지 (화면 가운데 아래)
	var thaw_box := VBoxContainer.new()
	root.add_child(thaw_box)
	thaw_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 150)
	thaw_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	thaw_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_thaw_label = Label.new()
	_thaw_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thaw_label.add_theme_font_size_override("font_size", 18)
	thaw_box.add_child(_thaw_label)
	_thaw_bar = ProgressBar.new()
	_thaw_bar.custom_minimum_size = Vector2(360, 18)
	_thaw_bar.show_percentage = false
	thaw_box.add_child(_thaw_bar)
	thaw_box.visible = false

	_build_pause_panel(root)
	_build_result_panel(root)


## main.gd가 게임 준비를 끝내면 불러 줍니다.
func setup(main_node: Node) -> void:
	main = main_node


func show_message(text: String, seconds: float) -> void:
	_message_label.text = text
	_message_time = seconds


## 카메라맨 플래시 효과
func flash() -> void:
	_flash.color.a = 0.85
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.5)


## 폭주 경고: 화면이 붉게 번쩍 + 울부짖음
func flash_red() -> void:
	_flash.color = Color(0.8, 0.0, 0.0, 0.6)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 1.2)
	tw.tween_callback(func() -> void: _flash.color = Color(1, 1, 1, 0))
	var a := AudioStreamPlayer.new()
	a.stream = preload("res://audio/howl.wav")
	a.pitch_scale = 0.7
	a.volume_db = -4.0
	add_child(a)
	a.play()
	a.finished.connect(a.queue_free)


func _process(delta: float) -> void:
	_message_time -= delta
	_message_label.visible = _message_time > 0.0
	if main == null or not main.ready_to_play:
		return
	var p = main.player
	_update_heartbeat(delta, p)

	# --- 위쪽: 진행 상황
	var alive := 0
	var frozen := 0
	for s in main.survivors:
		if not s.is_dead:
			alive += 1
			if s.is_frozen:
				frozen += 1
	_top_label.text = "스테이지 %d    봉인석 %d / %d\n생존 %d / %d  (얼음 %d)    코인 %d" % [
		SaveData.stage, main.missions_done, main.mission_total,
		alive, main.survivors.size(), frozen, SaveData.coins]
	if main.escape_phase:
		var t := ceili(main.escape_left)
		_top_label.text += "\n탈출구가 열렸어요! 남은 시간 %d:%02d   탈출 %d명" % [t / 60, t % 60, main.survivors.filter(func(x): return x.escaped).size()]
	if main.raged:
		_top_label.text += "\n술래 폭주 중!"
	if main.seal_broken:
		_top_label.text += "\n봉인석 파괴됨! 술래를 모두 쓰러뜨려야 해요 (남은 술래 %d)" % main.seekers.filter(func(x): return not x.is_killed).size()
	if main.paint_time_left > 0.0:
		_top_label.text += "\n맵 물들이기 %d초" % ceili(main.paint_time_left)
	if p.bleed_time_left > 0.0:
		_top_label.text += "\n피를 흘리는 중! 술래가 따라와요 (%d초)" % ceili(p.bleed_time_left)
	if p.speed_multiplier() < 0.99:
		_top_label.text += "\n느려짐 (%d%%)" % int(p.speed_multiplier() * 100.0)

	# --- 레트로 필터: 창 크기에 맞춰 거칠기를 일정하게 (큰 화면·전체화면에서도 같은 느낌)
	if _retro_mat:
		var vs := get_viewport().get_visible_rect().size
		_retro_mat.set_shader_parameter("pixel_res", vs * GameConfig.num("retro", "pixel_scale", 0.75))

	# --- 스태미나
	var ratio := clampf(p.stamina / GameConfig.num("stamina", "max", 100.0), 0.0, 1.0)
	_stamina_fill.size.x = 256.0 * ratio
	_stamina_fill.color = Color(1.0, 0.3, 0.2) if p.exhausted else Color(1.0, 0.85, 0.2)
	_stamina_bg.visible = not p.is_dead and not p.escaped

	# --- 화면 효과
	_frost.material.set_shader_parameter("strength", 0.85 if p.is_frozen else 0.0)
	_camo.material.set_shader_parameter("strength", 0.5 if p.is_hidden_from_seeker() else 0.0)

	# --- 해동 게이지: 내가 얼었을 때 / 내가 동료를 녹이고 있을 때
	var thaw_time := GameConfig.num("player", "thaw_time", 10.0)
	var thaw_target: Survivor = null
	if p.is_frozen:
		thaw_target = p
	elif not p.is_dead:
		var reach := GameConfig.num("player", "unfreeze_distance", 1.8)
		for s in main.survivors:
			if s != p and s.is_frozen and not s.is_dead and p.global_position.distance_to(s.global_position) <= reach:
				thaw_target = s
				break
	var thaw_box := _thaw_bar.get_parent() as Control
	thaw_box.visible = thaw_target != null
	if thaw_target:
		_thaw_bar.max_value = thaw_time
		_thaw_bar.value = thaw_target.thaw_progress
		if thaw_target == p:
			_thaw_label.text = "해동 중... %.1f / %d초" % [p.thaw_progress, thaw_time] if p.thaw_progress > 0.0 \
					else "얼음! 동료가 옆에 %d초 있어야 풀려요" % thaw_time
		else:
			_thaw_label.text = "%s 해동 중... %.1f / %d초 (떨어지면 처음부터)" % [thaw_target.display_name, thaw_target.thaw_progress, thaw_time]

	# --- 아래쪽 가운데: 내 상태
	if p.is_dead:
		_status_label.text = "탈락! (관전 중) 동료들이 봉인석을 다 가동하면 함께 클리어돼요."
	elif p.is_frozen:
		_status_label.text = "[ 얼음 %d회 ]  술래에게 잡히지 않아요" % p.freeze_count
		if p.ice_left > 0.0:
			_status_label.text += "  —  %d초 안에 땡을 못 받으면 얼음이 깨져요!" % ceili(p.ice_left)
	elif p.has_meta("bandaged"):
		_status_label.text = "의사의 붕대에 끌려가는 중!"
	elif p.pulled_time_left > 0.0 and not p.has_meta("vaulting") and not p.has_meta("executing"):
		_status_label.text = "쇠사슬에 끌려가는 중!"
	elif p.is_blended():
		_status_label.text = "동화 중 %.1f초 - 움직일 수 없어요 (R: 취소)" % p.blend_time_left
	elif p.paint_time_left > 0.0:
		_status_label.text = "물들이기 중 %.1f초 - 술래가 나를 감지 못해요 (상호작용 불가)" % p.paint_time_left
	elif p.has_meta("executing"):
		_status_label.text = "처형인에게 붙잡혔어요!! 동료가 처형인을 기절시켜야 해요!"
	elif p.chained_by:
		_status_label.text = "사이코의 쇠사슬에 묶여 끌려가는 중... 동료가 풀어 줘야 해요"
	elif p.rooted_left > 0.0 and p.has_meta("floating"):
		_status_label.text = "하마의 무중력에 떠올랐어요! (%.1f초)" % p.rooted_left
	elif p.rooted_left > 0.0:
		_status_label.text = "거미줄에 묶였어요! (%.1f초) 얼음(Q)만 쓸 수 있어요" % p.rooted_left
	elif p.is_shadowed():
		_status_label.text = "그림자 속 %.1f초 - 감지·잡기 불가 (R: 나오기 · T: 동료 그림자로 건너가기)" % p.shadow_left
	elif p.in_locker:
		_status_label.text = "사물함에 숨는 중... (E: 나가기)  30초가 넘으면 고양이가 울어요"
	elif p.escaped:
		_status_label.text = "탈출 성공! 동료들을 기다리는 중..."
	elif p.nearby_prop:
		_status_label.text = p.nearby_prop.call("prompt", p)
	elif p.nearby_web:
		_status_label.text = "[E] 거미줄 걷어내기"
	elif p.nearby_rat:
		_status_label.text = p.nearby_rat.get_meta("prompt", "[E] 쥐 잡기 (잡으면 술래가 위치를 알게 돼요)")
	elif p.is_repairing:
		_status_label.text = "미니게임 중... 술래를 조심하세요! (Esc: 그만두기)"
	elif p.nearby_generator:
		_status_label.text = "[E] 봉인석 미니게임 (%d / %d 단계)" % [p.nearby_generator.stages_done(), p.nearby_generator.stage_count()]
	elif p.is_in_grass():
		_status_label.text = "풀숲에 숨어 있어요"
	elif p.freeze_cooldown_left > 0.0:
		_status_label.text = "얼음 다시 쓰기까지 %.1f초" % p.freeze_cooldown_left
	else:
		_status_label.text = ""

	# --- 소환 창 (공간을 지배하는 자)
	_summon_label.visible = p.summon_menu_open
	if p.summon_menu_open:
		var lines := ["치료할 동료를 고르세요  (R: 취소)" if p.heal_menu else "소환할 동료를 고르세요  (T: 취소)"]
		for i in p.summon_candidates.size():
			var c = p.summon_candidates[i]
			var tag := ""
			if p.heal_menu:
				tag = "  (얼음 → 해동)" if c.is_frozen else "  (이동속도 +%d%%)" % int(GameConfig.num("medic", "heal_speed", 0.2) * 100)
			elif c.is_frozen:
				tag = "  (얼음)"
			lines.append("[%d] %s%s" % [i + 1, c.display_name, tag])
		_summon_label.text = "\n".join(lines)

	# --- 아래쪽 왼쪽: 캐릭터 고유 능력
	var info := CharacterDB.get_info(p.character_id)
	var ability_lines := [info["name"]]
	for slot in range(1, CharacterDB.slot_count(p.character_id) + 1):
		var key: String = ["R", "T", "Y"][slot - 1]
		var state: String
		var max_c := CharacterDB.max_charges(p.character_id, slot)
		var pid: String = p.character_id
		var arrows := -1
		if pid == "hunter":
			arrows = int(p.get("arrows_left"))
			if arrows < 0:
				arrows = main.seekers.size()
		if CharacterDB.is_passive(pid, slot):
			state = "패시브"
		elif pid == "bard":
			state = "♪ 연주 중 (다시 누르면 끔)" if p.get("song") == slot else "꺼짐"
		elif pid == "hunter" and slot == 2 and arrows == 0:
			state = "화살 없음"
		elif pid == "mechanic" and slot == 2 and p.item != "":
			state = "착용 중: %s (깨지면 다시 사용)" % Survivor.ITEM_NAMES[p.item]
		elif pid == "keeper" and slot == 2 and p.ability_cooldown_left[1] >= 9000.0:
			state = "탐색 중"
		elif max_c > 0:
			state = "%d / %d개" % [p.ability_charges[slot - 1], max_c]
			if p.ability_charges[slot - 1] < max_c:
				state += " (충전 %d초)" % ceili(p.ability_cooldown_left[slot - 1])
		elif p.ability_cooldown_left[slot - 1] > 0.0:
			state = "%d초" % ceili(p.ability_cooldown_left[slot - 1])
		else:
			state = "준비됨"
		if pid == "hunter" and slot == 2 and arrows > 0:
			state += "  (화살 %d발)" % arrows
		ability_lines.append("[%s] %s: %s" % [key, info["ability_%d" % slot], state])
	_ability_label.text = "\n".join(ability_lines)

	# --- 아래쪽 오른쪽: 상점 공통 능력
	var noise_text: String
	if not SaveData.has_ability("noise"):
		noise_text = "잠김"
	elif p.noise_cooldown_left > 0.0:
		noise_text = "%d초" % ceili(p.noise_cooldown_left)
	else:
		noise_text = "준비됨"
	var emote_text := "준비됨" if SaveData.has_ability("emote") else "잠김"
	_shared_label.text = "공통 능력 (얼음 상태에서)\n[F] 소리 내기: %s\n[G] 이모티콘: %s\n이모트 (숫자키): [1] 엉덩이 춤" % [noise_text, emote_text]


## 술래가 heartbeat_distance(6m) 안에 오면 두근두근. 가까울수록 빠르고 크게, 화면이 붉게 조여옴
func _update_heartbeat(delta: float, p) -> void:
	var near := INF
	if not p.is_dead:
		for sk in main.seekers:
			if sk.is_active() and not sk.is_disguised():  # 변신한 마녀는 심장이 안 뜀 (속이기)
				near = minf(near, p.global_position.distance_to(sk.global_position))
	var hear := GameConfig.num("horror", "heartbeat_distance", 6.0)
	var k := clampf(1.0 - near / hear, 0.0, 1.0) if near < hear else 0.0
	_heart_timer -= delta
	if near < hear and _heart_timer <= 0.0:
		_heart_timer = lerpf(0.85, 0.4, k)
		_heart.volume_db = lerpf(-4.0, 3.0, k)
		_heart.play()
	var pulse := maxf(0.0, 1.0 - (lerpf(0.85, 0.4, k) - _heart_timer) * 4.0) if near < hear else 0.0
	k = maxf(k, 0.25) if near < hear else 0.0
	_danger.material.set_shader_parameter("strength", k * 0.55 + pulse * k * 0.35)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and main and main.ready_to_play and not _result_panel.visible:
		_set_paused(not get_tree().paused)


func _set_paused(paused: bool) -> void:
	if not Net.in_match():  # 멀티에서는 게임을 멈추지 않고 메뉴만 띄움
		get_tree().paused = paused
	_pause_panel.visible = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


## main.gd가 판이 끝나면 불러 줍니다.
func show_result(win: bool, title: String, details: String) -> void:
	_pause_panel.visible = false
	_result_title.text = title
	_result_title.modulate = Color(0.5, 1, 0.6) if win else Color(1, 0.5, 0.5)
	_result_body.text = details
	_result_retry.text = "다음 스테이지" if win else "다시 하기"
	if Net.in_match():
		# 멀티: 방은 유지된 채 로비로. 방장은 바로 다음 판도 가능
		_result_retry.text = "다음 판 바로 시작"
		_result_retry.visible = Net.is_host()
		_result_menu.text = "로비로 (모두 함께)" if Net.is_host() else "로비로"
	_result_panel.visible = true


# ---------------------------------------------------------------- UI 만들기 도우미

func _make_overlay(parent: Control, tint: Color, strength: float, inner: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("strength", strength)
	mat.set_shader_parameter("inner", inner)
	rect.material = mat
	parent.add_child(rect)
	return rect


func _make_label(parent: Control, font_size: int, preset: Control.LayoutPreset) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	parent.add_child(label)
	label.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 20)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH if preset in [
		Control.PRESET_CENTER, Control.PRESET_CENTER_TOP, Control.PRESET_CENTER_BOTTOM] else (
		Control.GROW_DIRECTION_BEGIN if preset in [Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT]
		else Control.GROW_DIRECTION_END)
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN if preset in [
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_CENTER_BOTTOM, Control.PRESET_BOTTOM_RIGHT] else (
		Control.GROW_DIRECTION_BOTH if preset == Control.PRESET_CENTER else Control.GROW_DIRECTION_END)
	return label


func _make_panel(parent: Control) -> Array:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	panel.visible = false
	return [panel, box]


func _make_button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 48)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(on_pressed)
	parent.add_child(b)
	return b


func _build_pause_panel(root: Control) -> void:
	var made := _make_panel(root)
	_pause_panel = made[0]
	var box: VBoxContainer = made[1]
	var title := Label.new()
	title.text = "일시정지"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_make_button(box, "계속하기", func() -> void: _set_paused(false))
	_make_button(box, ("로비로 (모두 함께, 방 유지)" if Net.is_host() else "로비로 (방 유지, 내 자리는 봇이)") if Net.in_match() else "메뉴로 (이번 판 포기)", _go_menu)


func _build_result_panel(root: Control) -> void:
	var made := _make_panel(root)
	_result_panel = made[0]
	var box: VBoxContainer = made[1]
	_result_title = Label.new()
	_result_title.add_theme_font_size_override("font_size", 38)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_title)
	_result_body = Label.new()
	_result_body.add_theme_font_size_override("font_size", 20)
	box.add_child(_result_body)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	_result_retry = _make_button(buttons, "다시 하기", _restart)
	_result_menu = _make_button(buttons, "메뉴로", _go_menu)


func _restart() -> void:
	if Net.in_match():
		if Net.is_host():
			Net.start_match()  # 멀티: 방장이 다음 판 시작 → 모두 같이 이동
		return
	get_tree().paused = false
	get_tree().reload_current_scene()


func _go_menu() -> void:
	if Net.in_match():
		Net.return_to_lobby()  # 멀티: 방을 깨지 않고 로비로
		return
	if Net.active:
		Net.leave()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MENU_SCENE)
