#include <amxmodx>

const Float:g_fDelay = 5.0 // задержка проверки после входа на сервер (в секундах)
const Float:g_fFreq = 15.0 // как часто проверять (в секундах)
const g_iMaxBads = 3 // кикать если значение квара 'bad request' (нет квара или протектор отказывает в проверке)
const Float:g_fMaxValue = 0.25 // макс. значение квара (лучше не трогать)
const Float:g_fDefaultValue = 0.25 // значение квара по-умолчанию

const ADMIN_FLAG = ADMIN_BAN // флаг админа (видят инфу о киках)

new const LOGFILE[] = "gl_alphamin_checker.log"

new g_iBadRequests[MAX_PLAYERS + 1]

public plugin_init() {
	register_plugin("gl_alphamin checker", "1.0", "mx?!")
}

public client_putinserver(pPlayer) {
	if(is_user_bot(pPlayer) || is_user_hltv(pPlayer)) {
		return
	}

	set_task(g_fDelay, "task_CheckDelay", pPlayer)
}

public task_CheckDelay(pPlayer) {
	QueryCvar(pPlayer)

	set_task(g_fFreq, "task_CheckDelay", pPlayer, .flags = "b")
}

QueryCvar(pPlayer) {
	query_client_cvar(pPlayer, "gl_alphamin", "CheckValue")
}

public CheckValue(pPlayer, szCvar[], szValue[], szParam[]) {
	if(!is_user_connected(pPlayer)) {
		return
	}

	if(szValue[0] == 'B' && equal(szValue, "Bad CVAR request")) {
		if(++g_iBadRequests[pPlayer] == g_iMaxBads) {
			log_to_file(LOGFILE, "%N kicked due to bad gl_alphamin value (%i bads)", pPlayer, g_iBadRequests[pPlayer])
			ShowInfo(pPlayer, "bad request")
			server_cmd("kick #%i ^"Bad gl_alphamin value^"", get_user_userid(pPlayer))
		}

		return
	}

	g_iBadRequests[pPlayer] = 0

	new Float:fValue = str_to_float(szValue)

	if(fValue > g_fMaxValue) {
		log_to_file(LOGFILE, "%N kicked due to wrong gl_alphamin value (%f / %f)", pPlayer, fValue, g_fMaxValue)
		new szValue[8]; formatex(szValue, charsmax(szValue), "%f", fValue)
		ShowInfo(pPlayer, szValue)
		server_cmd("kick #%i ^"%s^"", get_user_userid(pPlayer), fmt("Пропиши в консоли gl_alphamin %.2f", g_fDefaultValue))
	}
}

ShowInfo(pPlayer, const szValue[]) {
	new pPlayers[MAX_PLAYERS], iPlCount, pGamer
	get_players(pPlayers, iPlCount, "c")

	for(new i; i < iPlCount; i++) {
		pGamer = pPlayers[i]

		if((get_user_flags(pGamer) & ADMIN_FLAG) || is_user_hltv(pGamer)) {
			client_print_color(pGamer, pPlayer, "^4* ^3%n ^1кикнут за ^3gl_alphamin ^1(^3значение: %s^1)", pPlayer, szValue)
		}
	}
}

public client_disconnected(pPlayer) {
	g_iBadRequests[pPlayer] = 0
	remove_task(pPlayer)
}