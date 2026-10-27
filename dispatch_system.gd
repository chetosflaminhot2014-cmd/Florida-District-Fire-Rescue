extends CanvasLayer
## Radio de despacho para F.D.F.R. — interfaz de radio operativa y opciones de respuesta.

signal call_accepted(location: Vector3, description: String)
signal mission_completed(reward: int, description: String)
signal mission_failed(description: String)

var _panel: PanelContainer
var _call_label: RichTextLabel
var _radio_log: RichTextLabel
var _radio_status: Label
var _accept_button: Button
var _details_button: Button
var _unavailable_button: Button
var _backup_button: Button
var _en_route_button: Button
var _timer := 0.0
var _next_call_in := 12.0
var _active_location := Vector3.ZERO
var _active_location_name := ""
var _active_description := ""
var _active_code := ""
var _active_unit := ""
var _active_priority := "MEDIA"
var _active_reward := 100
var _mission_active := false
var _mission_time_left := 180.0
var _rng := RandomNumberGenerator.new()
var _score := 0
var _completed_count := 0
var _radio_tx_count := 0

const C_BG := Color(0.025, 0.039, 0.050, 0.97)
const C_PANEL := Color(0.055, 0.078, 0.090, 1.0)
const C_EDGE := Color(0.20, 0.31, 0.34, 1.0)
const C_TEXT := Color(0.88, 0.93, 0.92, 1.0)
const C_MUTED := Color(0.55, 0.67, 0.69, 1.0)
const C_TEAL := Color(0.30, 0.83, 0.75, 1.0)
const C_AMBER := Color(1.0, 0.70, 0.25, 1.0)
const C_RED := Color(0.95, 0.30, 0.25, 1.0)

var _calls := [
	{"type": "Incendio en vivienda", "code": "FIRE-1", "unit": "MOTOR 1", "reward": 250, "priority": "ALTA", "fire": true},
	{"type": "Incendio de vehículo", "code": "FIRE-2", "unit": "MOTOR 1 / RESCATE", "reward": 200, "priority": "ALTA", "fire": true},
	{"type": "Incendio en comercio", "code": "FIRE-3", "unit": "MOTOR 1 / ESCALERA", "reward": 300, "priority": "CRÍTICA", "fire": true},
	{"type": "Rescate por accidente de tránsito", "code": "RESCUE-1", "unit": "MOTOR 1 / RESCATE", "reward": 180, "priority": "ALTA", "fire": false},
	{"type": "Persona atrapada y humo reportado", "code": "RESCUE-2", "unit": "MOTOR 1", "reward": 220, "priority": "CRÍTICA", "fire": false},
	{"type": "Alarma de humo en edificio público", "code": "ALARM-1", "unit": "MOTOR 1", "reward": 120, "priority": "MEDIA", "fire": false},
	{"type": "Incendio en almacén industrial", "code": "FIRE-4", "unit": "MOTOR 1 / ESCALERA", "reward": 350, "priority": "CRÍTICA", "fire": true},
	{"type": "Incendio eléctrico en local", "code": "FIRE-5", "unit": "MOTOR 1", "reward": 280, "priority": "ALTA", "fire": true},
	{"type": "Incendio de vegetación", "code": "FIRE-6", "unit": "MOTOR 1 / AGUA", "reward": 190, "priority": "MEDIA", "fire": true},
	{"type": "Rescate de animal en vivienda", "code": "RESCUE-3", "unit": "MOTOR 1 / RESCATE", "reward": 160, "priority": "MEDIA", "fire": false},
	{"type": "Falsa alarma de humo", "code": "ALARM-2", "unit": "MOTOR 1", "reward": 80, "priority": "BAJA", "fire": false},
	{"type": "Rescate en edificio público", "code": "RESCUE-4", "unit": "MOTOR 1 / RESCATE", "reward": 240, "priority": "ALTA", "fire": false}
]
var _locations := [
	{"name": "Downtown", "position": Vector3(-30, 0, -30)},
	{"name": "North Residential", "position": Vector3(15, 0, -150)},
	{"name": "East Industrial", "position": Vector3(135, 0, 15)},
	{"name": "Civic District", "position": Vector3(-150, 0, 75)},
	{"name": "South Gardens", "position": Vector3(15, 0, 135)},
	{"name": "Mirage Fuel East", "position": Vector3(138, 0, 150)},
	{"name": "Central Avenue", "position": Vector3(15, 0, 45)}
]

