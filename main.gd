extends Node3D

class MinimapControl extends Control:
	var player_world_position := Vector3.ZERO
	var target_world_position := Vector3.ZERO
	var target_active := false
	var world_limit := 400.0

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

const WORLD_LIMIT := 400.0
# Earth2Road exports a complete Godot scene plus its dependent resources.
# Place the exported scene and its resource folders under assets/earth2road/tampa/.
const GEN_MAP_COMBINED_CANDIDATES := [
	"res://assets/florida_city/gen_map/city.glb",
	"res://assets/florida_city/gen_map/map.glb",
	"res://assets/florida_city/gen_map/combined.glb",
	"res://assets/florida_city/gen_map/scene.glb"
]
const GEN_MAP_PART_CANDIDATES := [
	"res://assets/florida_city/gen_map/terrain.glb",
	"res://assets/florida_city/gen_map/roads.glb",
	"res://assets/florida_city/gen_map/buildings.glb",
	"res://assets/florida_city/gen_map/water.glb",
	"res://assets/florida_city/gen_map/vegetation.glb",
	"res://assets/florida_city/gen_map/street_furniture.glb"
]
const EARTH2ROAD_SCENE_CANDIDATES := [
	"res://assets/earth2road/tampa/map.tscn",
	"res://assets/earth2road/tampa/world.tscn",
	"res://assets/earth2road/tampa/main.tscn"
]
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
# Lightweight ambient traffic follows real road polylines from the Tampa OSM map.
var city_traffic: Array[Dictionary] = []
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
var vehicle_cockpit_camera := false
# First-person is the default on foot; V / the mobile camera button switches perspective.
var first_person_mode := true
var graphics_quality := 2
var world_sun: DirectionalLight3D
var world_environment: WorldEnvironment
var rescue_victim: Node3D
var rescue_victim_active := false
var rescue_scene_reached := false
var siren_player: AudioStreamPlayer3D
var siren_enabled := false
var secondary_controls_open := false

func _ready() -> void:
	rng.randomize()
	graphics_quality = 0 if OS.has_feature("mobile") else 2
	# Draw a safe startup screen first. If the full menu encounters a runtime
	# error, this overlay remains visible instead of leaving a blank grey screen.
	var startup_fallback := _create_startup_fallback()
	# Render a 3D station and fire engine behind the menu instead of a flat color screen.
	_create_menu_scene_preview()
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
	title.text = "F.D.F.R.\nFLORIDA DISTRICT FIRE & RESCUE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	column.add_child(title)
	var message := Label.new()
	message.text = "Iniciando F.D.F.R. — Florida District Fire & Rescue..."
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
	_update_city_traffic(delta)
	_update_remote_network(delta)
	_update_fire_response(delta)
	_update_fire_visuals(delta)
	_update_dispatch_arrival()
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

func _create_menu_scene_preview() -> void:
	# Menú cinematográfico: una escena 3D de calle de Florida, no una pantalla gris.
	# Se mantiene ligera para que también funcione en Android.
	var preview := Node3D.new()
	preview.name = "MenuScenePreview"
	add_child(preview)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.10, 0.30, 0.52)
	sky_material.sky_horizon_color = Color(0.70, 0.79, 0.84)
	sky_material.ground_bottom_color = Color(0.12, 0.16, 0.17)
	sky_material.ground_horizon_color = Color(0.58, 0.65, 0.65)
	sky_material.sun_angle_max = 18.0
	sky_material.use_debanding = true
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.80, 0.88)
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	preview.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -28, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = not OS.has_feature("mobile")
	preview.add_child(sun)

	# Wide Florida street and sidewalks.
	_menu_preview_box(preview, "FloridaGround", Vector3(100, 0.3, 110), Vector3(0, -0.25, -16), Color(0.20, 0.30, 0.22))
	_menu_preview_box(preview, "CityRoad", Vector3(17, 0.08, 100), Vector3(0, -0.035, -19), Color(0.095, 0.11, 0.12))
	_menu_preview_box(preview, "SidewalkLeft", Vector3(4.0, 0.14, 100), Vector3(-10.5, 0.01, -19), Color(0.52, 0.53, 0.49))
	_menu_preview_box(preview, "SidewalkRight", Vector3(4.0, 0.14, 100), Vector3(10.5, 0.01, -19), Color(0.52, 0.53, 0.49))
	_menu_preview_box(preview, "CurbLeft", Vector3(0.22, 0.24, 100), Vector3(-8.45, 0.08, -19), Color(0.80, 0.79, 0.71))
	_menu_preview_box(preview, "CurbRight", Vector3(0.22, 0.24, 100), Vector3(8.45, 0.08, -19), Color(0.80, 0.79, 0.71))
	for mark_z in range(-62, 24, 8):
		_menu_preview_box(preview, "RoadLaneDash", Vector3(0.18, 0.025, 3.2), Vector3(0, 0.02, float(mark_z)), Color(0.91, 0.84, 0.58))
	for edge_x in [-7.9, 7.9]:
		_menu_preview_box(preview, "RoadEdgeLine", Vector3(0.12, 0.025, 100), Vector3(edge_x, 0.02, -19), Color(0.88, 0.88, 0.78))

	# Commercial blocks of different heights give the camera a city skyline.
	var shop_colors := [
		Color(0.69, 0.61, 0.48), Color(0.63, 0.70, 0.70),
		Color(0.74, 0.70, 0.61), Color(0.53, 0.59, 0.62),
		Color(0.74, 0.75, 0.68), Color(0.60, 0.55, 0.48)
	]
	for side in [-1.0, 1.0]:
		for i in range(6):
			var z := -14.0 - float(i) * 12.0
			var height := 5.0 + float((i * 3) % 5)
			var width := 7.0 + float(i % 3) * 1.8
			var x: float = side * (15.0 + float(i % 2) * 2.0)
			_menu_preview_box(preview, "FloridaShop", Vector3(width, height, 8.5), Vector3(x, height * 0.5, z), shop_colors[i])
			_menu_preview_box(preview, "ShopRoofTrim", Vector3(width + 0.2, 0.22, 8.7), Vector3(x, height + 0.08, z), Color(0.16, 0.20, 0.22))
			_menu_preview_box(preview, "ShopWindowBand", Vector3(width * 0.78, 1.25, 0.09), Vector3(x, 1.75, z + 4.3), Color(0.10, 0.23, 0.29))
			_menu_preview_box(preview, "ShopAwning", Vector3(width * 0.84, 0.22, 1.0), Vector3(x, 2.55, z + 4.75), Color(0.72, 0.12, 0.09) if i % 2 == 0 else Color(0.83, 0.82, 0.72))
			for window_x in [-1.0, 1.0]:
				_menu_preview_box(preview, "UpperWindow", Vector3(1.05, 1.25, 0.08), Vector3(x + window_x, minf(height - 1.0, 4.0), z + 4.32), Color(0.13, 0.26, 0.32))

	# Palm trees along the sidewalks make the location read as Florida.
	for side in [-1.0, 1.0]:
		for i in range(5):
			var tree_z := 5.0 - float(i) * 14.0
			var tree_x: float = side * (12.4 + float(i % 2) * 1.2)
			var trunk := MeshInstance3D.new()
			trunk.name = "FloridaPalmTrunk"
			var trunk_mesh := CylinderMesh.new()
			trunk_mesh.top_radius = 0.16
			trunk_mesh.bottom_radius = 0.28
			trunk_mesh.height = 4.6
			trunk.mesh = trunk_mesh
			var trunk_mat := StandardMaterial3D.new()
			trunk_mat.albedo_color = Color(0.43, 0.30, 0.18)
			trunk_mat.roughness = 1.0
			trunk.mesh.surface_set_material(0, trunk_mat)
			trunk.position = Vector3(tree_x, 2.3, tree_z)
			preview.add_child(trunk)
			for frond_index in range(6):
				var frond := MeshInstance3D.new()
				frond.name = "PalmFrond"
				var frond_mesh := BoxMesh.new()
				frond_mesh.size = Vector3(0.16, 0.10, 2.6)
				frond.mesh = frond_mesh
				var frond_mat := StandardMaterial3D.new()
				frond_mat.albedo_color = Color(0.12, 0.34, 0.20)
				frond_mat.roughness = 1.0
				frond.mesh.surface_set_material(0, frond_mat)
				frond.position = Vector3(tree_x, 4.55, tree_z)
				frond.rotation.y = TAU * float(frond_index) / 6.0
				frond.rotation.x = -0.20
				preview.add_child(frond)

	# Fire engine is the focal point, placed to the right so the menu remains legible.
	var truck_path := "res://fire_truck.glb"
	if ResourceLoader.exists(truck_path):
		var truck_scene := load(truck_path) as PackedScene
		if truck_scene != null:
			var truck := truck_scene.instantiate() as Node3D
			if truck != null:
				truck.name = "MenuFireEngine"
				truck.position = Vector3(3.4, 0.0, 3.2)
				truck.rotation_degrees.y = -8.0
				preview.add_child(truck)
				_fit_imported_model(truck, Vector3(3.7, 3.7, 8.6))
	else:
		_menu_preview_box(preview, "FallbackTruckBody", Vector3(3.1, 2.1, 6.6), Vector3(3.4, 1.25, 3.2), Color(0.72, 0.055, 0.045))
		_menu_preview_box(preview, "FallbackTruckCab", Vector3(2.8, 1.6, 2.1), Vector3(3.4, 2.65, 5.1), Color(0.78, 0.075, 0.055))
		_menu_preview_box(preview, "FallbackTruckWindshield", Vector3(2.25, 0.82, 0.06), Vector3(3.4, 2.85, 6.18), Color(0.09, 0.19, 0.25))
		_menu_preview_box(preview, "FallbackTruckLightbar", Vector3(1.65, 0.18, 0.32), Vector3(3.4, 3.55, 5.0), Color(0.95, 0.05, 0.035))
	for wheel_x in [1.82, 4.98]:
		for wheel_z in [1.15, 5.05]:
			var wheel := MeshInstance3D.new()
			wheel.name = "PreviewTruckWheel"
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.48
			wheel_mesh.bottom_radius = 0.48
			wheel_mesh.height = 0.28
			wheel.mesh = wheel_mesh
			wheel.position = Vector3(wheel_x, 0.48, wheel_z)
			wheel.rotation_degrees.z = 90
			var wheel_material := StandardMaterial3D.new()
			wheel_material.albedo_color = Color(0.025, 0.03, 0.035)
			wheel.mesh.surface_set_material(0, wheel_material)
			preview.add_child(wheel)

	# Static firefighter silhouette beside the truck to sell the gameplay perspective.
	var firefighter := Node3D.new()
	firefighter.name = "MenuFirefighter"
	firefighter.position = Vector3(0.5, 0.0, 3.1)
	preview.add_child(firefighter)
	_menu_preview_box(firefighter, "FirefighterBoots", Vector3(0.48, 0.28, 0.30), Vector3(0, 0.14, 0), Color(0.08, 0.09, 0.10))
	_menu_preview_box(firefighter, "FirefighterLegs", Vector3(0.52, 0.82, 0.30), Vector3(0, 0.68, 0), Color(0.16, 0.20, 0.22))
	_menu_preview_box(firefighter, "FirefighterJacket", Vector3(0.78, 0.88, 0.42), Vector3(0, 1.48, 0), Color(0.17, 0.20, 0.22))
	_menu_preview_box(firefighter, "FirefighterReflectiveStripe", Vector3(0.80, 0.10, 0.44), Vector3(0, 1.38, 0), Color(0.94, 0.66, 0.12))
	_menu_preview_box(firefighter, "FirefighterHelmet", Vector3(0.48, 0.24, 0.45), Vector3(0, 2.12, 0), Color(0.84, 0.12, 0.06))

	# A broad three-quarter camera view resembles a paused gameplay scene.
	var camera := Camera3D.new()
	camera.name = "MenuCamera"
	camera.fov = 52.0
	camera.position = Vector3(18.0, 9.5, 21.0)
	preview.add_child(camera)
	camera.look_at(Vector3(0.5, 1.8, -8.0), Vector3.UP)
	camera.current = true


