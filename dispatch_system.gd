extends CanvasLayer
## Despacho 911 con panel compacto de radio para F.D.F.R.

signal call_accepted(location: Vector3, description: String)
signal mission_completed(reward: int, description: String)
signal mission_failed(description: String)

var _panel: PanelContainer
var _call_label: Label
var _radio_log: RichTextLabel
var _radio_status: Label
var _accept_button: Button
var _radio_button: Button
var _timer := 0.0
var _next_call_in := 12.0
var _active_location := Vector3.ZERO
var _active_description := ""
var _active_code := ""
var _active_unit := ""
var _active_reward := 100
var _mission_active := false
var _mission_time_left := 180.0
var _rng := RandomNumberGenerator.new()
var _score := 0
var _completed_count := 0
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
	_log("RADIO", "Canal 03 abierto. Motor 1, permanezca atento.")
	_roll_call()

func _process(delta: float) -> void:
	if _mission_active:
		_mission_time_left -= delta
		_update_mission_display()
		if _mission_time_left <= 0.0:
			var failed_description := _active_description
			_mission_active = false
			_active_description = ""
			_radio_status.text = "TIEMPO AGOTADO · UNIDAD DISPONIBLE"
			_radio_button.disabled = true
			_log("CENTRAL", "Tiempo agotado. " + failed_description + ". Unidad disponible.")
			_call_label.text = "SERVICIO DISPONIBLE\nLa llamada venció. Espera el siguiente aviso."
			mission_failed.emit(failed_description)
			_timer = 0.0
			_next_call_in = 8.0
	elif _active_description.is_empty():
		_timer += delta
		if _timer >= _next_call_in:
			_timer = 0.0
			_roll_call()

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "RadioDispatchPanel"
	if OS.has_feature("mobile"):
		_panel.anchor_left = 0.42
		_panel.anchor_top = 0.09
		_panel.anchor_right = 0.985
		_panel.anchor_bottom = 0.09
		_panel.offset_bottom = 230
	else:
		_panel.anchor_left = 0.02
		_panel.anchor_top = 0.12
		_panel.anchor_right = 0.35
		_panel.anchor_bottom = 0.12
		_panel.offset_bottom = 270
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.035, 0.047, 0.94)
	style.border_color = Color(0.16, 0.48, 0.57, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4 if OS.has_feature("mobile") else 6)
	_panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "●  CENTRAL 911"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(0.45, 0.91, 0.79))
	title.add_theme_font_size_override("font_size", 12 if OS.has_feature("mobile") else 15)
	header.add_child(title)
	var channel := Label.new()
	channel.text = "CH 03 · FIRE"
	channel.add_theme_color_override("font_color", Color(0.65, 0.78, 0.86))
	channel.add_theme_font_size_override("font_size", 10 if OS.has_feature("mobile") else 12)
	header.add_child(channel)

	_radio_status = Label.new()
	_radio_status.text = "RADIO EN ESPERA · MOTOR 1"
	_radio_status.add_theme_color_override("font_color", Color(0.96, 0.72, 0.28))
	_radio_status.add_theme_font_size_override("font_size", 10 if OS.has_feature("mobile") else 12)
	column.add_child(_radio_status)

	_call_label = Label.new()
	_call_label.text = "Central: unidades disponibles, permanezcan atentas."
	_call_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_call_label.add_theme_font_size_override("font_size", 12 if OS.has_feature("mobile") else 13)
	column.add_child(_call_label)

	_accept_button = Button.new()
	_accept_button.text = "ACEPTAR DESPACHO"
	_accept_button.custom_minimum_size.y = 34 if OS.has_feature("mobile") else 0
	_accept_button.pressed.connect(_accept_call)
	_accept_button.disabled = true
	column.add_child(_accept_button)

	_radio_button = Button.new()
	_radio_button.text = "TRANSMITIR POR RADIO"
	_radio_button.custom_minimum_size.y = 30 if OS.has_feature("mobile") else 0
	_radio_button.pressed.connect(_transmit_status)
	_radio_button.disabled = true
	column.add_child(_radio_button)

	var score_label := Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = "SERVICIOS: 0 · CRÉDITOS: 0"
	score_label.add_theme_font_size_override("font_size", 11 if OS.has_feature("mobile") else 13)
	column.add_child(score_label)

	_radio_log = RichTextLabel.new()
	_radio_log.custom_minimum_size = Vector2(140, 34) if OS.has_feature("mobile") else Vector2(180, 54)
	_radio_log.fit_content = false
	_radio_log.scroll_following = true
	_radio_log.add_theme_color_override("default_color", Color(0.75, 0.87, 0.87))
	_radio_log.add_theme_font_size_override("normal_font_size", 10 if OS.has_feature("mobile") else 12)
	column.add_child(_radio_log)

