#include amxmodx
#include amxmisc

new const PLUGIN_NAME[] = "Console MOTD"
new const PLUGIN_VERSION[] = "1.0"

// Config filename in 'amxmodx/configs'.
new const CFG_FILENAME[] = "console_motd.ini"

// Maximum of console message rows. Can be changed if needed.
const MAX_STRINGS = 10

// Delay between logging into the server and displaying the message. Can be changed if needed.
const Float:MSG_DELAY = 1.0

const MSG_LEN = 256

new g_szMotdRow[MAX_STRINGS][MSG_LEN], g_iMsgCount

public plugin_init() {
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, "mx?!")
	
	new szBuffer[MSG_LEN]
	new iLen = get_configsdir(szBuffer, charsmax(szBuffer))
	formatex(szBuffer[iLen], charsmax(szBuffer) - iLen, "/%s", CFG_FILENAME)
	new hFile = fopen(szBuffer, "r")
	
	if(!hFile) {
		set_fail_state("Can't %s '%s'", file_exists(szBuffer) ? "read" : "find", szBuffer)
		return
	}
	
	while(fgets(hFile, szBuffer, charsmax(szBuffer))) {
		trim(szBuffer)
		
		if(!szBuffer[0] || szBuffer[0] == ';' || szBuffer[0] == '/') {
			continue
		}
		
		replace_string(szBuffer, charsmax(szBuffer), "<br>", "^n")
		
		copy(g_szMotdRow[g_iMsgCount], charsmax(g_szMotdRow[]), szBuffer)
		
		if(++g_iMsgCount == MAX_STRINGS) {
			break
		}
	}
	
	fclose(hFile)
	
	server_print("[%s] Loaded %i message rows", PLUGIN_NAME, g_iMsgCount)
	
	if(!g_iMsgCount) {
		pause("ad")
	}
}

public client_putinserver(pPlayer) {
	if(!is_user_bot(pPlayer) && !is_user_hltv(pPlayer)) {
		set_task(MSG_DELAY, "task_PrintMOTD", pPlayer)
	}
}

public client_disconnected(pPlayer) {
	remove_task(pPlayer)
}

public task_PrintMOTD(pPlayer) {
	for(new i; i < g_iMsgCount; i++) {
		engclient_print(pPlayer, engprint_console, g_szMotdRow[i])
	}
}