func _menu_preview_box(parent: Node3D, node_name: String, box_size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	mesh.material = material
	instance.mesh = mesh
	instance.position = pos
	parent.add_child(instance)
	return instance

func _create_menu() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.name = "MenuLayer"
	menu_layer.layer = 5
	add_child(menu_layer)

	# F.D.F.R. cinematic command screen: restrained emergency-red accents,
	# clear action hierarchy, and a compact layout for portrait mobile screens.
	var background := ColorRect.new()
	background.name = "MenuBackground"
	background.color = Color(0.018, 0.026, 0.038, 0.28)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(background)

	var scene_tint := ColorRect.new()
	scene_tint.name = "SceneTint"
	scene_tint.anchor_left = 0.0
	scene_tint.anchor_right = 0.30
	scene_tint.anchor_top = 0.0
	scene_tint.anchor_bottom = 1.0
	scene_tint.color = Color(0.012, 0.022, 0.034, 0.52)
	scene_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(scene_tint)

	var top_rule := ColorRect.new()
	top_rule.anchor_left = 0.0
	top_rule.anchor_right = 1.0
	top_rule.anchor_top = 0.0
	top_rule.anchor_bottom = 0.0
	top_rule.offset_bottom = 5
	top_rule.color = Color(0.88, 0.13, 0.09)
	top_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(top_rule)

	var brand := VBoxContainer.new()
	brand.name = "BrandHeader"
	brand.anchor_left = 0.035
	brand.anchor_right = 0.34
	brand.anchor_top = 0.035
	brand.anchor_bottom = 0.235
	brand.add_theme_constant_override("separation", 3)
	menu_layer.add_child(brand)

	var eyebrow := Label.new()
	eyebrow.text = "FLORIDA DISTRICT  /  SERVICIO DE EMERGENCIAS"
	eyebrow.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override("font_color", Color(1.0, 0.70, 0.39))
	brand.add_child(eyebrow)

	var brand_title := Label.new()
	brand_title.text = "F.D.F.R."
	brand_title.add_theme_font_size_override("font_size", 46)
	brand_title.add_theme_color_override("font_color", Color(0.98, 0.97, 0.94))
	brand.add_child(brand_title)

	var brand_subtitle := Label.new()
	brand_subtitle.text = "FLORIDA DISTRICT FIRE & RESCUE"
	brand_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brand_subtitle.add_theme_font_size_override("font_size", 14)
	brand_subtitle.add_theme_color_override("font_color", Color(0.96, 0.27, 0.20))
	brand.add_child(brand_subtitle)

	var brand_rule := ColorRect.new()
	brand_rule.custom_minimum_size = Vector2(84, 3)
	brand_rule.color = Color(0.88, 0.13, 0.09)
	brand.add_child(brand_rule)

	var right_panel := PanelContainer.new()
	right_panel.name = "OperationsPanel"
	right_panel.anchor_left = 0.035
	right_panel.anchor_right = 0.31
	right_panel.anchor_top = 0.285
	right_panel.anchor_bottom = 0.875
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.012, 0.022, 0.034, 0.94)
	panel_style.border_color = Color(0.88, 0.13, 0.09, 0.85)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(3)
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	right_panel.add_theme_stylebox_override("panel", panel_style)
	menu_layer.add_child(right_panel)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 13)
	right_panel.add_child(info)

	var status := Label.new()
	status.text = "CENTRO DE OPERACIONES  /  F.D.F.R."
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_color", Color(1.0, 0.70, 0.39))
	info.add_child(status)

	var scene_title := Label.new()
	scene_title.text = "LISTOS PARA\nLA EMERGENCIA."
	scene_title.add_theme_font_size_override("font_size", 30)
	scene_title.add_theme_color_override("font_color", Color(0.98, 0.97, 0.94))
	info.add_child(scene_title)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 3)
	divider.color = Color(0.88, 0.13, 0.09)
	info.add_child(divider)

	var description := Label.new()
	description.text = "Cada llamada cuenta. Despacha tu unidad, responde al incidente y protege a la comunidad."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 14)
	description.add_theme_color_override("font_color", Color(0.76, 0.80, 0.84))
	info.add_child(description)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	info.add_child(spacer)

	for feature in ["01   EXTINCIÓN DE INCENDIOS", "02   RESCATE TÉCNICO", "03   RESPUESTA A EMERGENCIAS"]:
		var feature_row := HBoxContainer.new()
		feature_row.add_theme_constant_override("separation", 10)
		var marker := ColorRect.new()
		marker.custom_minimum_size = Vector2(3, 20)
		marker.color = Color(0.88, 0.13, 0.09)
		feature_row.add_child(marker)
		var feature_label := Label.new()
		feature_label.text = feature
		feature_label.add_theme_font_size_override("font_size", 12)
		feature_label.add_theme_color_override("font_color", Color(0.88, 0.90, 0.92))
		feature_row.add_child(feature_label)
		info.add_child(feature_row)

	var briefing_note := Label.new()
	briefing_note.text = "UN JUGADOR  •  CIUDAD ABIERTA  •  MISIONES DINÁMICAS"
	briefing_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	briefing_note.add_theme_font_size_override("font_size", 10)
	briefing_note.add_theme_color_override("font_color", Color(0.65, 0.70, 0.75))
	info.add_child(briefing_note)

	var footer := Label.new()
	footer.name = "MenuFooter"
	footer.anchor_left = 0.035
	footer.anchor_right = 0.355
	footer.anchor_top = 0.89
	footer.anchor_bottom = 0.95
	footer.text = "F.D.F.R.  /  ALPHA 0.1.2  /  SERVICIO ACTIVO 24/7"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 10)
	footer.add_theme_color_override("font_color", Color(0.62, 0.66, 0.70))
	menu_layer.add_child(footer)

	var left_area := Control.new()
	left_area.name = "MenuNavigation"
	left_area.anchor_left = 0.025
	left_area.anchor_right = 0.285
	left_area.anchor_top = 0.285
	left_area.anchor_bottom = 0.77
	menu_layer.add_child(left_area)

	var left_center := CenterContainer.new()
	left_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left_area.add_child(left_center)

	menu_panel = VBoxContainer.new()
	menu_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_panel.add_theme_constant_override("separation", 11)
	left_center.add_child(menu_panel)

	# Keep the logo, actions and touch targets readable on a phone.
	if OS.has_feature("mobile") or get_viewport().get_visible_rect().size.x < 760:
		# Mobile gets a distinct left-side command rail, rather than the old centered menu.
		scene_tint.visible = true
		scene_tint.anchor_left = 0.0
		scene_tint.anchor_right = 0.43
		scene_tint.color = Color(0.008, 0.016, 0.026, 0.72)
		right_panel.visible = false
		footer.visible = true
		footer.anchor_left = 0.035
		footer.anchor_right = 0.40
		footer.anchor_top = 0.91
		footer.anchor_bottom = 0.97
		footer.text = "SERVIR  •  PROTEGER  •  SALVAR"
		footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		brand.anchor_left = 0.045
		brand.anchor_right = 0.41
		brand.anchor_top = 0.045
		brand.anchor_bottom = 0.245
		brand_title.add_theme_font_size_override("font_size", 40)
		brand_subtitle.add_theme_font_size_override("font_size", 11)
		left_area.anchor_left = 0.035
		left_area.anchor_right = 0.405
		left_area.anchor_top = 0.29
		left_area.anchor_bottom = 0.84
		menu_panel.add_theme_constant_override("separation", 9)
	_show_main_menu()

