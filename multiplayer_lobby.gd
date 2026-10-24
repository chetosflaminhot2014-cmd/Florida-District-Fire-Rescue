extends Node
## Multiplayer networking for Police Officer Simulator.
## Host mode supports LAN and internet clients when the host network permits UDP port 7000.

signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal remote_state_received(peer_id: int, position: Vector3, rotation_y: float)
signal network_status_changed(message: String)
signal dispatch_received(message: String, location: Vector3)

const PORT := 7000
const MAX_CLIENTS := 8
var player_name := "Officer"
var remote_states: Dictionary = {}

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func(): network_status_changed.emit("Conectado al servidor"))
	multiplayer.connection_failed.connect(func(): network_status_changed.emit("No se pudo conectar. Revisa la IP y el puerto UDP 7000."))
	multiplayer.server_disconnected.connect(func(): network_status_changed.emit("Se perdió la conexión con el servidor"))

func host_game() -> Error:
	leave_game()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_CLIENTS)
	if error != OK:
		network_status_changed.emit("No se pudo crear la sesión: " + error_string(error))
		return error
	multiplayer.multiplayer_peer = peer
	network_status_changed.emit("Sesión creada. Puerto UDP " + str(PORT))
	peer_joined.emit(1)
	return OK

func join_game(address: String) -> Error:
	if address.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	leave_game()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(), PORT)
	if error != OK:
		network_status_changed.emit("No se pudo iniciar la conexión: " + error_string(error))
		return error
	multiplayer.multiplayer_peer = peer
	network_status_changed.emit("Conectando con " + address.strip_edges() + "...")
	return OK

func leave_game() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	remote_states.clear()

func publish_player_state(position: Vector3, rotation_y: float) -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	if multiplayer.is_server():
		_receive_player_state.rpc(1, position, rotation_y)
	else:
		_submit_player_state.rpc_id(1, position, rotation_y)

@rpc("any_peer", "call_remote", "unreliable")
func _submit_player_state(position: Vector3, rotation_y: float) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	_receive_player_state(sender, position, rotation_y)
	_receive_player_state.rpc(sender, position, rotation_y)

@rpc("authority", "call_remote", "unreliable")
func _receive_player_state(peer_id: int, position: Vector3, rotation_y: float) -> void:
	remote_states[peer_id] = {"position": position, "rotation_y": rotation_y}
	remote_state_received.emit(peer_id, position, rotation_y)

@rpc("any_peer", "call_remote", "reliable")
func _submit_dispatch(message: String, location: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var safe_message := message.left(180)
	_dispatch_broadcast(safe_message, location)
	_dispatch_broadcast.rpc(safe_message, location)

@rpc("authority", "call_remote", "reliable")
func _dispatch_broadcast(message: String, location: Vector3) -> void:
	dispatch_received.emit(message, location)

func broadcast_dispatch(message: String, location: Vector3) -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		dispatch_received.emit(message, location)
	elif multiplayer.is_server():
		_dispatch_broadcast.rpc(message.left(180), location)
		dispatch_received.emit(message.left(180), location)
	else:
		_submit_dispatch.rpc_id(1, message.left(180), location)

func _on_peer_connected(peer_id: int) -> void:
	peer_joined.emit(peer_id)
	network_status_changed.emit("Unidad conectada: " + str(peer_id))

func _on_peer_disconnected(peer_id: int) -> void:
	remote_states.erase(peer_id)
	peer_left.emit(peer_id)
	network_status_changed.emit("Unidad desconectada: " + str(peer_id))
