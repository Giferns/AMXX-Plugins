#include amxmodx

new const PLUGIN_VERSION[] = "1.0";

const Float:CHECK_FREQ = 5.0;
const MONTH_FIRST_DAY = 1;
const MONTH_LAST_DAY = 3;
new const LOG_FILENAME[] = "gl_monolights_check.log";

public plugin_init() {
	register_plugin("gl_monolights check", PLUGIN_VERSION, "mx?!");
	
	new iDay; date(.day = iDay);
	
	if(iDay < MONTH_FIRST_DAY || iDay > MONTH_LAST_DAY) {
		pause("ad");
		return;
	}
}

public client_connect(pPlayer) {
	if(!is_user_bot(pPlayer) && !is_user_hltv(pPlayer)) {
		set_task(CHECK_FREQ, "task_CheckCvar", pPlayer, .flags = "b");
		task_CheckCvar(pPlayer);
	}
}

public client_disconnected(pPlayer) {
	remove_task(pPlayer);
}

public task_CheckCvar(pPlayer) {
	query_client_cvar(pPlayer, "gl_monolights", "CvarValueHandler");
}

public CvarValueHandler(pPlayer, const szCvar[], const szValue[]) {
	if(szValue[0] == 'B' || str_to_num(szValue)) {
		log_to_file(LOG_FILENAME, "%N --- cvar value: %s", pPlayer, szValue);
		server_cmd("kick #%i ^"Пропишите gl_monolights 0^"", get_user_userid(pPlayer));
	}
}