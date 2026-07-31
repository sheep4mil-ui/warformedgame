extends Node

signal motion_packet_received(packet: Dictionary)
signal connection_changed(connected: bool)

const PORT := 8765

var _server := TCPServer.new()
var _pending: Array[WebSocketPeer] = []
var _clients: Array[WebSocketPeer] = []
var _web_status_label: Label
var _web_code_input: LineEdit

func _ready() -> void:
	if OS.has_feature("web"):
		_setup_web_receiver()
		return
	var error := _server.listen(PORT, "127.0.0.1")
	if error != OK:
		push_error("Motion tracker could not listen on port %d (error %s)" % [PORT, error])
		return
	print("Motion tracker bridge listening on ws://127.0.0.1:%d" % PORT)

func _process(_delta: float) -> void:
	if OS.has_feature("web"):
		_poll_web_receiver()
		return
	_poll_desktop_receiver()

func _poll_desktop_receiver() -> void:
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
			_emit_json_packet(text)

func _setup_web_receiver() -> void:
	JavaScriptBridge.eval("""
		window.motionMirrorQueue = [];
		window.motionMirrorStatus = 'Enter phone code';
		window.motionMirrorTakePacket = () => {
			const packet = window.motionMirrorQueue.shift();
			return packet ? JSON.stringify(packet) : '';
		};
		window.motionMirrorConnect = (code) => {
			window.motionMirrorStatus = 'Connecting...';
			const start = () => {
				if (window.motionMirrorPeer) window.motionMirrorPeer.destroy();
				const peer = new window.Peer();
				window.motionMirrorPeer = peer;
				peer.on('open', () => {
					const connection = peer.connect('warformed-motion-' + code.toLowerCase(), { reliable: false });
					connection.on('open', () => window.motionMirrorStatus = 'Phone connected');
					connection.on('data', packet => {
						if (window.motionMirrorQueue.length > 2) window.motionMirrorQueue.shift();
						window.motionMirrorQueue.push(packet);
					});
					connection.on('close', () => window.motionMirrorStatus = 'Phone disconnected');
					connection.on('error', () => window.motionMirrorStatus = 'Connection failed');
				});
				peer.on('error', () => window.motionMirrorStatus = 'Phone not found');
			};
			if (window.Peer) return start();
			const script = document.createElement('script');
			script.src = 'https://cdn.jsdelivr.net/npm/peerjs@1.5.5/dist/peerjs.min.js';
			script.onload = start;
			script.onerror = () => window.motionMirrorStatus = 'Connection service unavailable';
			document.head.appendChild(script);
		};
	""", true)
	_create_pairing_ui()

func _create_pairing_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MotionTrackingPairing"
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	panel.custom_minimum_size = Vector2(250, 0)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "PHONE BODY TRACKING"
	box.add_child(title)
	_web_code_input = LineEdit.new()
	_web_code_input.placeholder_text = "6-character phone code"
	_web_code_input.max_length = 6
	box.add_child(_web_code_input)
	var connect_button := Button.new()
	connect_button.text = "Connect phone"
	connect_button.pressed.connect(_connect_web_phone)
	box.add_child(connect_button)
	_web_status_label = Label.new()
	_web_status_label.text = "Open /phone on your phone"
	box.add_child(_web_status_label)

func _connect_web_phone() -> void:
	var code := _web_code_input.text.strip_edges().to_lower()
	if code.length() != 6:
		_web_status_label.text = "Enter the 6-character code"
		return
	JavaScriptBridge.eval("window.motionMirrorConnect(%s)" % JSON.stringify(code), true)

func _poll_web_receiver() -> void:
	var status = JavaScriptBridge.eval("window.motionMirrorStatus || 'Enter phone code'", true)
	if _web_status_label and status is String:
		_web_status_label.text = status
	var packet_json = JavaScriptBridge.eval("window.motionMirrorTakePacket ? window.motionMirrorTakePacket() : ''", true)
	if packet_json is String and not packet_json.is_empty():
		_emit_json_packet(packet_json)
		connection_changed.emit(true)

func _emit_json_packet(text: String) -> void:
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		motion_packet_received.emit(parsed)

func is_tracker_connected() -> bool:
	if OS.has_feature("web"):
		return JavaScriptBridge.eval("window.motionMirrorStatus === 'Phone connected'", true) == true
	return not _clients.is_empty()
