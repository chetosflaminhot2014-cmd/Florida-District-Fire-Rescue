extends Node

signal wanted_level_changed(stars: int, charges: int)

const MAX_STARS := 5
const STAR_DECAY_SECONDS := 32.0

var stars: int = 0
var charges: Array[String] = []
var decay_elapsed: float = 0.0

func register_pedestrian_collision() -> void:
	_add_charge("Colisión con peatón", 2)

func register_red_light_violation(authorized_emergency: bool) -> void:
	if authorized_emergency:
		return
	_add_charge("Cruzar semáforo en rojo sin llamada autorizada", 1)

func _add_charge(description: String, star_amount: int) -> void:
	charges.append(description)
	stars = clampi(stars + star_amount, 0, MAX_STARS)
	decay_elapsed = 0.0
	wanted_level_changed.emit(stars, charges.size())

func clear_wanted_level() -> void:
	stars = 0
	charges.clear()
	decay_elapsed = 0.0
	wanted_level_changed.emit(stars, charges.size())

func _process(delta: float) -> void:
	if stars <= 0:
		decay_elapsed = 0.0
		return
	decay_elapsed += delta
	if decay_elapsed >= STAR_DECAY_SECONDS:
		decay_elapsed = 0.0
		stars = maxi(0, stars - 1)
		wanted_level_changed.emit(stars, charges.size())
