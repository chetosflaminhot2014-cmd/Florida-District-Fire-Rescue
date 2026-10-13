
extends Node3D

const MALE_OFFICER: PackedScene = preload("res://Models/Officer-Male/source/officer-men.glb")
const FEMALE_OFFICER: PackedScene = preload("res://Models/Officer-Femal/source/officer-woman.glb")

var menu_layer: CanvasLayer
var menu_panel: VBoxContainer
var title_label: Label

var red_light: ColorRect
var blue_light: ColorRect
var light_timer: float = 0.0
var lights_red: bool = true

var player: CharacterBody3D
var camera_pivot: Node3D
var game_world: Node3D

var game_active: bool = false
var invert_camera: bool = false
var mouse_sensitivity: float = 0.002
var move_speed: float = 5.0


func _ready() -> void:
	_create_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	if not is_instance_valid(menu_layer) or not menu_layer.visible:
		return

	light_timer += delta

	if light_timer >= 0.3:
		light_timer = 0.0
		lights_red = not lights_red

		if is_instance_valid(red_light):
			red_light.color = Color(1.0, 0.02, 0.02) if lights_red else Color(0.22, 0.0, 0.0)

		if is_instance_valid(blue_light):
			blue_light.color = Color(0.02, 0.2, 1.0) if not lights_red else Color(0.0, 0.03, 0.22)


# ==================================================
# MENU Y FONDO POLICIAL
# ==================================================

func _create_menu() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.name = "MenuLayer"
	add_child(menu_layer)

	var background := ColorRect.new()
	background.color = Color(0.015, 0.025, 0.055)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(background)

	_add_glow(0.0, 0.42, Color(0.02, 0.12, 0.55, 0.22))
	_add_glow(0.58, 0.42, Color(0.55, 0.015, 0.035, 0.20))
	_add_city_silhouette()
	_add_decoration_line(0.12, 0.08, 0.76, Color(0.1, 0.35, 0.8, 0.8))
	_add_decoration_line(0.12, 0.92, 0.76, Color(0.1, 0.35, 0.8, 0.8))

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(center)

	menu_panel = VBoxContainer.new()
	menu_panel.custom_minimum_size = Vector2(360, 400)
	menu_panel.add_theme_constant_override("separation", 16)
	center.add_child(menu_panel)

	_show_main_menu()


func _add_glow(x: float, width: float, glow_color: Color) -> void:
	var glow := ColorRect.new()
	glow.anchor_left = x
	glow.anchor_right = x + width
	glow.anchor_bottom = 1.0
	glow.color = glow_color
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(glow)


func _add_decoration_line(x: float, y: float, width: float, line_color: Color) -> void:
	var line := ColorRect.new()
	line.anchor_left = x
	line.anchor_top = y
	line.anchor_right = x + width
	line.anchor_bottom = y
	line.offset_bottom = 2.0
	line.color = line_color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(line)


func _add_city_silhouette() -> void:
	var screen_size := get_viewport().get_visible_rect().size

	var buildings: Array[Vector4] = [
		Vector4(0.00, 0.32, 0.09, 0.68),
		Vector4(0.09, 0.44, 0.08, 0.56),
		Vector4(0.17, 0.27, 0.07, 0.73),
		Vector4(0.25, 0.48, 0.08, 0.52),
		Vector4(0.67, 0.40, 0.08, 0.60),
		Vector4(0.75, 0.24, 0.09, 0.76),
		Vector4(0.84, 0.38, 0.08, 0.62),
		Vector4(0.92, 0.28, 0.08, 0.72)
	]

	for data in buildings:
		var building := ColorRect.new()
		building.position = Vector2(data.x * screen_size.x, data.y * screen_size.y)
		building.size = Vector2(data.z * screen_size.x, data.w * screen_size.y)
		building.color = Color(0.025, 0.045, 0.085, 0.98)
		building.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu_layer.add_child(building)

		for row in range(3, 7):
			for col in range(2):
				var window_light := ColorRect.new()
				window_light.position = Vector2(
					building.position.x + 12 + col * 24,
					building.position.y + row * 20
				)
				window_light.size = Vector2(7, 9)

				if (row + col) % 2 == 0:
					window_light.color = Color(0.12, 0.32, 0.65, 0.65)
				else:
					window_light.color = Color(0.65, 0.12, 0.12, 0.55)

				window_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
				menu_layer.add_child(window_light)

	var bottom := ColorRect.new()
	bottom.anchor_top = 0.88
	bottom.anchor_right = 1.0
	bottom.anchor_bottom = 1.0
	bottom.color = Color(0.015, 0.025, 0.045)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(bottom)


func _clear_menu() -> void:
	for child in menu_panel.get_children():
		menu_panel.remove_child(child)
		child.free()

	title_label = null
	red_light = null
	blue_light = null


