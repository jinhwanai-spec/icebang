extends Node
## [자동 로드] 멀티플레이 담당 (1단계: IP 주소로 접속, 최대 4명)
## - 방장(호스트)이 술래 AI·봉인석·판정을 모두 계산하고, 결과를 다른 사람들에게 보냄
## - 각자 자기 캐릭터는 자기 컴퓨터에서 움직이고, 위치를 방장에게 보냄 (반응이 빠르게)
## - 빈 자리는 방장 컴퓨터의 봇이 채움
## 나중에 Steam으로 바꿀 때는 이 파일의 접속 부분(host/join)만 바꾸면 됨

signal lobby_changed
signal status_changed(text: String)

const PORT := 7777
const MAX_PLAYERS := 4

## 멀티 로비 또는 멀티 판 진행 중
var active := false
## 접속한 사람들: peer_id → {"name": 이름, "character": 캐릭터 id, "ready": 준비 완료, "in_game": 게임 화면에 있는지}
var players := {}
## 지금 판 설정 (방장이 정해서 모두에게 보냄)
var match_config := {}
var my_name := "플레이어"
## 게임 방식: "classic" = 지금 방식 (AI 술래) / "turncoat" = 술래 변신 (판 중간에 무작위 플레이어 한 명이 술래로 변함)
var match_mode := "classic"
const MODE_NAMES := {"classic": "기본 (AI 술래)", "turncoat": "술래 변신 (무작위 플레이어가 술래로)"}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_host() -> bool:
	return active and multiplayer.multiplayer_peer != null and multiplayer.is_server()


func is_client() -> bool:
	return active and multiplayer.multiplayer_peer != null and not multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id() if active else 1


## 지금 멀티 판을 하는 중인지 (로비가 아니라 게임 안)
func in_match() -> bool:
	return active and not match_config.is_empty()


# ---------------------------------------------------------------- 접속

func host(player_name: String) -> bool:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		status_changed.emit("방을 만들 수 없어요 (포트 %d 사용 중?)" % PORT)
		return false
	multiplayer.multiplayer_peer = peer
	active = true
	my_name = player_name
	players = {1: {"name": player_name, "character": "", "ready": true, "in_game": false, "cos": SaveData.equipped.duplicate()}}
	status_changed.emit("방을 만들었어요! 친구에게 IP를 알려 주세요")
	lobby_changed.emit()
	return true


func join(ip: String, player_name: String) -> bool:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip.strip_edges(), PORT)
	if err != OK:
		status_changed.emit("접속할 수 없어요")
		return false
	multiplayer.multiplayer_peer = peer
	active = true
	my_name = player_name
	status_changed.emit("%s 에 접속하는 중..." % ip)
	return true


func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	active = false
	players = {}
	match_config = {}
	lobby_changed.emit()


## 이 컴퓨터의 IP 주소들 (방장이 친구에게 알려 줄 용도)
func local_ips() -> Array:
	var out: Array = []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254"):
			out.append(a)
	return out


func _on_connected() -> void:
	status_changed.emit("접속 성공!")
	register.rpc_id(1, my_name, SaveData.equipped.duplicate())


func _on_connection_failed() -> void:
	leave()
	status_changed.emit("접속 실패. IP를 확인하거나 방장이 방을 만들었는지 확인해 주세요")
	lobby_changed.emit()


func _on_server_disconnected() -> void:
	var was_in_game := in_match()
	leave()
	status_changed.emit("방장과 연결이 끊겼어요")
	lobby_changed.emit()
	if was_in_game:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var name: String = players.get(id, {}).get("name", "누군가")
	players.erase(id)
	sync_players.rpc(players)
	if in_match():
		var main := get_tree().get_first_node_in_group("game")
		if main and main.has_method("net_peer_left"):
			main.call("net_peer_left", id, name)


# ---------------------------------------------------------------- 로비

@rpc("any_peer", "reliable")
func register(player_name: String, cos := {}) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if in_match() or players.size() >= MAX_PLAYERS:
		kicked.rpc_id(id, "방이 가득 찼거나 이미 게임 중이에요")
		return
	players[id] = {"name": player_name, "character": "", "ready": false, "in_game": false, "cos": cos}
	sync_players.rpc(players)
	sync_mode.rpc(match_mode)


## 방장: 게임 방식 바꾸기 (모두에게 알림)
func toggle_mode() -> void:
	if not multiplayer.is_server():
		return
	sync_mode.rpc("turncoat" if match_mode == "classic" else "classic")


