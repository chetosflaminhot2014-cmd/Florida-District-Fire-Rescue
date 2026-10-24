extends Node3D

# Police Officer Simulator — lightweight procedural prototype for PC and Android.
# No external assets are required; missing officer models are replaced by generated characters.

const WORLD_LIMIT := 92.0
const WALK_SPEED := 5.0
const RUN_SPEED := 8.0

var menu_layer: CanvasLayer
var menu_panel: VBoxContainer
var game_world: Node3D
var player: CharacterBody3D
var camera_pivot: Node3D
var camera: Camera3D
var vehicle: CharacterBody3D
var player_visual: Node3D
var hud_layer: CanvasLayer
var status_label: Label
var game_active := false
var driving := false
var invert_camera := false
var mouse_sensitivity := 0.002
var move_speed := WALK_SPEED
var vehicle_speed := 0.0
var light_timer := 0.0
var lights_red := true
var red_light: ColorRect
var blue_light: ColorRect
var touch_move := Vector2.ZERO
var touch_run := false
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

func _ready() -> void:
	rng.randomize()
	_create_menu()
	if has_node("/root/MultiplayerLobby"):
		MultiplayerLobby.peer_joined.connect(_on_peer_joined)
		MultiplayerLobby.peer_left.connect(_on_peer_left)
		MultiplayerLobby.remote_state_received.connect(_on_remote_state_received)
		MultiplayerLobby.network_status_changed.connect(_on_network_status_changed)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	if not game_active:
		light_timer += delta
		if light_timer >= 0.3:
			light_timer = 0.0
			lights_red = not lights_red
			if is_instance_valid(red_light):
				red_light.color = Color(1.0, 0.02, 0.02) if lights_red else Color(0.22, 0.0, 0.0)
			if is_instance_valid(blue_light):
				blue_light.color = Color(0.02, 0.2, 1.0) if not lights_red else Color(0.0, 0.03, 0.22)
		return
	_update_npcs(delta)
	_update_remote_network(delta)
	if is_instance_valid(status_label):
		status_label.text = ("CONDUCIENDO — WASD / controles táctiles" if driving else "A PIE — WASD para moverte · E para usar el vehículo") + "   |   NPC: " + str(npc_nodes.size())

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
	status.text = "MIRAGE HILLS  /  PATROL DIVISION"
	status.add_theme_font_size_override("font_size", 13)
	status.add_theme_color_override("font_color", Color(0.35, 0.72, 1.0))
	info.add_child(status)
	var scene_title := Label.new()
	scene_title.text = "YOUR CITY.\nYOUR SHIFT."
	scene_title.add_theme_font_size_override("font_size", 34)
	scene_title.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	info.add_child(scene_title)
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.13, 0.49, 0.78)
	info.add_child(divider)
	var description := Label.new()
	description.text = "Respond to calls, patrol the streets,\nand work together as one unit."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 17)
	description.add_theme_color_override("font_color", Color(0.68, 0.76, 0.84))
	info.add_child(description)
	var feature_gap := Control.new()
	feature_gap.custom_minimum_size.y = 18
	info.add_child(feature_gap)
	for feature in ["01  OPEN-WORLD CITY", "02  EMERGENCY DISPATCH", "03  MULTIPLAYER PATROL"]:
		var feature_label := Label.new()
		feature_label.text = feature
		feature_label.add_theme_font_size_override("font_size", 14)
		feature_label.add_theme_color_override("font_color", Color(0.8, 0.87, 0.94))
		info.add_child(feature_label)
	var footer := Label.new()
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
	title.text = "POLICE OFFICER\nSIMULATOR"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	menu_panel.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "MIRAGE HILLS POLICE DEPARTMENT"
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
	label.text = "ELIGE A TU OFICIAL"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 19)
	menu_panel.add_child(label)
	_add_button("OFICIAL MASCULINO", func(): _start_game(false))
	_add_button("OFICIAL FEMENINA", func(): _start_game(true))
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
	credits.text = "POLICE OFFICER SIMULATOR\n\nCiudad ficticia de Mirage Hills\nProyecto independiente en Godot 4"
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
	_create_npcs(18)
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
	_box("Ground", Vector3(200, 1, 200), Vector3(0, -0.55, 0), Color(0.19, 0.29, 0.19), true)
	# A cross-shaped road grid with sidewalks, intersections, markings, and parking bays.
	for z in [-60.0, -30.0, 0.0, 30.0, 60.0]:
		_box("Street_NS", Vector3(12, 0.08, 200), Vector3(z, 0.0, 0), Color(0.105, 0.12, 0.14), false)
		_box("Sidewalk_L", Vector3(2.0, 0.18, 200), Vector3(z - 7.0, 0.05, 0), Color(0.48, 0.49, 0.48), false)
		_box("Sidewalk_R", Vector3(2.0, 0.18, 200), Vector3(z + 7.0, 0.05, 0), Color(0.48, 0.49, 0.48), false)
	for x in [-60.0, -30.0, 0.0, 30.0, 60.0]:
		_box("Street_EW", Vector3(200, 0.08, 12), Vector3(0, 0.015, x), Color(0.105, 0.12, 0.14), false)
		_box("Sidewalk_T", Vector3(200, 0.18, 2.0), Vector3(0, 0.05, x - 7.0), Color(0.48, 0.49, 0.48), false)
		_box("Sidewalk_B", Vector3(200, 0.18, 2.0), Vector3(0, 0.05, x + 7.0), Color(0.48, 0.49, 0.48), false)
	for z in range(-90, 100, 8):
		for x in [-60.0, -30.0, 0.0, 30.0, 60.0]:
			_box("CenterLine", Vector3(0.16, 0.025, 3.4), Vector3(x, 0.06, float(z)), Color(0.95, 0.82, 0.35), false)
	for x in range(-90, 100, 8):
		for z in [-60.0, -30.0, 0.0, 30.0, 60.0]:
			_box("CenterLine", Vector3(3.4, 0.025, 0.16), Vector3(float(x), 0.06, z), Color(0.95, 0.82, 0.35), false)
	_create_police_station()
	_create_city_blocks()
	_create_trees()

