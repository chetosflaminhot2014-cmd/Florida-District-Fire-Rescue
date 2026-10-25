extends Node3D

class MinimapControl extends Control:
	var player_world_position := Vector3.ZERO
	var target_world_position := Vector3.ZERO
	var target_active := false
	var world_limit := 220.0

	func _draw() -> void:
		var area := Rect2(Vector2.ZERO, size)
		draw_rect(area, Color(0.025, 0.055, 0.075, 0.94), true)
		draw_rect(area, Color(0.25, 0.68, 0.85, 0.95), false, 2.0)
		var pad := 12.0
		var map_size := size - Vector2(pad * 2.0, pad * 2.0)
		for i in range(1, 6):
			var x := pad + map_size.x * float(i) / 6.0
			var y := pad + map_size.y * float(i) / 6.0
			draw_line(Vector2(x, pad), Vector2(x, size.y - pad), Color(0.18, 0.28, 0.32, 0.8), 3.0)
			draw_line(Vector2(pad, y), Vector2(size.x - pad, y), Color(0.18, 0.28, 0.32, 0.8), 3.0)
		var player_point := _map_point(player_world_position, pad, map_size)
		if target_active:
			var target_point := _map_point(target_world_position, pad, map_size)
			draw_line(player_point, target_point, Color(1.0, 0.68, 0.12, 0.9), 2.0)
			draw_circle(target_point, 7.0, Color(1.0, 0.55, 0.08))
			draw_arc(target_point, 11.0, 0.0, TAU, 24, Color(1.0, 0.72, 0.2), 2.0)
		draw_circle(player_point, 6.0, Color(0.15, 0.8, 1.0))
		draw_arc(player_point, 10.0, 0.0, TAU, 24, Color(0.65, 0.92, 1.0), 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(9, 18), "MAPA", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.88, 0.96, 1.0))

	func _map_point(world_position: Vector3, pad: float, map_size: Vector2) -> Vector2:
		return Vector2(
			pad + clampf((world_position.x + world_limit) / (world_limit * 2.0), 0.0, 1.0) * map_size.x,
			pad + clampf((world_position.z + world_limit) / (world_limit * 2.0), 0.0, 1.0) * map_size.y
		)

# Fire Department Simulator — open-world emergency response prototype for Android and Windows.
# No external assets are required; missing officer models are replaced by generated characters.

const WORLD_LIMIT := 220.0
const WALK_SPEED := 5.0
const RUN_SPEED := 8.0
const PATROL_MAX_FORWARD_SPEED := 27.0 # m/s; about 97 km/h
const PATROL_MAX_REVERSE_SPEED := 7.0 # m/s; controlled reverse for parking
const PATROL_ACCELERATION := 6.5
const PATROL_BRAKING := 16.0
const PATROL_COAST_DECELERATION := 2.0
const PATROL_STEERING_CURVATURE := 0.055
const FLORIDA_BUILDING_SCENES := [
	"res://assets/florida_city/building-type-a.glb",
	"res://assets/florida_city/building-type-b.glb",
	"res://assets/florida_city/building-type-c.glb",
	"res://assets/florida_city/building-type-d.glb",
	"res://assets/florida_city/building-type-e.glb",
	"res://assets/florida_city/building-type-f.glb",
	"res://assets/florida_city/building-type-g.glb",
	"res://assets/florida_city/building-type-h.glb"
]
const FLORIDA_DOWNTOWN_SCENES := [
	"res://assets/florida_city/commercial/building-a.glb",
	"res://assets/florida_city/commercial/building-b.glb",
	"res://assets/florida_city/commercial/building-c.glb",
	"res://assets/florida_city/commercial/building-d.glb",
	"res://assets/florida_city/commercial/building-f.glb",
	"res://assets/florida_city/commercial/building-g.glb",
	"res://assets/florida_city/commercial/building-h.glb",
	"res://assets/florida_city/commercial/building-l.glb",
	"res://assets/florida_city/commercial/building-m.glb"
]
const FLORIDA_SKYSCRAPER_SCENES := [
	"res://assets/florida_city/commercial/building-skyscraper-a.glb",
	"res://assets/florida_city/commercial/building-skyscraper-b.glb",
	"res://assets/florida_city/commercial/building-skyscraper-c.glb",
	"res://assets/florida_city/commercial/building-skyscraper-d.glb",
	"res://assets/florida_city/commercial/building-skyscraper-e.glb"
]

var menu_layer: CanvasLayer
var menu_panel: VBoxContainer
var game_world: Node3D
var player: CharacterBody3D
var camera_pivot: Node3D
var camera: Camera3D
var vehicle: CharacterBody3D
var player_visual: Node3D
var player_animation_player: AnimationPlayer
var player_animation_names: Array[StringName] = []
var player_motion_state := ""
var hud_layer: CanvasLayer
var status_label: Label
var minimap: MinimapControl
var dispatch_target_position := Vector3.ZERO
var dispatch_target_active := false
var game_active := false
var driving := false
var invert_camera := false
var mouse_sensitivity := 0.002
var move_speed := WALK_SPEED
var vehicle_speed := 0.0
var vehicle_steering := 0.0
var light_timer := 0.0
var lights_red := true
var red_light: ColorRect
var blue_light: ColorRect
var patrol_red_light: MeshInstance3D
var patrol_blue_light: MeshInstance3D
var emergency_lights_enabled := true
var touch_move := Vector2.ZERO
var touch_run := false
var touch_brake := false
var look_touch_id := -1
var last_touch_position := Vector2.ZERO
var npc_nodes: Array[Node3D] = []
var npc_targets: Array[Vector3] = []
var rng := RandomNumberGenerator.new()
var remote_players: Dictionary = {}
var network_send_timer := 0.0
var dispatch_layer: CanvasLayer
var dispatch_marker: MeshInstance3D
var multiplayer_ip_input: LineEdit
var multiplayer_name_input: LineEdit
var shared_materials: Dictionary = {}
var player_anim_clock := 0.0
var fire_active := false
var fire_strength := 100.0
var fire_location := Vector3.ZERO
var extinguishing := false
var fire_visual: Node3D
var fire_glow: OmniLight3D
var fire_flames: Array[MeshInstance3D] = []
var fire_spread_patches: Array[MeshInstance3D] = []
var fire_elapsed := 0.0
var fire_spread_timer := 0.0
var fire_smoke: CPUParticles3D
var fire_particles: CPUParticles3D
var fire_embers: CPUParticles3D
var water_drops: Array[MeshInstance3D] = []
var gas_station_positions: Array[Vector3] = []
var fuel_level := 100.0
var refuel_notice_timer := 0.0

func _ready() -> void:
	rng.randomize()
	# Draw a safe startup screen first. If the full menu encounters a runtime
	# error, this overlay remains visible instead of leaving a blank grey screen.
	var startup_fallback := _create_startup_fallback()
	# Keep a valid active camera while the menu is shown on Android and desktop.
	var menu_camera := Camera3D.new()
	menu_camera.name = "MenuCamera"
	menu_camera.position = Vector3(0, 2, 10)
	add_child(menu_camera)
	menu_camera.current = true
	_create_menu()
	startup_fallback.queue_free()
	if has_node("/root/MultiplayerLobby"):
		MultiplayerLobby.peer_joined.connect(_on_peer_joined)
		MultiplayerLobby.peer_left.connect(_on_peer_left)
		MultiplayerLobby.remote_state_received.connect(_on_remote_state_received)
		MultiplayerLobby.network_status_changed.connect(_on_network_status_changed)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# CI-only gameplay smoke test: build the city, character, patrol car, and HUD headlessly.
	if OS.get_cmdline_user_args().has("--smoke-test"):
		_start_game(false)

func _create_startup_fallback() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "StartupFallback"
	layer.layer = 100
	add_child(layer)
	var background := ColorRect.new()
	background.name = "FallbackBackground"
	background.color = Color(0.018, 0.035, 0.065)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(280, 0)
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)
	var title := Label.new()
	title.text = "FIRE DEPARTMENT SIMULATOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	column.add_child(title)
	var message := Label.new()
	message.text = "Iniciando Fire Department Simulator..."
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_color_override("font_color", Color(0.55, 0.75, 0.92))
	column.add_child(message)
	var retry := Button.new()
	retry.text = "REINTENTAR"
	retry.custom_minimum_size = Vector2(0, 48)
	retry.pressed.connect(func(): get_tree().reload_current_scene())
	column.add_child(retry)
	return layer

func _process(delta: float) -> void:
	light_timer += delta
	if light_timer >= 0.28:
		light_timer = 0.0
		lights_red = not lights_red
		if is_instance_valid(red_light):
			red_light.color = Color(1.0, 0.02, 0.02) if lights_red else Color(0.22, 0.0, 0.0)
		if is_instance_valid(blue_light):
			blue_light.color = Color(0.02, 0.2, 1.0) if not lights_red else Color(0.0, 0.03, 0.22)
		if is_instance_valid(patrol_red_light):
			patrol_red_light.visible = emergency_lights_enabled and lights_red
		if is_instance_valid(patrol_blue_light):
			patrol_blue_light.visible = emergency_lights_enabled and not lights_red
	if not game_active:
		return
	_update_npcs(delta)
	_update_remote_network(delta)
	_update_fire_response(delta)
	_update_fire_visuals(delta)
	if is_instance_valid(minimap):
		var tracked_position := vehicle.global_position if driving and is_instance_valid(vehicle) else (player.global_position if is_instance_valid(player) else Vector3.ZERO)
		minimap.player_world_position = tracked_position
		minimap.target_world_position = dispatch_target_position
		minimap.target_active = dispatch_target_active
		minimap.queue_redraw()
	if is_instance_valid(status_label):
		if driving:
			var speed_kmh := roundi(absf(vehicle_speed) * 3.6)
			var gear := "R" if vehicle_speed < -0.2 else "D"
			status_label.text = "CAMIÓN · %d km/h · COMBUSTIBLE %d%% · LUCES %s" % [speed_kmh, roundi(fuel_level), "ON" if emergency_lights_enabled else "OFF"]
		else:
			status_label.text = "BOMBERO A PIE · WASD · E PARA SUBIR/BAJAR · NPC: " + str(npc_nodes.size())

