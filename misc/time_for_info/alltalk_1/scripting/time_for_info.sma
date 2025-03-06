new const PLUGIN_VERSION[] = "1.0"

// Предполагается юзать с sv_alltalk 1

#include <amxmodx>
#include <reapi>

enum {
	STATE__DEAD,
	STATE__DYING,
	STATE__ALIVE
}

new g_iState[MAX_PLAYERS + 1] = { STATE__DEAD, ... }
new g_iEnabled, g_iInfoTime

public plugin_init() {
	register_plugin("Time for Info", PLUGIN_VERSION, "mx?!")
	register_dictionary("time_for_info.txt")

	bind_pcvar_num(create_cvar("time_for_info_enabled", "1"), g_iEnabled) // включён плагин или нет
	bind_pcvar_num(create_cvar("time_for_info_time", "5"), g_iInfoTime) // сколько секунд есть для инфы
	
	AutoExecConfig() // Создать и запустить автоконфиг в 'amxmodx/configs/plugins'

	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true)
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", true)
	RegisterHookChain(RG_CSGameRules_CanPlayerHearPlayer, "CSGameRules_CanPlayerHearPlayer_Pre")
}

public client_disconnected(pPlayer) {
	remove_task(pPlayer)
	g_iState[pPlayer] = STATE__DEAD
}

public CBasePlayer_Spawn_Post(pPlayer) {
	if(is_user_alive(pPlayer)) {
		g_iState[pPlayer] = STATE__ALIVE
		remove_task(pPlayer)
	}
}

public CBasePlayer_Killed_Post(pPlayer) {
	g_iState[pPlayer] = STATE__DYING

	set_task(float(g_iInfoTime), "task_ResetSpeak", pPlayer)

	if(g_iEnabled) {
		client_print_color(pPlayer, print_team_red, "%l", "TFI__KILLED", g_iInfoTime)
	}
}

public CSGameRules_CanPlayerHearPlayer_Pre(pListener, pSender) {
	if(g_iEnabled && g_iState[pSender] == STATE__DEAD && g_iState[pListener] == STATE__ALIVE) {
		SetHookChainReturn(ATYPE_BOOL, false)
		return HC_SUPERCEDE
	}

	return HC_CONTINUE
}

public task_ResetSpeak(pPlayer) {
	g_iState[pPlayer] = STATE__DEAD

	if(g_iEnabled) {
		client_print_color(pPlayer, print_team_red, "%l", "TFI__DEAD")
	}
}