func _create_police_station() -> void:
	_box("PoliceStation", Vector3(17, 6, 11), Vector3(-20, 3, 18), Color(0.25, 0.31, 0.39), true)
	_box("StationEntrance", Vector3(5, 3.3, 0.25), Vector3(-20, 1.65, 12.35), Color(0.08, 0.13, 0.2), false)
	_box("StationSign", Vector3(8, 0.8, 0.2), Vector3(-20, 5.0, 12.15), Color(0.08, 0.2, 0.38), false)
	_box("StationParking", Vector3(24, 0.08, 16), Vector3(-20, 0.0, 4), Color(0.16, 0.17, 0.18), false)
	for i in range(3):
		_box("ParkingLine", Vector3(0.12, 0.025, 6), Vector3(-28 + i * 7, 0.06, 4), Color(0.9, 0.9, 0.82), false)

func _create_city_blocks() -> void:
	var colors: Array[Color] = [Color(0.48,0.48,0.46), Color(0.42,0.46,0.5), Color(0.56,0.48,0.39), Color(0.34,0.42,0.47), Color(0.55,0.56,0.53)]
	for x in [-75.0, -45.0, -15.0, 15.0, 45.0, 75.0]:
		for z in [-75.0, -45.0, -15.0, 15.0, 45.0, 75.0]:
			if absf(x) < 20 and absf(z - 18) < 18:
				continue
			var civic_name := ""
			if x == -45.0 and z == -45.0: civic_name = "CITY HALL"
			elif x == 45.0 and z == -45.0: civic_name = "MEDICAL CENTER"
			elif x == 45.0 and z == 45.0: civic_name = "FIRE DEPARTMENT"
			elif x == -75.0 and z == 45.0: civic_name = "PUBLIC LIBRARY"
			if not civic_name.is_empty():
				_create_civic_building(civic_name, Vector3(x, 0, z))
			else:
				_create_civilian_building(Vector3(x, 0, z), colors[rng.randi_range(0, colors.size()-1)])

