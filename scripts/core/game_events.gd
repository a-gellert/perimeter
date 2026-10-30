extends Node
## Global Event Bus for Perimeter
## Facilitates decoupled communication between UI, Camera, Player, and World.

# Camera & View
signal camera_mode_changed(new_mode: int)
signal request_mode_switch(desired_mode: int)

# Player State
signal stats_updated(hp: float, stamina: float, max_stamina: float, hunger: float)
signal logs_carried_changed(current_count: int, max_capacity: int)
signal context_action_updated(action_title: String, target: Node)

# Environment & Time
signal time_updated(hours: int, minutes: int, phase: int)
signal day_phase_changed(phase: int)
signal request_sleep_dialog(bed_node: Node)
signal breach_alarm_triggered(location: Vector3)

# Construction
signal blueprint_placed(blueprint_node: Node)
signal structure_completed(structure_node: Node)

# Game State
signal player_died
signal game_restarted
signal night_raid_started(wave_count: int)
signal night_raid_ended
