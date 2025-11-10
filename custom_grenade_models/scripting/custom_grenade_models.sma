/* История изменений:
	1.0 (03.11.2025) by mx?!:
*/

new const PLUGIN_VERSION[] = "1.0"

#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <hamsandwich>
#include <fakemeta>

/* -------------------- */

new const CFG_FILENAME[] = "plugins/custom_grenade_models.ini"

/* -------------------- */

enum _:WEAPON_MODELS_ENUM {
	MODEL__V,
	MODEL__P,
	MODEL__W
}

enum _:GrenadeType {
	GrenadeType__HE,
	GrenadeType__FB,
	GrenadeType__SM
}

new g_szModels[GrenadeType][WEAPON_MODELS_ENUM][128]

/* -------------------- */

public plugin_precache() {
	register_plugin("Custom Grenade Models", PLUGIN_VERSION, "mx?!")
	
	LoadCfg()

	RegisterHam(Ham_Spawn, "armoury_entity", "OnItemSpawn_ArmouryEntity_Post", true)
}

/* -------------------- */

LoadCfg() {
	new szBuffer[256], iGrenadeType = -1, iModelType
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
		
		if(szBuffer[0] == '[') {
			iGrenadeType++
			iModelType = 0
			continue
		}
				
		if(!file_exists(szBuffer)) {
			fclose(hFile)
			set_fail_state("Can't find '%s'", szBuffer)
			return
		}
		
		copy(g_szModels[iGrenadeType][iModelType], charsmax(g_szModels[][]), szBuffer)
		iModelType++
		
		precache_model(szBuffer)
	}
	
	fclose(hFile)
}

/* -------------------- */

public plugin_init() {
	RegisterHookChain(RG_CBasePlayer_ThrowGrenade, "CBasePlayer_ThrowGrenade_Post", true)
	RegisterHam(Ham_Item_Deploy, "weapon_hegrenade", "OnItemDeploy_Grenade_Post", true)
	RegisterHam(Ham_Item_Deploy, "weapon_flashbang", "OnItemDeploy_Grenade_Post", true)
	RegisterHam(Ham_Item_Deploy, "weapon_smokegrenade", "OnItemDeploy_Grenade_Post", true)
	RegisterHookChain(RG_CWeaponBox_SetModel, "CWeaponBox_SetModel_Pre")
}

/* -------------------- */

public CWeaponBox_SetModel_Pre(pEnt, const szModelName[]) {
	new pWeapon = get_member(pEnt, m_WeaponBox_rgpPlayerItems, GRENADE_SLOT)

	if(is_nullent(pWeapon)) {
		return
	}
	
	new iGrenadeType = -1
	
	switch(get_member(pWeapon, m_iId)) {
		case WEAPON_HEGRENADE: iGrenadeType = GrenadeType__HE
		case WEAPON_FLASHBANG: iGrenadeType = GrenadeType__FB
		case WEAPON_SMOKEGRENADE: iGrenadeType = GrenadeType__SM
	}

	if(iGrenadeType != -1 && g_szModels[iGrenadeType][MODEL__W][0]) {
		SetHookChainArg(2, ATYPE_STRING, g_szModels[iGrenadeType][MODEL__W])
	}
}

/* -------------------- */

public OnItemSpawn_ArmouryEntity_Post(pEnt) {
	if(is_nullent(pEnt)) {
		return
	}
	
	new iGrenadeType = -1
	
	switch(get_member(pEnt, m_Armoury_iItem)) {
		case ARMOURY_HEGRENADE: iGrenadeType = GrenadeType__HE
		case ARMOURY_FLASHBANG: iGrenadeType = GrenadeType__FB
		case ARMOURY_SMOKEGRENADE: iGrenadeType = GrenadeType__SM
	}
	
	if(iGrenadeType != -1 && g_szModels[iGrenadeType][MODEL__W][0]) {
		engfunc(EngFunc_SetModel, pEnt, g_szModels[iGrenadeType][MODEL__W])
	}
}

/* -------------------- */

public CBasePlayer_ThrowGrenade_Post(pPlayer, pGrenade, Float:vecSrc[3], Float:vecThrow[3], Float:time, const usEvent) {
	new pEnt = GetHookChainReturn(ATYPE_INTEGER)

	if(is_nullent(pEnt)) {
		return
	}
	
	new iGrenadeType = -1

	switch(GetGrenadeType(pEnt)) {
		case WEAPON_HEGRENADE: iGrenadeType = GrenadeType__HE
		case WEAPON_FLASHBANG: iGrenadeType = GrenadeType__FB
		case WEAPON_SMOKEGRENADE: iGrenadeType = GrenadeType__SM
	}
	
	if(iGrenadeType != -1 && g_szModels[iGrenadeType][MODEL__W][0]) {
		engfunc(EngFunc_SetModel, pEnt, g_szModels[iGrenadeType][MODEL__W])
	}
}

/* -------------------- */

public OnItemDeploy_Grenade_Post(pEnt) {
	new pPlayer = get_member(pEnt, m_pPlayer)
	
	if(!is_user_alive(pPlayer)) {
		return
	}
	
	new iGrenadeType = -1
	
	switch(get_member(pEnt, m_iId)) {
		case WEAPON_HEGRENADE: iGrenadeType = GrenadeType__HE
		case WEAPON_FLASHBANG: iGrenadeType = GrenadeType__FB
		case WEAPON_SMOKEGRENADE: iGrenadeType = GrenadeType__SM
	}

	if(iGrenadeType == -1) {
		return
	}
	
	if(g_szModels[iGrenadeType][MODEL__V][0]) {
		set_entvar(pPlayer, var_viewmodel, g_szModels[iGrenadeType][MODEL__V])
	}
	
	if(g_szModels[iGrenadeType][MODEL__P][0]) {
		set_entvar(pPlayer, var_weaponmodel, g_szModels[iGrenadeType][MODEL__P])
	}
}