func _create_civic_building(building_type: String, base_position: Vector3) -> void:
	var building_color := Color(0.66, 0.63, 0.55)
	var accent_color := Color(0.13, 0.22, 0.34)
	var width := 15.0
	var depth := 12.0
	var height := 7.0
	if building_type == "MEDICAL CENTER":
		building_color = Color(0.83, 0.85, 0.83)
		accent_color = Color(0.12, 0.48, 0.55)
		width = 14.0
		depth = 13.0
		height = 8.0
	elif building_type == "FIRE DEPARTMENT":
		building_color = Color(0.57, 0.16, 0.12)
		accent_color = Color(0.9, 0.72, 0.2)
		width = 15.0
		depth = 12.0
		height = 6.0
	elif building_type == "PUBLIC LIBRARY":
		building_color = Color(0.69, 0.57, 0.42)
		accent_color = Color(0.2, 0.32, 0.4)
		width = 13.0
		depth = 12.0
		height = 6.0
	_box(building_type.replace(" ", "_"), Vector3(width, height, depth), base_position + Vector3(0, height / 2.0, 0), building_color, true)
	_box("CivicRoof_" + building_type, Vector3(width + 0.8, 0.35, depth + 0.8), base_position + Vector3(0, height + 0.16, 0), accent_color, false)
	_box("Entrance_" + building_type, Vector3(3.2, 3.1, 0.22), base_position + Vector3(0, 1.55, -depth / 2.0 - 0.12), accent_color.darkened(0.4), false)
	_box("Sign_" + building_type, Vector3(minf(width - 2.0, 10.0), 0.65, 0.18), base_position + Vector3(0, height - 1.0, -depth / 2.0 - 0.15), accent_color, false)
	for window_x in [-4.0, 4.0]:
		for window_y in [2.2, 4.5]:
			_box("CivicWindow", Vector3(1.6, 1.1, 0.08), base_position + Vector3(window_x, window_y, -depth / 2.0 - 0.13), Color(0.18, 0.36, 0.47), false)
	if building_type == "MEDICAL CENTER":
		_box("MedicalCross", Vector3(0.45, 2.0, 0.16), base_position + Vector3(0, height - 1.3, -depth / 2.0 - 0.27), Color(0.88, 0.97, 0.95), false)
		_box("MedicalCrossBar", Vector3(1.5, 0.45, 0.16), base_position + Vector3(0, height - 1.3, -depth / 2.0 - 0.27), Color(0.88, 0.97, 0.95), false)