func _clear_menu() -> void:
	if not is_instance_valid(menu_panel):
		return
	for child in menu_panel.get_children():
		menu_panel.remove_child(child)
		child.queue_free()

func _add_title() -> void:
	if not is_instance_valid(menu_panel):
		return
	var title := Label.new()
	title.text = "F.D.F.R.  /  EMERGENCY RESPONSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.97, 0.96, 0.93))
	menu_panel.add_child(title)

func _add_button(button_text: String, action: Callable, primary: bool = false) -> void:
	if not is_instance_valid(menu_panel):
		return
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(0, 52 if primary else 47)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 16 if primary else 14)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.76, 0.105, 0.075) if primary else Color(0.075, 0.09, 0.11)
	style.border_color = Color(0.96, 0.29, 0.20) if primary else Color(0.25, 0.29, 0.33)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	button.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.91, 0.16, 0.11) if primary else Color(0.13, 0.16, 0.19)
	button.add_theme_stylebox_override("hover", hover_style)
	var pressed_style := style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.55, 0.07, 0.05) if primary else Color(0.045, 0.055, 0.065)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_color_override("font_color", Color(1.0, 0.98, 0.95))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.83, 0.62))
	button.pressed.connect(action)
	menu_panel.add_child(button)

func _add_coming_soon_button(button_text: String) -> void:
	if not is_instance_valid(menu_panel):
		return
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(0, 47)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = true
	button.tooltip_text = "El modo multijugador se añadirá después de completar la experiencia para un jugador."
	button.add_theme_font_size_override("font_size", 13)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.055, 0.065)
	style.border_color = Color(0.16, 0.19, 0.22)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 12
	style.content_margin_right = 12
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_color_override("font_color", Color(0.48, 0.52, 0.56))
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.52, 0.56))
	menu_panel.add_child(button)

func _show_main_menu() -> void:
	_clear_menu()
	_add_title()
	_add_button("INICIAR SERVICIO", _show_character_selection, true)
	_add_coming_soon_button("MULTIJUGADOR  ·  PRÓXIMAMENTE")
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
	var quality_label := Label.new()
	quality_label.text = "Calidad gráfica (Android: prioriza rendimiento)"
	menu_panel.add_child(quality_label)
	var quality_buttons := HBoxContainer.new()
	quality_buttons.add_theme_constant_override("separation", 6)
	menu_panel.add_child(quality_buttons)
	for option in [{"label": "LIGERA", "value": 0}, {"label": "MEDIA", "value": 1}, {"label": "ALTA", "value": 2}]:
		var quality_button := Button.new()
		quality_button.text = str(option["label"])
		quality_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quality_button.pressed.connect(_set_graphics_quality.bind(int(option["value"])))
		quality_buttons.add_child(quality_button)
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
	world_environment = env_node
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.47, 0.65, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.84)
	env.ambient_light_energy = 0.85
	env_node.environment = env
	game_world.add_child(env_node)
	world_sun = DirectionalLight3D.new()
	world_sun.rotation_degrees = Vector3(-48, -28, 0)
	world_sun.light_energy = 1.1
	world_sun.shadow_enabled = graphics_quality >= 2 and not OS.has_feature("mobile")
	game_world.add_child(world_sun)
	_box("Ground", Vector3(840, 1, 840), Vector3(0, -0.55, 0), Color(0.19, 0.29, 0.19), true)
	# Prefer a city exported from gen-map as GLB, then Earth2Road, then the bundled OSM fallback.
	var has_real_city_map := _create_gen_map_city()
	if not has_real_city_map:
		has_real_city_map = _create_earth2road_city_map()
	if not has_real_city_map:
		has_real_city_map = _create_prebuilt_tampa_model()
	if not has_real_city_map:
		has_real_city_map = _create_osm_city_map()
	if not has_real_city_map:
		_create_road_network_from_pack()
	_create_fire_station()
	if not has_real_city_map:
		_create_city_blocks()
	_create_hospital_complex()
	_create_airport()
	_create_gas_stations()
	_create_trees()
	if not has_real_city_map:
		_create_street_furniture()
		_create_crosswalks()
		_create_district_markers()
	else:
		_create_osm_map_signage()
	_apply_graphics_quality()


func _create_gen_map_city() -> bool:
	# Put gen-map's exported GLB files in assets/florida_city/gen_map/.
	# Prefer one combined scene when present to avoid loading overlapping duplicate geometry.
	for scene_path in GEN_MAP_COMBINED_CANDIDATES:
		if not ResourceLoader.exists(scene_path):
			continue
		var packed_scene := load(scene_path) as PackedScene
		if packed_scene == null:
			push_warning("No se pudo cargar el GLB de gen-map: " + scene_path)
			continue
		var city_instance := packed_scene.instantiate() as Node3D
		if city_instance == null:
			push_warning("El GLB de gen-map no produjo un Node3D: " + scene_path)
			continue
		city_instance.name = "GenMapCity"
		game_world.add_child(city_instance)
		print("F.D.F.R. mapa gen-map cargado: ", scene_path)
		return true

	var loaded_parts := 0
	for scene_path in GEN_MAP_PART_CANDIDATES:
		if not ResourceLoader.exists(scene_path):
			continue
		var packed_scene := load(scene_path) as PackedScene
		if packed_scene == null:
			push_warning("No se pudo cargar el componente GLB de gen-map: " + scene_path)
			continue
		var part_instance := packed_scene.instantiate() as Node3D
		if part_instance == null:
			continue
		part_instance.name = "GenMap_" + scene_path.get_file().get_basename()
		game_world.add_child(part_instance)
		loaded_parts += 1
	if loaded_parts > 0:
		print("F.D.F.R. mapa gen-map cargado: ", loaded_parts, " componentes GLB.")
		return true
	return false


func _create_osm_city_map() -> bool:
	var map_path := "res://assets/florida_city/tampa_osm_map.json"
	if not FileAccess.file_exists(map_path):
		push_warning("No se encontró el mapa OSM de Tampa; se usará la ciudad de respaldo.")
		return false
	var raw_json := FileAccess.get_file_as_string(map_path)
	var parsed: Variant = JSON.parse_string(raw_json)
	if not parsed is Dictionary:
		push_warning("El archivo del mapa OSM no es válido; se usará la ciudad de respaldo.")
		return false
	var map_data: Dictionary = parsed
	var roads: Array = map_data.get("roads", [])
	var buildings: Array = map_data.get("buildings", [])
	if roads.is_empty():
		push_warning("El mapa OSM no contiene calles; se usará la ciudad de respaldo.")
		return false

	var asphalt := Color(0.075, 0.085, 0.095)
	var road_count := 0
	for road_variant in roads:
		if not road_variant is Dictionary:
			continue
		var road: Dictionary = road_variant
		var points: Array = road.get("points", [])
		var width := float(road.get("width", 4.0))
		for point_index in range(points.size() - 1):
			var a_data: Array = points[point_index]
			var b_data: Array = points[point_index + 1]
			if a_data.size() < 2 or b_data.size() < 2:
				continue
			var a := Vector2(float(a_data[0]), float(a_data[1]))
			var b := Vector2(float(b_data[0]), float(b_data[1]))
			var segment := b - a
			var segment_length := segment.length()
			if segment_length < 0.35:
				continue
			var road_piece := _box("OSM_Road_Segment", Vector3(width, 0.12, segment_length + 0.25), Vector3((a.x + b.x) * 0.5, 0.035, (a.y + b.y) * 0.5), asphalt, false)
			road_piece.rotation.y = atan2(segment.x, segment.y)
			road_count += 1

	var building_count := 0
	for building_index in range(buildings.size()):
		var building_variant: Variant = buildings[building_index]
		if not building_variant is Dictionary:
			continue
		var building: Dictionary = building_variant
		var x := float(building.get("x", 0.0))
		var z := float(building.get("z", 0.0))
		# Reserve clear footprints for the playable emergency facilities and fuel stops.
		var reserved := false
		for facility_position in [Vector2(60, 115), Vector2(75, -105), Vector2(-140, -145), Vector2(-150, 15), Vector2(150, -150), Vector2(-150, 150), Vector2(150, 150)]:
			if Vector2(x, z).distance_to(facility_position) < 24.0:
				reserved = true
				break
		if reserved:
			continue
		var width := clampf(float(building.get("w", 8.0)), 5.0, 17.0)
		var depth := clampf(float(building.get("d", 8.0)), 5.0, 17.0)
		var height := clampf(float(building.get("h", 6.0)), 5.5, 30.0)
		var target_size := Vector3(width, height, depth)
		var footprint_data: Array = building.get("footprint", [])
		var building_kind := str(building.get("kind", "building"))
		# Choose architecture by actual map classification instead of scattering the same
		# suburban house models through every district.
		var kind_key := building_kind.to_lower()
		var placed_asset := false
		if height >= 19.0 and (kind_key in ["commercial", "office", "hotel", "apartments"] or width >= 12.0):
			var tower_index := posmod(hash(building_kind + str(building_index)), FLORIDA_SKYSCRAPER_SCENES.size())
			placed_asset = _try_create_building_from_path(FLORIDA_SKYSCRAPER_SCENES[tower_index], Vector3(x, 0.0, z), target_size, "Tampa_OSM_Skyscraper")
		elif kind_key in ["commercial", "office", "hotel", "apartments", "retail", "industrial", "warehouse"]:
			var commercial_index := posmod(hash(building_kind + str(building_index)), FLORIDA_DOWNTOWN_SCENES.size())
			placed_asset = _try_create_building_from_path(FLORIDA_DOWNTOWN_SCENES[commercial_index], Vector3(x, 0.0, z), target_size, "Tampa_OSM_Commercial")
		else:
			var residential_index := posmod(hash(building_kind + str(building_index)), FLORIDA_BUILDING_SCENES.size())
			placed_asset = _try_create_asset_building(Vector3(x, 0.0, z), target_size, residential_index, "Tampa_OSM_Residential")
		if not placed_asset:
			if footprint_data.size() >= 3:
				_create_osm_footprint_building(footprint_data, height, building_kind, building_index)
			else:
				_box("Tampa_OSM_Building_Fallback", target_size, Vector3(x, height * 0.5, z), Color(0.45, 0.49, 0.51), true)
		building_count += 1

	_create_osm_street_lights(roads)
	_create_city_traffic(roads)
	print("F.D.F.R. real map loaded: Downtown Tampa, ", road_count, " road segments, ", building_count, " buildings, ", city_traffic.size(), " traffic vehicles.")
	return true


