extends CanvasLayer
## Lightweight fictional 911 fire and rescue dispatch simulation.

signal call_accepted(location: Vector3, description: String)

var _panel: PanelContainer
var _call_label: Label
var _radio_log: RichTextLabel
var _accept_button: Button
var _timer := 0.0
var _next_call_in := 12.0
var _active_location := Vector3.ZERO
var _active_description := ""
var _rng := RandomNumberGenerator.new()
var _calls := [
	{"type": "Incendio en vivienda", "code": "FIRE-1", "unit": "MOTOR 1"},
	{"type": "Incendio de vehículo", "code": "FIRE-2", "unit": "MOTOR 1 / RESCATE"},
	{"type": "Incendio en comercio", "code": "FIRE-3", "unit": "MOTOR 1 / ESCALERA"},
	{"type": "Rescate por accidente de tránsito", "code": "RESCUE-1", "unit": "MOTOR 1 / RESCATE"},
	{"type": "Persona atrapada y humo reportado", "code": "RESCUE-2", "unit": "MOTOR 1"}
]

func _ready() -> void:
	_rng.randomize()
	_build_panel()
	if has_node("/root/MultiplayerLobby"):
		MultiplayerLobby.dispatch_received.connect(_on_dispatch_received)
		_log("RADIO", "Canal de bomberos abierto. En espera de emergencias.")
		_roll_call()

func _process(delta: float) -> void:
	if _active_description.is_empty():
		_timer += delta
		if _timer >= _next_call_in:
			_timer = 0.0
			_roll_call()

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.02
	_panel.anchor_top = 0.12
	_panel.anchor_right = 0.44
	_panel.anchor_bottom = 0.12
	_panel.offset_bottom = 210
	add_child(_panel)
	var column := VBoxContainer.new()
	_panel.add_child(column)
	var title := Label.new()
	title.text = "911 · CENTRAL DE BOMBEROS"
	title.add_theme_color_override("font_color", Color(0.55, 0.78, 1.0))
	column.add_child(title)
	_call_label = Label.new()
	_call_label.text = "Central: unidades disponibles, permanezcan atentas."
	_call_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_call_label)
	_accept_button = Button.new()
	_accept_button.text = "ACEPTAR LLAMADA"
	_accept_button.pressed.connect(_accept_call)
	_accept_button.disabled = true
	column.add_child(_accept_button)
	_radio_log = RichTextLabel.new()
	_radio_log.custom_minimum_size = Vector2(250, 75)
	_radio_log.fit_content = false
	_radio_log.scroll_following = true
	column.add_child(_radio_log)

func _roll_call() -> void:
	var call: Dictionary = _calls[_rng.randi_range(0, _calls.size() - 1)]
	_active_description = str(call["type"])
	_active_location = Vector3(_rng.randf_range(-190, 190), 0.0, _rng.randf_range(-190, 190))
	_call_label.text = "911: %s\nCódigo %s · Unidades: %s\nUbicación: %.0f, %.0f" % [_active_description, call["code"], call["unit"], _active_location.x, _active_location.z]
	_accept_button.disabled = false
	_log("CENTRAL", "Nueva llamada 911: " + _active_description)

func _accept_call() -> void:
	if _active_description.is_empty():
		return
	var description := _active_description
	var location := _active_location
	_active_description = ""
	_accept_button.disabled = true
	_call_label.text = "Unidad asignada. Conduce al lugar y prepara la intervención."
	_log("UNIDAD", "Llamada aceptada: " + description)
	call_accepted.emit(location, description)
	if has_node("/root/MultiplayerLobby"):
		MultiplayerLobby.broadcast_dispatch("Unidad asignada: " + description, location)
	_timer = 0.0
	_next_call_in = _rng.randf_range(25.0, 42.0)

func _on_dispatch_received(message: String, _location: Vector3) -> void:
	_log("RADIO", message)

func _log(source: String, message: String) -> void:
	if is_instance_valid(_radio_log):
		_radio_log.append_text("[b]%s:[/b] %s\n" % [source, message])
