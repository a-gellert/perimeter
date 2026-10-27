extends Node
## Global Enumerations for Perimeter
## Keeps all gameplay state definitions centralized and lightweight.

enum CameraMode {
	FPV,        # First-person view (movement, gathering, defense)
	ARCHITECT   # Top-down tablet view (building, assigning shifts)
}

enum DayPhase {
	DAWN,       # 05:00 - 07:00
	DAY,        # 07:00 - 18:00
	DUSK,       # 18:00 - 21:00
	NIGHT       # 21:00 - 05:00
}

enum ResourceType {
	NONE,
	LOG,
	SCRAP,
	FUEL,
	PROVISIONS,
	TECTONIC_AMBER,
	SPORE_GLAND
}

enum Shift {
	DAY_SHIFT,
	NIGHT_SHIFT,
	RESTING
}