func _create_city_traffic(roads: Array) -> void:
	city_traffic.clear()
	var candidates: Array[Dictionary] = []
	for road_variant in roads:
		if not road_variant is Dictionary:
			continue
		var road: Dictionary = road_variant
		var points: Array = road.get("points", [])
		if points.size() < 5 or float(road.get("width", 4.0)) < 4.0:
			continue
		var kind := str(road.get("kind", ""))
		if kind == "service" or kind == "footway" or kind == "path":
			continue
		var total_length := 0.0
		for i in range(1, points.size()):
			var a: Array = points[i - 1]
			var b: Array = points[i]
			if a.size() >= 2 and b.size() >= 2:
				total_length += Vector2(float(b[0]) - float(a[0]), float(b[1]) - float(a[1])).length()
		if total_length >= 90.0:
			candidates.append({"road": road, "length": total_length})
	if candidates.is_empty():
		push_warning("No se encontraron calles suficientemente largas para el tráfico ambiental.")
		return

	var vehicle_count := mini(5, candidates.size())
	for vehicle_index in range(vehicle_count):
		var candidate_index := int(round(float(vehicle_index) * float(candidates.size() - 1) / float(maxi(1, vehicle_count - 1))))
		var road: Dictionary = candidates[candidate_index]["road"]
		var source_points: Array = road.get("points", [])
		var route: Array[Vector3] = []
		var lane_offset := 0.95 if vehicle_index % 2 == 0 else -0.95
		for point_index in range(source_points.size()):
			var point_data: Array = source_points[point_index]
			if point_data.size() < 2:
				continue
			var previous_data: Array = source_points[maxi(0, point_index - 1)]
			var next_data: Array = source_points[mini(source_points.size() - 1, point_index + 1)]
			var previous_point := Vector2(float(previous_data[0]), float(previous_data[1]))
			var next_point := Vector2(float(next_data[0]), float(next_data[1]))
			var tangent := (next_point - previous_point).normalized()
			var side := Vector2(tangent.y, -tangent.x) * lane_offset
			route.append(Vector3(float(point_data[0]) + side.x, 0.04, float(point_data[1]) + side.y))
		if route.size() < 2:
			continue
		var traffic_node := Node3D.new()
		traffic_node.name = "AmbientTraffic_%02d" % vehicle_index
		traffic_node.position = route[0]
		game_world.add_child(traffic_node)
		var model_path := "res://assets/vehicles/sedan.glb" if vehicle_index % 3 != 2 else "res://assets/vehicles/suv.glb"
		var packed_model := load(model_path) as PackedScene
		if packed_model == null:
			traffic_node.queue_free()
			continue
		var model := packed_model.instantiate() as Node3D
		if model == null:
			traffic_node.queue_free()
			continue
		model.name = "TrafficVehicleModel"
		traffic_node.add_child(model)
		_fit_imported_model(model, Vector3(1.95, 1.55, 4.25))
		var first_target: Vector3 = route[1]
		traffic_node.rotation.y = atan2(first_target.x - route[0].x, first_target.z - route[0].z)
		city_traffic.append({
			"node": traffic_node,
			"route": route,
			"route_index": 1,
			"direction": 1,
			"speed": 4.0 + float(vehicle_index % 3) * 1.1
		})


func _update_city_traffic(delta: float) -> void:
	for traffic_variant in city_traffic:
		if not traffic_variant is Dictionary:
			continue
		var traffic: Dictionary = traffic_variant
		var node := traffic.get("node") as Node3D
		var route: Array = traffic.get("route", [])
		if not is_instance_valid(node) or route.size() < 2:
			continue
		var route_index := clampi(int(traffic.get("route_index", 1)), 0, route.size() - 1)
		var direction := int(traffic.get("direction", 1))
		var target: Vector3 = route[route_index]
		var offset := target - node.position
		offset.y = 0.0
		var step := float(traffic.get("speed", 4.5)) * delta
		if offset.length() <= step + 0.2:
			node.position.x = target.x
			node.position.z = target.z
			route_index += direction
			if route_index >= route.size():
				direction = -1
				route_index = route.size() - 2
			elif route_index < 0:
				direction = 1
				route_index = 1
			traffic["route_index"] = route_index
			traffic["direction"] = direction
			target = route[route_index]
			offset = target - node.position
			offset.y = 0.0
		if offset.length() > 0.05:
			node.position += offset.normalized() * minf(step, offset.length())
			node.rotation.y = atan2(offset.x, offset.z)


func _create_osm_street_lights(roads: Array) -> void:
	var placed := 0
	for road_variant in roads:
		if placed >= 16:
			break
		if not road_variant is Dictionary:
			continue
		var road: Dictionary = road_variant
		var points: Array = road.get("points", [])
		if points.size() < 9 or float(road.get("width", 4.0)) < 4.0:
			continue
		for sample_fraction in [0.33, 0.67]:
			if placed >= 16:
				break
			var point_index := clampi(int(float(points.size() - 1) * sample_fraction), 0, points.size() - 1)
			var point_data: Array = points[point_index]
			var previous_data: Array = points[maxi(0, point_index - 1)]
			var next_data: Array = points[mini(points.size() - 1, point_index + 1)]
			if point_data.size() < 2 or previous_data.size() < 2 or next_data.size() < 2:
				continue
			var tangent := (Vector2(float(next_data[0]), float(next_data[1])) - Vector2(float(previous_data[0]), float(previous_data[1]))).normalized()
			var side := Vector2(tangent.y, -tangent.x) * (float(road.get("width", 4.0)) * 0.5 + 2.0)
			_place_road_model("light-curved.glb", Vector3(float(point_data[0]) + side.x, 0.0, float(point_data[1]) + side.y))
			placed += 1


func _create_osm_footprint_building(footprint_data: Array, height: float, kind: String, building_index: int) -> void:
	var polygon := PackedVector2Array()
	for point_variant in footprint_data:
		if point_variant is Array and point_variant.size() >= 2:
			polygon.append(Vector2(float(point_variant[0]), float(point_variant[1])))
	if polygon.size() < 3:
		return
	var triangles := Geometry2D.triangulate_polygon(polygon)
	if triangles.is_empty():
		return

	var mesh_tool := SurfaceTool.new()
	mesh_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Roof: preserve the real OSM footprint rather than replacing every building
	# with a rectangular block. Disable back-face culling for unusual OSM winding.
	for tri in range(0, triangles.size(), 3):
		var p0 := polygon[triangles[tri]]
		var p1 := polygon[triangles[tri + 1]]
		var p2 := polygon[triangles[tri + 2]]
		var winding := (p1.x - p0.x) * (p2.y - p0.y) - (p1.y - p0.y) * (p2.x - p0.x)
		if winding > 0.0:
			var swap_point := p1
			p1 = p2
			p2 = swap_point
		mesh_tool.add_vertex(Vector3(p0.x, height, p0.y))
		mesh_tool.add_vertex(Vector3(p1.x, height, p1.y))
		mesh_tool.add_vertex(Vector3(p2.x, height, p2.y))
	# Exterior walls follow the surveyed footprint ring.
	for edge in range(polygon.size()):
		var a := polygon[edge]
		var b := polygon[(edge + 1) % polygon.size()]
		mesh_tool.add_vertex(Vector3(a.x, 0.0, a.y))
		mesh_tool.add_vertex(Vector3(b.x, 0.0, b.y))
		mesh_tool.add_vertex(Vector3(b.x, height, b.y))
		mesh_tool.add_vertex(Vector3(a.x, 0.0, a.y))
		mesh_tool.add_vertex(Vector3(b.x, height, b.y))
		mesh_tool.add_vertex(Vector3(a.x, height, a.y))
	mesh_tool.generate_normals()
	var mesh := mesh_tool.commit()
	if mesh == null:
		return

	var building_body := StaticBody3D.new()
	building_body.name = "Tampa_OSM_Footprint_%d" % building_index
	game_world.add_child(building_body)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "SurveyedBuildingFootprint"
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.88
	if kind in ["commercial", "office", "hotel", "apartments"]:
		material.albedo_color = Color(0.48, 0.53, 0.57)
	elif kind in ["industrial", "warehouse"]:
		material.albedo_color = Color(0.48, 0.46, 0.41)
	else:
		material.albedo_color = Color(0.62, 0.58, 0.49)
	mesh_instance.material_override = material
	building_body.add_child(mesh_instance)
	# Lightweight collision uses the footprint's bounding box for safe driving.
	var min_x := polygon[0].x
	var max_x := polygon[0].x
	var min_z := polygon[0].y
	var max_z := polygon[0].y
	for point in polygon:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_z = minf(min_z, point.y)
		max_z = maxf(max_z, point.y)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(1.0, max_x - min_x), height, maxf(1.0, max_z - min_z))
	collision.shape = shape
	collision.position = Vector3((min_x + max_x) * 0.5, height * 0.5, (min_z + max_z) * 0.5)
	building_body.add_child(collision)