func _create_civilian_building(base_position: Vector3, building_color: Color) -> void:
	var height := rng.randf_range(5.0, 13.0)
	var size_x := rng.randf_range(9.0, 14.0)
	var size_z := rng.randf_range(9.0, 14.0)
	var style := rng.randi_range(0, 2)
	if style == 0:
		height = rng.randf_range(4.0, 6.0)
		size_x = rng.randf_range(8.0, 10.0)
		size_z = rng.randf_range(8.0, 11.0)
	_box("CivilianBuilding", Vector3(size_x, height, size_z), base_position + Vector3(0, height / 2.0, 0), building_color, true)
	var roof_color := building_color.darkened(0.28)
	if style == 0:
		# Techo a dos aguas simulado con una pieza elevada y aleros visibles.
		_box("HouseRoof", Vector3(size_x + 0.9, 0.35, size_z + 0.9), base_position + Vector3(0, height + 0.18, 0), roof_color, false)
	else:
		_box("BuildingRoof", Vector3(size_x + 0.5, 0.28, size_z + 0.5), base_position + Vector3(0, height + 0.14, 0), roof_color, false)
	# Fachada con ventanas separadas, marcos y puerta reconocible.
	var floors := max(1, int(height / 2.6))
	for floor_index in range(floors):
		for window_index in range(3):
			var wx := -size_x * 0.32 + window_index * size_x * 0.32
			var wy := 1.4 + floor_index * 2.35
			_box("WindowFrame", Vector3(1.45, 1.05, 0.16), base_position + Vector3(wx, wy, -size_z / 2.0 - 0.08), Color(0.88, 0.83, 0.68), false)
			_box("CivilianWindow", Vector3(1.18, 0.8, 0.08), base_position + Vector3(wx, wy, -size_z / 2.0 - 0.17), Color(0.12, 0.29, 0.4), false)
	_box("FrontDoor", Vector3(1.15, 2.15, 0.12), base_position + Vector3(0, 1.08, -size_z / 2.0 - 0.12), Color(0.18, 0.12, 0.08), false)
	if style == 0:
		_box("Porch", Vector3(2.8, 0.18, 1.2), base_position + Vector3(0, 0.12, -size_z / 2.0 - 0.6), Color(0.55, 0.52, 0.45), false)

func _create_trees() -> void:
	for i in range(34):
		var x := rng.randf_range(-88, 88)
		var z := rng.randf_range(-88, 88)
		if absf(fposmod(x + 15.0, 30.0) - 15.0) < 8.5 or absf(fposmod(z + 15.0, 30.0) - 15.0) < 8.5:
			continue
		_box("TreeTrunk", Vector3(0.45, 2.2, 0.45), Vector3(x, 1.1, z), Color(0.25, 0.15, 0.09), false)
		_sphere("TreeCanopy", Vector3(x, 2.9, z), 1.5, Color(0.12, 0.32, 0.16))

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
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh_node.material_override = mat
	root.add_child(mesh_node)
	return root

func _sphere(node_name: String, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	node.material_override = mat
	node.position = pos
	game_world.add_child(node)
	return node

func _create_player(female: bool) -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 0.2, 9)
	game_world.add_child(player)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	player.add_child(collider)
	player_visual = _make_person(female, true)
	player_visual.name = "PlayerOfficer"
	player_visual.position.y = 0.0
	player.add_child(player_visual)
	camera_pivot = Node3D.new()
	camera_pivot.position.y = 1.55
	player.add_child(camera_pivot)
	camera = Camera3D.new()
	camera.name = "FollowCamera"
	camera.position = Vector3(0, 1.0, 5.5)
	camera.rotation_degrees.x = -10
	camera.current = true
	camera_pivot.add_child(camera)

func _make_person(female: bool, police: bool, role: String = "civilian") -> Node3D:
	var person := Node3D.new()
	var model_path := "res://models/civilian.obj"
	if police or role == "sheriff":
		model_path = "res://models/officer.obj"
	elif role == "fire":
		model_path = "res://models/fire.obj"
	elif role == "ems":
		model_path = "res://models/ems.obj"
	var model_mesh := load(model_path) as Mesh
	if model_mesh != null:
		var model := MeshInstance3D.new()
		model.name = "CustomCharacterModel"
		model.mesh = model_mesh
		model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		person.add_child(model)
	else:
		# Fallback only if a model asset cannot be imported.
		_add_person_capsule(person, Vector3(0, 1.08, 0), 0.29, 0.72, Color(0.07, 0.12, 0.23))
		_sphere_child(person, Vector3(0, 1.64, 0), 0.22, Color(0.72, 0.53, 0.4))
	return person

func _add_person_capsule(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, angles := Vector3.ZERO) -> void:
	var mesh_node := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh_node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	mesh_node.material_override = material
	mesh_node.position = pos
	mesh_node.rotation_degrees = angles
	parent.add_child(mesh_node)

