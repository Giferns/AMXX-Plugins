// https://dev-cs.ru/threads/21083/page-12#post-158708

/* 1.0 (26.09.2023):
	* Первая версия
*/

new const PLUGIN_VERSION[] = "1.0"

#include amxmodx
#include fakemeta

new const LOGFILE[] = "check_cl_lw_cl_lc.log"

new bool:g_bKicked[MAX_PLAYERS + 1]

public plugin_init() {
	register_plugin("Check cl_lw/cl_lc", PLUGIN_VERSION, "mx?!")

	register_dictionary("check_cl_lw_cl_lc.txt")

	register_forward(FM_ClientUserInfoChanged, "ClientUserInfoChanged_Post", true)
}

public ClientUserInfoChanged_Post(pPlayer, hBuffer) {
	if(!is_user_connected(pPlayer) || is_user_bot(pPlayer) || is_user_hltv(pPlayer)) {
		return
	}

	CheckValues(pPlayer)
}

CheckValues(pPlayer) {
	CheckValue(pPlayer, "cl_lw")
	CheckValue(pPlayer, "cl_lc")
}

CheckValue(pPlayer, const szKey[]) {
	if(g_bKicked[pPlayer]) {
		return
	}

	new szValue[8]
	get_user_info(pPlayer, szKey, szValue, charsmax(szValue))

	if(!str_to_num(szValue)) {
		g_bKicked[pPlayer] = true
		log_to_file(LOGFILE, "%N kicked for %s 0", pPlayer, szKey)
		server_cmd("kick #%i ^"%L^"", get_user_userid(pPlayer), pPlayer, "KICK_CLLW_INFO", szKey)
	}
}

public client_remove(pPlayer) {
	g_bKicked[pPlayer] = false
}