func _ready() -> void:
	_rng.randomize()
	_build_panel()
	if has_node("/root/MultiplayerLobby"):
		MultiplayerLobby.dispatch_received.connect(_on_dispatch_received)
	_log("CENTRAL", "Canal 03 abierto. Motor 1, compruebe radio.")
	_roll_call()

func _process(delta: float) -> void:
	if _mission_active:
		_mission_time_left -= delta
		_update_mission_display()
		if _mission_time_left <= 0.0:
			var failed_description := _active_description
			_mission_active = false
			_active_description = ""
			_radio_status.text = "UNIDAD DISPONIBLE · LLAMADA VENCIDA"
			_set_response_buttons(false)
			_log("CENTRAL", "Tiempo agotado. " + failed_description + ". Unidad disponible.")
			_call_label.text = "[b]SERVICIO DISPONIBLE[/b]\nLa llamada venció. Espera el siguiente aviso."
			mission_failed.emit(failed_description)
			_timer = 0.0
			_next_call_in = 8.0
	elif _active_description.is_empty():
		_timer += delta
		if _timer >= _next_call_in:
			_timer = 0.0
			_roll_call()

func _build_panel() -> void:
	var mobile := OS.has_feature("mobile")
	_panel = PanelContainer.new()
	_panel.name = "RadioDispatchPanel"
	if mobile:
		_panel.anchor_left = 0.35
		_panel.anchor_top = 0.075
		_panel.anchor_right = 0.985
		_panel.anchor_bottom = 0.075
		_panel.offset_bottom = 360
	else:
		_panel.anchor_left = 0.025
		_panel.anchor_top = 0.105
		_panel.anchor_right = 0.345
		_panel.anchor_bottom = 0.105
		_panel.offset_bottom = 410
	var outer := StyleBoxFlat.new()
	outer.bg_color = C_BG
	outer.border_color = C_EDGE
	outer.set_border_width_all(2)
	outer.set_corner_radius_all(8)
	outer.content_margin_left = 9
	outer.content_margin_right = 9
	outer.content_margin_top = 8
	outer.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", outer)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	_panel.add_child(column)

	# Radio hardware-style header.
	var header_plate := PanelContainer.new()
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(0.075, 0.11, 0.12, 1.0)
	header_style.border_color = Color(0.16, 0.27, 0.28, 1.0)
	header_style.set_border_width_all(1)
	header_style.set_corner_radius_all(5)
	header_style.content_margin_left = 7
	header_style.content_margin_right = 7
	header_style.content_margin_top = 5
	header_style.content_margin_bottom = 5
	header_plate.add_theme_stylebox_override("panel", header_style)
	column.add_child(header_plate)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	header_plate.add_child(header)
	var led := Label.new()
	led.text = "●"
	led.add_theme_color_override("font_color", C_TEAL)
	led.add_theme_font_size_override("font_size", 14)
	header.add_child(led)
	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 0)
	header.add_child(title_col)
	var title := Label.new()
	title.text = "F.D.F.R.  /  DISPATCH RADIO"
	title.add_theme_color_override("font_color", C_TEXT)
	title.add_theme_font_size_override("font_size", 12 if mobile else 14)
	title_col.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "PUBLIC SAFETY · DIGITAL TRUNKED"
	subtitle.add_theme_color_override("font_color", C_MUTED)
	subtitle.add_theme_font_size_override("font_size", 8 if mobile else 9)
	title_col.add_child(subtitle)
	var channel := Label.new()
	channel.text = "CH 03\nFIRE"
	channel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	channel.add_theme_color_override("font_color", C_TEAL)
	channel.add_theme_font_size_override("font_size", 10)
	header.add_child(channel)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 5)
	column.add_child(status_row)
	_radio_status = Label.new()
	_radio_status.text = "STANDBY · MOTOR 1"
	_radio_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_radio_status.add_theme_color_override("font_color", C_AMBER)
	_radio_status.add_theme_font_size_override("font_size", 10 if mobile else 11)
	status_row.add_child(_radio_status)
	var signal_label := Label.new()
	signal_label.text = "▂▄▆█  4/4"
	signal_label.add_theme_color_override("font_color", C_TEAL)
	signal_label.add_theme_font_size_override("font_size", 10)
	status_row.add_child(signal_label)

	var separator := HSeparator.new()
	column.add_child(separator)
	var incoming := Label.new()
	incoming.text = "INCOMING CALL  /  911"
	incoming.add_theme_color_override("font_color", C_AMBER)
	incoming.add_theme_font_size_override("font_size", 10 if mobile else 11)
	column.add_child(incoming)

	_call_label = RichTextLabel.new()
	_call_label.bbcode_enabled = true
	_call_label.fit_content = true
	_call_label.scroll_active = false
	_call_label.custom_minimum_size.y = 83 if mobile else 95
	_call_label.add_theme_color_override("default_color", C_TEXT)
	_call_label.add_theme_font_size_override("normal_font_size", 11 if mobile else 13)
	column.add_child(_call_label)

	var response_title := Label.new()
	response_title.text = "RESPUESTA DE UNIDAD"
	response_title.add_theme_color_override("font_color", C_MUTED)
	response_title.add_theme_font_size_override("font_size", 9)
	column.add_child(response_title)

	var row_one := HBoxContainer.new()
	row_one.add_theme_constant_override("separation", 5)
	column.add_child(row_one)
	_accept_button = _make_button("ACEPTAR LLAMADA", C_TEAL, true)
	_accept_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_accept_button.pressed.connect(_accept_call)
	row_one.add_child(_accept_button)
	_details_button = _make_button("SOLICITAR DATOS", Color(0.25, 0.43, 0.50), false)
	_details_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_button.pressed.connect(_request_details)
	row_one.add_child(_details_button)

	var row_two := HBoxContainer.new()
	row_two.add_theme_constant_override("separation", 5)
	column.add_child(row_two)
	_backup_button = _make_button("PEDIR APOYO", C_AMBER, false)
	_backup_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_backup_button.pressed.connect(_request_backup)
	row_two.add_child(_backup_button)
	_unavailable_button = _make_button("NO DISPONIBLE", C_RED, false)
	_unavailable_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_unavailable_button.pressed.connect(_decline_call)
	row_two.add_child(_unavailable_button)

	_en_route_button = _make_button("EN RUTA  ▶", C_TEAL, true)
	_en_route_button.custom_minimum_size.y = 30 if mobile else 34
	_en_route_button.pressed.connect(_confirm_en_route)
	column.add_child(_en_route_button)

	var score_label := Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = "SERVICIOS  0     ·     CRÉDITOS  0"
	score_label.add_theme_color_override("font_color", C_MUTED)
	score_label.add_theme_font_size_override("font_size", 10)
	column.add_child(score_label)

	var log_title := Label.new()
	log_title.text = "RADIO TRAFFIC  /  ÚLTIMAS TRANSMISIONES"
	log_title.add_theme_color_override("font_color", C_MUTED)
	log_title.add_theme_font_size_override("font_size", 8 if mobile else 9)
	column.add_child(log_title)
	_radio_log = RichTextLabel.new()
	_radio_log.custom_minimum_size = Vector2(100, 48) if mobile else Vector2(150, 62)
	_radio_log.fit_content = false
	_radio_log.scroll_following = true
	_radio_log.add_theme_color_override("default_color", C_TEXT)
	_radio_log.add_theme_font_size_override("normal_font_size", 9 if mobile else 10)
	column.add_child(_radio_log)
	_set_response_buttons(false)