func _add_person_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	# Se conserva para detalles de vehículos; los personajes usan cápsulas.
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	m.material_override = material
	m.position = pos
	parent.add_child(m)

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
	vehicle = CharacterBody3D.new()
	vehicle.name = "PatrolCar"
	vehicle.position = Vector3(-20, 0.35, 3)
	game_world.add_child(vehicle)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 1.0, 4.2)
	shape_node.shape = shape
	shape_node.position.y = 0.55
	vehicle.add_child(shape_node)
	_add_person_box(vehicle, Vector3(2.0, 0.65, 4.2), Vector3(0, 0.5, 0), Color(0.86, 0.88, 0.9))
	_add_person_box(vehicle, Vector3(1.65, 0.6, 2.0), Vector3(0, 1.05, -0.15), Color(0.055, 0.09, 0.15))
	_add_person_box(vehicle, Vector3(0.55, 0.16, 0.45), Vector3(0, 1.42, -0.15), Color(0.04,0.04,0.05))
	_add_person_box(vehicle, Vector3(0.5, 0.18, 0.28), Vector3(-0.35, 1.42, -0.15), Color(0.9,0.04,0.04))
	_add_person_box(vehicle, Vector3(0.5, 0.18, 0.28), Vector3(0.35, 1.42, -0.15), Color(0.02,0.15,0.95))
	for x in [-0.9, 0.9]:
		for z in [-1.35, 1.35]:
			_sphere_child(vehicle, Vector3(x, 0.22, z), 0.28, Color(0.04,0.04,0.05))

func _create_service_vehicles() -> void:
	# Lightweight parked emergency-service vehicles for the prototype.
	var ambulance := _box("AmbulanceBody", Vector3(2.2, 1.5, 4.5), Vector3(8, 0.8, -18), Color(0.88, 0.9, 0.88), false)
	_box("AmbulanceCab", Vector3(2.05, 1.15, 1.8), Vector3(8, 1.95, -19.0), Color(0.75, 0.84, 0.87), false)
	_box("AmbulanceStripe", Vector3(2.23, 0.22, 3.0), Vector3(8, 0.95, -18), Color(0.75, 0.08, 0.07), false)
	_box("AmbulanceLightbar", Vector3(1.0, 0.16, 0.35), Vector3(8, 2.58, -19.0), Color(0.05, 0.2, 0.95), false)
	var fire_truck := _box("FireEngineBody", Vector3(2.5, 1.65, 5.0), Vector3(15, 0.9, -18), Color(0.68, 0.055, 0.035), false)
	_box("FireEngineCab", Vector3(2.35, 1.35, 1.8), Vector3(15, 2.0, -19.3), Color(0.72, 0.07, 0.04), false)
	_box("FireEngineStripe", Vector3(2.53, 0.18, 3.2), Vector3(15, 1.05, -18), Color(0.92, 0.78, 0.16), false)
	_box("FireEngineLightbar", Vector3(1.0, 0.16, 0.35), Vector3(15, 2.75, -19.3), Color(0.05, 0.2, 0.95), false)

func _create_npcs(count: int) -> void:
	npc_nodes.clear()
	npc_targets.clear()
	for i in range(count):
		var npc := Node3D.new()
		var role := "civilian"
		if i == 0 or i == 1: role = "sheriff"
		elif i == 2 or i == 3: role = "ems"
		elif i == 4 or i == 5: role = "fire"
		npc.name = role.to_upper() + "_NPC_%02d" % i
		var x := rng.randf_range(-85, 85)
		var z := rng.randf_range(-85, 85)
		if absf(x) < 10:
			x += 18
		npc.position = Vector3(x, 0, z)
		npc.add_child(_make_person(false, role == "sheriff", role))
		game_world.add_child(npc)
		npc_nodes.append(npc)
		npc_targets.append(Vector3(rng.randf_range(-85,85), 0, rng.randf_range(-85,85)))