func _roll_call() -> void:
	if _mission_active:
		return
	var call: Dictionary = _calls[_rng.randi_range(0, _calls.size() - 1)]
	var location_data: Dictionary = _locations[_rng.randi_range(0, _locations.size() - 1)]
	_active_description = str(call["type"])
	_active_code = str(call["code"])
	_active_unit = str(call["unit"])
	_active_reward = int(call["reward"])
	_active_location = location_data["position"]
	_call_label.text = "911: %s\nPrioridad %s · %s\nUnidad sugerida: %s\nZona: %s\nRecompensa: %d créditos" % [
		_active_description, str(call["priority"]), _active_code, _active_unit, str(location_data["name"]), _active_reward
	]
	_accept_button.disabled = false
	_radio_button.disabled = false
	_radio_status.text = "LLAMADA ENTRANTE · PRIORIDAD " + str(call["priority"])
	_log("DESPACHO", "Tono de alerta. " + _active_description + " · " + str(location_data["name"]))

func _accept_call() -> void:
	if _active_description.is_empty() or _mission_active:
		return
	var description := _active_description
	var location := _active_location
	_mission_active = true
	_mission_time_left = 180.0
	_accept_button.disabled = true
	_radio_button.disabled = false
	_radio_status.text = "UNIDAD EN CAMINO · MOTOR 1"
	_call_label.text = "UNIDAD DESPACHADA\n%s\nTiempo de respuesta: 03:00\nRecompensa base: %d créditos." % [description, _active_reward]
	_log("CENTRAL", "Motor 1, despacho recibido. Confirme salida.")
	_log("MOTOR 1", "Recibido, en camino al incidente.")
	call_accepted.emit(location, description)
	if has_node("/root/MultiplayerLobby"):
		MultiplayerLobby.broadcast_dispatch("Unidad asignada: " + description, location)

func _transmit_status() -> void:
	if _active_description.is_empty():
		_log("MOTOR 1", "Central, unidad en espera de asignación.")
	elif _mission_active:
		_radio_status.text = "TX / RX · CANAL 03"
		_log("MOTOR 1", "Central, unidad en camino. Incidente: " + _active_description + ".")
		_radio_status.text = "CANAL 03 DISPONIBLE"
	else:
		_log("MOTOR 1", "Central, recibido el aviso. Solicitamos asignación.")

func mark_arrived() -> void:
	if not _mission_active:
		return
	_radio_status.text = "EN LA ESCENA · MOTOR 1"
	_log("MOTOR 1", "Central, llegamos a la escena. Iniciando evaluación.")

func _update_mission_display() -> void:
	if not is_instance_valid(_call_label):
		return
	var total_seconds := maxi(0, int(ceil(_mission_time_left)))
	var minutes := int(total_seconds / 60)
	var seconds := total_seconds % 60
	_call_label.text = "LLAMADA ACTIVA · %s\nCódigo %s · %s\nTiempo restante: %02d:%02d\nAcércate al punto y completa la intervención." % [
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
	_accept_button.disabled = true
	_radio_button.disabled = true
	_radio_status.text = "SERVICIO CERRADO · UNIDAD DISPONIBLE"
	_log("MOTOR 1", "Incidente controlado. Unidad disponible, regresando a servicio.")
	_call_label.text = "INCIDENTE RESUELTO\n%s\n+%d créditos (bono incluido).\nServicios completados: %d" % [description, total_reward, _completed_count]
	_log("CENTRAL", "Servicio cerrado: " + description + " · +" + str(total_reward) + " créditos")
	var score_label := _panel.find_child("ScoreLabel", true, false) as Label
	if is_instance_valid(score_label):
		score_label.text = "SERVICIOS: %d · CRÉDITOS: %d" % [_completed_count, _score]
	mission_completed.emit(total_reward, description)
	_active_description = ""
	_timer = 0.0
	_next_call_in = _rng.randf_range(10.0, 18.0)

func _on_dispatch_received(message: String, _location: Vector3) -> void:
	_log("RADIO", message)

func _log(source: String, message: String) -> void:
	if is_instance_valid(_radio_log):
		var stamp := Time.get_time_string_from_system()
		_radio_log.append_text("[color=#70c7c9]%s[/color] [b]%s:[/b] %s\n" % [stamp, source, message])
