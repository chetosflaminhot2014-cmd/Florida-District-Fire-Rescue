extends Node
## Progresión persistente local: carrera, créditos, experiencia, estadísticas y 50 logros.
signal career_updated
const SAVE_PATH := "user://fdfr_career.cfg"
const RANKS := [
	{"name":"Cadete","xp":0},{"name":"Bombero","xp":100},{"name":"Bombero II","xp":300},
	{"name":"Conductor","xp":650},{"name":"Especialista","xp":1100},{"name":"Sargento","xp":1750},
	{"name":"Teniente","xp":2600},{"name":"Capitán","xp":3700},{"name":"Jefe de batallón","xp":5000},
	{"name":"Jefe de distrito","xp":7000}
]
const TRACKS := [
	{"id":"services","name":"Servidor público","stat":"calls_completed","steps":[1,5,10,25,50]},
	{"id":"fires","name":"Control del fuego","stat":"fires_extinguished","steps":[1,3,5,10,25]},
	{"id":"rescues","name":"Manos que ayudan","stat":"rescues_completed","steps":[1,3,5,10,25]},
	{"id":"credits","name":"Economía de estación","stat":"credits_earned","steps":[500,2000,5000,10000,25000]},
	{"id":"distance","name":"Kilómetros de servicio","stat":"distance_km","steps":[1,10,25,50,100]},
	{"id":"time","name":"Experiencia en turno","stat":"hours_played","steps":[1,5,10,25,50]},
	{"id":"shifts","name":"Siempre de guardia","stat":"shifts_started","steps":[1,5,10,25,50]},
	{"id":"repairs","name":"Mantenimiento de flota","stat":"vehicle_repairs","steps":[1,3,5,10,25]},
	{"id":"fuel","name":"Depósito lleno","stat":"refuels","steps":[1,3,5,10,25]},
	{"id":"water","name":"Listo para extinguir","stat":"water_refills","steps":[1,3,5,10,25]}
]
var credits := 0
var experience := 0
var stats: Dictionary = {}
var unlocked_achievements: Array[String] = []
var _definitions: Array[Dictionary] = []
var _save_timer := 0.0

func _ready() -> void:
	_init_stats()
	_build_achievements()
	_load_progress()

func _process(delta: float) -> void:
	stats["seconds_played"] = float(stats.get("seconds_played",0.0)) + delta
	_save_timer += delta
	if _save_timer >= 60.0:
		_save_timer = 0.0
		stats["hours_played"] = float(stats.get("seconds_played",0.0)) / 3600.0
		_check_achievements()
		_save_progress()

func _init_stats() -> void:
	stats = {"calls_completed":0,"calls_failed":0,"fires_extinguished":0,"rescues_completed":0,
		"credits_earned":0,"vehicle_collisions":0,"vehicle_damage_events":0,"vehicle_repairs":0,
		"refuels":0,"water_refills":0,"distance_km":0.0,"seconds_played":0.0,"hours_played":0.0,"shifts_started":0}

func _build_achievements() -> void:
	for track in TRACKS:
		for index in range(track["steps"].size()):
			_definitions.append({"id":str(track["id"])+"_"+str(index+1),
				"name":str(track["name"])+" "+str(index+1),"stat":str(track["stat"]),
				"target":float(track["steps"][index])})

func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	credits = maxi(0,int(config.get_value("career","credits",0)))
	experience = maxi(0,int(config.get_value("career","experience",0)))
	var saved_stats: Variant = config.get_value("career","stats",{})
	if saved_stats is Dictionary:
		stats.merge(saved_stats,true)
	var saved: Variant = config.get_value("career","achievements",[])
	if saved is Array:
		for item in saved:
			var achievement_id := str(item)
			if not unlocked_achievements.has(achievement_id):
				unlocked_achievements.append(achievement_id)
	_check_achievements()

func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("career","credits",credits)
	config.set_value("career","experience",experience)
	config.set_value("career","stats",stats)
	config.set_value("career","achievements",unlocked_achievements)
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("No se pudo guardar la carrera F.D.F.R.: "+str(error))

func start_shift() -> void:
	record_stat("shifts_started",1)
	_save_progress()

func complete_mission(reward: int, description: String) -> void:
	var safe_reward := maxi(0,reward)
	credits += safe_reward
	experience += 30 + int(safe_reward/10)
	record_stat("calls_completed",1)
	record_stat("credits_earned",safe_reward)
	var normalized := description.to_lower()
	if normalized.contains("incendio") or normalized.contains("fuego"):
		record_stat("fires_extinguished",1)
	elif normalized.contains("rescate") or normalized.contains("atrapada"):
		record_stat("rescues_completed",1)
	_check_achievements()
	_save_progress()
	career_updated.emit()

func record_failed_call() -> void:
	record_stat("calls_failed",1)
	_save_progress()

func record_stat(stat_name: String, amount: float) -> void:
	if not stats.has(stat_name):
		push_warning("Estadística F.D.F.R. desconocida: "+stat_name)
		return
	var updated := float(stats[stat_name]) + amount
	if stat_name in ["calls_completed","calls_failed","fires_extinguished","rescues_completed","credits_earned","vehicle_collisions","vehicle_damage_events","vehicle_repairs","refuels","water_refills","shifts_started"]:
		stats[stat_name] = int(updated)
	else:
		stats[stat_name] = updated
	_check_achievements()
	career_updated.emit()

func get_rank_title() -> String:
	var result := str(RANKS[0]["name"])
	for rank in RANKS:
		if experience >= int(rank["xp"]):
			result = str(rank["name"])
		else:
			break
	return result

func get_xp() -> int:
	return experience

func get_credits() -> int:
	return credits

func get_rank_progress() -> Dictionary:
	var index := 0
	for i in range(RANKS.size()):
		if experience >= int(RANKS[i]["xp"]):
			index = i
	if index == RANKS.size()-1:
		return {"current":experience-int(RANKS[index]["xp"]),"needed":0,"next":"Rango máximo"}
	var base := int(RANKS[index]["xp"])
	var next_rank: Dictionary = RANKS[index+1]
	return {"current":experience-base,"needed":int(next_rank["xp"])-base,"next":str(next_rank["name"])}

func get_achievement_count() -> int:
	return unlocked_achievements.size()

func get_achievement_total() -> int:
	return _definitions.size()

func get_stats_snapshot() -> Dictionary:
	return stats.duplicate(true)

func _check_achievements() -> void:
	for achievement in _definitions:
		var id := str(achievement["id"])
		if unlocked_achievements.has(id):
			continue
		if float(stats.get(str(achievement["stat"]),0.0)) >= float(achievement["target"]):
			unlocked_achievements.append(id)
			experience += 10
			credits += 25
			career_updated.emit()