func _make_button(caption: String, accent: Color, filled: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 28 if OS.has_feature("mobile") else 32
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 9 if OS.has_feature("mobile") else 10)
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent.darkened(0.72) if filled else Color(0.055, 0.082, 0.094, 1.0)
	normal.border_color = accent
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 5
	normal.content_margin_right = 5
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = accent.darkened(0.48)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = accent.darkened(0.30)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_color_override("font_color", C_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", C_MUTED)
	return button

func _set_response_buttons(enabled: bool) -> void:
	if is_instance_valid(_accept_button):
		_accept_button.disabled = not enabled or _mission_active
	if is_instance_valid(_details_button):
		_details_button.disabled = not enabled
	if is_instance_valid(_unavailable_button):
		_unavailable_button.disabled = not enabled or _mission_active
	if is_instance_valid(_backup_button):
		_backup_button.disabled = not enabled
	if is_instance_valid(_en_route_button):
		_en_route_button.disabled = _active_description.is_empty()

func _roll_call() -> void:
	if _mission_active or not _active_description.is_empty():
		return
	var call: Dictionary = _calls[_rng.randi_range(0, _calls.size() - 1)]
	var location_data: Dictionary = _locations[_rng.randi_range(0, _locations.size() - 1)]
	_active_description = str(call["type"])
	_active_code = str(call["code"])
	_active_unit = str(call["unit"])
	_active_priority = str(call["priority"])
	_active_reward = int(call["reward"])
	_active_location = location_data["position"]
	_active_location_name = str(location_data["name"])
	_call_label.text = "[b]%s[/b]\n[color=#ffb640]PRIORIDAD %s[/color]   ·   %s\nUnidad sugerida: %s\nUbicación: %s\nRecompensa: %d créditos" % [
		_active_description, _active_priority, _active_code, _active_unit, _active_location_name, _active_reward
	]
	_set_response_buttons(true)
	_radio_status.text = "● LLAMADA ENTRANTE · " + _active_priority
	_radio_status.add_theme_color_override("font_color", C_RED if _active_priority == "CRÍTICA" else C_AMBER)
	_log("CENTRAL 911", "Alerta recibida: " + _active_description + " · " + _active_location_name)

func _accept_call() -> void:
	if _active_description.is_empty() or _mission_active:
		return
	_mission_active = true
	_mission_time_left = 180.0
	_radio_status.text = "CALL ACCEPTED · MOTOR 1"
	_radio_status.add_theme_color_override("font_color", C_TEAL)
	_call_label.text = "[b]DESPACHO ACEPTADO[/b]\n%s\nZona: %s\nTiempo de respuesta: 03:00\nConfirma EN RUTA cuando salgas." % [_active_description, _active_location_name]
	_accept_button.disabled = true
	_unavailable_button.disabled = true
	_details_button.disabled = false
	_backup_button.disabled = false
	_en_route_button.disabled = false
	_log("MOTOR 1", "Central, despacho aceptado. Preparando salida.")
	call_accepted.emit(_active_location, _active_description)
	if has_node("/root/MultiplayerLobby"):
		MultiplayerLobby.broadcast_dispatch("Unidad asignada: " + _active_description, _active_location)

func _request_details() -> void:
	if _active_description.is_empty():
		return
	_radio_tx_count += 1
	_log("MOTOR 1 → CENTRAL", "Solicitamos datos adicionales del incidente.")
	_log("CENTRAL 911", "Confirmado: " + _active_description + " en " + _active_location_name + ". Prioridad " + _active_priority + ". Unidad sugerida: " + _active_unit + ".")
	_radio_status.text = "RX MESSAGE · DETAILS RECEIVED"
	_radio_status.add_theme_color_override("font_color", C_TEAL)
	_call_label.text = "[b]%s[/b]\nPrioridad: %s  ·  Código: %s\nUbicación confirmada: %s\nUnidad sugerida: %s\nCentral confirmó los datos solicitados." % [_active_description, _active_priority, _active_code, _active_location_name, _active_unit]

func _request_backup() -> void:
	if _active_description.is_empty():
		return
	_radio_tx_count += 1
	_log("MOTOR 1 → CENTRAL", "Solicitamos unidad de apoyo para " + _active_description + ".")
	_log("CENTRAL 911", "Solicitud de apoyo registrada. Unidades adicionales sujetas a disponibilidad.")
	_radio_status.text = "BACKUP REQUESTED · CH 03"
	_radio_status.add_theme_color_override("font_color", C_AMBER)
	if has_node("/root/MultiplayerLobby"):
		MultiplayerLobby.broadcast_dispatch("APOYO SOLICITADO: " + _active_description, _active_location)

func _decline_call() -> void:
	if _active_description.is_empty() or _mission_active:
		return
	var declined := _active_description
	_log("MOTOR 1 → CENTRAL", "Unidad no disponible. No aceptamos el despacho.")
	_log("CENTRAL 911", "Recibido. Se buscará otra unidad.")
	_active_description = ""
	_active_location_name = ""
	_radio_status.text = "UNIT UNAVAILABLE · STANDBY"
	_radio_status.add_theme_color_override("font_color", C_MUTED)
	_call_label.text = "[b]UNIDAD NO DISPONIBLE[/b]\nCentral buscará otra unidad. Permanece atento al siguiente aviso."
	_set_response_buttons(false)
	_timer = 0.0
	_next_call_in = _rng.randf_range(7.0, 12.0)
	if has_node("/root/MultiplayerLobby"):
		MultiplayerLobby.broadcast_dispatch("Unidad no disponible para: " + declined, Vector3.ZERO)

func _confirm_en_route() -> void:
	if _active_description.is_empty():
		return
	if not _mission_active:
		_accept_call()
		if not _mission_active:
			return
	_radio_status.text = "TRANSMITTING · EN ROUTE"
	_radio_status.add_theme_color_override("font_color", C_TEAL)
	_log("MOTOR 1 → CENTRAL", "Copiado. Motor 1 en ruta a " + _active_location_name + ".")
	_log("CENTRAL 911", "Recibido Motor 1. Mantenga canal 03 disponible.")
	_call_label.text = "[b]UNIDAD EN RUTA[/b]\n%s\nDestino: %s\nCódigo: %s\nTiempo restante: 03:00\nSiga el marcador de incidente." % [_active_description, _active_location_name, _active_code]
	_en_route_button.disabled = true
	if has_node("/root/MultiplayerLobby"):
		MultiplayerLobby.broadcast_dispatch("Motor 1 EN RUTA: " + _active_description, _active_location)

func _transmit_status() -> void:
	# Compatibility with older callers; all player-facing replies now have dedicated buttons.
	if _active_description.is_empty():
		_log("MOTOR 1 → CENTRAL", "Unidad en espera de asignación.")
	elif _mission_active:
		_confirm_en_route()
	else:
		_request_details()

func mark_arrived() -> void:
	if not _mission_active:
		return
	_radio_status.text = "ON SCENE · MOTOR 1"
	_radio_status.add_theme_color_override("font_color", C_TEAL)
	_log("MOTOR 1 → CENTRAL", "Llegamos a la escena. Iniciando evaluación.")

func _update_mission_display() -> void:
	if not is_instance_valid(_call_label):
		return
	var total_seconds := maxi(0, int(ceil(_mission_time_left)))
	var minutes := int(total_seconds / 60)
	var seconds := total_seconds % 60
	_call_label.text = "[b]LLAMADA ACTIVA[/b]\n%s\nCódigo: %s  ·  %s\nTiempo restante: %02d:%02d\nAcércate al punto y completa la intervención." % [
		_active_description, _active_code, _active_unit, minutes, seconds
	]

func complete_arrival_mission() -> void:
	if not _mission_active:
		return
	if _active_description.to_lower().contains("incendio"):
		return
	_finish_mission(_active_description, _active_reward)

func complete_fire_mission() -> void:
	if not _mission_active:
		return
	_finish_mission(_active_description, _active_reward)

func _finish_mission(description: String, reward: int) -> void:
	_mission_active = false
	_completed_count += 1
	var time_bonus := int(maxf(0.0, _mission_time_left / 180.0) * 50.0)
	var total_reward := reward + time_bonus
	_score += total_reward
	_radio_status.text = "SERVICE CLOSED · UNIT AVAILABLE"
	_radio_status.add_theme_color_override("font_color", C_TEAL)
	_log("MOTOR 1 → CENTRAL", "Incidente controlado. Unidad disponible, regresando a servicio.")
	_call_label.text = "[b]INCIDENTE RESUELTO[/b]\n%s\n+%d créditos (bono incluido).\nServicios completados: %d" % [description, total_reward, _completed_count]
	_log("CENTRAL 911", "Servicio cerrado: " + description + " · +" + str(total_reward) + " créditos")
	var score_label := _panel.find_child("ScoreLabel", true, false) as Label
	if is_instance_valid(score_label):
		score_label.text = "SERVICIOS  %d     ·     CRÉDITOS  %d" % [_completed_count, _score]
	_active_description = ""
	_active_location_name = ""
	_set_response_buttons(false)
	mission_completed.emit(total_reward, description)
	_timer = 0.0
	_next_call_in = _rng.randf_range(10.0, 18.0)

func _on_dispatch_received(message: String, _location: Vector3) -> void:
	_log("MULTI / CENTRAL", message)

func _log(source: String, message: String) -> void:
	if is_instance_valid(_radio_log):
		var stamp := Time.get_time_string_from_system()
		_radio_log.append_text("[color=#70c7c9]%s[/color] [b]%s:[/b] %s\n" % [stamp, source, message])
