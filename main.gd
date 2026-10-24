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

func _ready() -> void:
	rng.randomize()
	_create_menu()
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
	if is_instance_valid(status_label):
		status_label.text = ("CONDUCIENDO — WASD / controles táctiles" if driving else "A PIE — WASD para moverte · E para usar el vehículo") + "   |   NPC: " + str(npc_nodes.size())

func _create_menu() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.name = "MenuLayer"
	add_child(menu_layer)
	var background := ColorRect.new()
	background.color = Color(0.012, 0.022, 0.045)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(background)
	var glow := ColorRect.new()
	glow.anchor_left = 0.0
	glow.anchor_right = 1.0
	glow.anchor_top = 0.35
	glow.anchor_bottom = 0.9
	glow.color = Color(0.035, 0.12, 0.28, 0.55)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(glow)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(center)
	menu_panel = VBoxContainer.new()
	menu_panel.custom_minimum_size = Vector2(310, 0)
	menu_panel.add_theme_constant_override("separation", 12)
	center.add_child(menu_panel)
	_show_main_menu()

func _clear_menu() -> void:
	for child in menu_panel.get_children():
		menu_panel.remove_child(child)
		child.queue_free()
	red_light = null
	blue_light = null

func _add_title() -> void:
	var lights := HBoxContainer.new()
	lights.alignment = BoxContainer.ALIGNMENT_CENTER
	lights.add_theme_constant_override("separation", 16)
	menu_panel.add_child(lights)
	red_light = ColorRect.new()
	red_light.custom_minimum_size = Vector2(68, 10)
	red_light.color = Color.RED
	lights.add_child(red_light)
	blue_light = ColorRect.new()
	blue_light.custom_minimum_size = Vector2(68, 10)
	blue_light.color = Color.BLUE
	lights.add_child(blue_light)
	var title := Label.new()
	title.text = "POLICE OFFICER\nSIMULATOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 31)
	title.add_theme_color_override("font_color", Color.WHITE)
	menu_panel.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "MIRAGE HILLS POLICE DEPARTMENT"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.72, 0.95))
	menu_panel.add_child(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size.y = 12
	menu_panel.add_child(gap)

func _add_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(290, 48)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.045, 0.09, 0.16)
	normal.border_color = Color(0.15, 0.38, 0.72)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.09, 0.19, 0.32)
	hover.border_color = Color(0.3, 0.58, 1.0)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(5)
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
	_create_npcs(14)
	_create_hud()
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
			var h := rng.randf_range(5.0, 13.0)
			var size_x := rng.randf_range(9.0, 14.0)
			var size_z := rng.randf_range(9.0, 14.0)
			_box("Building", Vector3(size_x, h, size_z), Vector3(x, h / 2.0, z), colors[rng.randi_range(0, colors.size()-1)], true)
			# Simple facade windows on the street-facing side.
			for floor_index in range(1, int(h / 2.5)):
				for window_index in range(2):
					_box("Window", Vector3(1.2, 0.8, 0.06), Vector3(x - 2.5 + window_index * 5.0, floor_index * 2.3, z - size_z / 2.0 - 0.04), Color(0.14, 0.28, 0.38), false)

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

func _make_person(female: bool, police: bool) -> Node3D:
	var person := Node3D.new()
	var uniform := Color(0.07, 0.12, 0.23) if police else Color(rng.randf_range(0.25,0.85), rng.randf_range(0.25,0.8), rng.randf_range(0.25,0.8))
	_add_person_box(person, Vector3(0.55, 0.75, 0.3), Vector3(0, 1.0, 0), uniform)
	_add_person_box(person, Vector3(0.22, 0.55, 0.24), Vector3(-0.19, 0.36, 0), uniform.darkened(0.12))
	_add_person_box(person, Vector3(0.22, 0.55, 0.24), Vector3(0.19, 0.36, 0), uniform.darkened(0.12))
	_add_person_box(person, Vector3(0.17, 0.55, 0.18), Vector3(-0.39, 1.0, 0), uniform)
	_add_person_box(person, Vector3(0.17, 0.55, 0.18), Vector3(0.39, 1.0, 0), uniform)
	_sphere_child(person, Vector3(0, 1.65, 0), 0.25, Color(0.72,0.53,0.4))
	if police:
		_add_person_box(person, Vector3(0.22, 0.13, 0.05), Vector3(0, 1.12, -0.17), Color(0.85,0.72,0.2))
	return person

func _add_person_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
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

func _create_npcs(count: int) -> void:
	npc_nodes.clear()
	npc_targets.clear()
	for i in range(count):
		var npc := Node3D.new()
		npc.name = "CivilianNPC_%02d" % i
		var x := rng.randf_range(-85, 85)
		var z := rng.randf_range(-85, 85)
		if absf(x) < 10:
			x += 18
		npc.position = Vector3(x, 0, z)
		npc.add_child(_make_person(false, false))
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
	_touch_button("▲", Vector2(24, -160), Vector2(66, 60), func(): touch_move.y = -1.0, func(): if touch_move.y < 0: touch_move.y = 0.0)
	_touch_button("▼", Vector2(24, -88), Vector2(66, 60), func(): touch_move.y = 1.0, func(): if touch_move.y > 0: touch_move.y = 0.0)
	_touch_button("◀", Vector2(96, -88), Vector2(66, 60), func(): touch_move.x = -1.0, func(): if touch_move.x < 0: touch_move.x = 0.0)
	_touch_button("▶", Vector2(168, -88), Vector2(66, 60), func(): touch_move.x = 1.0, func(): if touch_move.x > 0: touch_move.x = 0.0)
	_touch_button("CORRER", Vector2(-150, -100), Vector2(120, 54), func(): touch_run = true, func(): touch_run = false, true)
	_touch_button("USAR / BAJAR", Vector2(-150, -38), Vector2(120, 54), _interact_vehicle, Callable(), true)

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
		vehicle.rotate_y(-steer * delta * 1.2)
		var forward := -vehicle.global_transform.basis.z
		vehicle.velocity.x = forward.x * throttle * 18.0
		vehicle.velocity.z = forward.z * throttle * 18.0
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
		player.rotate_y(-event.relative.x * mouse_sensitivity)
		var vertical := 1.0 if invert_camera else -1.0
		camera_pivot.rotate_x(event.relative.y * mouse_sensitivity * vertical)
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, deg_to_rad(-60), deg_to_rad(45))

func _toggle_pause_menu() -> void:
	if not game_active:
		return
	get_tree().paused = not get_tree().paused
	var popup := AcceptDialog.new()
	popup.title = "Police Officer Simulator"
	popup.dialog_text = "Juego pausado. Pulsa PAUSA para continuar."
	add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(func(): get_tree().paused = false; popup.queue_free())
