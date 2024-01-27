new const PLUGIN_VERSION[] = "1.2"

new const START_MAP[] = "de_dust2" // вписать карту с которой перезапускается сервер
new const MAP_TO_CHANGE[] = "aim_headshot" // вписать карту на которую надо будет поменять карту
const Float:DELAY = 60.0 // задержка между запуском сервера и сменой карты (в секундах), минимум 0.1
const HOUR = 8 // час работы (когда работать)
const MIN_WINDOW_START = 8 // минута работы (минимальное окно)
const MIN_WINDOW_END = 15 // минута работы (максимальное окно)

#include amxmodx

public plugin_init() {
	register_plugin("Change map at restart", PLUGIN_VERSION, "mx?!")

	new szMapName[64]
	get_mapname(szMapName, charsmax(szMapName))

	if(!equal(szMapName, START_MAP)) {
		return
	}

	new iHour, iMinutes

	time(iHour, iMinutes)

	if(iHour != HOUR || (iMinutes < MIN_WINDOW_START || iMinutes > MIN_WINDOW_END)) {
		return
	}

	if(!get_cvar_pointer("_cmar")) {
		set_task(DELAY, "task_ChangeMap")
	}
}

public task_ChangeMap() {
	engine_changelevel(MAP_TO_CHANGE)
}

public plugin_end() {
	create_cvar("_cmar", "1")
}