@rpc("authority", "reliable", "call_local")
func sync_mode(mode: String) -> void:
	match_mode = mode if MODE_NAMES.has(mode) else "classic"
	lobby_changed.emit()


## 누군가 창문 유리를 깨고 넘음 → 모두의 화면에서 그 유리가 깨짐
@rpc("any_peer", "reliable", "call_local")
func window_broken(index: int) -> void:
	var m := _main()
	if m:
		m.call("break_window", index)


## 방장 → 모두: slot 자리의 플레이어가 술래로 변함
@rpc("authority", "reliable", "call_local")
func turn_seeker(slot: int) -> void:
	var m := _main()
	if m:
		m.call("net_turn_seeker", slot)


@rpc("authority", "reliable")
func kicked(reason: String) -> void:
	leave()
	status_changed.emit(reason)
	lobby_changed.emit()


@rpc("authority", "reliable", "call_local")
func sync_players(p: Dictionary) -> void:
	players = p
	lobby_changed.emit()


## 캐릭터 고르기 (같은 캐릭터는 한 명만)
func pick_character(id: String) -> void:
	request_character.rpc_id(1, id)


@rpc("any_peer", "reliable", "call_local")
func request_character(id: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	for pid in players:
		if pid != sender and players[pid]["character"] == id:
			return  # 이미 다른 사람이 고름
	if players.has(sender):
		players[sender]["character"] = id
		if sender != 1:
			players[sender]["ready"] = false  # 캐릭터를 바꾸면 다시 준비해야 함
	sync_players.rpc(players)


## 준비 완료 / 취소 (방장이 아닌 사람)
func set_ready(on: bool) -> void:
	request_set_ready.rpc_id(1, on)


@rpc("any_peer", "reliable", "call_local")
func request_set_ready(on: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	if players.has(sender) and sender != 1:
		players[sender]["ready"] = on and players[sender]["character"] != ""
		sync_players.rpc(players)


func is_ready(pid: int) -> bool:
	return pid == 1 or bool(players.get(pid, {}).get("ready", false))


## 방장 말고 모두 준비했는지
func all_ready() -> bool:
	for pid in players:
		if not is_ready(pid):
			return false
	return true


## 방장이 아직 게임 화면에 있는지 (로비로 먼저 돌아온 사람에게 보여 줌)
func host_in_game() -> bool:
	return bool(players.get(1, {}).get("in_game", false))


func all_picked() -> bool:
	for pid in players:
		if players[pid]["character"] == "":
			return false
	return true


# ---------------------------------------------------------------- 판 시작

## 방장이 시작: 맵·술래·자리(사람/봇)를 정해서 모두에게 보냄
func start_match() -> void:
	if not multiplayer.is_server():
		return
	var slots: Array = []
	var used: Array = []
	var ids: Array = players.keys()
	ids.sort()
	# 캐릭터를 아직 안 고른 사람은 남은 캐릭터 중 하나를 자동으로 (준비 안 한 사람도 같이 시작)
	for pid in ids:
		if players[pid]["character"] != "":
			used.append(players[pid]["character"])
	var left: Array = CharacterDB.ORDER.filter(func(c): return not used.has(c) and not CharacterDB.is_hidden(c))
	left.shuffle()
	for pid in ids:
		if players[pid]["character"] == "" and not left.is_empty():
			players[pid]["character"] = left.pop_front()
	used.clear()
	for pid in ids:
		slots.append({"peer": pid, "character": players[pid]["character"], "name": players[pid]["name"], "cos": players[pid].get("cos", {})})
		used.append(players[pid]["character"])
	var free: Array = CharacterDB.ORDER.filter(func(c): return not used.has(c) and not CharacterDB.is_hidden(c))
	free.shuffle()
	var bot_n := 1
	while slots.size() < MAX_PLAYERS and not free.is_empty():
		var c: String = free.pop_front()
		slots.append({"peer": 0, "character": c, "name": "봇%d (%s)" % [bot_n, CharacterDB.get_info(c)["name"]]})
		bot_n += 1
	for pid in players:
		players[pid]["in_game"] = true
		if pid != 1:
			players[pid]["ready"] = false  # 다음 판에는 다시 준비
	sync_players.rpc(players)
	var cfg := {
		"seed": randi(),
		"map": SaveData.test_map if SaveData.test_map != "" else ["city", "forest", "school", "hospital"][randi() % 4],
		"stage": SaveData.stage,
		"slots": slots,
		"mode": match_mode,
	}
	begin_match.rpc(cfg)


@rpc("authority", "reliable", "call_local")
func begin_match(cfg: Dictionary) -> void:
	match_config = cfg
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")


## 판에서 로비로 (방은 그대로 유지)
## 방장: 모두 함께 로비로 / 다른 사람: 나만 로비로 (내 캐릭터는 봇이 이어서 함)
func return_to_lobby() -> void:
	if not active:
		return
	if multiplayer.is_server():
		back_to_lobby.rpc()
	else:
		left_match.rpc_id(1)
		_go_lobby()


@rpc("authority", "reliable", "call_local")
func back_to_lobby() -> void:
	if multiplayer.is_server():
		for pid in players:
			players[pid]["in_game"] = false
		sync_players.rpc(players)
	_go_lobby()


func _go_lobby() -> void:
	match_config = {}
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	lobby_changed.emit()


## 다른 사람 → 방장: 나는 먼저 로비로 돌아감
@rpc("any_peer", "reliable")
func left_match() -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	players[id]["in_game"] = false
	sync_players.rpc(players)
	var m := _main()
	if m and in_match() and m.has_method("net_peer_left"):
		m.call("net_peer_left", id, str(players[id]["name"]), true)


## 내 자리 번호 (없으면 -1)
func my_slot() -> int:
	var slots: Array = match_config.get("slots", [])
	for i in slots.size():
		if int(slots[i]["peer"]) == my_id():
			return i
	return -1


# ---------------------------------------------------------------- 게임 중 메시지 (main.gd 로 전달)

func _main() -> Node:
	return get_tree().get_first_node_in_group("game")


## 방장 → 모두: 세계 상태 (초당 20번)
@rpc("authority", "unreliable_ordered")
func world_snapshot(data: Array) -> void:
	var m := _main()
	if m:
		m.call("net_apply_snapshot", data)


## 각자 → 방장: 내 캐릭터 상태 (초당 20번)
@rpc("any_peer", "unreliable_ordered")
func player_state(slot: int, data: Array) -> void:
	var m := _main()
	if m and multiplayer.is_server():
		m.call("net_apply_player_state", multiplayer.get_remote_sender_id(), slot, data)


## 방장 → 그 사람: 내 캐릭터에 일어난 일 (잡힘, 묶임, 감속 등)
@rpc("authority", "reliable")
func apply_to_me(method: String, args: Array) -> void:
	var m := _main()
	if m:
		m.call("net_apply_to_me", method, args)


## 방장 → 그 사람: 계속 끌려가는 힘 (하마 블랙홀)
@rpc("authority", "unreliable")
func pull_me(v: Vector3) -> void:
	var m := _main()
	if m and m.player:
		m.player.add_external_pull(v)


## 각자 → 방장: 봉인석 미니게임 결과
@rpc("any_peer", "reliable")
func minigame_result(gen_index: int, slot: int, cleared: bool) -> void:
	var m := _main()
	if m and multiplayer.is_server():
		m.call("net_minigame_result", gen_index, slot, cleared)


## 각자 → 방장: 봉인석 미니게임을 중간에 그만둠 (술래가 알게 됨)
@rpc("any_peer", "reliable")
func minigame_cancel(gen_index: int) -> void:
	var m := _main()
	if m and multiplayer.is_server():
		m.call("net_minigame_cancel", gen_index)


## 각자 → 방장: 사나이 강펀치로 술래를 날림 (술래는 방장 컴퓨터가 움직이므로)
@rpc("any_peer", "reliable")
func seeker_knockback(index: int, dir: Vector3, stun: float) -> void:
	var m := _main()
	if m and multiplayer.is_server():
		m.call("net_seeker_knockback", index, dir, stun)


## 방장 → 모두: 화면 가운데 알림
@rpc("authority", "reliable")
func message(text: String, seconds: float) -> void:
	var m := _main()
	if m:
		m.hud.show_message(text, seconds)


## 방장 → 모두: 탈출 단계 시작 (탈출구 위치)
@rpc("authority", "reliable")
func escape_started(positions: Array) -> void:
	var m := _main()
	if m:
		m.call("net_client_escape", positions)


## 방장 → 모두: 판 끝
@rpc("authority", "reliable")
func round_ended(win: bool, reason: String, details: String, rows: Array) -> void:
	var m := _main()
	if m:
		m.call("net_client_round_end", win, reason, details, rows)
