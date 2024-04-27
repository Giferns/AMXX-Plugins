#include <amxmodx>
#include <fakemeta>
#include <reapi>

/* 1.1 (27.04.2024 by mx?!):
	* Добавлен периодический вывод чат-сообщения о активном режиме 'Только headshot'
	* Добавлен словарь 'data/amx_hs_only.txt'
	* Добавлен квар 'amx_hs_only_msg_freq'
	* Добавлен квар 'amx_hs_only_obey_knife'
*/

new const PLUGIN_VERSION[] = "1.1"

#define IsPlayer(%0) (1 <= %0 <= MaxClients)

new HookChain:g_hTraceAttack, HookChain:g_hSpawn, Float:g_fLastMsg[MAX_PLAYERS + 1]
new Float:g_fMsgFreq, g_iObeyKnife

public plugin_init() {
	register_plugin("HS Only", PLUGIN_VERSION, "mx?!")
	register_dictionary("amx_hs_only.txt")

	new pCvar = create_cvar("amx_hs_only", "0")
	set_pcvar_num(pCvar, 0)
	hook_cvar_change(pCvar, "hook_CvarChange")

	bind_pcvar_float(create_cvar("amx_hs_only_msg_freq", "180.0"), g_fMsgFreq)

	bind_pcvar_num(create_cvar("amx_hs_only_obey_knife", "0"), g_iObeyKnife)
}

public CBasePlayer_Spawn_Post(pPlayer) {
	if(!is_user_alive(pPlayer) || !g_fMsgFreq) {
		return
	}

	new Float:fGameTime = get_gametime()

	if(g_fLastMsg[pPlayer] && fGameTime - g_fLastMsg[pPlayer] < g_fMsgFreq) {
		return
	}

	g_fLastMsg[pPlayer] = get_gametime()
	client_print_color(pPlayer, print_team_red, "%l", "HS_ONLY__ANNOUNCE")
}

public CBasePlayer_TraceAttack_Pre(pVictim, pAttacker, Float:fDamage, Float:fVecDir[3], hTraceHandle, bitsDamageType) {
	if(HitBoxGroup:get_tr2(hTraceHandle, TR_iHitgroup) != HITGROUP_HEAD && IsPlayer(pAttacker) && (g_iObeyKnife || get_user_weapon(pAttacker) != CSW_KNIFE)) {
		return HC_SUPERCEDE
	}

	return HC_CONTINUE
}

public hook_CvarChange(pCvar, const szOldVal[], const szNewVal[]) {
	if(!str_to_num(szNewVal)) {
		if(g_hTraceAttack) {
			DisableHookChain(g_hTraceAttack)
			DisableHookChain(g_hSpawn)
		}

		return
	}

	if(!g_hTraceAttack) {
		g_hTraceAttack = RegisterHookChain(RG_CBasePlayer_TraceAttack, "CBasePlayer_TraceAttack_Pre")
		g_hSpawn = RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true)
	}
	else {
		EnableHookChain(g_hTraceAttack)
		EnableHookChain(g_hSpawn)

		arrayset(g_fLastMsg, 0, sizeof(g_fLastMsg))
	}
}