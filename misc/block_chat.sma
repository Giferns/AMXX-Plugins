new const PLUGIN_VERSION[] = "1.0"

#include amxmodx

public plugin_precache() {
	register_plugin("Block Chat", PLUGIN_VERSION, "mx?!")

	register_clcmd("say", "clcmd_HookSay")
	register_clcmd("say_team", "clcmd_HookSay")
}

public clcmd_HookSay(pPlayer) {
	static Float:fLastTime[MAX_PLAYERS + 1]
	new Float:fGameTime = get_gametime()

	if(fGameTime - fLastTime[pPlayer] < 1.0) {
		return PLUGIN_HANDLED
	}

	fLastTime[pPlayer] = fGameTime

	new szArgs[200]
	read_args(szArgs, charsmax(szArgs))
	remove_quotes(szArgs)

	if(szArgs[0] == '/' || szArgs[0] == '!' || szArgs[0] == '.') {
		return PLUGIN_HANDLED_MAIN
	}

	client_print_color(pPlayer, print_team_red, "^3* ^1Чат отключён на данном сервере!")
	return PLUGIN_HANDLED
}