func _add_title() -> void:
	var light_row := HBoxContainer.new()
	light_row.alignment = BoxContainer.ALIGNMENT_CENTER
	light_row.add_theme_constant_override("separation", 18)
	menu_panel.add_child(light_row)

	red_light = ColorRect.new()
	red_light.custom_minimum_size = Vector2(75, 14)
	red_light.color = Color.RED
	red_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	light_row.add_child(red_light)

	blue_light = ColorRect.new()
	blue_light.custom_minimum_size = Vector2(75, 14)
	blue_light.color = Color.BLUE
	blue_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	light_row.add_child(blue_light)

	var space := Control.new()
	space.custom_minimum_size.y = 8
	menu_panel.add_child(space)

	title_label = Label.new()
	title_label.text = "POLICE OFFICER\nSIMULATOR"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	menu_panel.add_child(title_label)

	var subtitle := Label.new()
	subtitle.text = "MIRAGE HILLS POLICE DEPARTMENT"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.75, 0.9))
	menu_panel.add_child(subtitle)

	var space_bottom := Control.new()
	space_bottom.custom_minimum_size.y = 18
	menu_panel.add_child(space_bottom)


func _add_button(button_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(300, 52)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 18)
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.055, 0.11, 0.20)
	normal.border_color = Color(0.15, 0.38, 0.72)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(5)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.12, 0.24, 0.40)
	hover.border_color = Color(0.3, 0.58, 1.0)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(5)

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.16, 0.3, 0.48)
	pressed_style.set_corner_radius_all(5)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)

	button.pressed.connect(callback)
	menu_panel.add_child(button)
	return button


func _show_main_menu() -> void:
	_clear_menu()
	_add_title()
	_add_button("PLAY", _show_character_selection)
	_add_button("CONFIGURATIONS", _show_settings)
	_add_button("CREDITS", _show_credits)


# ==================================================
# SELECCION DE PERSONAJE
# ==================================================

func _show_character_selection() -> void:
	_clear_menu()
	_add_title()

	var heading := Label.new()
	heading.text = "SELECT YOUR OFFICER"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 20)
	menu_panel.add_child(heading)

	var description := Label.new()
	description.text = "Choose your character"
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	menu_panel.add_child(description)

	_add_button("MALE OFFICER", func() -> void: _start_game(MALE_OFFICER))
	_add_button("FEMALE OFFICER", func() -> void: _start_game(FEMALE_OFFICER))
	_add_button("BACK", _show_main_menu)


# ==================================================
# CONFIGURACIONES
# ==================================================

func _show_settings() -> void:
	_clear_menu()
	_add_title()

	var heading := Label.new()
	heading.text = "CONFIGURATIONS"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 21)
	menu_panel.add_child(heading)

	var volume_label := Label.new()
	volume_label.text = "MASTER VOLUME"
	volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_panel.add_child(volume_label)

	var volume_slider := HSlider.new()
	volume_slider.custom_minimum_size = Vector2(280, 28)
	volume_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.value = 80
	volume_slider.value_changed.connect(_set_volume)
	menu_panel.add_child(volume_slider)

	var sensitivity_label := Label.new()
	sensitivity_label.text = "MOUSE SENSITIVITY"
	sensitivity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_panel.add_child(sensitivity_label)

	var sensitivity_slider := HSlider.new()
	sensitivity_slider.custom_minimum_size = Vector2(280, 28)
	sensitivity_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sensitivity_slider.min_value = 0.5
	sensitivity_slider.max_value = 5.0
	sensitivity_slider.step = 0.1
	sensitivity_slider.value = mouse_sensitivity * 1000.0
	sensitivity_slider.value_changed.connect(
		func(value: float) -> void:
			mouse_sensitivity = value / 1000.0
	)
	menu_panel.add_child(sensitivity_slider)

	var invert_button := CheckButton.new()
	invert_button.text = "Invert camera vertically"
	invert_button.button_pressed = invert_camera
	invert_button.toggled.connect(
		func(value: bool) -> void:
			invert_camera = value
	)
	menu_panel.add_child(invert_button)

	_add_button("BACK", _show_main_menu)


func _set_volume(value: float) -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index >= 0:
		if value <= 0.0:
			AudioServer.set_bus_volume_db(bus_index, -80.0)
		else:
			AudioServer.set_bus_volume_db(bus_index, linear_to_db(value / 100.0))


# ==================================================
# CREDITOS
# ==================================================

func _show_credits() -> void:
	_clear_menu()
	_add_title()

	var heading := Label.new()
	heading.text = "CREDITS"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 23)
	menu_panel.add_child(heading)

	var credits := Label.new()
	credits.text = "POLICE OFFICER SIMULATOR\n\nA fictional police simulation\nMirage Hills Police Department\n\nDeveloped with Godot Engine"
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.add_theme_font_size_override("font_size", 15)
	menu_panel.add_child(credits)

	_add_button("BACK", _show_main_menu)


