new const PLUGIN_VERSION[] = "1.1";

#include <amxmodx>
#include <engine>
#include <reapi>

const TASKID__DISABLE_BUY = 18976;

new const g_szBuyZoneClassName[] = "func_buyzone";

new g_pBuyZoneEnt;
new Float:g_fBuyTime;

public plugin_init() {
	register_plugin("Custom Buyzone", PLUGIN_VERSION, "mx?!");

	new pCvar = get_cvar_pointer("mp_buytime");
	g_fBuyTime = get_pcvar_float(pCvar);
	hook_cvar_change(pCvar, "hook_CvarChange");
}

public plugin_cfg() {
	new pEnt = MaxClients;

	while((pEnt = rg_find_ent_by_class(pEnt, g_szBuyZoneClassName, .useHashTable = true))) {
		set_entvar(pEnt, var_flags, FL_KILLME);
	}

	g_pBuyZoneEnt = rg_create_entity(g_szBuyZoneClassName, .useHashTable = true);
	
	if(is_nullent(g_pBuyZoneEnt)) {
		set_fail_state("g_pBuyZoneEnt is NULLENT");
		return;
	}
	
	DispatchKeyValue(g_pBuyZoneEnt, "team", "0");
	DispatchSpawn(g_pBuyZoneEnt);
	entity_set_size(g_pBuyZoneEnt, Float:{-8191.0, -8191.0, -8191.0}, Float:{8191.0, 8191.0, 8191.0});
	set_entvar(g_pBuyZoneEnt, var_solid, SOLID_NOT);
	
	set_member_game(m_bMapHasBuyZone, true);
	
	RegisterHookChain(RG_CSGameRules_RestartRound, "OnRestartRound_Pre");
	RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "OnRoundFreezeEnd_Post", true);
}

public OnRestartRound_Pre() {
	if(g_fBuyTime) {
		remove_task(TASKID__DISABLE_BUY);
		set_entvar(g_pBuyZoneEnt, var_solid, SOLID_TRIGGER);
	}
}

public OnRoundFreezeEnd_Post() {
	if(g_fBuyTime > 0.0) {
		set_task(g_fBuyTime, "task_DisableBuy", TASKID__DISABLE_BUY);
	}
}

public hook_CvarChange(pCvar, const szOldVal[], const szNewVal[]) {
	g_fBuyTime = str_to_float(szNewVal);

	if(g_fBuyTime <= 0.0) {
		if(g_fBuyTime == 0.0) {
			set_entvar(g_pBuyZoneEnt, var_solid, SOLID_NOT);
		}
		
		remove_task(TASKID__DISABLE_BUY);
	}
}

public task_DisableBuy() {
	set_entvar(g_pBuyZoneEnt, var_solid, SOLID_NOT);
}