func _create_osm_map_signage() -> void:
	var title := Label3D.new()
	title.name = "RealMapAreaLabel"
	title.text = "DOWNTOWN TAMPA · FLORIDA"
	title.position = Vector3(-110.0, 10.0, -185.0)
	title.font_size = 38
	title.outline_size = 7
	title.modulate = Color(0.95, 0.84, 0.58)
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	game_world.add_child(title)

	var credit := Label3D.new()
	credit.name = "OpenStreetMapAttribution"
	credit.text = "Map data © OpenStreetMap contributors"
	credit.position = Vector3(0.0, 1.5, 407.0)
	credit.font_size = 20
	credit.outline_size = 4
	credit.modulate = Color(0.93, 0.95, 0.96)
	credit.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	game_world.add_child(credit)


func _create_road_network_from_pack() -> void:
	var road_root := "res://assets/city_roads/kenney_city_roads_glb_cc0_v1/models_glb/"
	var straight_path := road_root + "road-straight.glb"
	var cross_path := road_root + "road-crossroad.glb"
	if not ResourceLoader.exists(straight_path) or not ResourceLoader.exists(cross_path):
		_create_visible_road_surfaces()
		return

	var road_lines: Array[float] = [-360.0, -300.0, -240.0, -180.0, -120.0, -60.0, 0.0, 60.0, 120.0, 180.0, 240.0, 300.0, 360.0]
	# Each intersection is a real GLB junction; straight road pieces fill the 60 m blocks.
	for road_x in road_lines:
		for road_z in road_lines:
			_place_road_model("road-crossroad.glb", Vector3(road_x, 0.015, road_z))
		for segment_z in range(-390, 391, 60):
			_place_road_model("road-straight.glb", Vector3(road_x, 0.015, float(segment_z)), 0.0, Vector3(1.0, 1.0, 6.0))
	for road_z in road_lines:
		for segment_x in range(-390, 391, 60):
			_place_road_model("road-straight.glb", Vector3(float(segment_x), 0.016, road_z), PI / 2.0, Vector3(1.0, 1.0, 6.0))

	# Add small traffic details at major intersections without adding heavy collision meshes.
	for road_x in [-120.0, 0.0, 120.0]:
		for road_z in [-120.0, 0.0, 120.0]:
			_place_road_model("road-intersection-line.glb", Vector3(road_x, 0.025, road_z), 0.0, Vector3(1.0, 1.0, 1.0))

	# Guaranteed visible asphalt and lane markings sit above imported tile meshes.
	_create_visible_road_surfaces()


func _create_visible_road_surfaces() -> void:
	var road_lines: Array[float] = [-360.0, -300.0, -240.0, -180.0, -120.0, -60.0, 0.0, 60.0, 120.0, 180.0, 240.0, 300.0, 360.0]
	var asphalt := Color(0.075, 0.085, 0.095)
	var edge_paint := Color(0.88, 0.88, 0.80)
	var center_paint := Color(0.96, 0.72, 0.12)
	for road_x in road_lines:
		_box("Visible_Asphalt_NS", Vector3(14.0, 0.12, 840.0), Vector3(road_x, 0.045, 0.0), asphalt, false)
		_box("Road_Edge_NS_Left", Vector3(0.16, 0.025, 840.0), Vector3(road_x - 6.1, 0.115, 0.0), edge_paint, false)
		_box("Road_Edge_NS_Right", Vector3(0.16, 0.025, 840.0), Vector3(road_x + 6.1, 0.115, 0.0), edge_paint, false)
		_box("Road_Center_NS_Left", Vector3(0.12, 0.026, 840.0), Vector3(road_x - 0.16, 0.117, 0.0), center_paint, false)
		_box("Road_Center_NS_Right", Vector3(0.12, 0.026, 840.0), Vector3(road_x + 0.16, 0.117, 0.0), center_paint, false)
	for road_z in road_lines:
		_box("Visible_Asphalt_EW", Vector3(840.0, 0.12, 14.0), Vector3(0.0, 0.046, road_z), asphalt, false)
		_box("Road_Edge_EW_North", Vector3(840.0, 0.025, 0.16), Vector3(0.0, 0.116, road_z - 6.1), edge_paint, false)
		_box("Road_Edge_EW_South", Vector3(840.0, 0.025, 0.16), Vector3(0.0, 0.116, road_z + 6.1), edge_paint, false)
		_box("Road_Center_EW_Left", Vector3(840.0, 0.026, 0.12), Vector3(0.0, 0.118, road_z - 0.16), center_paint, false)
		_box("Road_Center_EW_Right", Vector3(840.0, 0.026, 0.12), Vector3(0.0, 0.118, road_z + 0.16), center_paint, false)


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
	# Station compound with marked engine bays and a dispatch board.
	_box("FireStation", Vector3(21, 6.5, 13), Vector3(60, 3.25, 115), Color(0.42, 0.105, 0.08), true)
	_box("StationRoofTrim", Vector3(21.5, 0.35, 13.5), Vector3(60, 6.55, 115), Color(0.13, 0.16, 0.19), false)
	_box("StationEntrance", Vector3(5.2, 3.6, 0.25), Vector3(54.7, 1.8, 108.35), Color(0.08, 0.13, 0.2), false)
	for bay_x in [58.0, 64.0]:
		_box("EngineBayDoor", Vector3(4.8, 3.5, 0.22), Vector3(bay_x, 1.8, 108.3), Color(0.11, 0.19, 0.25), false)
		for stripe in range(5):
			_box("BayDoorStripe", Vector3(4.2, 0.07, 0.04), Vector3(bay_x, 0.45 + float(stripe) * 0.62, 108.15), Color(0.68, 0.74, 0.77), false)
	_box("StationSign", Vector3(12, 0.9, 0.22), Vector3(60, 5.35, 108.15), Color(0.62, 0.13, 0.1), false)
	var station_label := Label3D.new()
	station_label.text = "F.D.F.R. · FLORIDA DISTRICT · STATION 01"
	station_label.position = Vector3(60, 5.35, 108.0)
	station_label.font_size = 28
	station_label.outline_size = 5
	station_label.modulate = Color(1.0, 0.91, 0.78)
	station_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	game_world.add_child(station_label)
	_box("StationParking", Vector3(28, 0.08, 18), Vector3(60, 0.0, 99), Color(0.16, 0.17, 0.18), false)
	for i in range(4):
		_box("ParkingLine", Vector3(0.12, 0.025, 7), Vector3(48 + i * 7.5, 0.06, 99), Color(0.9, 0.9, 0.82), false)
	_box("StationDispatchBoard", Vector3(4.2, 2.4, 0.12), Vector3(68.8, 2.2, 109.0), Color(0.025, 0.12, 0.16), false)
	_box("StationDispatchScreen", Vector3(3.6, 1.7, 0.05), Vector3(68.8, 2.35, 108.9), Color(0.08, 0.48, 0.52), false)

func _apply_graphics_quality() -> void:
	if is_instance_valid(world_sun):
		world_sun.shadow_enabled = graphics_quality >= 2 and not OS.has_feature("mobile")
		world_sun.light_energy = 0.95 if graphics_quality == 0 else (1.05 if graphics_quality == 1 else 1.15)
	if is_instance_valid(world_environment) and world_environment.environment != null:
		world_environment.environment.ambient_light_energy = 0.95 if graphics_quality == 0 else 1.0

func _set_graphics_quality(value: int) -> void:
	graphics_quality = clampi(value, 0, 2)
	_apply_graphics_quality()
	if is_instance_valid(status_label):
		var quality_name := "RENDIMIENTO" if graphics_quality == 0 else ("EQUILIBRADO" if graphics_quality == 1 else "CALIDAD PC")
		status_label.text = "GRÁFICOS: " + quality_name


