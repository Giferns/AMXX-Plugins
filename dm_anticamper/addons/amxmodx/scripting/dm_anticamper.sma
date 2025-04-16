/*
	1.0 (16.04.2025 by mx?!):
		* First release
*/

new const PLUGIN_VERSION[] = "1.0"

#include amxmodx
#include reapi
#include xs

// Create and execture autoconfig?
// Valus represents name of the config file, excluding the .cfg extension. If empty, <plugin-filename.cfg> is assumed.
#define AUTO_CFG ""

// Debug mode. Should be commented by default.
//#define DEBUG

enum _:CVAR_ENUM {
	Float:CVAR_F__CHECK_FREQ,
	CVAR__CAMP_RADIUS,
	CVAR__MAX_WARNS,
	CVAR__SLAP_POWER
}

new g_eCvar[CVAR_ENUM]
new g_iLastCampOrigin[MAX_PLAYERS + 1][3]
new g_iWarns[MAX_PLAYERS + 1]

public plugin_init() {
	register_plugin("DM AntiCamper", PLUGIN_VERSION, "mx?!")
	register_dictionary("dm_anticamper.txt")
	
	RegCvars()
	
	set_task(3.0, "task_RegHooks")
}

public task_RegHooks() {	
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true)
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", true)
}

RegCvars() {
	bind_pcvar_float(create_cvar("dmac_check_freq", "1.0", .description = "Check frequency"), g_eCvar[CVAR_F__CHECK_FREQ])
	bind_pcvar_num(create_cvar("dmac_camp_radius", "400", .description = "Camping radius to gain warns"), g_eCvar[CVAR__CAMP_RADIUS])
	bind_pcvar_num(create_cvar("dmac_max_warns", "15", .description = "Max warns to start slapping"), g_eCvar[CVAR__MAX_WARNS])
	bind_pcvar_num(create_cvar("dmac_slap_power", "1", .description = "Damage power of each slap"), g_eCvar[CVAR__SLAP_POWER])
	
#if defined AUTO_CFG
	AutoExecConfig(.name = AUTO_CFG)
#endif
}

public CBasePlayer_Spawn_Post(pPlayer) {
	if(is_user_alive(pPlayer) && !is_user_bot(pPlayer)) {
		g_iLastCampOrigin[pPlayer][0] = g_iLastCampOrigin[pPlayer][1] = g_iLastCampOrigin[pPlayer][2] = 4096
		g_iWarns[pPlayer] = 0
		remove_task(pPlayer)
		
		if(g_eCvar[CVAR_F__CHECK_FREQ]) {
			set_task(g_eCvar[CVAR_F__CHECK_FREQ], "task_CheckCoords", pPlayer, .flags = "b")
		}
	}
}

public CBasePlayer_Killed_Post(pVictim, pKiller, iGibType) {
	remove_task(pVictim)
}

public client_disconnected(pPlayer) {
	remove_task(pPlayer)
}

public task_CheckCoords(pPlayer) {
	new iOrigin[3]
	get_user_origin(pPlayer, iOrigin, Origin_Client)
	
	if(
		IsIntCoordsNearlyEqual(iOrigin[0], g_iLastCampOrigin[pPlayer][0])
			&&
		IsIntCoordsNearlyEqual(iOrigin[1], g_iLastCampOrigin[pPlayer][1])
			&&
		IsIntCoordsNearlyEqual(iOrigin[2], g_iLastCampOrigin[pPlayer][2])
	) {
		if(++g_iWarns[pPlayer] >= g_eCvar[CVAR__MAX_WARNS]) {
			client_print(pPlayer, print_center, "%l", "DMAC__STOP_CAMPING")
			user_slap(pPlayer, g_eCvar[CVAR__SLAP_POWER])
		}
	}
	else {
		g_iWarns[pPlayer] = 0
		get_user_origin(pPlayer, g_iLastCampOrigin[pPlayer], Origin_Client)
	}
	
#if defined DEBUG
	client_print(pPlayer, print_chat, "DM AntiCamper warns: %i/%i", g_iWarns[pPlayer], g_eCvar[CVAR__MAX_WARNS])
#endif
}

stock bool:IsIntCoordsNearlyEqual(iCoord1, iCoord2) {
	return xs_abs(iCoord1 - iCoord2) <= g_eCvar[CVAR__CAMP_RADIUS]
}