extends CanvasLayer
## Lightweight 911 dispatch and mission loop for Fire Department Simulator.

signal call_accepted(location: Vector3, description: String)
signal mission_completed(reward: int, description: String)
signal mission_failed(description: String)

var _panel: PanelContainer
var _call_label: Label
var _radio_log: RichTextLabel
var _accept_button: Button
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
	{"type": "Incendio en vivienda", "code": "FIRE-1", "unit": "MOTOR 1", "reward": 250, "priority": "PRIORIDAD ALTA", "fire": true},
	{"type": "Incendio de vehículo", "code": "FIRE-2", "unit": "MOTOR 1 / RESCATE", "reward": 200, "priority": "PRIORIDAD ALTA", "fire": true},
	{"type": "Incendio en comercio", "code": "FIRE-3", "unit": "MOTOR 1 / ESCALERA", "reward": 300, "priority": "PRIORIDAD CRÍTICA", "fire": true},
	{"type": "Rescate por accidente de tránsito", "code": "RESCUE-1", "unit": "MOTOR 1 / RESCATE", "reward": 180, "priority": "PRIORIDAD ALTA", "fire": false},
	{"type": "Persona atrapada y humo reportado", "code": "RESCUE-2", "unit": "MOTOR 1", "reward": 220, "priority": "PRIORIDAD CRÍTICA", "fire": false},
	{"type": "Alarma de humo en edificio público", "code": "ALARM-1", "unit": "MOTOR 1", "reward": 120, "priority": "PRIORIDAD MEDIA", "fire": false},
	{"type": "Incendio en almacén industrial", "code": "FIRE-4", "unit": "MOTOR 1 / ESCALERA", "reward": 350, "priority": "PRIORIDAD CRÍTICA", "fire": true},
	{"type": "Incendio eléctrico en local", "code": "FIRE-5", "unit": "MOTOR 1", "reward": 280, "priority": "PRIORIDAD ALTA", "fire": true},
	{"type": "Incendio de vegetación", "code": "FIRE-6", "unit": "MOTOR 1 / AGUA", "reward": 190, "priority": "PRIORIDAD MEDIA", "fire": true},
	{"type": "Rescate de animal en vivienda", "code": "RESCUE-3", "unit": "MOTOR 1 / RESCATE", "reward": 160, "priority": "PRIORIDAD MEDIA", "fire": false},
	{"type": "Falsa alarma de humo", "code": "ALARM-2", "unit": "MOTOR 1", "reward": 80, "priority": "PRIORIDAD BAJA", "fire": false},
	{"type": "Rescate en edificio público", "code": "RESCUE-4", "unit": "MOTOR 1 / RESCATE", "reward": 240, "priority": "PRIORIDAD ALTA", "fire": false}
]
var _locations := [
	# Targets sit in the blocks beside the road grid, not directly on the center lines.
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
	_log("RADIO", "Canal de bomberos abierto. En espera de emergencias.")
	_roll_call()

func _process(delta: float) -> void:
	if _mission_active:
		_mission_time_left -= delta
		_update_mission_display()
		if _mission_time_left <= 0.0:
			var failed_description := _active_description
			_mission_active = false
			_active_description = ""
			_log("CENTRAL", "Tiempo agotado: " + failed_description + ". Unidad disponible.")
			_call_label.text = "SERVICIO DISPONIBLE\nLa llamada anterior venció. Espera el siguiente aviso."
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
	_panel.anchor_left = 0.02
	_panel.anchor_top = 0.12
	_panel.anchor_right = 0.34
	_panel.anchor_bottom = 0.12
	_panel.offset_bottom = 218
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_panel.add_child(column)
	var title := Label.new()
	title.text = "911 · CENTRAL DE BOMBEROS"
	title.add_theme_color_override("font_color", Color(0.55, 0.78, 1.0))
	column.add_child(title)
	_call_label = Label.new()
	_call_label.text = "Central: unidades disponibles, permanezcan atentas."
	_call_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_call_label.add_theme_font_size_override("font_size", 13)
	column.add_child(_call_label)
	_accept_button = Button.new()
	_accept_button.text = "ACEPTAR LLAMADA"
	_accept_button.pressed.connect(_accept_call)
	_accept_button.disabled = true
	column.add_child(_accept_button)
	var score_label := Label.new()
	score_label.text = "SERVICIOS: 0 · CRÉDITOS: 0"
	score_label.name = "ScoreLabel"
	column.add_child(score_label)
	_radio_log = RichTextLabel.new()
	_radio_log.custom_minimum_size = Vector2(180, 42)
	_radio_log.fit_content = false
	_radio_log.scroll_following = true
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
	_call_label.text = "911: %s\n%s · Código %s\nUnidades: %s\nZona: %s\nRecompensa: %d créditos\nLlega al punto asignado." % [
		_active_description, str(call["priority"]), _active_code, _active_unit, str(location_data["name"]), _active_reward
	]
	_accept_button.disabled = false
	_log("CENTRAL", "Nueva llamada: " + _active_description + " · " + str(location_data["name"]))

func _accept_call() -> void:
	if _active_description.is_empty() or _mission_active:
		return
	var description := _active_description
	var location := _active_location
	_mission_active = true
	_mission_time_left = 180.0
	_accept_button.disabled = true
	_call_label.text = "UNIDAD DESPACHADA\n%s\nObjetivo: llegar al lugar en 03:00.\nRecompensa base: %d créditos." % [description, _active_reward]
	_log("UNIDAD", "Despacho aceptado: " + description)
	call_accepted.emit(location, description)
	if has_node("/root/MultiplayerLobby"):
		MultiplayerLobby.broadcast_dispatch("Unidad asignada: " + description, location)

func _update_mission_display() -> void:
	if not is_instance_valid(_call_label):
		return
	var total_seconds := maxi(0, int(ceil(_mission_time_left)))
	var minutes := int(total_seconds / 60)
	var seconds := total_seconds % 60
	_call_label.text = "LLAMADA ACTIVA · %s\nCódigo %s · Unidad %s\nTiempo restante: %02d:%02d\nObjetivo: llega al punto y completa la intervención." % [
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
	_call_label.text = "INCIDENTE RESUELTO\n%s\n+%d créditos (incluye bono de respuesta).\nServicios completados: %d" % [description, total_reward, _completed_count]
	_log("CENTRAL", "Servicio completado: " + description + " · +" + str(total_reward) + " créditos")
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
		_radio_log.append_text("[b]%s:[/b] %s\n" % [source, message])
