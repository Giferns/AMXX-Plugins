new const PLUGIN_VERSION[] = "1.0"

// Частота сброса счёта, в минутах (минимум 1)
#define RS_FREQ_MINS 30

#include amxmodx
#include reapi

new Float:g_fRsFreqSecs
new bool:g_bBot[MAX_PLAYERS + 1]
new Float:g_fLastTime[MAX_PLAYERS + 1]

public plugin_init() {
	register_plugin("Bot AutoRS", PLUGIN_VERSION, "mx?!")

	g_fRsFreqSecs = RS_FREQ_MINS.0 * 60.0

	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Pre")
}

public client_putinserver(pPlayer) {
	g_bBot[pPlayer] = bool:is_user_bot(pPlayer)
	g_fLastTime[pPlayer] = get_gametime()
}

public CBasePlayer_Spawn_Pre(pPlayer) {
	if(!g_bBot[pPlayer] || !is_user_connected(pPlayer)) {
		return
	}

	new Float:fGameTime = get_gametime()

	if(fGameTime - g_fLastTime[pPlayer] < g_fRsFreqSecs) {
		return
	}

	g_fLastTime[pPlayer] = fGameTime
	set_member(pPlayer, m_iDeaths, 0)
	set_entvar(pPlayer, var_frags, 0)
}