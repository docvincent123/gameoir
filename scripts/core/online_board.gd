class_name OnlineBoard
extends Node

signal changed
var rows: Array = []
var busy := false
var status := "ONLINE_OFFLINE"
var request := HTTPRequest.new()

func _ready() -> void:
	add_child(request)
	request.timeout = 12.0
	request.request_completed.connect(finished)
	if configured():
		status = "ONLINE_READY"

func endpoint() -> String:
	return String(ProjectSettings.get_setting("clay/leaderboard_url", "")).strip_edges().trim_suffix("/")

func configured() -> bool:
	return endpoint().begins_with("https://")

func refresh() -> void:
	send(HTTPClient.METHOD_GET, "")

func submit(save) -> void:
	if not configured() or busy:
		return
	var id := String(save.setting("online_id", ""))
	if id.is_empty():
		id = Crypto.new().generate_random_bytes(16).hex_encode()
		save.set_setting("online_id", id)
	send(HTTPClient.METHOD_POST, JSON.stringify({"id": id, "score": save.best()}))

func send(method: int, body: String) -> void:
	if not configured() or busy:
		return
	busy = true
	status = "ONLINE_LOADING"
	var error := request.request(endpoint() + "/scores", ["Content-Type: application/json"], method, body)
	if error != OK:
		busy = false
		status = "ONLINE_ERROR"
	changed.emit()

func finished(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	status = "ONLINE_ERROR"
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Array:
			rows.clear()
			for entry: Variant in parsed:
				if entry is Dictionary and entry.has("name") and entry.has("score"):
					rows.append(entry)
			status = "ONLINE_READY"
	changed.emit()