func _create_menu() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.name = "MenuLayer"
	add_child(menu_layer)
	var background := ColorRect.new()
	background.color = Color(0.018, 0.035, 0.065)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(background)
	# Modern police-simulator landing screen: navigation on the left, operations panel on the right.
	var upper_glow := ColorRect.new()
	upper_glow.anchor_left = 0.42
	upper_glow.anchor_right = 1.0
	upper_glow.anchor_top = 0.0
	upper_glow.anchor_bottom = 1.0
	upper_glow.color = Color(0.025, 0.09, 0.16, 0.92)
	upper_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(upper_glow)
	var accent := ColorRect.new()
	accent.anchor_left = 0.435
	accent.anchor_right = 0.442
	accent.anchor_top = 0.0
	accent.anchor_bottom = 1.0
	accent.color = Color(0.12, 0.55, 0.9)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(accent)
	var right_panel := PanelContainer.new()
	right_panel.name = "OperationsPanel"
	right_panel.anchor_left = 0.49
	right_panel.anchor_right = 0.95
	right_panel.anchor_top = 0.15
	right_panel.anchor_bottom = 0.84
	right_panel.offset_left = 0
	right_panel.offset_right = 0
	right_panel.offset_top = 0
	right_panel.offset_bottom = 0
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.025, 0.055, 0.09, 0.9)
	card_style.border_color = Color(0.12, 0.3, 0.45)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(12)
	right_panel.add_theme_stylebox_override("panel", card_style)
	menu_layer.add_child(right_panel)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 16)
	right_panel.add_child(info)
	var status := Label.new()
	status.text = "MIRAGE HILLS  /  FIRE & RESCUE"
	status.add_theme_font_size_override("font_size", 13)
	status.add_theme_color_override("font_color", Color(0.35, 0.72, 1.0))
	info.add_child(status)
	var scene_title := Label.new()
	scene_title.text = "YOUR CITY.\nYOUR CALL."
	scene_title.add_theme_font_size_override("font_size", 34)
	scene_title.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	info.add_child(scene_title)
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.13, 0.49, 0.78)
	info.add_child(divider)
	var description := Label.new()
	description.text = "Answer emergency calls, drive the engine,\nand protect every district."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 17)
	description.add_theme_color_override("font_color", Color(0.68, 0.76, 0.84))
	info.add_child(description)
	var feature_gap := Control.new()
	feature_gap.custom_minimum_size.y = 18
	info.add_child(feature_gap)
	for feature in ["01  OPEN-WORLD DISTRICTS", "02  FIRE & RESCUE CALLS", "03  ENGINE RESPONSE"]:
		var feature_label := Label.new()
		feature_label.text = feature
		feature_label.add_theme_font_size_override("font_size", 14)
		feature_label.add_theme_color_override("font_color", Color(0.8, 0.87, 0.94))
		info.add_child(feature_label)
	var footer := Label.new()
	footer.name = "MenuFooter"
	footer.anchor_left = 0.49
	footer.anchor_right = 0.95
	footer.anchor_top = 0.88
	footer.anchor_bottom = 0.96
	footer.text = "EARLY ACCESS  •  GODOT ENGINE  •  MIRAGE HILLS"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 10)
	footer.add_theme_color_override("font_color", Color(0.38, 0.5, 0.62))
	menu_layer.add_child(footer)
	var left_area := Control.new()
	left_area.name = "MenuNavigation"
	left_area.anchor_left = 0.045
	left_area.anchor_right = 0.405
	left_area.anchor_top = 0.06
	left_area.anchor_bottom = 0.94
	menu_layer.add_child(left_area)
	var left_center := CenterContainer.new()
	left_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left_area.add_child(left_center)
	menu_panel = VBoxContainer.new()
	menu_panel.custom_minimum_size = Vector2(0, 0)
	menu_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_panel.add_theme_constant_override("separation", 11)
	left_center.add_child(menu_panel)
	# On phones, use a single-column layout instead of squeezing the desktop split screen.
	if OS.has_feature("mobile") or get_viewport().get_visible_rect().size.x < 760:
		right_panel.visible = false
		upper_glow.visible = false
		accent.visible = false
		footer.visible = false
		left_area.anchor_left = 0.06
		left_area.anchor_right = 0.94
		left_area.anchor_top = 0.04
		left_area.anchor_bottom = 0.96
		menu_panel.add_theme_constant_override("separation", 8)
		for child in menu_panel.get_children():
			if child is Button:
				child.custom_minimum_size = Vector2(0, 44)
	_show_main_menu()

func _clear_menu() -> void:
	for child in menu_panel.get_children():
		menu_panel.remove_child(child)
		child.queue_free()
	red_light = null
	blue_light = null

func _add_title() -> void:
	var emblem := PanelContainer.new()
	emblem.custom_minimum_size = Vector2(62, 62)
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var emblem_style := StyleBoxFlat.new()
	emblem_style.bg_color = Color(0.06, 0.17, 0.29)
	emblem_style.border_color = Color(0.16, 0.55, 0.88)
	emblem_style.set_border_width_all(2)
	emblem_style.set_corner_radius_all(12)
	emblem.add_theme_stylebox_override("panel", emblem_style)
	menu_panel.add_child(emblem)
	var badge_label := Label.new()
	badge_label.text = "MH\nPD"
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.add_theme_font_size_override("font_size", 19)
	badge_label.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0))
	emblem.add_child(badge_label)
	var title := Label.new()
	title.text = "FIRE DEPARTMENT\nSIMULATOR"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	menu_panel.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "MIRAGE HILLS FIRE & RESCUE"
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", Color(0.32, 0.67, 0.94))
	menu_panel.add_child(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size.y = 14
	menu_panel.add_child(gap)

func _add_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(250, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.045, 0.085, 0.13)
	normal.border_color = Color(0.12, 0.25, 0.37)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(7)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.06, 0.22, 0.36)
	hover.border_color = Color(0.16, 0.62, 0.96)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(7)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.pressed.connect(callback)
	menu_panel.add_child(button)
	return button

func _show_main_menu() -> void:
	_clear_menu()
	_add_title()
	_add_button("JUGAR", _show_character_selection)
	_add_button("MULTIJUGADOR", _show_multiplayer_menu)
	_add_button("CONFIGURACIÓN", _show_settings)
	_add_button("CRÉDITOS", _show_credits)

func _show_character_selection() -> void:
	_clear_menu()
	_add_title()
	var label := Label.new()
	label.text = "BOMBERO DISPONIBLE"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 19)
	menu_panel.add_child(label)
	var detail := Label.new()
	detail.text = "BOMBERO · UNIDAD DE RESPUESTA"
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_panel.add_child(detail)
	_add_button("INICIAR TURNO", func(): _start_game(true))
	_add_button("VOLVER", _show_main_menu)

func _show_multiplayer_menu() -> void:
	_clear_menu()
	_add_title()
	var label := Label.new()
	label.text = "MULTIJUGADOR · HASTA 8 UNIDADES"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_panel.add_child(label)
	multiplayer_name_input = LineEdit.new()
	multiplayer_name_input.placeholder_text = "Nombre de unidad (opcional)"
	multiplayer_name_input.text = "Officer"
	menu_panel.add_child(multiplayer_name_input)
	multiplayer_ip_input = LineEdit.new()
	multiplayer_ip_input.placeholder_text = "IP del anfitrión para unirse"
	multiplayer_ip_input.text = "127.0.0.1"
	menu_panel.add_child(multiplayer_ip_input)
	_add_button("CREAR SESIÓN", _host_multiplayer)
	_add_button("UNIRSE A SESIÓN", _join_multiplayer)
	var note := Label.new()
	note.text = "Prueba inicial por LAN. Para jugar por Internet, el anfitrión necesita una red accesible por UDP 7000 o un servidor dedicado."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 11)
	menu_panel.add_child(note)
	_add_button("VOLVER", _show_main_menu)

func _host_multiplayer() -> void:
	if has_node("/root/MultiplayerLobby"):
		MultiplayerLobby.player_name = multiplayer_name_input.text.strip_edges() if not multiplayer_name_input.text.strip_edges().is_empty() else "Officer"
		if MultiplayerLobby.host_game() == OK:
			_show_character_selection()

func _join_multiplayer() -> void:
	if has_node("/root/MultiplayerLobby"):
		MultiplayerLobby.player_name = multiplayer_name_input.text.strip_edges() if not multiplayer_name_input.text.strip_edges().is_empty() else "Officer"
		if MultiplayerLobby.join_game(multiplayer_ip_input.text) == OK:
			_show_character_selection()

func _show_settings() -> void:
	_clear_menu()
	_add_title()
	var label := Label.new()
	label.text = "CONFIGURACIÓN"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_panel.add_child(label)
	var invert := CheckButton.new()
	invert.text = "Invertir cámara vertical"
	invert.button_pressed = invert_camera
	invert.toggled.connect(func(value: bool): invert_camera = value)
	menu_panel.add_child(invert)
	var sensitivity_label := Label.new()
	sensitivity_label.text = "Sensibilidad de cámara"
	menu_panel.add_child(sensitivity_label)
	var sensitivity := HSlider.new()
	sensitivity.min_value = 0.001
	sensitivity.max_value = 0.006
	sensitivity.step = 0.0005
	sensitivity.value = mouse_sensitivity
	sensitivity.custom_minimum_size = Vector2(260, 28)
	sensitivity.value_changed.connect(func(value: float): mouse_sensitivity = value)
	menu_panel.add_child(sensitivity)
	_add_button("VOLVER", _show_main_menu)

func _show_credits() -> void:
	_clear_menu()
	_add_title()
	var credits := Label.new()
	credits.text = "FIRE DEPARTMENT SIMULATOR\n\nCiudad ficticia de Mirage Hills\nSimulador de bomberos y rescate en Godot 4"
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.add_theme_font_size_override("font_size", 14)
	menu_panel.add_child(credits)
	_add_button("VOLVER", _show_main_menu)

