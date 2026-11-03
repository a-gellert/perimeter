class_name LocalizationData
extends Node
## Central Localization Dictionary (RU / EN) for Perimeter: Warden.
## Provides translated UI labels, survival lore, item descriptions, and quest hints.

const TRANSLATIONS := {
	"ru": {
		"game_title": "ПЕРИМЕТР",
		"game_subtitle": "КОРДОН ЕГЕРЯ  |  ЗОНА КАРАНТИНА",
		"btn_continue": "Продолжить",
		"btn_new_game": "Новая игра",
		"btn_settings": "Настройки",
		"btn_quit": "Выход",
		"quest_day1": "1. Срубите сосну топором и заделайте брешь в частоколе брёвнами.",
		"quest_day2": "2. Осмотрите АЗС на западе: найдите канистры топлива и металлолом.",
		"quest_day3": "3. Постройте смотровую вышку и вооружите часового на ночь.",
		"quest_day4": "4. Добудьте янтарь в серных штольнях и включите УФ-прожектор.",
		"quest_day5": "5. Восстановите радиомаяк на Северном хребте и вызовите эвакуацию!",
		"warning_night": "⚠ Сумерки сгущаются. Спящие твари пробуждаются в оврагах!",
		"warning_raid": "⚠ ТРЕВОГА: НОЧНОЙ ШТУРМ ПЕРИМЕТРА! ⚠",
		"warning_breach": "🚨 ВНИМАНИЕ: ЗАБОР ПРОЛОМЛЕН! ОНИ ВО ДВОРЕ! 🚨",
		"weapon_axe": "Топор Егеря",
		"weapon_rifle": "Охотничий Карабин ТОЗ-16",
		"weapon_trap": "Стальной Капкан"
	},
	"en": {
		"game_title": "PERIMETER",
		"game_subtitle": "RANGER'S POST  |  QUARANTINE ZONE",
		"btn_continue": "Continue",
		"btn_new_game": "New Game",
		"btn_settings": "Settings",
		"btn_quit": "Quit",
		"quest_day1": "1. Chop a pine tree and fortify palisade breach with carried logs.",
		"quest_day2": "2. Scavenge the western Gas Station: recover fuel canisters and scrap.",
		"quest_day3": "3. Construct a watchtower and assign a nocturnal sentry.",
		"quest_day4": "4. Gather tectonic amber in sulfur shafts to power UV spotlights.",
		"quest_day5": "5. Repair the rescue radio beacon on North Ridge and call for extraction!",
		"warning_night": "⚠ Dusk falls. Spore sleepers awaken in the ravines!",
		"warning_raid": "⚠ WARNING: NIGHT SIEGE COMMENCED! ⚠",
		"warning_breach": "🚨 DANGER: PERIMETER BREACHED! THEY ARE INSIDE! 🚨",
		"weapon_axe": "Warden's Axe",
		"weapon_rifle": "Hunting Carbine TOZ-16",
		"weapon_trap": "Steel Bear Trap"
	}
}

static func get_text(key: String, lang: String = "ru") -> String:
	if TRANSLATIONS.has(lang) and TRANSLATIONS[lang].has(key):
		return TRANSLATIONS[lang][key]
	if TRANSLATIONS["ru"].has(key):
		return TRANSLATIONS["ru"][key]
	return key