func _update_npcs(delta: float) -> void:
	for i in range(npc_nodes.size()):
		var npc := npc_nodes[i]
		if not is_instance_valid(npc):
			continue
		var target := npc_targets[i]
		var offset: Vector3 = target - npc.position
		offset.y = 0
		if offset.length() < 2.0:
			npc_targets[i] = Vector3(rng.randf_range(-85,85), 0, rng.randf_range(-85,85))
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
	remote.add_child(_make_person(false, true, "sheriff"))
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
	# Touch controls are always visible on Android and harmless on PC.
	_touch_button("▲", Vector2(24, -160), Vector2(66, 60), func(): touch_move.y = -1.0, func(): touch_move.y = 0.0)
	_touch_button("▼", Vector2(24, -88), Vector2(66, 60), func(): touch_move.y = 1.0, func(): touch_move.y = 0.0)
	_touch_button("◀", Vector2(96, -88), Vector2(66, 60), func(): touch_move.x = -1.0, func(): touch_move.x = 0.0)
	_touch_button("▶", Vector2(168, -88), Vector2(66, 60), func(): touch_move.x = 1.0, func(): touch_move.x = 0.0)
	_touch_button("CORRER", Vector2(-150, -100), Vector2(120, 54), func(): touch_run = true, func(): touch_run = false, true)
	_touch_button("USAR / BAJAR", Vector2(-150, -38), Vector2(120, 54), func(): pass, Callable(), true)

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
	b.modulate = Color(0.78, 0.88, 1.0, 0.86)
	hud_layer.add_child(b)
	b.button_down.connect(on_down)
	if on_up.is_valid():
		b.button_up.connect(on_up)
	if label_text == "USAR / BAJAR":
		b.pressed.connect(_interact_vehicle)

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
		camera.position = Vector3(0,1.0,5.5)
	else:
		if player.global_position.distance_to(vehicle.global_position) <= 5.0:
			driving = true
			player.visible = false
			camera_pivot.reparent(vehicle)
			camera_pivot.position = Vector3(0,2.0,0)
			camera.position = Vector3(0,2.0,7.0)
		else:
			status_label.text = "Acércate al coche patrulla para entrar"

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
		var throttle := -input_dir.y
		var steer := input_dir.x
		# Aceleración y frenado progresivos; el coche no cambia de velocidad instantáneamente.
		var target_speed := throttle * 16.0
		var acceleration := 9.0 if absf(throttle) > 0.01 else 5.0
		vehicle_speed = move_toward(vehicle_speed, target_speed, acceleration * delta)
		if absf(vehicle_speed) > 0.25:
			var steering_factor := clampf(absf(vehicle_speed) / 5.0, 0.25, 1.0)
			vehicle.rotate_y(-steer * delta * 1.35 * steering_factor * signf(vehicle_speed))
		var forward := -vehicle.global_transform.basis.z
		vehicle.velocity.x = forward.x * vehicle_speed
		vehicle.velocity.z = forward.z * vehicle_speed
		vehicle.velocity.y = 0
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
	if event is InputEventMouseButton and event.pressed and not OS.has_feature("mobile"):
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not driving:
		_rotate_camera(event.relative)
	if event is InputEventScreenTouch:
		if event.pressed:
			look_touch_id = event.index
			last_touch_position = event.position
		elif event.index == look_touch_id:
			look_touch_id = -1
	if event is InputEventScreenDrag and event.index == look_touch_id and not driving:
		_rotate_camera(event.relative)

func _rotate_camera(relative_motion: Vector2) -> void:
	if not is_instance_valid(player) or not is_instance_valid(camera_pivot):
		return
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
	popup.title = "Police Officer Simulator"
	popup.dialog_text = "Juego pausado. Pulsa PAUSA para continuar."
	add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(func(): get_tree().paused = false; popup.queue_free())