func _start_game(female: bool) -> void:
	if game_active:
		return
	game_active = true
	menu_layer.visible = false
	game_world = Node3D.new()
	game_world.name = "GameWorld"
	add_child(game_world)
	_create_world()
	_create_player(female)
	_create_vehicle()
	_create_service_vehicles()
	_create_npcs(10 if OS.has_feature("mobile") else 14)
	_create_hud()
	_create_dispatch_system()
	for peer_id in MultiplayerLobby.remote_states.keys():
		var state: Dictionary = MultiplayerLobby.remote_states[peer_id]
		_on_remote_state_received(int(peer_id), state["position"], float(state["rotation_y"]))
	if OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _create_world() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.47, 0.65, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.84)
	env.ambient_light_energy = 0.85
	env_node.environment = env
	game_world.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = false
	game_world.add_child(sun)
	_box("Ground", Vector3(440, 1, 440), Vector3(0, -0.55, 0), Color(0.19, 0.29, 0.19), true)
	# Real road pieces from the uploaded Kenney City Roads CC0 pack.
	_create_road_network_from_pack()
	_create_fire_station()
	_create_city_blocks()
	_create_gas_stations()
	_create_trees()
	_create_street_furniture()
	_create_crosswalks()
	_create_district_markers()


func _create_road_network_from_pack() -> void:
	var road_root := "res://assets/city_roads/kenney_city_roads_glb_cc0_v1/models_glb/"
	var straight_path := road_root + "road-straight.glb"
	var cross_path := road_root + "road-crossroad.glb"
	if not ResourceLoader.exists(straight_path) or not ResourceLoader.exists(cross_path):
		_create_visible_road_surfaces()
		return

	var road_lines: Array[float] = [-180.0, -120.0, -60.0, 0.0, 60.0, 120.0, 180.0]
	# Each intersection is a real GLB junction; straight road pieces fill the 60 m blocks.
	for road_x in road_lines:
		for road_z in road_lines:
			_place_road_model("road-crossroad.glb", Vector3(road_x, 0.015, road_z))
		for segment_z in range(-210, 211, 60):
			_place_road_model("road-straight.glb", Vector3(road_x, 0.015, float(segment_z)), 0.0, Vector3(1.0, 1.0, 6.0))
	for road_z in road_lines:
		for segment_x in range(-210, 211, 60):
			_place_road_model("road-straight.glb", Vector3(float(segment_x), 0.016, road_z), PI / 2.0, Vector3(1.0, 1.0, 6.0))

	# Add small traffic details at major intersections without adding heavy collision meshes.
	for road_x in [-120.0, 0.0, 120.0]:
		for road_z in [-120.0, 0.0, 120.0]:
			_place_road_model("road-intersection-line.glb", Vector3(road_x, 0.025, road_z), 0.0, Vector3(1.0, 1.0, 1.0))

	# Guaranteed visible asphalt and lane markings sit above imported tile meshes.
	_create_visible_road_surfaces()


func _create_visible_road_surfaces() -> void:
	var road_lines: Array[float] = [-180.0, -120.0, -60.0, 0.0, 60.0, 120.0, 180.0]
	var asphalt := Color(0.075, 0.085, 0.095)
	var edge_paint := Color(0.88, 0.88, 0.80)
	var center_paint := Color(0.96, 0.72, 0.12)
	for road_x in road_lines:
		_box("Visible_Asphalt_NS", Vector3(14.0, 0.12, 440.0), Vector3(road_x, 0.045, 0.0), asphalt, false)
		_box("Road_Edge_NS_Left", Vector3(0.16, 0.025, 440.0), Vector3(road_x - 6.1, 0.115, 0.0), edge_paint, false)
		_box("Road_Edge_NS_Right", Vector3(0.16, 0.025, 440.0), Vector3(road_x + 6.1, 0.115, 0.0), edge_paint, false)
		_box("Road_Center_NS_Left", Vector3(0.12, 0.026, 440.0), Vector3(road_x - 0.16, 0.117, 0.0), center_paint, false)
		_box("Road_Center_NS_Right", Vector3(0.12, 0.026, 440.0), Vector3(road_x + 0.16, 0.117, 0.0), center_paint, false)
	for road_z in road_lines:
		_box("Visible_Asphalt_EW", Vector3(440.0, 0.12, 14.0), Vector3(0.0, 0.046, road_z), asphalt, false)
		_box("Road_Edge_EW_North", Vector3(440.0, 0.025, 0.16), Vector3(0.0, 0.116, road_z - 6.1), edge_paint, false)
		_box("Road_Edge_EW_South", Vector3(440.0, 0.025, 0.16), Vector3(0.0, 0.116, road_z + 6.1), edge_paint, false)
		_box("Road_Center_EW_Left", Vector3(440.0, 0.026, 0.12), Vector3(0.0, 0.118, road_z - 0.16), center_paint, false)
		_box("Road_Center_EW_Right", Vector3(440.0, 0.026, 0.12), Vector3(0.0, 0.118, road_z + 0.16), center_paint, false)


func _place_road_model(model_file: String, world_position: Vector3, rotation_y: float = 0.0, model_scale: Vector3 = Vector3.ONE) -> void:
	var model_path := "res://assets/city_roads/kenney_city_roads_glb_cc0_v1/models_glb/" + model_file
	if not ResourceLoader.exists(model_path):
		return
	var packed_model := load(model_path) as PackedScene
	if packed_model == null:
		push_warning("No se pudo cargar el modelo de calle: " + model_file)
		return
	var road_instance := packed_model.instantiate()
	if not road_instance is Node3D:
		road_instance.queue_free()
		return
	road_instance.name = model_file.get_basename().replace("-", "_")
	road_instance.position = world_position
	road_instance.rotation.y = rotation_y
	road_instance.scale = model_scale
	game_world.add_child(road_instance)

func _create_district_markers() -> void:
	var districts := [
		{"name": "DOWNTOWN", "position": Vector3(-30, 8, -30), "color": Color(0.25, 0.72, 1.0)},
		{"name": "NORTH RESIDENTIAL", "position": Vector3(15, 8, -150), "color": Color(0.75, 0.9, 1.0)},
		{"name": "EAST INDUSTRIAL", "position": Vector3(150, 8, 15), "color": Color(1.0, 0.68, 0.28)},
		{"name": "CIVIC DISTRICT", "position": Vector3(-150, 8, 75), "color": Color(0.55, 0.95, 0.76)},
		{"name": "SOUTH GARDENS", "position": Vector3(15, 8, 150), "color": Color(0.65, 0.9, 0.58)}
	]
	for district in districts:
		var sign := Label3D.new()
		sign.name = str(district["name"]).replace(" ", "_")
		sign.text = str(district["name"])
		sign.position = district["position"]
		sign.font_size = 48
		sign.outline_size = 8
		sign.modulate = district["color"]
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign.no_depth_test = false
		game_world.add_child(sign)

func _create_fire_station() -> void:
	_box("FireStation", Vector3(17, 6, 11), Vector3(60, 3, 115), Color(0.48, 0.12, 0.09), true)
	_box("StationEntrance", Vector3(5, 3.3, 0.25), Vector3(60, 1.65, 109.35), Color(0.08, 0.13, 0.2), false)
	_box("StationSign", Vector3(8, 0.8, 0.2), Vector3(60, 5.0, 109.15), Color(0.62, 0.13, 0.1), false)
	_box("StationParking", Vector3(24, 0.08, 16), Vector3(60, 0.0, 101), Color(0.16, 0.17, 0.18), false)
	for i in range(3):
		_box("ParkingLine", Vector3(0.12, 0.025, 6), Vector3(52 + i * 7, 0.06, 101), Color(0.9, 0.9, 0.82), false)

func _create_city_blocks() -> void:
	var colors: Array[Color] = [Color(0.48,0.48,0.46), Color(0.42,0.46,0.5), Color(0.56,0.48,0.39), Color(0.34,0.42,0.47), Color(0.55,0.56,0.53)]
	for x in [-165.0, -105.0, -45.0, 15.0, 75.0, 135.0]:
		for z in [-165.0, -105.0, -45.0, 15.0, 75.0, 135.0]:
			if absf(x) < 20 and absf(z - 18) < 18:
				continue
			var civic_name := ""
			if x == -105.0 and z == -105.0: civic_name = "CITY HALL"
			elif x == 75.0 and z == -105.0: civic_name = "MEDICAL CENTER"
			elif x == 75.0 and z == 75.0: civic_name = "FIRE DEPARTMENT"
			elif x == -165.0 and z == 75.0: civic_name = "PUBLIC LIBRARY"
			var block_position := Vector3(x, 0, z)
			var reserved_for_gas_station := false
			for station_position in [Vector3(-150, 0, -150), Vector3(150, 0, -150), Vector3(-150, 0, 150), Vector3(150, 0, 150)]:
				if absf(x - station_position.x) < 24.0 and absf(z - station_position.z) < 24.0:
					reserved_for_gas_station = true
					break
			if reserved_for_gas_station:
				continue
			if not civic_name.is_empty():
				_create_civic_building(civic_name, block_position)
			elif absf(x) <= 45.0 and absf(z) <= 45.0:
				# A distinct downtown skyline replaces the repeated suburban houses in the central district.
				_create_downtown_building(block_position)
			else:
				_create_civilian_building(block_position, colors[rng.randi_range(0, colors.size()-1)])

