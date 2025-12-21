/*
	1.0 (21.12.2025 by mx?!):
		* First version
*/

new const PLUGIN_VERSION[] = "1.0"

new const CFG_FILENAME[] = "plugins/silentrun.cfg"

#include amxmodx
#include amxmisc
#include reapi

// gamecms5.inc
/**
* Получение данных о купленных услугах игрока
* 
* @Note	Запрос информации обо всех услугах игрока: (szService[] = "" И serviceID = 0)
*		Запрос информации о конкретной услуге: (szService[] = "`services`.`rights`" ИЛИ serviceID = `services`.`id`)
*
* @param index		id игрока
* @param szAuth		steamID игрока
* @param szService	Название услуги
* @param serviceID	Номер услуги
* @param part		Совпадение наименования услуги (флагов)
* 					true - частичное совпадение
* 					false - полное совпадение
*
* @return			New array handle or Invalid_Array if empty
*/
native Array:cmsapi_get_user_services(const index, const szAuth[] = "", const szService[] = "", serviceID = 0, bool:part = false);

#define MAX_GCMS_PRIVS 32

enum _:CVAR_ENUM {
	CVAR__ACCESS_FLAGS[32]
}

new g_eCvar[CVAR_ENUM]
new g_bitAccess
new Trie:g_tSteamIDs
new g_szGameCmsPrivs[MAX_GCMS_PRIVS][36], g_iGameCmsPrivsCount
new bool:g_bLoaded[MAX_PLAYERS + 1], bool:g_bAccess[MAX_PLAYERS + 1]

public plugin_init() {
	register_plugin("Silent Run", PLUGIN_VERSION, "mx?!")
	
	new pCvar = create_cvar("sr_access_flags", "t")
	bind_pcvar_string(pCvar, g_eCvar[CVAR__ACCESS_FLAGS], charsmax(g_eCvar[CVAR__ACCESS_FLAGS]))
	g_bitAccess = read_flags(g_eCvar[CVAR__ACCESS_FLAGS])
	hook_cvar_change(pCvar, "hook_CvarChange")
	
	register_srvcmd("sr_reg_access", "srvcmd_RegAccess")
	
	g_tSteamIDs = TrieCreate()
	
	new szPath[240]
	get_configsdir(szPath, charsmax(szPath))
	server_cmd("exec %s/%s", szPath, CFG_FILENAME)
	
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true)
}

public hook_CvarChange(pCvar, const szOldVal[], const szNewVal[]) {
	g_bitAccess = read_flags(szNewVal)
}

public srvcmd_RegAccess() {
	static szAccess[64]

	read_argv(1, szAccess, charsmax(szAccess))
	
	if(szAccess[0] == '_') {
		copy(g_szGameCmsPrivs[g_iGameCmsPrivsCount], charsmax(g_szGameCmsPrivs[]), szAccess)
		g_iGameCmsPrivsCount++
		return PLUGIN_HANDLED
	}
	
	TrieSetCell(g_tSteamIDs, szAccess, 0)
	
	return PLUGIN_HANDLED
}

public CBasePlayer_Spawn_Post(pPlayer) {
	if(!is_user_alive(pPlayer)) {
		return
	}
	
	if(g_bAccess[pPlayer] || (get_user_flags(pPlayer) & g_bitAccess)) {
		rg_set_user_footsteps(pPlayer, .silent = true)
		return
	}
	
	if(g_bLoaded[pPlayer]) {
		return
	}
	
	g_bLoaded[pPlayer] = true
	
	new szAuthID[64]
	get_user_authid(pPlayer, szAuthID, charsmax(szAuthID))
	
	if(TrieKeyExists(g_tSteamIDs, szAuthID)) {
		g_bAccess[pPlayer] = true
		rg_set_user_footsteps(pPlayer, .silent = true)
		return
	}
	
	for(new i; i < g_iGameCmsPrivsCount; i++) {
		if(cmsapi_get_user_services(pPlayer, "", g_szGameCmsPrivs[i], 0) != Invalid_Array) {
			g_bAccess[pPlayer] = true
			rg_set_user_footsteps(pPlayer, .silent = true)
			return
		}
	}
}

public client_disconnected(pPlayer) {
	g_bLoaded[pPlayer] = false
	g_bAccess[pPlayer] = false
}

public plugin_natives() {
	set_native_filter("native_filter")
}

public native_filter(const szNativeName[], iNativeID, iTrapMode) {
	return PLUGIN_HANDLED
}
