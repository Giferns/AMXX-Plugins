/*
	1.0 (10.11.2025 by mx?!):
		* First release
*/

new const PLUGIN_VERSION[] = "1.0"

#define HEALTH_TO_ADD 10

#include amxmodx
#include reapi

public plugin_init() {
	register_plugin("Simple Vampirism", PLUGIN_VERSION, "mx?!")
	
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", true)
}

public CBasePlayer_Killed_Post(pVictim, pKiller, iGibType) {
	if(!is_user_alive(pKiller) || is_user_connected(pVictim) || get_member(pVictim, m_iTeam) == get_member(pKiller, m_iTeam) || get_member(pVictim, m_bKilledByBomb)) {
		return
	}
	
	const Float:fMaxHealth = 100.0
	
	new Float:fHealth = get_entvar(pKiller, var_health)
	
	if(fHealth >= fMaxHealth) {
		return
	}
	
	set_entvar(pKiller, var_health, floatmin(fMaxHealth, fHealth + HEALTH_TO_ADD.0))
}