func _create_gas_stations() -> void:
	# Four separated stations, each placed in a reserved block beside the road grid.
	gas_station_positions.clear()
	var locations: Array[Dictionary] = [
		{"name": "MIRAGE FUEL · DOWNTOWN", "position": Vector3(-150, 0, -150), "rotation": 0.0},
		{"name": "MIRAGE FUEL · NORTH", "position": Vector3(150, 0, -150), "rotation": PI},
		{"name": "MIRAGE FUEL · SOUTHWEST", "position": Vector3(-150, 0, 150), "rotation": PI / 2.0},
		{"name": "MIRAGE FUEL · EAST", "position": Vector3(150, 0, 150), "rotation": -PI / 2.0}
	]
	for data in locations:
		var station_position: Vector3 = data["position"]
		gas_station_positions.append(station_position)
		var station := Node3D.new()
		station.name = str(data["name"]).replace(" ", "_").replace("·", "")
		station.position = station_position
		station.rotation.y = float(data["rotation"])
		game_world.add_child(station)

		# The uploaded GLB supplies the canopy; pumps, forecourt and shop are lightweight game objects.
		var canopy_path := "res://gas-station-canopy.glb"
		if ResourceLoader.exists(canopy_path):
			var canopy_scene := load(canopy_path) as PackedScene
			if canopy_scene != null:
				var canopy := canopy_scene.instantiate()
				canopy.name = "GasStationCanopy"
				if canopy is Node3D:
					canopy.position = Vector3(0, 0.15, 0)
					canopy.scale = Vector3.ONE
					station.add_child(canopy)
				else:
					canopy.queue_free()

		_box("GasStationForecourt", Vector3(25, 0.12, 22), station_position + Vector3(0, 0.02, 0), Color(0.24, 0.25, 0.25), false)
		_box("GasStationShop", Vector3(7, 3.6, 5), station_position + Vector3(0, 1.8, 8.0), Color(0.82, 0.83, 0.78), true)
		_box("GasStationShopRoof", Vector3(7.5, 0.35, 5.5), station_position + Vector3(0, 3.75, 8.0), Color(0.75, 0.12, 0.08), false)
		_box("GasStationSign", Vector3(4.8, 1.0, 0.18), station_position + Vector3(0, 3.0, 5.35), Color(0.05, 0.12, 0.18), false)
		for pump_x in [-5.0, 0.0, 5.0]:
			_box("FuelPumpBase", Vector3(1.0, 0.18, 0.8), station_position + Vector3(pump_x, 0.17, -2.0), Color(0.12, 0.13, 0.14), false)
			_box("FuelPump", Vector3(0.7, 1.35, 0.55), station_position + Vector3(pump_x, 0.92, -2.0), Color(0.88, 0.88, 0.82), false)
			_box("FuelPumpDisplay", Vector3(0.42, 0.3, 0.08), station_position + Vector3(pump_x, 1.25, -2.3), Color(0.04, 0.16, 0.19), false)
			_box("FuelHose", Vector3(0.08, 0.65, 0.08), station_position + Vector3(pump_x + 0.37, 0.7, -1.85), Color(0.035, 0.04, 0.045), false)
		var sign_3d := Label3D.new()
		sign_3d.name = "StationName"
		sign_3d.text = str(data["name"])
		sign_3d.position = station_position + Vector3(0, 5.2, 0)
		sign_3d.font_size = 30
		sign_3d.outline_size = 5
		sign_3d.modulate = Color(1.0, 0.82, 0.3)
		sign_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		game_world.add_child(sign_3d)

func _try_refuel() -> void:
	if not driving or not is_instance_valid(vehicle):
		if is_instance_valid(status_label):
			status_label.text = "REPOSTAR · Súbete al camión y estaciónalo junto a los surtidores"
		return
	if absf(vehicle_speed) > 0.8:
		if is_instance_valid(status_label):
			status_label.text = "REPOSTAR · Detén el camión primero"
		return
	var nearest_distance := INF
	for station_position in gas_station_positions:
		nearest_distance = minf(nearest_distance, Vector2(vehicle.global_position.x - station_position.x, vehicle.global_position.z - station_position.z).length())
	if nearest_distance > 17.0:
		if is_instance_valid(status_label):
			status_label.text = "REPOSTAR · Acércate a una gasolinera señalizada"
		return
	if fuel_level >= 99.9:
		if is_instance_valid(status_label):
			status_label.text = "DEPÓSITO LLENO · 100%"
		return
	fuel_level = 100.0
	if is_instance_valid(status_label):
		status_label.text = "REPOSTAJE COMPLETADO · Depósito al 100%"

func _create_civic_building(building_type: String, base_position: Vector3) -> void:
	var target_size := Vector3(13.0, 7.5, 11.0)
	if building_type == "MEDICAL CENTER":
		target_size = Vector3(14.0, 8.5, 12.0)
	elif building_type == "FIRE DEPARTMENT":
		target_size = Vector3(15.0, 7.0, 12.0)
	elif building_type == "PUBLIC LIBRARY":
		target_size = Vector3(12.0, 6.5, 11.0)
	var variant := absi(hash(building_type)) % FLORIDA_BUILDING_SCENES.size()
	if not _try_create_asset_building(base_position, target_size, variant, building_type.replace(" ", "_")):
		push_error("Faltan modelos de ciudad Florida. Ejecuta el workflow de preparación de assets.")
		return
	# Señalización pequeña sobre fachadas modeladas; los edificios ya no se generan como cubos.
	var sign_color := Color(0.08, 0.2, 0.34)
	if building_type == "MEDICAL CENTER":
		sign_color = Color(0.1, 0.43, 0.48)
	elif building_type == "FIRE DEPARTMENT":
		sign_color = Color(0.62, 0.13, 0.1)
	_box("Sign_" + building_type, Vector3(3.6, 0.42, 0.12), base_position + Vector3(0, target_size.y * 0.72, -target_size.z * 0.48), sign_color, false)


func _create_civilian_building(base_position: Vector3, building_color: Color) -> void:
	var height := rng.randf_range(5.0, 9.0)
	var size_x := rng.randf_range(8.5, 13.0)
	var size_z := rng.randf_range(8.0, 12.0)
	var style := rng.randi_range(0, FLORIDA_BUILDING_SCENES.size() - 1)
	# En el centro se permiten fachadas más altas, sin volver a usar prismas como edificios.
	if absf(base_position.x) <= 45.0 and absf(base_position.z) <= 45.0:
		height = rng.randf_range(7.0, 11.0)
	var target_size := Vector3(size_x, height, size_z)
	if not _try_create_asset_building(base_position, target_size, style, "FloridaBuilding"):
		push_error("No se encontró el modelo 3D de ciudad: assets/florida_city.")
		return

func _create_downtown_building(base_position: Vector3) -> void:
	var coordinate_seed := absi(hash(str(int(base_position.x)) + ":" + str(int(base_position.z))))
	var is_tower := coordinate_seed % 3 == 0
	var model_list: Array = FLORIDA_SKYSCRAPER_SCENES if is_tower else FLORIDA_DOWNTOWN_SCENES
	var variant := coordinate_seed % model_list.size()
	var target_size := Vector3(13.0, rng.randf_range(13.0, 21.0), 11.0)
	if is_tower:
		target_size = Vector3(13.0, rng.randf_range(23.0, 34.0), 13.0)
	var asset_path: String = model_list[variant]
	if not _try_create_building_from_path(asset_path, base_position, target_size, "Downtown_" + str(int(base_position.x)) + "_" + str(int(base_position.z))):
		# Missing optional commercial assets should not leave an empty city block.
		_create_civilian_building(base_position, Color(0.42, 0.46, 0.5))

func _try_create_asset_building(base_position: Vector3, target_size: Vector3, variant: int, node_name: String) -> bool:
	if FLORIDA_BUILDING_SCENES.is_empty():
		return false
	var asset_path: String = FLORIDA_BUILDING_SCENES[posmod(variant, FLORIDA_BUILDING_SCENES.size())]
	return _try_create_building_from_path(asset_path, base_position, target_size, node_name)

func _try_create_building_from_path(asset_path: String, base_position: Vector3, target_size: Vector3, node_name: String) -> bool:
	var packed_scene := load(asset_path) as PackedScene
	if packed_scene == null:
		return false
	var building_body := StaticBody3D.new()
	building_body.name = node_name
	building_body.position = base_position
	game_world.add_child(building_body)
	var collision_node := CollisionShape3D.new()
	var collision := BoxShape3D.new()
	collision.size = target_size
	collision_node.shape = collision
	collision_node.position.y = target_size.y * 0.5
	building_body.add_child(collision_node)
	var building_model := packed_scene.instantiate() as Node3D
	if building_model == null:
		building_body.queue_free()
		return false
	building_model.name = "TexturedBuildingModel"
	building_body.add_child(building_model)
	_fit_imported_model(building_model, target_size)
	return true

func _create_crosswalks() -> void:
	# Zebra crossings and white lane-edge lines make the grid read as actual streets.
	for street in [-60.0, -30.0, 0.0, 30.0, 60.0]:
		_box("RoadEdgeLine", Vector3(0.12, 0.025, 200), Vector3(street - 6.0, 0.065, 0), Color(0.82, 0.84, 0.83), false)
		_box("RoadEdgeLine", Vector3(0.12, 0.025, 200), Vector3(street + 6.0, 0.065, 0), Color(0.82, 0.84, 0.83), false)
		_box("RoadEdgeLine", Vector3(200, 0.025, 0.12), Vector3(0, 0.065, street - 6.0), Color(0.82, 0.84, 0.83), false)
		_box("RoadEdgeLine", Vector3(200, 0.025, 0.12), Vector3(0, 0.065, street + 6.0), Color(0.82, 0.84, 0.83), false)
	for ix in [-30.0, 0.0, 30.0]:
		for iz in [-30.0, 0.0, 30.0]:
			for stripe in range(5):
				var offset := -4.0 + float(stripe) * 2.0
				_box("CrosswalkStripe", Vector3(0.9, 0.035, 2.8), Vector3(ix + offset, 0.075, iz - 7.3), Color(0.88, 0.9, 0.88), false)
				_box("CrosswalkStripe", Vector3(0.9, 0.035, 2.8), Vector3(ix + offset, 0.075, iz + 7.3), Color(0.88, 0.9, 0.88), false)
				_box("CrosswalkStripe", Vector3(2.8, 0.035, 0.9), Vector3(ix - 7.3, 0.075, iz + offset), Color(0.88, 0.9, 0.88), false)
				_box("CrosswalkStripe", Vector3(2.8, 0.035, 0.9), Vector3(ix + 7.3, 0.075, iz + offset), Color(0.88, 0.9, 0.88), false)

