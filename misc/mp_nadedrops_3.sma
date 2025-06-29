/*
	// Drop a grenade after player death
	// 0 - disabled
	// 1 - drop first available grenade
	// 2 - drop all grenades
	// [NEW] 3 - drop one grenade in turn: hegrenade, flashbang (if no hegrenade), smoke (if no hegrenade and flashbang)
	//
	// Default value: "0"
	mp_nadedrops "0"
*/

/*
	1.0 (29.06.2025 by mx?!):
		* First release
*/

new const PLUGIN_VERSION[] = "1.0"

#include amxmodx
#include reapi
#include xs

//#define DEBUG

enum _:GRENADES_ENUM {
	GRENADE__HE,
	GRENADE__FB,
	GRENADE__SM
}

enum _:GRENADES_DATA_STRUCT {
	GRENADE_NAME[32],
	WeaponIdType:GRENADE_TYPE,
	GRENADE_MODEL[32],
	Float:GRENADE_DROP_OFFSET
}

new const g_eGrenadesData[GRENADES_ENUM][GRENADES_DATA_STRUCT] = {
	{ "weapon_hegrenade", WEAPON_HEGRENADE, "models/w_hegrenade.mdl", 14.0 },
	{ "weapon_flashbang", WEAPON_FLASHBANG, "models/w_flashbang.mdl", 0.0 },
	{ "weapon_smokegrenade", WEAPON_SMOKEGRENADE, "models/w_smokegrenade.mdl", -14.0 }
}

new g_iNadeDrops, Float:g_fStayTime

public plugin_init() {
	register_plugin("mp_nadedrops 3", PLUGIN_VERSION, "mx?!")
	
	RegisterHookChain(RG_CSGameRules_DeadPlayerWeapons, "CSGameRules_DeadPlayerWeapons_Post", true)
	
	bind_pcvar_num(get_cvar_pointer("mp_nadedrops"), g_iNadeDrops)
	bind_pcvar_float(get_cvar_pointer("mp_item_staytime"), g_fStayTime)
}

public CSGameRules_DeadPlayerWeapons_Post(pPlayer) {
	// https://github.com/rehlds/ReGameDLL_CS/blob/8d5aa54cebe8ab08ad345d9146c85b30dbc2bde6/regamedll/dlls/player.cpp#L1537
	if(g_iNadeDrops != 3 || g_fStayTime <= 0.0 || GetHookChainReturn(ATYPE_INTEGER) == GR_PLR_DROP_GUN_NO) {
		return
	}
	
	for(new i, pItem; i < GRENADES_ENUM; i++) {
		pItem = rg_find_weapon_bpack_by_name(pPlayer, g_eGrenadesData[i][GRENADE_NAME])
	
		if(is_nullent(pItem)) {
			continue
		}
		
		// https://github.com/rehlds/ReGameDLL_CS/blob/8d5aa54cebe8ab08ad345d9146c85b30dbc2bde6/regamedll/dlls/player.cpp#L1486C6-L1486C27
		if(get_member(pItem, m_flStartThrow) || rg_get_user_bpammo(pPlayer, g_eGrenadesData[i][GRENADE_TYPE]) <= 0) {
			continue
		}
		
		// https://github.com/rehlds/ReGameDLL_CS/blob/8d5aa54cebe8ab08ad345d9146c85b30dbc2bde6/regamedll/dlls/player.cpp#L1507
		new Float:fAngles[3]
		get_entvar(pPlayer, var_angles, fAngles)
		
		//dir(Q_cos(vecAngles.y) * flOffset, Q_sin(vecAngles.y) * flOffset, 0.0f);
		new Float:fDir[3]
		xs_vec_copy(fAngles, fDir)
		fDir[0] = floatcos(fAngles[0]) * g_eGrenadesData[i][GRENADE_DROP_OFFSET]
		fDir[1] = floatsin(fAngles[1]) * g_eGrenadesData[i][GRENADE_DROP_OFFSET]
		
		fAngles[0] = 0.0
		fAngles[1] += 45.0
		
		new Float:fOrigin[3]
		get_entvar(pPlayer, var_origin, fOrigin)
		xs_vec_add(fOrigin, fDir, fOrigin)		
		
		new Float:fVelocity[3]
		get_entvar(pPlayer, var_velocity, fVelocity)
		xs_vec_mul_scalar(fVelocity, 0.75, fVelocity)
		
	#if defined DEBUG
		server_print("Spawn %s", g_eGrenadesData[i][GRENADE_MODEL])
	#endif
		
		rg_create_weaponbox(pItem, pPlayer, g_eGrenadesData[i][GRENADE_MODEL], fOrigin, fAngles, fVelocity, .lifeTime = g_fStayTime, .packAmmo = true)
		break
	}	
}