func _create_hospital_complex() -> void:
	# The medical center block is expanded with a visible ER entrance and ambulance bays.
	var hospital_center := Vector3(75.0, 0.0, -105.0)
	_box("HospitalEmergencyDrive", Vector3(25.0, 0.08, 12.0), hospital_center + Vector3(0, 0.02, 13.0), Color(0.24, 0.25, 0.26), false)
	_box("HospitalERCanopy", Vector3(9.0, 0.45, 3.2), hospital_center + Vector3(0, 3.5, 6.5), Color(0.86, 0.89, 0.88), false)
	_box("HospitalERSign", Vector3(5.8, 0.75, 0.18), hospital_center + Vector3(0, 4.1, 4.8), Color(0.05, 0.36, 0.42), false)
	var er_label := Label3D.new()
	er_label.name = "HospitalEmergencyLabel"
	er_label.text = "HOSPITAL · EMERGENCY"
	er_label.position = hospital_center + Vector3(0, 4.12, 4.68)
	er_label.font_size = 26
	er_label.outline_size = 4
	er_label.modulate = Color(0.95, 1.0, 1.0)
	er_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	game_world.add_child(er_label)
	for bay_x in [-5.0, 5.0]:
		_box("HospitalAmbulanceBay", Vector3(4.2, 3.0, 0.18), hospital_center + Vector3(bay_x, 1.5, 5.0), Color(0.08, 0.28, 0.32), false)
		_box("HospitalAmbulanceBayStripe", Vector3(3.8, 0.08, 0.04), hospital_center + Vector3(bay_x, 0.65, 4.87), Color(0.88, 0.92, 0.9), false)
	_box("HospitalParking", Vector3(26.0, 0.06, 10.0), hospital_center + Vector3(0, 0.02, 20.0), Color(0.18, 0.19, 0.2), false)
	for i in range(5):
		_box("HospitalParkingLine", Vector3(0.12, 0.025, 7.0), hospital_center + Vector3(-10.0 + float(i) * 5.0, 0.06, 20.0), Color(0.9, 0.9, 0.84), false)


func _create_airport() -> void:
	# Compact regional airport inspired by Florida's low coastal airports.
	# The airport occupies the reserved northwest blocks and remains inside the driving area.
	var airport_root := Node3D.new()
	airport_root.name = "Sunshine_Coast_Regional_Airport"
	airport_root.position = Vector3(-140.0, 0.0, -145.0)
	game_world.add_child(airport_root)

	_box("AirportGround", Vector3(142.0, 0.08, 102.0), Vector3(-140.0, 0.015, -145.0), Color(0.31, 0.39, 0.29), false)
	_box("AirportApron", Vector3(62.0, 0.12, 34.0), Vector3(-113.0, 0.08, -105.0), Color(0.34, 0.35, 0.34), false)
	_box("AirportRunway", Vector3(126.0, 0.16, 17.0), Vector3(-140.0, 0.13, -160.0), Color(0.075, 0.085, 0.09), false)
	_box("RunwayCenterLine", Vector3(116.0, 0.025, 0.22), Vector3(-140.0, 0.225, -160.0), Color(0.93, 0.93, 0.86), false)
	for runway_mark in range(9):
		var mark_x := -194.0 + float(runway_mark) * 13.5
		_box("RunwayThresholdMark", Vector3(0.7, 0.03, 4.0), Vector3(mark_x, 0.235, -160.0), Color(0.94, 0.94, 0.9), false)
	for taxi_mark in range(7):
		_box("TaxiwayCenterLine", Vector3(0.16, 0.025, 5.0), Vector3(-104.0, 0.235, -135.0 + float(taxi_mark) * 4.5), Color(1.0, 0.78, 0.12), false)

	# Passenger terminal and airfield operations hangar.
	_box("AirportTerminal", Vector3(25.0, 7.0, 10.0), Vector3(-104.0, 3.5, -104.0), Color(0.68, 0.72, 0.72), true)
	_box("AirportTerminalRoof", Vector3(26.0, 0.4, 10.8), Vector3(-104.0, 7.1, -104.0), Color(0.1, 0.19, 0.25), false)
	_box("AirportTerminalWindows", Vector3(18.0, 2.4, 0.12), Vector3(-104.0, 3.7, -98.88), Color(0.12, 0.32, 0.42), false)
	_box("AirportTerminalSign", Vector3(13.0, 0.9, 0.2), Vector3(-104.0, 5.8, -98.82), Color(0.05, 0.16, 0.22), false)
	var airport_label := Label3D.new()
	airport_label.name = "AirportTerminalLabel"
	airport_label.text = "SUNSHINE COAST REGIONAL"
	airport_label.position = Vector3(-104.0, 5.82, -98.68)
	airport_label.font_size = 25
	airport_label.outline_size = 5
	airport_label.modulate = Color(0.95, 0.97, 1.0)
	airport_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	game_world.add_child(airport_label)

	_box("AirportHangar", Vector3(19.0, 6.5, 13.0), Vector3(-176.0, 3.25, -112.0), Color(0.66, 0.68, 0.67), true)
	_box("AirportHangarDoor", Vector3(10.0, 4.2, 0.16), Vector3(-176.0, 2.2, -105.35), Color(0.12, 0.18, 0.21), false)
	_box("AirportControlTower", Vector3(5.0, 12.0, 5.0), Vector3(-82.0, 6.0, -115.0), Color(0.76, 0.78, 0.76), true)
	_box("AirportTowerGlass", Vector3(5.2, 1.8, 5.2), Vector3(-82.0, 11.0, -115.0), Color(0.13, 0.34, 0.43), false)
	_box("AirportTowerRoof", Vector3(6.0, 0.4, 6.0), Vector3(-82.0, 12.2, -115.0), Color(0.12, 0.18, 0.22), false)

	# Lightweight parked aircraft silhouette; no heavy imported model required.
	_box("AirportAircraftFuselage", Vector3(2.1, 1.5, 15.0), Vector3(-123.0, 1.4, -112.0), Color(0.83, 0.85, 0.83), false)
	_box("AirportAircraftWing", Vector3(12.0, 0.22, 3.0), Vector3(-123.0, 1.6, -111.0), Color(0.76, 0.79, 0.78), false)
	_box("AirportAircraftTail", Vector3(4.0, 1.3, 1.0), Vector3(-123.0, 2.0, -119.0), Color(0.78, 0.8, 0.79), false)
	_box("AirportAircraftFin", Vector3(0.22, 2.4, 1.4), Vector3(-123.0, 2.6, -119.0), Color(0.8, 0.82, 0.81), false)
	var airport_marker := Label3D.new()
	airport_marker.text = "AIRPORT · FIRE & RESCUE ACCESS"
	airport_marker.position = Vector3(-140.0, 4.0, -188.0)
	airport_marker.font_size = 26
	airport_marker.outline_size = 5
	airport_marker.modulate = Color(1.0, 0.8, 0.28)
	airport_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	game_world.add_child(airport_marker)

func _create_city_blocks() -> void:
	var colors: Array[Color] = [Color(0.48,0.48,0.46), Color(0.42,0.46,0.5), Color(0.56,0.48,0.39), Color(0.34,0.42,0.47), Color(0.55,0.56,0.53)]
	for x in [-165.0, -105.0, -45.0, 15.0, 75.0, 135.0]:
		for z in [-165.0, -105.0, -45.0, 15.0, 75.0, 135.0]:
			if absf(x) < 20 and absf(z - 18) < 18:
				continue
			# Reserve the northwest edge for the regional airport, runway and apron.
			if x <= -105.0 and z <= -105.0:
				continue
			var civic_name := ""
			if x == -105.0 and z == -105.0: civic_name = "CITY HALL"
			elif x == 75.0 and z == -105.0: civic_name = "MEDICAL CENTER"
			elif x == 75.0 and z == 75.0: civic_name = "FIRE DEPARTMENT"
			elif x == -165.0 and z == 75.0: civic_name = "PUBLIC LIBRARY"
			var block_position := Vector3(x, 0, z)
			var reserved_for_gas_station := false
			for station_position in [Vector3(-150, 0, 15), Vector3(150, 0, -150), Vector3(-150, 0, 150), Vector3(150, 0, 150)]:
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
		{"name": "MIRAGE FUEL · WEST", "position": Vector3(-150, 0, 15), "rotation": 0.0},
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
	# Fit each axis to the measured footprint. Uniform scaling previously made many
	# imported houses tiny inside their real map parcels, which looked like toy blocks.
	var sx := target_size.x / bounds.size.x
	var sy := target_size.y / bounds.size.y
	var sz := target_size.z / bounds.size.z
	if not is_finite(sx) or not is_finite(sy) or not is_finite(sz) or sx <= 0.0 or sy <= 0.0 or sz <= 0.0:
		model.position.y = 0.05
		return
	model.scale = Vector3(sx, sy, sz)
	model.position.y = -bounds.position.y * sy + 0.05

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
	player_visual.visible = not first_person_mode
	player.add_child(player_visual)
	_setup_player_animations(player_visual)
	camera_pivot = Node3D.new()
	camera_pivot.position.y = 1.62
	player.add_child(camera_pivot)
	camera = Camera3D.new()
	camera.name = "FollowCamera"
	camera.current = true
	camera.position = Vector3.ZERO if first_person_mode else Vector3(0, 0.25, 4.2)
	camera.rotation_degrees.x = 0 if first_person_mode else -8
	camera_pivot.add_child(camera)

func _setup_player_animations(root: Node) -> void:
	player_animation_player = _find_animation_player(root)
	player_animation_names.clear()
	player_motion_state = ""
	# The free CC0 firefighter model is detailed but ships as a static mesh.
	# Add lightweight AnimationPlayer clips so the imported model has distinct
	# idle, walk, run and hose-use motion without external plugins or runtime cost.
	if not is_instance_valid(player_animation_player):
		player_animation_player = AnimationPlayer.new()
		player_animation_player.name = "ProceduralAnimationPlayer"
		root.add_child(player_animation_player)
		player_animation_player.root_node = NodePath("..")
		var library := AnimationLibrary.new()
		library.add_animation("idle", _make_firefighter_motion("idle"))
		library.add_animation("walk", _make_firefighter_motion("walk"))
		library.add_animation("run", _make_firefighter_motion("run"))
		library.add_animation("extinguish", _make_firefighter_motion("extinguish"))
		player_animation_player.add_animation_library("", library)
	for animation_name in player_animation_player.get_animation_list():
		player_animation_names.append(StringName(animation_name))
	_play_player_animation("idle")