func _create_street_furniture() -> void:
	# Repeated street lamps and traffic signals use simple meshes to stay mobile-friendly.
	for z in [-84.0, -48.0, -18.0, 18.0, 48.0, 84.0]:
		for x in [-67.0, -37.0, -7.0, 23.0, 53.0]:
			if absf(x) < 12.0 and absf(z) < 12.0:
				continue
			_box("StreetLampPole", Vector3(0.16, 5.2, 0.16), Vector3(x, 2.6, z), Color(0.16, 0.18, 0.2), false)
			_box("StreetLampArm", Vector3(1.15, 0.12, 0.12), Vector3(x + 0.48, 5.08, z), Color(0.16, 0.18, 0.2), false)
			_box("StreetLampHead", Vector3(0.55, 0.16, 0.3), Vector3(x + 0.95, 5.0, z), Color(0.95, 0.82, 0.55), false)
	# A few signalised intersections near downtown, with red/amber/green lenses.
	for ix in [-30.0, 0.0, 30.0]:
		for iz in [-30.0, 0.0, 30.0]:
			for side in [-1.0, 1.0]:
				var px: float = ix + side * 8.0
				var pz: float = iz - side * 8.0
				_box("TrafficSignalPole", Vector3(0.14, 3.8, 0.14), Vector3(px, 1.9, pz), Color(0.12, 0.13, 0.14), false)
				_box("TrafficSignalHousing", Vector3(0.42, 0.95, 0.32), Vector3(px, 3.65, pz), Color(0.055, 0.06, 0.065), false)
				_sphere("SignalRed", Vector3(px, 3.94, pz - 0.18), 0.105, Color(0.9, 0.035, 0.025))
				_sphere("SignalAmber", Vector3(px, 3.66, pz - 0.18), 0.105, Color(0.95, 0.55, 0.035))
				_sphere("SignalGreen", Vector3(px, 3.38, pz - 0.18), 0.105, Color(0.04, 0.72, 0.19))

func _create_trees() -> void:
	for i in range(34):
		var x := rng.randf_range(-88, 88)
		var z := rng.randf_range(-88, 88)
		if absf(fposmod(x + 15.0, 30.0) - 15.0) < 8.5 or absf(fposmod(z + 15.0, 30.0) - 15.0) < 8.5:
			continue
		_box("TreeTrunk", Vector3(0.45, 2.2, 0.45), Vector3(x, 1.1, z), Color(0.25, 0.15, 0.09), false)
		_sphere("TreeCanopy", Vector3(x, 2.9, z), 1.5, Color(0.12, 0.32, 0.16))


func _fit_imported_model(model: Node3D, target_size: Vector3) -> void:
	var bounds := _get_model_local_bounds(model)
	if bounds.size.x <= 0.001 or bounds.size.y <= 0.001 or bounds.size.z <= 0.001:
		model.position.y = 0.05
		return
	var factor := minf(target_size.x / bounds.size.x, minf(target_size.y / bounds.size.y, target_size.z / bounds.size.z))
	if not is_finite(factor) or factor <= 0.0:
		model.position.y = 0.05
		return
	model.scale = Vector3.ONE * factor
	model.position.y = -bounds.position.y * factor + 0.05

func _get_model_local_bounds(model: Node3D) -> AABB:
	var combined := AABB()
	var found := false
	var pending: Array[Node] = [model]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is MeshInstance3D:
			var mesh_node := node as MeshInstance3D
			if mesh_node.mesh != null:
				var relative_transform := model.global_transform.affine_inverse() * mesh_node.global_transform
				var mesh_bounds: AABB = relative_transform * mesh_node.get_aabb()
				if not found:
					combined = mesh_bounds
					found = true
				else:
					combined = combined.merge(mesh_bounds)
		for child in node.get_children():
			pending.append(child)
	return combined

func _shared_material(color: Color, roughness := 0.9) -> StandardMaterial3D:
	var key := color.to_html(true) + ":" + str(roughness)
	if shared_materials.has(key):
		return shared_materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	shared_materials[key] = material
	return material

func _box(node_name: String, box_size: Vector3, pos: Vector3, color: Color, collision: bool) -> Node3D:
	var root: Node3D
	if collision:
		var body := StaticBody3D.new()
		body.name = node_name
		game_world.add_child(body)
		root = body
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box_size
		shape_node.shape = shape
		body.add_child(shape_node)
	else:
		root = Node3D.new()
		root.name = node_name
		game_world.add_child(root)
	root.position = pos
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh_node.mesh = mesh
	mesh_node.material_override = _shared_material(color, 0.9)
	root.add_child(mesh_node)
	return root

func _sphere(node_name: String, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	node.mesh = mesh
	node.material_override = _shared_material(color, 0.9)
	node.position = pos
	game_world.add_child(node)
	return node

func _create_player(female: bool) -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(56.0, 0.08, 92.0)
	game_world.add_child(player)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	player.add_child(collider)
	# Use the male officer OBJ already included in the project; the previous GLB pivot clipped the character.
	player_visual = _make_person(false, false, "fire")
	player_visual.name = "PlayerFirefighter"
	player_visual.scale = Vector3(0.86, 0.86, 0.86)
	player_visual.position.y = 0.0
	player.add_child(player_visual)
	_setup_player_animations(player_visual)
	camera_pivot = Node3D.new()
	camera_pivot.position.y = 1.55
	player.add_child(camera_pivot)
	camera = Camera3D.new()
	camera.name = "FollowCamera"
	camera.position = Vector3(0, 1.0, 5.5)
	camera.rotation_degrees.x = -10
	camera.current = true
	camera_pivot.add_child(camera)

func _setup_player_animations(root: Node) -> void:
	player_animation_player = _find_animation_player(root)
	player_animation_names.clear()
	player_motion_state = ""
	if not is_instance_valid(player_animation_player):
		return
	for animation_name in player_animation_player.get_animation_list():
		player_animation_names.append(StringName(animation_name))
	_play_player_animation("idle")

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if is_instance_valid(found):
			return found
	return null

func _play_player_animation(state: String) -> void:
	if not is_instance_valid(player_animation_player) or player_animation_names.is_empty() or player_motion_state == state:
		return
	var preferred: Array[String] = []
	if state == "run":
		preferred = ["run", "sprint", "jog", "walk"]
	elif state == "walk":
		preferred = ["walk", "move", "run", "jog"]
	else:
		preferred = ["idle", "stand", "breath", "rest"]
	for keyword in preferred:
		for animation_name in player_animation_names:
			if String(animation_name).to_lower().contains(keyword):
				player_animation_player.play(String(animation_name))
				player_motion_state = state
				return
	# If the file contains only a differently named clip, use its first animation.
	if state == "idle" and not player_animation_names.is_empty():
		player_animation_player.play(String(player_animation_names[0]))
		player_motion_state = state

func _make_person(female: bool, police: bool, role: String = "civilian") -> Node3D:
	var person := Node3D.new()
	var model_path := "res://models/civilian.obj"
	var imported_character_path := ""
	if role == "police":
		imported_character_path = "res://assets/characters/police-officer.glb"
	elif role == "fire":
		imported_character_path = "res://assets/characters/firefighter.glb"
	elif role == "ems":
		imported_character_path = "res://assets/characters/paramedic.glb"
	elif role == "civilian":
		# Two compact CC0 GLBs give pedestrians visible model variety without adding
		# tens of megabytes to the Android build. Keep the original OBJ as fallback.
		imported_character_path = "res://assets/characters/civilian-female.glb" if rng.randi_range(0, 1) == 0 else "res://assets/characters/civilian-male.glb"
	elif police or role == "sheriff":
		# Keep the existing sheriff/officer mesh rather than falsely labeling a
		# generic city-police uniform as a sheriff uniform.
		model_path = "res://models/officer.obj"
	var imported_character := false
	if not imported_character_path.is_empty():
		var character_scene := load(imported_character_path) as PackedScene
		if character_scene != null:
			var character_model := character_scene.instantiate() as Node3D
			if character_model != null:
				character_model.name = "ImportedCharacterModel"
				person.add_child(character_model)
				imported_character = true
	if not imported_character:
		var model_mesh := load(model_path) as Mesh
		if model_mesh != null:
			var model := MeshInstance3D.new()
			model.name = "CustomCharacterModel"
			model.mesh = model_mesh
			model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			person.add_child(model)
		else:
			# Fallback only if an asset cannot be imported.
			_add_person_capsule(person, Vector3(0, 1.08, 0), 0.29, 0.72, Color(0.07, 0.12, 0.23))
			_sphere_child(person, Vector3(0, 1.64, 0), 0.22, Color(0.72, 0.53, 0.4))
	# Imported uniform models already include their clothing and equipment.
	if not imported_character and (police or role == "sheriff"):
		_add_person_box(person, Vector3(0.56, 0.09, 0.34), Vector3(0, 0.96, 0), Color(0.035, 0.04, 0.045))
		_add_person_box(person, Vector3(0.09, 0.13, 0.035), Vector3(-0.12, 1.38, -0.19), Color(0.92, 0.72, 0.18))
		_add_person_box(person, Vector3(0.10, 0.16, 0.08), Vector3(0.22, 1.39, -0.14), Color(0.035, 0.04, 0.05))
		_add_person_box(person, Vector3(0.32, 0.08, 0.30), Vector3(0, 1.79, 0), Color(0.035, 0.055, 0.09))
	elif not imported_character and role == "fire":
		_add_person_box(person, Vector3(0.43, 0.12, 0.36), Vector3(0, 1.78, 0), Color(0.68, 0.07, 0.035))
		_add_person_box(person, Vector3(0.58, 0.07, 0.35), Vector3(0, 1.03, -0.01), Color(0.9, 0.68, 0.12))
	elif not imported_character and role == "ems":
		_add_person_box(person, Vector3(0.58, 0.08, 0.34), Vector3(0, 1.02, -0.01), Color(0.9, 0.78, 0.16))
		_add_person_box(person, Vector3(0.12, 0.12, 0.04), Vector3(-0.14, 1.38, -0.19), Color(0.92, 0.94, 0.91))
	return person

func _add_person_capsule(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, angles := Vector3.ZERO) -> void:
	var mesh_node := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh_node.mesh = mesh
	mesh_node.material_override = _shared_material(color, 0.82)
	mesh_node.position = pos
	mesh_node.rotation_degrees = angles
	parent.add_child(mesh_node)

func _add_person_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	# Lightweight box detail used by generated vehicle models.
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = _shared_material(color, 0.9)
	m.position = pos
	parent.add_child(m)
	return m

func _sphere_child(parent: Node3D, pos: Vector3, radius: float, color: Color) -> void:
	var m := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	m.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	m.material_override = material
	m.position = pos
	parent.add_child(m)

func _create_vehicle() -> void:
	# Única patrulla jugable: modelo GLB aportado al proyecto.
	vehicle = CharacterBody3D.new()
	vehicle.name = "FireEngine_Main"
	vehicle.position = Vector3(60, 0.0, 92)
	vehicle.floor_snap_length = 0.2
	game_world.add_child(vehicle)

	# La colisión independiente mantiene conducción y choques aunque el modelo sea solo visual.
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.6, 3.0, 8.5)
	shape_node.shape = shape
	shape_node.position.y = 1.5
	vehicle.add_child(shape_node)

	var patrol_scene := load("res://fire_truck.glb") as PackedScene
	if patrol_scene != null:
		var patrol_visual := patrol_scene.instantiate()
		patrol_visual.name = "FireEngineModel"
		if patrol_visual is Node3D:
			patrol_visual.position = Vector3.ZERO
		vehicle.add_child(patrol_visual)
		_fit_imported_model(patrol_visual, Vector3(3.6, 3.6, 8.5))
	else:
		push_error("No se pudo cargar res://fire_truck.glb")

	# Luces de emergencia funcionales sobre el techo, independientes del modelo.
	patrol_red_light = _add_person_box(vehicle, Vector3(0.42, 0.16, 0.28), Vector3(-0.45, 2.05, -0.05), Color(0.95, 0.025, 0.025))
	_add_person_box(vehicle, Vector3(0.30, 0.16, 0.28), Vector3(0.0, 2.05, -0.05), Color(0.94, 0.94, 0.88))
	patrol_blue_light = _add_person_box(vehicle, Vector3(0.42, 0.16, 0.28), Vector3(0.45, 2.05, -0.05), Color(0.025, 0.12, 0.98))


