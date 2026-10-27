class_name PlayerStats
extends Node
## Manages Player Health, Stamina/Energy, and Hunger.
## Kept small and focused strictly on status numbers and depletion/recovery.

@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
@export var max_hunger: float = 100.0

@export var stamina_regen_rate: float = 12.0
@export var hunger_deplete_rate: float = 0.25

var health: float = 100.0
var stamina: float = 100.0
var hunger: float = 100.0

func _ready() -> void:
	health = max_health
	stamina = max_stamina
	hunger = max_hunger
	_emit_stats()

func _process(delta: float) -> void:
	# Passive hunger decay
	hunger = maxf(0.0, hunger - hunger_deplete_rate * delta)
	
	# Regenerate stamina if hungry enough (> 10%)
	if hunger > 10.0 and stamina < max_stamina:
		restore_stamina(stamina_regen_rate * delta)
	
	_emit_stats()

func consume_stamina(amount: float) -> bool:
	if stamina >= amount:
		stamina = maxf(0.0, stamina - amount)
		_emit_stats()
		return true
	return false

func restore_stamina(amount: float) -> void:
	stamina = minf(max_stamina, stamina + amount)
	_emit_stats()

func take_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	_emit_stats()

func heal(amount: float) -> void:
	health = minf(max_health, health + amount)
	_emit_stats()

func _emit_stats() -> void:
	GameEvents.stats_updated.emit(health, stamina, max_stamina, hunger)