func _make_firefighter_motion(motion: String) -> Animation:
	var animation := Animation.new()
	var duration := 1.0
	match motion:
		"idle":
			duration = 2.4
		"walk":
			duration = 0.72
		"run":
			duration = 0.46
		"extinguish":
			duration = 0.8
	animation.length = duration
	animation.loop_mode = Animation.LOOP_LINEAR
	var position_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(position_track, NodePath(".:position"))
	animation.value_track_set_update_mode(position_track, Animation.UPDATE_CONTINUOUS)
	var rotation_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(rotation_track, NodePath(".:rotation"))
	animation.value_track_set_update_mode(rotation_track, Animation.UPDATE_CONTINUOUS)
	var base_position := Vector3.ZERO
	var base_rotation := Vector3.ZERO
	var times: Array[float] = []
	var positions: Array[Vector3] = []
	var rotations: Array[Vector3] = []
	match motion:
		"idle":
			times = [0.0, 0.6, 1.2, 1.8, duration]
			positions = [base_position, Vector3(0, 0.018, 0), base_position, Vector3(0, 0.012, 0), base_position]
			rotations = [base_rotation, Vector3(0, 0, 0.008), base_rotation, Vector3(0, 0, -0.008), base_rotation]
		"walk":
			times = [0.0, duration * 0.25, duration * 0.5, duration * 0.75, duration]
			positions = [base_position, Vector3(0, 0.035, 0), base_position, Vector3(0, 0.035, 0), base_position]
			rotations = [Vector3(0, 0, -0.018), Vector3(0.012, 0, 0.018), Vector3(0, 0, -0.018), Vector3(-0.012, 0, 0.018), Vector3(0, 0, -0.018)]
		"run":
			times = [0.0, duration * 0.25, duration * 0.5, duration * 0.75, duration]
			positions = [base_position, Vector3(0, 0.065, 0), base_position, Vector3(0, 0.065, 0), base_position]
			rotations = [Vector3(deg_to_rad(-4), 0, -0.03), Vector3(deg_to_rad(-5), 0, 0.03), Vector3(deg_to_rad(-4), 0, -0.03), Vector3(deg_to_rad(-5), 0, 0.03), Vector3(deg_to_rad(-4), 0, -0.03)]
		"extinguish":
			times = [0.0, duration * 0.5, duration]
			positions = [base_position, Vector3(0, 0.012, 0), base_position]
			rotations = [Vector3(deg_to_rad(-7), 0, 0), Vector3(deg_to_rad(-9), 0, 0), Vector3(deg_to_rad(-7), 0, 0)]
	for i in range(times.size()):
		animation.track_insert_key(position_track, times[i], positions[i])
		animation.track_insert_key(rotation_track, times[i], rotations[i])
	return animation

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
	elif state == "extinguish":
		preferred = ["extinguish", "hose", "work", "attack"]
	else:
		preferred = ["idle", "stand", "breath", "rest"]
	for keyword in preferred:
		for animation_name in player_animation_names:
			if String(animation_name).to_lower().contains(keyword):
				player_animation_player.play(String(animation_name))
				player_motion_state = state
				return
	# Fall back to a known procedural clip when a source model uses unrelated names.
	if player_animation_names.has(StringName(state)):
		player_animation_player.play(state)
		player_motion_state = state
	elif state == "idle" and not player_animation_names.is_empty():
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
	_create_siren_audio()


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
	dispatch_layer.mission_completed.connect(_on_mission_completed)
	dispatch_layer.mission_failed.connect(_on_mission_failed)

func _on_dispatch_call_accepted(location: Vector3, description: String) -> void:
	rescue_scene_reached = false
	rescue_victim_active = false
	if is_instance_valid(rescue_victim):
		rescue_victim.queue_free()
		rescue_victim = null
	if description.to_lower().contains("rescate") or description.to_lower().contains("atrapada"):
		rescue_victim = Node3D.new()
		rescue_victim.name = "RescueVictim"
		rescue_victim.position = location + Vector3(2.4, 0.0, 1.5)
		game_world.add_child(rescue_victim)
		rescue_victim_active = true
		var body := _add_person_box(rescue_victim, Vector3(0.42, 0.8, 0.35), Vector3(0, 0.42, 0), Color(0.9, 0.55, 0.22))
		body.rotation_degrees.z = 72
		_add_person_box(rescue_victim, Vector3(0.32, 0.32, 0.32), Vector3(0, 0.9, 0), Color(0.82, 0.62, 0.46))
		var rescue_marker := Label3D.new()
		rescue_marker.text = "RESCATAR · ACÉRCATE Y PULSA E"
		rescue_marker.position = Vector3(0, 2.0, 0)
		rescue_marker.font_size = 28
		rescue_marker.outline_size = 5
		rescue_marker.modulate = Color(1.0, 0.72, 0.22)
		rescue_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		rescue_victim.add_child(rescue_marker)
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


func _update_dispatch_arrival() -> void:
	if not dispatch_target_active or fire_active:
		return
	var responder_position := vehicle.global_position if driving and is_instance_valid(vehicle) else (player.global_position if is_instance_valid(player) else Vector3.ZERO)
	if responder_position.distance_to(dispatch_target_position) > 11.0:
		return
	if rescue_victim_active:
		rescue_scene_reached = true
		if is_instance_valid(status_label): status_label.text = "RESCATE EN CURSO · ACÉRCATE A LA PERSONA Y PULSA E"
		return
	dispatch_target_active = false
	if is_instance_valid(dispatch_marker):
		dispatch_marker.queue_free()
		dispatch_marker = null
	if is_instance_valid(minimap):
		minimap.target_active = false
		minimap.queue_redraw()
	if is_instance_valid(dispatch_layer):
		dispatch_layer.call("mark_arrived")
		dispatch_layer.call("complete_arrival_mission")

func _on_mission_completed(reward: int, description: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = "SERVICIO COMPLETADO · %s · +%d créditos" % [description, reward]

func _on_mission_failed(description: String) -> void:
	dispatch_target_active = false
	rescue_victim_active = false
	rescue_scene_reached = false
	if is_instance_valid(rescue_victim):
		rescue_victim.queue_free()
		rescue_victim = null
	if fire_active:
		fire_active = false
		extinguishing = false
		_set_water_stream_visible(false)
		if is_instance_valid(fire_visual):
			fire_visual.queue_free()
			fire_visual = null
	if is_instance_valid(dispatch_marker):
		dispatch_marker.queue_free()
		dispatch_marker = null
	if is_instance_valid(minimap):
		minimap.target_active = false
		minimap.queue_redraw()
	if is_instance_valid(status_label):
		status_label.text = "LLAMADA VENCIDA · %s" % description

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
	var mobile_quality := graphics_quality == 0 or OS.has_feature("mobile")
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
			if is_instance_valid(dispatch_layer):
				dispatch_layer.call("complete_fire_mission")
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

	# HUD móvil: controles secundarios siempre cerrados al entrar; evita que
	# una sesión anterior deje la pantalla cubierta por botones.
	secondary_controls_open = false
	var top := PanelContainer.new()
	top.name = "StatusBar"
	top.anchor_left = 0.22
	top.anchor_top = 0.02
	top.anchor_right = 0.78
	top.anchor_bottom = 0.02
	top.offset_bottom = 38
	hud_layer.add_child(top)
	status_label = Label.new()
	status_label.text = "BOMBEROS · EN SERVICIO"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 12)
	top.add_child(status_label)

	minimap = MinimapControl.new()
	minimap.name = "Minimapa"
	minimap.custom_minimum_size = Vector2(142, 112)
	minimap.anchor_left = 0.0
	minimap.anchor_right = 0.0
	minimap.anchor_top = 0.0
	minimap.anchor_bottom = 0.0
	minimap.offset_left = 12
	minimap.offset_right = 154
	minimap.offset_top = 54
	minimap.offset_bottom = 166
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(minimap)

	var pause := Button.new()
	pause.name = "PauseButton"
	pause.text = "Ⅱ"
	pause.anchor_left = 1.0
	pause.anchor_right = 1.0
	pause.offset_left = -54
	pause.offset_right = -12
	pause.offset_top = 12
	pause.offset_bottom = 54
	pause.add_theme_font_size_override("font_size", 22)
	pause.pressed.connect(_toggle_pause_menu)
	hud_layer.add_child(pause)

	# Cruceta compacta en la esquina inferior izquierda.
	_touch_button("▲", Vector2(70, -154), Vector2(48, 46), func(): touch_move.y = -1.0, func(): touch_move.y = 0.0)
	_touch_button("▼", Vector2(70, -54), Vector2(48, 46), func(): touch_move.y = 1.0, func(): touch_move.y = 0.0)
	_touch_button("◀", Vector2(20, -104), Vector2(46, 46), func(): touch_move.x = -1.0, func(): touch_move.x = 0.0)
	_touch_button("▶", Vector2(122, -104), Vector2(46, 46), func(): touch_move.x = 1.0, func(): touch_move.x = 0.0)

	# Tres acciones principales en la esquina inferior derecha.
	_touch_button("USAR", Vector2(-116, -58), Vector2(102, 48), func(): pass, Callable(), true)
	_touch_button("MANGUERA", Vector2(-116, -112), Vector2(102, 48), func(): pass, Callable(), true)
	_touch_button("SIRENA", Vector2(-116, -166), Vector2(102, 48), func(): pass, Callable(), true)

	# Acciones poco frecuentes quedan ocultas hasta que el jugador las necesite.
	_touch_button("MÁS  +", Vector2(-116, -220), Vector2(102, 44), func(): pass, Callable(), true)
	_touch_button("LUCES", Vector2(-116, -270), Vector2(102, 42), func(): pass, Callable(), true)
	_touch_button("CORRER", Vector2(-116, -318), Vector2(102, 42), func(): pass, Callable(), true)
	_touch_button("FRENO", Vector2(-116, -366), Vector2(102, 42), func(): pass, Callable(), true)
	_touch_button("REPOSTAR", Vector2(-116, -414), Vector2(102, 42), func(): pass, Callable(), true)
	_touch_button("CÁMARA", Vector2(-116, -462), Vector2(102, 42), func(): pass, Callable(), true)
	for control_name in ["LUCES", "CORRER", "FRENO", "REPOSTAR", "CÁMARA"]:
		var secondary := hud_layer.find_child("Touch_" + control_name, true, false)
		if is_instance_valid(secondary):
			secondary.visible = false
	var more_button := hud_layer.find_child("Touch_MÁS  +", true, false)
	if is_instance_valid(more_button):
		more_button.text = "MÁS  +"
		more_button.pressed.connect(_toggle_secondary_controls)