func _create_service_vehicles() -> void:
	# Real lightweight GLB vehicle models replace the old box-built emergency vehicles.
	_create_static_vehicle_model("Ambulance_Model", "res://assets/vehicles/ambulance.glb", Vector3(8.0, 0.0, -18.0), Vector3(2.25, 2.35, 4.8))
	_create_static_vehicle_model("CivilianSedan_Model", "res://assets/vehicles/sedan.glb", Vector3(-13.0, 0.0, -18.0), Vector3(2.1, 1.8, 4.5))
	_create_static_vehicle_model("CivilianSUV_Model", "res://assets/vehicles/suv.glb", Vector3(-20.0, 0.0, -18.0), Vector3(2.2, 2.0, 4.7))

func _create_static_vehicle_model(node_name: String, model_path: String, base_position: Vector3, target_size: Vector3) -> void:
	var vehicle_body := StaticBody3D.new()
	vehicle_body.name = node_name
	vehicle_body.position = base_position
	game_world.add_child(vehicle_body)
	var collision_node := CollisionShape3D.new()
	var collision := BoxShape3D.new()
	collision.size = target_size
	collision_node.shape = collision
	collision_node.position.y = target_size.y * 0.5
	vehicle_body.add_child(collision_node)
	var packed := load(model_path) as PackedScene
	if packed == null:
		push_error("No se pudo cargar el modelo 3D: " + model_path)
		return
	var model := packed.instantiate() as Node3D
	if model == null:
		push_error("El archivo no contiene un modelo 3D válido: " + model_path)
		return
	model.name = "VehicleVisual"
	vehicle_body.add_child(model)
	_fit_imported_model(model, target_size)


func _create_npcs(count: int) -> void:
	npc_nodes.clear()
	npc_targets.clear()
	for i in range(count):
		var npc := Node3D.new()
		var role := "civilian"
		if i == 0 or i == 1: role = "fire"
		elif i == 2 or i == 3: role = "ems"
		elif i == 4 or i == 5: role = "fire"
		elif i == 6 or i == 7: role = "civilian"
		npc.name = role.to_upper() + "_NPC_%02d" % i
		var x := rng.randf_range(-200, 200)
		var z := rng.randf_range(-200, 200)
		if absf(x) < 10:
			x += 18
		npc.position = Vector3(x, 0, z)
		npc.add_child(_make_person(false, role == "sheriff", role))
		game_world.add_child(npc)
		npc_nodes.append(npc)
		npc_targets.append(Vector3(rng.randf_range(-200,200), 0, rng.randf_range(-200,200)))

func _update_npcs(delta: float) -> void:
	for i in range(npc_nodes.size()):
		var npc := npc_nodes[i]
		if not is_instance_valid(npc):
			continue
		var target := npc_targets[i]
		var offset: Vector3 = target - npc.position
		offset.y = 0
		if offset.length() < 2.0:
			npc_targets[i] = Vector3(rng.randf_range(-200,200), 0, rng.randf_range(-200,200))
			continue
		var direction := offset.normalized()
		npc.position += direction * delta * 1.0
		npc.rotation.y = atan2(direction.x, direction.z)

func _create_dispatch_system() -> void:
	dispatch_layer = load("res://dispatch_system.gd").new()
	dispatch_layer.name = "DispatchSystem"
	add_child(dispatch_layer)
	dispatch_layer.call_accepted.connect(_on_dispatch_call_accepted)

func _on_dispatch_call_accepted(location: Vector3, description: String) -> void:
	dispatch_target_position = location
	dispatch_target_active = true
	if description.to_lower().contains("incendio") or description.to_lower().contains("fuego"):
		_spawn_fire(location)
	if is_instance_valid(minimap):
		minimap.target_world_position = location
		minimap.target_active = true
		minimap.queue_redraw()
	if is_instance_valid(dispatch_marker):
		dispatch_marker.queue_free()
	dispatch_marker = MeshInstance3D.new()
	dispatch_marker.name = "DispatchLocationMarker"
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 1.1
	marker_mesh.bottom_radius = 1.1
	marker_mesh.height = 0.12
	dispatch_marker.mesh = marker_mesh
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color(1.0, 0.65, 0.08)
	marker_material.emission_enabled = true
	marker_material.emission = Color(0.8, 0.25, 0.02)
	dispatch_marker.material_override = marker_material
	dispatch_marker.position = location + Vector3(0, 0.12, 0)
	game_world.add_child(dispatch_marker)
	if is_instance_valid(status_label):
		status_label.text = "911 ASIGNADO: " + description + " · Coordenadas %.0f, %.0f" % [location.x, location.z]


func _toggle_extinguishing() -> void:
	if not game_active:
		return
	extinguishing = not extinguishing
	if not extinguishing:
		_set_water_stream_visible(false)
	if is_instance_valid(status_label):
		status_label.text = "MANGUERA ABIERTA: apunta y acércate al foco" if extinguishing else "MANGUERA CERRADA"

func _ensure_water_stream() -> void:
	if not water_drops.is_empty() or not is_instance_valid(game_world):
		return
	var water_material := StandardMaterial3D.new()
	water_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	water_material.albedo_color = Color(0.18, 0.78, 1.0, 0.88)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.emission_enabled = true
	water_material.emission = Color(0.08, 0.48, 1.0)
	for i in range(9):
		var drop := MeshInstance3D.new()
		drop.name = "WaterJet_%02d" % i
		var sphere := SphereMesh.new()
		sphere.radius = 0.10 if i % 3 == 0 else 0.065
		sphere.height = sphere.radius * 2.0
		drop.mesh = sphere
		drop.material_override = water_material
		drop.visible = false
		game_world.add_child(drop)
		water_drops.append(drop)

func _set_water_stream_visible(value: bool) -> void:
	for drop in water_drops:
		if is_instance_valid(drop):
			drop.visible = value

func _spawn_fire(location: Vector3) -> void:
	if is_instance_valid(fire_visual):
		fire_visual.queue_free()
	fire_location = location
	fire_strength = 100.0
	fire_elapsed = 0.0
	fire_spread_timer = 0.0
	fire_active = true
	fire_flames.clear()
	fire_spread_patches.clear()
	fire_visual = Node3D.new()
	fire_visual.name = "ActiveFire"
	fire_visual.position = location
	game_world.add_child(fire_visual)
	var mobile_quality := OS.has_feature("mobile")
	# Layered, emissive flame meshes keep a visible core even on low-end devices.
	for i in range(7):
		var flame := MeshInstance3D.new()
		flame.name = "FlameCore_%02d" % i
		var sphere := SphereMesh.new()
		sphere.radius = 0.48 + float(i % 3) * 0.16
		sphere.height = sphere.radius * 2.0
		flame.mesh = sphere
		flame.position = Vector3(rng.randf_range(-0.9, 0.9), 0.45 + float(i) * 0.42, rng.randf_range(-0.75, 0.75))
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.16 + float(i % 3) * 0.16, 0.015, 0.92)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.16 + float(i % 2) * 0.08, 0.015)
		flame.material_override = mat
		fire_visual.add_child(flame)
		fire_flames.append(flame)
	# CPU particles are used for compatibility with both the mobile and desktop renderers.
	fire_particles = _make_fire_particles("FlameParticles", 22 if mobile_quality else 52, 0.9, Vector3(0, 1, 0), 34.0, 2.0, 4.6, Vector3(0, -1.2, 0), 0.22, 0.75, Color(1.0, 0.72, 0.08, 1.0), Color(1.0, 0.12, 0.015, 0.0))
	fire_particles.position.y = 0.5
	fire_visual.add_child(fire_particles)
	# Dark smoke rises above the fire and expands as the incident grows.
	fire_smoke = _make_fire_particles("SmokeParticles", 18 if mobile_quality else 42, 3.2, Vector3(0, 1, 0), 18.0, 0.65, 1.8, Vector3(0, 0.18, 0), 0.45, 1.65, Color(0.16, 0.17, 0.19, 0.78), Color(0.24, 0.25, 0.27, 0.0))
	fire_smoke.position.y = 1.4
	fire_visual.add_child(fire_smoke)
	# Sparse glowing embers hint at fire spread without spawning expensive full fire simulations.
	fire_embers = _make_fire_particles("EmberParticles", 8 if mobile_quality else 20, 1.5, Vector3(0, 1, 0), 48.0, 1.4, 3.8, Vector3(0, -2.6, 0), 0.045, 0.12, Color(1.0, 0.34, 0.035, 1.0), Color(1.0, 0.12, 0.015, 0.0))
	fire_embers.position.y = 0.65
	fire_visual.add_child(fire_embers)
	fire_glow = OmniLight3D.new()
	fire_glow.light_color = Color(1.0, 0.22, 0.035)
	fire_glow.light_energy = 2.2
	fire_glow.omni_range = 13.0
	fire_glow.shadow_enabled = false
	fire_glow.position.y = 2.0
	fire_visual.add_child(fire_glow)

