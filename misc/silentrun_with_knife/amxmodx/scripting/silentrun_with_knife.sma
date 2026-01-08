new const PLUGIN_VERSION[] = "1.0"

#include amxmodx
#include hamsandwich
#include reapi

enum _:CVAR_ENUM {
	CVAR__ACCESS[32]
}

new g_eCvar[CVAR_ENUM]

public plugin_init() {
	register_plugin("SilentRun with Knife", PLUGIN_VERSION, "mx?!")
		
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "OnKnifeDeploy_Post", true)
	RegisterHam(Ham_Item_Holster, "weapon_knife", "OnKnifeHolster_Post", true)
	
	bind_pcvar_string( create_cvar( "srwk_access", "t", .description = "AMXX access flags (any of requirement), leave blank to access for all" ),
		g_eCvar[CVAR__ACCESS], charsmax(g_eCvar[CVAR__ACCESS]) );
	
	AutoExecConfig(.name = "silentrun_with_knife")
}

bool:CheckRules(pPlayer) {
	return (is_user_alive(pPlayer) && (!g_eCvar[CVAR__ACCESS][0] || (get_user_flags(pPlayer) & read_flags(g_eCvar[CVAR__ACCESS]))))
}

public OnKnifeDeploy_Post(pItem) {
	if(!is_entity(pItem)) {
		return
	}
	
	new pPlayer = get_member(pItem, m_pPlayer)

	if(CheckRules(pPlayer)) {
		rg_set_user_footsteps(pPlayer, .silent = true)
	}
}

public OnKnifeHolster_Post(pItem) {
	if(!is_entity(pItem)) {
		return
	}
	
	new pPlayer = get_member(pItem, m_pPlayer)

	if(CheckRules(pPlayer)) {
		rg_set_user_footsteps(pPlayer, .silent = false)
	}
}