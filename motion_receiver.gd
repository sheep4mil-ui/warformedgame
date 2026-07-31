extends Node

signal motion_packet_received(packet: Dictionary)
signal connection_changed(connected: bool)

const PORT := 8765

var _server := TCPServer.new()
var _pending: Array[WebSocketPeer] = []
var _clients: Array[WebSocketPeer] = []

func _ready() -> void:
	var error := _server.listen(PORT, "127.0.0.1")
	if error != OK:
		push_error("Motion tracker could not listen on port %d (error %s)" % [PORT, error])
		return
	print("Motion tracker bridge listening on ws://127.0.0.1:%d" % PORT)

func _process(_delta: float) -> void:
	while _server.is_connection_available():
		var socket := WebSocketPeer.new()
		var stream := _server.take_connection()
		if socket.accept_stream(stream) == OK:
			_pending.append(socket)

	for socket in _pending.duplicate():
		socket.poll()
		if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_pending.erase(socket)
			_clients.append(socket)
			connection_changed.emit(true)
		elif socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			_pending.erase(socket)

	for socket in _clients.duplicate():
		socket.poll()
		if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			_clients.erase(socket)
			connection_changed.emit(not _clients.is_empty())
			continue
		while socket.get_available_packet_count() > 0:
			var text: String = socket.get_packet().get_string_from_utf8()
			var parsed = JSON.parse_string(text)
			if parsed is Dictionary:
				motion_packet_received.emit(parsed)

func is_tracker_connected() -> bool:
	return not _clients.is_empty()