func _make_fire_particles(node_name: String, particle_count: int, particle_lifetime: float, emission_direction: Vector3, particle_spread: float, velocity_min: float, velocity_max: float, particle_gravity: Vector3, scale_minimum: float, scale_maximum: float, start_color: Color, end_color: Color) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = node_name
	particles.amount = particle_count
	particles.lifetime = particle_lifetime
	particles.explosiveness = 0.0
	particles.randomness = 0.45
	particles.local_coords = true
	particles.emitting = true
	var process_material := ParticleProcessMaterial.new()
	process_material.direction = emission_direction
	process_material.spread = particle_spread
	process_material.initial_velocity_min = velocity_min
	process_material.initial_velocity_max = velocity_max
	process_material.gravity = particle_gravity
	process_material.scale_min = scale_minimum
	process_material.scale_max = scale_maximum
	var color_gradient := Gradient.new()
	color_gradient.set_color(0, start_color)
	color_gradient.add_point(0.55, Color(start_color.r, start_color.g, start_color.b, start_color.a * 0.55))
	color_gradient.set_color(1, end_color)
	var color_texture := GradientTexture1D.new()
	color_texture.gradient = color_gradient
	process_material.color_ramp = color_texture
	particles.process_material = process_material
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.22
	particle_mesh.height = 0.44
	var particle_material := StandardMaterial3D.new()
	particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_material.vertex_color_use_as_albedo = true
	particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_material.emission_enabled = true
	particle_material.emission = start_color
	particles.draw_pass_1 = particle_mesh
	particles.material_override = particle_material
	particles.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 18, 16))
	return particles

func _update_fire_visuals(delta: float) -> void:
	if not fire_active or not is_instance_valid(fire_visual):
		return
	fire_elapsed += delta
	fire_spread_timer += delta
	var intensity := clampf(fire_strength / 100.0, 0.0, 1.0)
	# Animate each flame independently to avoid the old static-sphere appearance.
	for i in range(fire_flames.size()):
		var flame := fire_flames[i]
		if not is_instance_valid(flame):
			continue
		var pulse := 1.0 + sin(fire_elapsed * (5.0 + float(i) * 0.7) + float(i)) * 0.17
		var spread_growth := 1.0 + minf(fire_elapsed / 32.0, 0.5)
		flame.scale = Vector3(pulse * spread_growth, pulse * (1.0 + 0.12 * sin(fire_elapsed * 7.0 + float(i))), pulse * spread_growth) * maxf(0.22, intensity)
		flame.position.x = flame.position.x + sin(fire_elapsed * 0.8 + float(i)) * delta * 0.12
	if is_instance_valid(fire_glow):
		fire_glow.light_energy = 2.2 * intensity * (0.88 + 0.12 * sin(fire_elapsed * 8.0))
	# Periodic small ignition patches give a readable, lightweight spread effect.
	if fire_spread_timer >= 7.0 and fire_spread_patches.size() < 3:
		fire_spread_timer = 0.0
		var patch := MeshInstance3D.new()
		patch.name = "SpreadIgnition_%02d" % fire_spread_patches.size()
		var patch_mesh := SphereMesh.new()
		patch_mesh.radius = 0.28
		patch_mesh.height = 0.8
		patch.mesh = patch_mesh
		patch.position = Vector3(rng.randf_range(-3.2, 3.2), 0.38, rng.randf_range(-2.8, 2.8))
		var patch_material := StandardMaterial3D.new()
		patch_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		patch_material.albedo_color = Color(1.0, 0.22, 0.015, 0.88)
		patch_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		patch_material.emission_enabled = true
		patch_material.emission = Color(1.0, 0.12, 0.01)
		patch.material_override = patch_material
		patch.scale = Vector3(0.15, 0.15, 0.15)
		fire_visual.add_child(patch)
		fire_spread_patches.append(patch)
	for i in range(fire_spread_patches.size()):
		var patch := fire_spread_patches[i]
		if is_instance_valid(patch):
			var patch_pulse := 0.7 + 0.3 * sin(fire_elapsed * 5.5 + float(i))
			patch.scale = Vector3.ONE * patch_pulse * minf(1.0, fire_elapsed / 10.0)

func _update_fire_response(delta: float) -> void:
	if not fire_active:
		_set_water_stream_visible(false)
		return
	var responder_position := vehicle.global_position if driving and is_instance_valid(vehicle) else (player.global_position if is_instance_valid(player) else Vector3.ZERO)
	var nozzle_position := responder_position + Vector3(0, 1.25, 0)
	var fire_target := fire_location + Vector3(0, 1.1, 0)
	var distance := responder_position.distance_to(fire_location)
	var water_reaching_fire := extinguishing and distance <= 16.0
	if water_reaching_fire:
		_ensure_water_stream()
		_set_water_stream_visible(true)
		for i in range(water_drops.size()):
			var t := fposmod(float(i) / float(water_drops.size()) + light_timer * 1.8, 1.0)
			var drop_position := nozzle_position.lerp(fire_target, t)
			drop_position.y += sin(t * PI) * 0.35
			water_drops[i].global_position = drop_position
	else:
		_set_water_stream_visible(false)
	if water_reaching_fire:
		fire_strength = maxf(0.0, fire_strength - delta * 18.0)
		if is_instance_valid(fire_glow):
			fire_glow.light_energy = 2.2 * fire_strength / 100.0
		if is_instance_valid(status_label):
			status_label.text = "EXTINGUIENDO INCENDIO · %d%%" % roundi(fire_strength)
		if fire_strength <= 0.0:
			fire_active = false
			extinguishing = false
			dispatch_target_active = false
			if is_instance_valid(fire_visual):
				fire_visual.queue_free()
			if is_instance_valid(dispatch_marker):
				dispatch_marker.queue_free()
				dispatch_marker = null
			if is_instance_valid(minimap):
				minimap.target_active = false
				minimap.queue_redraw()
			if is_instance_valid(status_label):
				status_label.text = "INCENDIO CONTROLADO · Unidad disponible"
	elif extinguishing and is_instance_valid(status_label):
		status_label.text = "ACÉRCATE AL INCENDIO · %.0f m" % distance

func _update_remote_network(delta: float) -> void:
	if not has_node("/root/MultiplayerLobby") or not is_instance_valid(player):
		return
	network_send_timer += delta
	if network_send_timer >= 0.08:
		network_send_timer = 0.0
		var tracked := vehicle if driving and is_instance_valid(vehicle) else player
		MultiplayerLobby.publish_player_state(tracked.global_position, tracked.rotation.y)

func _on_peer_joined(peer_id: int) -> void:
	if peer_id == multiplayer.get_unique_id() or not game_active:
		return
	_create_remote_player(peer_id)

func _on_peer_left(peer_id: int) -> void:
	if remote_players.has(peer_id) and is_instance_valid(remote_players[peer_id]):
		remote_players[peer_id].queue_free()
	remote_players.erase(peer_id)

func _on_remote_state_received(peer_id: int, position: Vector3, rotation_y: float) -> void:
	if not game_active or peer_id == multiplayer.get_unique_id():
		return
	if not remote_players.has(peer_id) or not is_instance_valid(remote_players[peer_id]):
		_create_remote_player(peer_id)
	var remote: Node3D = remote_players[peer_id]
	remote.global_position = remote.global_position.lerp(position, 0.65)
	remote.rotation.y = rotation_y

func _create_remote_player(peer_id: int) -> void:
	if not is_instance_valid(game_world) or remote_players.has(peer_id):
		return
	var remote := Node3D.new()
	remote.name = "RemoteOfficer_%d" % peer_id
	remote.add_child(_make_person(false, false, "fire"))
	game_world.add_child(remote)
	remote_players[peer_id] = remote
	remote.position = Vector3(0, 0.1, 0)

