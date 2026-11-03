extends Node

func _ready() -> void:
	print("=== RUNNING SPORE MONSTERS & SPAWNER INTEGRATION TESTS ===")

	# 1. Test SporeZombie instantiation
	var zombie_scene := load("res://scenes/enemies/SporeZombie.tscn") as PackedScene
	assert(zombie_scene != null, "SporeZombie scene should exist")
	var zombie := zombie_scene.instantiate() as SporeZombie
	assert(zombie != null, "SporeZombie should instantiate as SporeZombie")
	add_child(zombie)
	assert(zombie.max_health == 65.0, "Zombie health should be 65")
	assert(zombie.animator != null, "Zombie should have MutantAnimator")
	zombie.animator.play_attack_animation(0.2)
	zombie.animator.play_hit_reaction()
	print("[PASS] SporeZombie instantiated and animator verified.")

	# 2. Test SporeWolf instantiation
	var wolf_scene := load("res://scenes/enemies/SporeWolf.tscn") as PackedScene
	assert(wolf_scene != null, "SporeWolf scene should exist")
	var wolf := wolf_scene.instantiate() as SporeWolf
	assert(wolf != null, "SporeWolf should instantiate as SporeWolf")
	add_child(wolf)
	assert(wolf.chase_speed == 8.5, "Wolf chase speed should be 8.5")
	assert(wolf.animator != null, "Wolf should have MutantAnimator")
	print("[PASS] SporeWolf instantiated and animator verified.")

	# 3. Test SporeBoar instantiation
	var boar_scene := load("res://scenes/enemies/SporeBoar.tscn") as PackedScene
	assert(boar_scene != null, "SporeBoar scene should exist")
	var boar := boar_scene.instantiate() as SporeBoar
	assert(boar != null, "SporeBoar should instantiate as SporeBoar")
	add_child(boar)
	assert(boar.max_health == 135.0, "Boar max health should be 135")
	assert(boar.animator != null, "Boar should have MutantAnimator")
	print("[PASS] SporeBoar instantiated and animator verified.")

	# 4. Test SporeNestSpawner instantiation & mechanics
	var spawner_scene := load("res://scenes/environment/SporeNestSpawner.tscn") as PackedScene
	assert(spawner_scene != null, "SporeNestSpawner scene should exist")
	var spawner := spawner_scene.instantiate() as SporeNestSpawner
	assert(spawner != null, "SporeNestSpawner should instantiate")
	add_child(spawner)
	assert(spawner.health == 120.0, "Spawner health should be 120")
	spawner.take_damage(25.0)
	assert(spawner.health == 95.0, "Spawner health should be 95 after damage")
	print("[PASS] SporeNestSpawner instantiated and damage mechanics verified.")

	# Cleanup
	zombie.queue_free()
	wolf.queue_free()
	boar.queue_free()
	spawner.queue_free()

	print("=== ALL SPORE MONSTER TESTS PASSED SUCCESSFULLY! ===")
	get_tree().quit(0)