# ==================================================
# PARTIDA Y CIUDAD
# ==================================================

func _start_game(character_scene: PackedScene) -> void:
	if game_active:
		return

	game_active = true
	menu_layer.visible = false

	game_world = Node3D.new()
	game_world.name = "GameWorld"
	add_child(game_world)

	_create_world()
	_create_player(character_scene)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _create_world() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.45, 0.62, 0.8)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.65, 0.7, 0.8)
	environment.ambient_light_energy = 0.8
	environment_node.environment = environment
	game_world.add_child(environment_node)

	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-50, -30, 0)
	sunlight.light_energy = 1.1
	sunlight.shadow_enabled = false
	game_world.add_child(sunlight)

	_create_box("Ground", Vector3(100, 1, 100), Vector3(0, -0.5, 0), Color(0.18, 0.22, 0.20), true)
	_create_box("MainRoad", Vector3(12, 0.08, 100), Vector3(0, 0.04, 0), Color(0.12, 0.13, 0.15), false)
	_create_box("CrossRoad", Vector3(100, 0.08, 12), Vector3(0, 0.05, -18), Color(0.12, 0.13, 0.15), false)

	for z in range(-45, 50, 8):
		_create_box("RoadLine", Vector3(0.18, 0.03, 3.5), Vector3(0, 0.1, z), Color(0.95, 0.85, 0.35), false)

	var building_colors: Array[Color] = [
		Color(0.35, 0.39, 0.44),
		Color(0.42, 0.43, 0.46),
		Color(0.28, 0.34, 0.42),
		Color(0.48, 0.45, 0.4)
	]

	for i in range(8):
		var z_position := -35.0 + float(i) * 10.0
		var height := 5.0 + float((i * 7) % 5) * 1.5
		var building_color: Color = building_colors[i % building_colors.size()]

		_create_box("BuildingLeft", Vector3(7, height, 7), Vector3(-12, height / 2.0, z_position), building_color, false)
		_create_box("BuildingRight", Vector3(7, height + 2.0, 7), Vector3(12, (height + 2.0) / 2.0, z_position), building_color.darkened(0.12), false)


func _create_box(box_name: String, box_size: Vector3, box_position: Vector3, box_color: Color, has_collision: bool) -> void:
	var box_node: Node3D

	if has_collision:
		var body := StaticBody3D.new()
		body.name = box_name
		game_world.add_child(body)
		box_node = body

		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box_size
		collision.shape = shape
		body.add_child(collision)
	else:
		box_node = Node3D.new()
		box_node.name = box_name
		game_world.add_child(box_node)

	box_node.position = box_position

	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box_size
	mesh_instance.mesh = box_mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = box_color
	mesh_instance.material_override = material
	box_node.add_child(mesh_instance)


# ==================================================
# JUGADOR Y CAMARA
# ==================================================

func _create_player(character_scene: PackedScene) -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 0, 8)
	game_world.add_child(player)

	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	player.add_child(collision)

	var character := character_scene.instantiate()
	character.name = "SelectedOfficer"
	player.add_child(character)

	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position.y = 1.6
	player.add_child(camera_pivot)

	var camera := Camera3D.new()
	camera.name = "PlayerCamera"
	camera.position = Vector3(0, 0.2, 4.5)
	camera.rotation_degrees.x = -8
	camera.current = true
	camera_pivot.add_child(camera)


func _physics_process(delta: float) -> void:
	if not game_active or not is_instance_valid(player):
		return

	var input_direction := Vector2.ZERO

	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_direction.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_direction.x += 1.0

	input_direction = input_direction.normalized()

	var direction := player.global_transform.basis.x * input_direction.x + -player.global_transform.basis.z * input_direction.y
	direction.y = 0.0
	direction = direction.normalized()

	var current_speed := move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		current_speed *= 1.6

	player.velocity.x = direction.x * current_speed
	player.velocity.z = direction.z * current_speed

	if not player.is_on_floor():
		player.velocity.y -= 20.0 * delta
	else:
		player.velocity.y = 0.0

	player.move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if not game_active:
		return

	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseButton:
		if event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			player.rotate_y(-event.relative.x * mouse_sensitivity)

			var vertical_direction := -1.0
			if invert_camera:
				vertical_direction = 1.0

			camera_pivot.rotate_x(event.relative.y * mouse_sensitivity * vertical_direction)
			camera_pivot.rotation.x = clampf(
				camera_pivot.rotation.x,
				deg_to_rad(-65),
				deg_to_rad(65)
			)