func _on_network_status_changed(message: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = "RED: " + message

func _create_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HUD"
	add_child(hud_layer)
	var top := PanelContainer.new()
	top.anchor_left = 0.02
	top.anchor_top = 0.02
	top.anchor_right = 0.98
	top.anchor_bottom = 0.02
	top.offset_bottom = 42
	hud_layer.add_child(top)
	status_label = Label.new()
	status_label.text = "A PIE — WASD para moverte"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(status_label)
	minimap = MinimapControl.new()
	minimap.name = "Minimapa"
	minimap.custom_minimum_size = Vector2(210, 170)
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.anchor_top = 0.12
	minimap.anchor_bottom = 0.12
	minimap.offset_left = -226
	minimap.offset_right = -16
	minimap.offset_top = 104
	minimap.offset_bottom = 274
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(minimap)
	var pause := Button.new()
	pause.text = "PAUSA"
	pause.anchor_left = 1.0
	pause.anchor_right = 1.0
	pause.offset_left = -100
	pause.offset_right = -12
	pause.offset_top = 56
	pause.offset_bottom = 96
	pause.pressed.connect(_toggle_pause_menu)
	hud_layer.add_child(pause)
	# Controles táctiles reorganizados: cruceta compacta a la izquierda y acciones grandes a la derecha.
	_touch_button("▲", Vector2(78, -198), Vector2(60, 56), func(): touch_move.y = -1.0, func(): touch_move.y = 0.0)
	_touch_button("▼", Vector2(78, -78), Vector2(60, 56), func(): touch_move.y = 1.0, func(): touch_move.y = 0.0)
	_touch_button("◀", Vector2(14, -138), Vector2(60, 56), func(): touch_move.x = -1.0, func(): touch_move.x = 0.0)
	_touch_button("▶", Vector2(142, -138), Vector2(60, 56), func(): touch_move.x = 1.0, func(): touch_move.x = 0.0)
	_touch_button("USAR / BAJAR", Vector2(-164, -70), Vector2(148, 56), func(): pass, Callable(), true)
	_touch_button("LUCES", Vector2(-164, -132), Vector2(148, 52), func(): pass, Callable(), true)
	_touch_button("CORRER", Vector2(-164, -190), Vector2(148, 52), func(): touch_run = true, func(): touch_run = false, true)
	_touch_button("FRENO", Vector2(-164, -248), Vector2(148, 52), func(): touch_brake = true, func(): touch_brake = false, true)
	_touch_button("MANGUERA", Vector2(-164, -306), Vector2(148, 52), func(): _toggle_extinguishing(), Callable(), true)
	_touch_button("REPOSTAR", Vector2(-164, -364), Vector2(148, 52), func(): _try_refuel(), Callable(), true)

func _touch_button(label_text: String, bottom_right_offset: Vector2, button_size: Vector2, on_down: Callable, on_up: Callable, right_side := false) -> void:
	var b := Button.new()
	b.text = label_text
	b.custom_minimum_size = button_size
	if right_side:
		b.anchor_left = 1.0
		b.anchor_right = 1.0
		b.offset_left = bottom_right_offset.x
		b.offset_right = bottom_right_offset.x + button_size.x
	else:
		b.anchor_left = 0.0
		b.anchor_right = 0.0
		b.offset_left = bottom_right_offset.x
		b.offset_right = bottom_right_offset.x + button_size.x
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_top = bottom_right_offset.y
	b.offset_bottom = bottom_right_offset.y + button_size.y
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15 if button_size.x > 80.0 else 22)
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.025, 0.075, 0.12, 0.90)
	normal_style.border_color = Color(0.18, 0.55, 0.78, 0.95)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(12)
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.08, 0.28, 0.42, 0.98)
	pressed_style.border_color = Color(0.35, 0.82, 1.0, 1.0)
	pressed_style.set_border_width_all(2)
	pressed_style.set_corner_radius_all(12)
	b.add_theme_stylebox_override("normal", normal_style)
	b.add_theme_stylebox_override("hover", normal_style)
	b.add_theme_stylebox_override("pressed", pressed_style)
	b.add_theme_color_override("font_color", Color(0.91, 0.97, 1.0))
	b.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
	hud_layer.add_child(b)
	b.button_down.connect(on_down)
	if on_up.is_valid():
		b.button_up.connect(on_up)
	if label_text == "USAR / BAJAR":
		b.pressed.connect(_interact_vehicle)
	elif label_text == "LUCES":
		b.pressed.connect(_toggle_emergency_lights)

func _toggle_emergency_lights() -> void:
	emergency_lights_enabled = not emergency_lights_enabled
	if is_instance_valid(patrol_red_light):
		patrol_red_light.visible = emergency_lights_enabled and lights_red
	if is_instance_valid(patrol_blue_light):
		patrol_blue_light.visible = emergency_lights_enabled and not lights_red
	if is_instance_valid(status_label):
		status_label.text = "LUCES DE EMERGENCIA: " + ("ACTIVADAS" if emergency_lights_enabled else "DESACTIVADAS")

func _interact_vehicle() -> void:
	if not game_active or not is_instance_valid(player) or not is_instance_valid(vehicle):
		return
	if driving:
		driving = false
		vehicle_speed = 0.0
		player.visible = true
		player.global_position = vehicle.global_position + vehicle.global_transform.basis.x * 2.0 + Vector3(0,0.1,0)
		player.velocity = Vector3.ZERO
		camera_pivot.reparent(player)
		camera_pivot.position = Vector3(0,1.55,0)
		camera_pivot.rotation = Vector3.ZERO
		camera.position = Vector3(0,1.0,5.5)
	else:
		if player.global_position.distance_to(vehicle.global_position) <= 5.0:
			driving = true
			player.visible = false
			camera_pivot.reparent(vehicle)
			camera_pivot.position = Vector3(0,2.0,0)
			camera_pivot.rotation = Vector3.ZERO
			camera.position = Vector3(0,2.0,7.0)
		else:
			status_label.text = "Acércate al camión de bomberos para subir"

func _physics_process(delta: float) -> void:
	if not game_active:
		return
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): input_dir.x += 1.0
	input_dir += touch_move
	input_dir = input_dir.limit_length(1.0)
	if driving:
		if fuel_level <= 0.0:
			vehicle_speed = move_toward(vehicle_speed, 0.0, PATROL_BRAKING * delta)
			input_dir.y = 0.0
		var throttle := -input_dir.y
		var steer := input_dir.x
		var braking := Input.is_key_pressed(KEY_SPACE) or touch_brake
		# Speed changes smoothly. Reversing is deliberately slower than forward driving.
		if braking:
			vehicle_speed = move_toward(vehicle_speed, 0.0, PATROL_BRAKING * delta)
		elif absf(throttle) > 0.01:
			var target_speed := PATROL_MAX_FORWARD_SPEED if throttle > 0.0 else -PATROL_MAX_REVERSE_SPEED
			target_speed *= absf(throttle)
			var changing_direction := absf(vehicle_speed) > 0.5 and signf(vehicle_speed) != signf(target_speed)
			var acceleration := PATROL_BRAKING if changing_direction else PATROL_ACCELERATION
			vehicle_speed = move_toward(vehicle_speed, target_speed, acceleration * delta)
		else:
			# Engine drag gradually slows the fire engine when the accelerator is released.
			vehicle_speed = move_toward(vehicle_speed, 0.0, PATROL_COAST_DECELERATION * delta)
		if fuel_level <= 0.0:
			vehicle_speed = move_toward(vehicle_speed, 0.0, PATROL_BRAKING * delta)
		elif absf(vehicle_speed) > 0.5:
			fuel_level = maxf(0.0, fuel_level - delta * (0.012 + absf(vehicle_speed) * 0.0008))
		# Smooth steering prevents abrupt keyboard/touch direction changes.
		vehicle_steering = move_toward(vehicle_steering, steer, 3.8 * delta)
		if absf(vehicle_speed) > 0.05 and absf(vehicle_steering) > 0.01:
			var yaw_rate := vehicle_steering * PATROL_STEERING_CURVATURE * vehicle_speed
			vehicle.rotate_y(-yaw_rate * delta)
		var forward := -vehicle.global_transform.basis.z
		vehicle.velocity.x = forward.x * vehicle_speed
		vehicle.velocity.z = forward.z * vehicle_speed
		vehicle.velocity.y = 0.0
		vehicle.move_and_slide()
		vehicle.position.x = clampf(vehicle.position.x, -WORLD_LIMIT, WORLD_LIMIT)
		vehicle.position.z = clampf(vehicle.position.z, -WORLD_LIMIT, WORLD_LIMIT)
		return
	var direction := player.global_transform.basis.x * input_dir.x + -player.global_transform.basis.z * input_dir.y
	direction.y = 0
	direction = direction.normalized()
	var speed := RUN_SPEED if (Input.is_key_pressed(KEY_SHIFT) or touch_run) else WALK_SPEED
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	if not player.is_on_floor():
		player.velocity.y -= 20.0 * delta
	else:
		player.velocity.y = 0
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -WORLD_LIMIT, WORLD_LIMIT)
	player.position.z = clampf(player.position.z, -WORLD_LIMIT, WORLD_LIMIT)
	var planar_speed := Vector2(player.velocity.x, player.velocity.z).length()
	# The included male OBJ is unrigged, so use subtle procedural movement instead of a missing AnimationPlayer.
	if is_instance_valid(player_visual):
		if planar_speed < 0.2:
			player_visual.position.y = move_toward(player_visual.position.y, 0.0, delta * 0.8)
			player_visual.rotation.z = move_toward(player_visual.rotation.z, 0.0, delta * 1.8)
		else:
			player_anim_clock += delta * (11.0 if speed > WALK_SPEED else 7.5)
			player_visual.position.y = absf(sin(player_anim_clock * 2.0)) * (0.035 if speed > WALK_SPEED else 0.018)
			player_visual.rotation.z = sin(player_anim_clock) * (0.035 if speed > WALK_SPEED else 0.02)

func _unhandled_input(event: InputEvent) -> void:
	if not game_active:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.keycode == KEY_E:
			_interact_vehicle()
		elif event.keycode == KEY_F:
			_toggle_extinguishing()
		elif event.keycode == KEY_G:
			_try_refuel()
	if event is InputEventMouseButton and event.pressed and not OS.has_feature("mobile"):
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(event.relative)
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x >= get_viewport().get_visible_rect().size.x * 0.45:
			look_touch_id = event.index
			last_touch_position = event.position
		elif not event.pressed and event.index == look_touch_id:
			look_touch_id = -1
	if event is InputEventScreenDrag and event.index == look_touch_id:
		_rotate_camera(event.relative)

func _rotate_camera(relative_motion: Vector2) -> void:
	if not is_instance_valid(player) or not is_instance_valid(camera_pivot):
		return
	if driving and is_instance_valid(vehicle):
		# Mouse/touch drag orbits the driving camera; steering stays on A/D or the touch pad.
		camera_pivot.rotate_y(-relative_motion.x * mouse_sensitivity)
	else:
		player.rotate_y(-relative_motion.x * mouse_sensitivity)
	var vertical := 1.0 if invert_camera else -1.0
	camera_pivot.rotate_x(relative_motion.y * mouse_sensitivity * vertical)
	camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, deg_to_rad(-60), deg_to_rad(45))

func _toggle_pause_menu() -> void:
	if not game_active:
		return
	get_tree().paused = not get_tree().paused
	var popup := AcceptDialog.new()
	popup.process_mode = Node.PROCESS_MODE_ALWAYS
	popup.title = "Fire Department Simulator"
	popup.dialog_text = "Fire Department Simulator pausado. Pulsa PAUSA para continuar."
	add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(func(): get_tree().paused = false; popup.queue_free())