func _touch_button(label_text: String, bottom_right_offset: Vector2, button_size: Vector2, on_down: Callable, on_up: Callable, right_side := false) -> void:
	var b := Button.new()
	b.name = "Touch_" + label_text
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
	if label_text == "USAR" or label_text == "USAR / BAJAR":
		b.pressed.connect(_interact_vehicle)
	elif label_text == "MANGUERA":
		b.pressed.connect(_toggle_extinguishing)
	elif label_text == "CÁMARA":
		b.pressed.connect(_toggle_vehicle_camera)
	elif label_text == "SIRENA":
		b.pressed.connect(_toggle_siren)
	elif label_text == "LUCES":
		b.pressed.connect(_toggle_emergency_lights)
	elif label_text == "CORRER":
		b.button_down.connect(func(): touch_run = true)
		b.button_up.connect(func(): touch_run = false)
	elif label_text == "FRENO":
		b.button_down.connect(func(): touch_brake = true)
		b.button_up.connect(func(): touch_brake = false)
	elif label_text == "REPOSTAR":
		b.pressed.connect(_try_refuel)

func _toggle_secondary_controls() -> void:
	secondary_controls_open = not secondary_controls_open
	for control_name in ["LUCES", "CORRER", "FRENO", "REPOSTAR", "CÁMARA"]:
		var secondary := hud_layer.find_child("Touch_" + control_name, true, false)
		if is_instance_valid(secondary):
			secondary.visible = secondary_controls_open
	var more_button := hud_layer.find_child("Touch_MÁS  +", true, false)
	if is_instance_valid(more_button):
		more_button.text = "MENOS  −" if secondary_controls_open else "MÁS  +"


func _create_siren_audio() -> void:
	# Generate a tiny looping two-tone siren in memory; no extra audio asset is required.
	var sample_rate := 22050
	var sample_count := sample_rate * 2
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	var phase := 0.0
	for i in range(sample_count):
		var t := float(i) / float(sample_count)
		var sweep := 0.5 - 0.5 * cos(t * TAU)
		var frequency := lerpf(620.0, 1040.0, sweep)
		phase += TAU * frequency / float(sample_rate)
		pcm.encode_s16(i * 2, int(sin(phase) * 14500.0))
	var siren_stream := AudioStreamWAV.new()
	siren_stream.format = AudioStreamWAV.FORMAT_16_BITS
	siren_stream.mix_rate = sample_rate
	siren_stream.stereo = false
	siren_stream.data = pcm
	siren_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	siren_stream.loop_begin = 0
	siren_stream.loop_end = sample_count
	siren_player = AudioStreamPlayer3D.new()
	siren_player.name = "EmergencySirenAudio"
	siren_player.stream = siren_stream
	siren_player.volume_db = -7.0
	siren_player.unit_size = 12.0
	siren_player.max_distance = 85.0
	vehicle.add_child(siren_player)

func _toggle_siren() -> void:
	if not is_instance_valid(siren_player):
		return
	siren_enabled = not siren_enabled
	if siren_enabled:
		siren_player.play()
	else:
		siren_player.stop()
	if is_instance_valid(status_label):
		status_label.text = "SIRENA ACTIVADA" if siren_enabled else "SIRENA DESACTIVADA"

func _toggle_vehicle_camera() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(camera_pivot):
		return
	if not driving:
		first_person_mode = not first_person_mode
		camera_pivot.position = Vector3(0, 1.62, 0)
		camera.position = Vector3.ZERO if first_person_mode else Vector3(0, 0.25, 4.2)
		camera.rotation_degrees = Vector3.ZERO if first_person_mode else Vector3(-8, 0, 0)
		if is_instance_valid(player_visual):
			player_visual.visible = not first_person_mode
		if is_instance_valid(status_label):
			status_label.text = "PRIMERA PERSONA · V / CÁMARA" if first_person_mode else "TERCERA PERSONA · V / CÁMARA"
		return
	vehicle_cockpit_camera = not vehicle_cockpit_camera
	if vehicle_cockpit_camera:
		camera.position = Vector3(0, 2.25, -0.85)
		camera.rotation_degrees = Vector3(-2, 0, 0)
		if is_instance_valid(status_label): status_label.text = "CÁMARA INTERIOR · C para cambiar"
	else:
		camera.position = Vector3(0, 2.0, 7.0)
		camera.rotation_degrees = Vector3(-10, 0, 0)
		if is_instance_valid(status_label): status_label.text = "CÁMARA EXTERIOR · C para cambiar"

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
	if rescue_victim_active and rescue_scene_reached and is_instance_valid(rescue_victim):
		if driving:
			if is_instance_valid(status_label): status_label.text = "BAJA DEL CAMIÓN PARA ATENDER A LA PERSONA"
			return
		var responder_position := player.global_position
		if responder_position.distance_to(rescue_victim.global_position) <= 5.0:
			rescue_victim_active = false
			rescue_scene_reached = false
			rescue_victim.queue_free()
			rescue_victim = null
			dispatch_target_active = false
			if is_instance_valid(dispatch_marker): dispatch_marker.queue_free(); dispatch_marker = null
			if is_instance_valid(minimap): minimap.target_active = false; minimap.queue_redraw()
			if is_instance_valid(dispatch_layer): dispatch_layer.call("complete_arrival_mission")
			if is_instance_valid(status_label): status_label.text = "RESCATE COMPLETADO · PERSONA ASEGURADA"
			return
	if driving:
		driving = false
		vehicle_speed = 0.0
		player.visible = true
		if is_instance_valid(player_visual):
			player_visual.visible = not first_person_mode
		player.global_position = vehicle.global_position + vehicle.global_transform.basis.x * 2.0 + Vector3(0,0.1,0)
		player.velocity = Vector3.ZERO
		camera_pivot.reparent(player)
		camera_pivot.position = Vector3(0,1.62,0)
		camera_pivot.rotation = Vector3.ZERO
		vehicle_cockpit_camera = false
		camera.position = Vector3.ZERO if first_person_mode else Vector3(0,0.25,4.2)
		camera.rotation_degrees = Vector3.ZERO if first_person_mode else Vector3(-8,0,0)
	else:
		if player.global_position.distance_to(vehicle.global_position) <= 5.0:
			driving = true
			player.visible = false
			camera_pivot.reparent(vehicle)
			camera_pivot.position = Vector3(0,2.0,0)
			camera_pivot.rotation = Vector3.ZERO
			vehicle_cockpit_camera = false
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
	# Select an authored AnimationPlayer clip for each firefighter state.
	if is_instance_valid(player_visual):
		if extinguishing:
			_play_player_animation("extinguish")
		elif planar_speed < 0.2:
			_play_player_animation("idle")
		elif speed > WALK_SPEED:
			_play_player_animation("run")
		else:
			_play_player_animation("walk")

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
		elif event.keycode == KEY_C and driving:
			_toggle_vehicle_camera()
		elif event.keycode == KEY_V and not driving:
			_toggle_vehicle_camera()
		elif event.keycode == KEY_H:
			_toggle_siren()
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


func _create_earth2road_city_map() -> bool:
	for scene_path in EARTH2ROAD_SCENE_CANDIDATES:
		if not ResourceLoader.exists(scene_path):
			continue
		var packed_map := load(scene_path) as PackedScene
		if packed_map == null:
			push_warning("La escena Earth2Road existe pero Godot no pudo cargarla: " + scene_path)
			continue
		var map_instance := packed_map.instantiate() as Node3D
		if map_instance == null:
			push_warning("La escena Earth2Road debe tener un nodo raíz Node3D: " + scene_path)
			continue
		map_instance.name = "Earth2Road_Tampa_City"
		map_instance.position = Vector3.ZERO
		map_instance.scale = Vector3.ONE
		game_world.add_child(map_instance)
		print("Mapa Earth2Road cargado: ", scene_path)
		return true
	return false


func _create_prebuilt_tampa_model() -> bool:
	var model_path := "res://assets/florida_city/tampa_city.glb"
	if not ResourceLoader.exists(model_path):
		return false
	var packed_model := load(model_path) as PackedScene
	if packed_model == null:
		push_warning("El modelo Tampa GLB existe, pero Godot no pudo importarlo como escena.")
		return false
	var model_instance := packed_model.instantiate()
	model_instance.name = "PrebuiltTampaCityModel"
	game_world.add_child(model_instance)
	model_instance.position = Vector3.ZERO
	model_instance.scale = Vector3.ONE
	print("Mapa 3D prehecho de Tampa cargado desde: ", model_path)
	return true
