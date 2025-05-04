/*
	1.0 (04.05.2025 by mx?!):
		* First release
*/

new const PLUGIN_VERSION[] = "1.0"

#include amxmodx
#include amxmisc
#include reapi

// Create autoconfig in amxmodx/configs/plugins, and execute it? Comment to disable.
// Value is the name of the config file, excluding the .cfg extension (if empty, name will be plugin-%filename%.cfg).
#define AUTO_CFG ""

// Access config in amxmodx/configs
new const CFG_FILENAME[] = "advanced_vampire_access.ini"

#define chx charsmax
#define INVALID_FLAGS -1337

// From gamecms5.inc ----->
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
// <-----

enum _:KillTypeEnum {
	KillType__Generic,
	KillType__Headshot,
	KillType__Grenade,
	KillType__Knife
}

enum _:AccessStruct {
	AccessStruct__Health,
	AccessStruct__MaxHealth,
	AccessStruct__MinRound
}

enum _:SteamIdAccessStoreStruct {
	SteamIdAccessStoreStruct__SteamId[MAX_AUTHID_LENGTH],
	SteamIdAccessStoreStruct__KillType,
	SteamIdAccessStoreStruct__Health,
	SteamIdAccessStoreStruct__MaxHealth,
	SteamIdAccessStoreStruct__MinRound
}

enum _:AmxxAccessStoreStruct {
	AmxxAccessStoreStruct__bitAmxxFlags,
	bool:AmxxAccessStoreStruct__FullMatchMode,
	AmxxAccessStoreStruct__KillType,
	AmxxAccessStoreStruct__Health,
	AmxxAccessStoreStruct__MaxHealth,
	AmxxAccessStoreStruct__MinRound
}

enum _:CmsAccessStoreStruct {
	CmsAccessStoreStruct__ServiceName[64],
	CmsAccessStoreStruct__KillType,
	CmsAccessStoreStruct__Health,
	CmsAccessStoreStruct__MaxHealth,
	CmsAccessStoreStruct__MinRound
}

enum _:StringAccessTypeEnum {
	StringAccessType__SteamId,
	StringAccessType__GameCMS,
	StringAccessType__AmxxFlags
}

enum _:CVAR_ENUM {
	CVAR__ENABLED,
	CVAR__ROUND_MODE,
	CVAR__FFA_MODE,
	CVAR__FREE_FOR_ALL
}

new g_eCvar[CVAR_ENUM]
new g_ePlayerData[MAX_PLAYERS + 1][KillTypeEnum][AccessStruct]
new Trie:g_tSteamIDs
new Array:g_aSteamIdAccessArray, g_iSteamIdAccessArraySize
new Array:g_aAmxxAccessArray, g_iAmxxAccessArraySize
new Array:g_aCmsAccessArray, g_iCmsAccessArraySize
new g_bitLastFlags[MAX_PLAYERS + 1] = { INVALID_FLAGS, ... }
new bool:g_bCmsCalculated[MAX_PLAYERS + 1]
new g_iRoundCounter

public plugin_init() {
	register_plugin("Advanced Vampire", PLUGIN_VERSION, "mx?!")

	RegCvars()

	g_tSteamIDs = TrieCreate()
	g_aSteamIdAccessArray = ArrayCreate(SteamIdAccessStoreStruct)
	g_aAmxxAccessArray = ArrayCreate(AmxxAccessStoreStruct)
	g_aCmsAccessArray = ArrayCreate(CmsAccessStoreStruct)

	LoadCfg()

	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true)
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", true)
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre")
}

RegCvars() {
	bind_cvar_num("av_enabled", "1", .desc = "Plugin enabled (1/0) ?", .bind = g_eCvar[CVAR__ENABLED])

	bind_cvar_num( "av_round_mode", "0",
		.desc = "Round mode: 0 - regamedll (reset on restarts); 1 - static counter; 2 - value as seconds (csdm support)",
		.bind = g_eCvar[CVAR__ROUND_MODE]
	);

	bind_cvar_num( "av_ffa", "-1",
		.desc = "FreeForAll mode: -1 - obey mp_freeforall (regamedll cvar); 0 - FFA disabled; 1 - FFA enabled",
		.bind = g_eCvar[CVAR__FFA_MODE]
	);
	
	bind_cvar_num_by_name("mp_freeforall", g_eCvar[CVAR__FREE_FOR_ALL])

#if defined AUTO_CFG
	AutoExecConfig(.name = AUTO_CFG)
#endif
}

LoadCfg() {
	new szPath[PLATFORM_MAX_PATH]

	new iLen = get_configsdir(szPath, chx(szPath))
	formatex(szPath[iLen], chx(szPath) - iLen, "/%s", CFG_FILENAME)

	new hFile = fopen(szPath, "r")

	if(!hFile) {
		set_fail_state("Can't %s '%s'", file_exists(szPath) ? "read" : "find", szPath)
		return
	}

	new szString[256], szAccess[MAX_AUTHID_LENGTH], szKillType[12], szHealth[8], szMaxHealth[8], szMinRound[8],
		iKillType, iHealth, iMaxHealth, iMinRound, iTotalCount, bool:bFullMatchMode;

	new eSteamIdAccessStoreData[SteamIdAccessStoreStruct], eAmxxAccessStoreData[AmxxAccessStoreStruct],
		eCmsAccssStoreData[CmsAccessStoreStruct];

	while(fgets(hFile, szString, chx(szString))) {
		trim(szString)

		if(!IsValidCfgString(szString)) {
			continue
		}

		parse( szString,
			szAccess, chx(szAccess),
			szKillType, chx(szKillType),
			szHealth, chx(szHealth),
			szMaxHealth, chx(szMaxHealth),
			szMinRound, chx(szMinRound)
		);

		iKillType = GetKillTypeFromString(szKillType)
		iHealth = str_to_num(szHealth)
		iMaxHealth = str_to_num(szMaxHealth)
		iMinRound = str_to_num(szMinRound)

		switch(GetStringAccessType(szAccess)) {
			case StringAccessType__SteamId: {
				if(!TrieGetCell(g_tSteamIDs, szAccess, iTotalCount)) {
					iTotalCount = 0
				}

				TrieSetCell(g_tSteamIDs, szAccess, iTotalCount + 1)

				copy(eSteamIdAccessStoreData[SteamIdAccessStoreStruct__SteamId], chx(eSteamIdAccessStoreData[SteamIdAccessStoreStruct__SteamId]), szAccess)
				eSteamIdAccessStoreData[SteamIdAccessStoreStruct__KillType] = iKillType
				eSteamIdAccessStoreData[SteamIdAccessStoreStruct__Health] = iHealth
				eSteamIdAccessStoreData[SteamIdAccessStoreStruct__MaxHealth] = iMaxHealth
				eSteamIdAccessStoreData[SteamIdAccessStoreStruct__MinRound] = iMinRound

				ArrayPushArray(g_aSteamIdAccessArray, eSteamIdAccessStoreData)
			}
			case StringAccessType__GameCMS: {
				copy(eCmsAccssStoreData[CmsAccessStoreStruct__ServiceName], chx(eCmsAccssStoreData[CmsAccessStoreStruct__ServiceName]), szAccess)
				eCmsAccssStoreData[CmsAccessStoreStruct__KillType] = iKillType
				eCmsAccssStoreData[CmsAccessStoreStruct__Health] = iHealth
				eCmsAccssStoreData[CmsAccessStoreStruct__MaxHealth] = iMaxHealth
				eCmsAccssStoreData[CmsAccessStoreStruct__MinRound] = iMinRound

				ArrayPushArray(g_aCmsAccessArray, eCmsAccssStoreData)
			}
			case StringAccessType__AmxxFlags: {
				bFullMatchMode = (szAccess[0] == '@')

				eAmxxAccessStoreData[AmxxAccessStoreStruct__bitAmxxFlags] = read_flags(szAccess[ bFullMatchMode ? 1 : 0])
				eAmxxAccessStoreData[AmxxAccessStoreStruct__FullMatchMode] = bFullMatchMode
				eAmxxAccessStoreData[AmxxAccessStoreStruct__KillType] = iKillType
				eAmxxAccessStoreData[AmxxAccessStoreStruct__Health] = iHealth
				eAmxxAccessStoreData[AmxxAccessStoreStruct__MaxHealth] = iMaxHealth
				eAmxxAccessStoreData[AmxxAccessStoreStruct__MinRound] = iMinRound

				ArrayPushArray(g_aAmxxAccessArray, eAmxxAccessStoreData)
			}
		}
	}

	fclose(hFile)

	g_iSteamIdAccessArraySize = ArraySize(g_aSteamIdAccessArray)
	g_iAmxxAccessArraySize = ArraySize(g_aAmxxAccessArray)
	g_iCmsAccessArraySize = ArraySize(g_aCmsAccessArray)
}

GetKillTypeFromString(const szKillType[]) {
	switch(szKillType[0]) {
		//case 'f': return KillType__Generic // frag
		case 'h': return KillType__Headshot // hs
		case 'g': return KillType__Grenade // gren
		case 'k': return KillType__Knife // knife
	}
	
	return KillType__Generic
}

GetStringAccessType(const szAccess[]) {
	if(szAccess[0] == 'S' || szAccess[0] == 'V' || szAccess[0] == 'B') { // STEAM_, VALVE_, BOT
		return StringAccessType__SteamId
	}

	if(szAccess[0] == '_') {
		return StringAccessType__GameCMS
	}

	return StringAccessType__AmxxFlags
}

public client_putinserver(pPlayer) {
	new szAuthID[MAX_AUTHID_LENGTH], iTotalCount
	get_user_authid(pPlayer, szAuthID, chx(szAuthID))

	if(TrieGetCell(g_tSteamIDs, szAuthID, iTotalCount)) {
		new eSteamIdAccessStoreData[SteamIdAccessStoreStruct]

		for(new i, iKillType, iCount; i < g_iSteamIdAccessArraySize && iCount < iTotalCount; i++) {
			ArrayGetArray(g_aSteamIdAccessArray, i, eSteamIdAccessStoreData, sizeof(eSteamIdAccessStoreData))

			if(strcmp(eSteamIdAccessStoreData[SteamIdAccessStoreStruct__SteamId], szAuthID)) { // 0 if string1 == string2
				continue
			}

			iCount++
			iKillType = eSteamIdAccessStoreData[SteamIdAccessStoreStruct__KillType]
			g_ePlayerData[pPlayer][iKillType][AccessStruct__Health] = eSteamIdAccessStoreData[SteamIdAccessStoreStruct__Health]
			g_ePlayerData[pPlayer][iKillType][AccessStruct__MaxHealth] = eSteamIdAccessStoreData[SteamIdAccessStoreStruct__MaxHealth]
			g_ePlayerData[pPlayer][iKillType][AccessStruct__MinRound] = eSteamIdAccessStoreData[SteamIdAccessStoreStruct__MinRound]
		}
	}
}

public client_disconnected(pPlayer) {
	g_bitLastFlags[pPlayer] = INVALID_FLAGS
	g_bCmsCalculated[pPlayer] = false

	arrayset_2d(g_ePlayerData[pPlayer], 0, sizeof(g_ePlayerData[]), sizeof(g_ePlayerData[][]))
}

public CBasePlayer_Spawn_Post(pPlayer) {
	if(!is_user_alive(pPlayer)) {
		return
	}

	CalculateCmsAccess(pPlayer)
	CalculateAmxxAccess(pPlayer)
}

CalculateCmsAccess(pPlayer) {
	if(g_bCmsCalculated[pPlayer]) {
		return
	}

	g_bCmsCalculated[pPlayer] = true

	new eCmsAccssStoreData[CmsAccessStoreStruct], szAuthID[MAX_AUTHID_LENGTH]
	get_user_authid(pPlayer, szAuthID, chx(szAuthID))

	for(new i, iTypeSetCount, iKillType; i < g_iCmsAccessArraySize && iTypeSetCount < (KillTypeEnum - 1); i++) {
		ArrayGetArray(g_aCmsAccessArray, i, eCmsAccssStoreData)

		iKillType = eCmsAccssStoreData[CmsAccessStoreStruct__KillType]

		if(g_ePlayerData[pPlayer][iKillType][AccessStruct__Health]) {
			continue
		}

		if(cmsapi_get_user_services(pPlayer, szAuthID, eCmsAccssStoreData[CmsAccessStoreStruct__ServiceName]) == Invalid_Array) {
			continue
		}

		iTypeSetCount++

		g_ePlayerData[pPlayer][iKillType][AccessStruct__Health] = eCmsAccssStoreData[CmsAccessStoreStruct__Health]
		g_ePlayerData[pPlayer][iKillType][AccessStruct__MaxHealth] = eCmsAccssStoreData[CmsAccessStoreStruct__MaxHealth]
		g_ePlayerData[pPlayer][iKillType][AccessStruct__MinRound] = eCmsAccssStoreData[CmsAccessStoreStruct__MinRound]
	}
}

CalculateAmxxAccess(pPlayer) {
	new bitFlags = get_user_flags(pPlayer)

	if(bitFlags == g_bitLastFlags[pPlayer]) {
		return
	}

	g_bitLastFlags[pPlayer] = bitFlags

	new eAmxxAccessStoreData[AmxxAccessStoreStruct]

	for(new i, iTypeSetCount, iKillType; i < g_iAmxxAccessArraySize && iTypeSetCount < (KillTypeEnum - 1); i++) {
		ArrayGetArray(g_aAmxxAccessArray, i, eAmxxAccessStoreData)

		iKillType = eAmxxAccessStoreData[AmxxAccessStoreStruct__KillType]

		if(g_ePlayerData[pPlayer][iKillType][AccessStruct__Health]) {
			continue
		}

		if(eAmxxAccessStoreData[AmxxAccessStoreStruct__bitAmxxFlags]) {
			if(eAmxxAccessStoreData[AmxxAccessStoreStruct__FullMatchMode]) {
				if((bitFlags & eAmxxAccessStoreData[AmxxAccessStoreStruct__bitAmxxFlags]) != eAmxxAccessStoreData[AmxxAccessStoreStruct__bitAmxxFlags]) {
					continue
				}
			}
			else if( !(bitFlags & eAmxxAccessStoreData[AmxxAccessStoreStruct__bitAmxxFlags]) ) {
				continue
			}
		}

		iTypeSetCount++

		g_ePlayerData[pPlayer][iKillType][AccessStruct__Health] = eAmxxAccessStoreData[AmxxAccessStoreStruct__Health]
		g_ePlayerData[pPlayer][iKillType][AccessStruct__MaxHealth] = eAmxxAccessStoreData[AmxxAccessStoreStruct__MaxHealth]
		g_ePlayerData[pPlayer][iKillType][AccessStruct__MinRound] = eAmxxAccessStoreData[AmxxAccessStoreStruct__MinRound]
	}
}

public CBasePlayer_Killed_Post(pVictim, pKiller, iGibType) {
	if(!g_eCvar[CVAR__ENABLED] || pVictim == pKiller || !is_user_alive(pKiller) || !is_user_connected(pVictim) || get_member(pVictim, m_bKilledByBomb) || IsTeamMateKill(pVictim, pKiller)) {
		return
	}

	new iKillType = GetKillType(pVictim, pKiller)
	new iHealthToAdd = g_ePlayerData[pKiller][iKillType][AccessStruct__Health]

	if(!iHealthToAdd || !CheckMinRound(pKiller, iKillType)) {
		return
	}

	new iHealth = get_user_health(pKiller)
	new iMaxHealth = g_ePlayerData[pKiller][iKillType][AccessStruct__MaxHealth]
	
	if(!iMaxHealth) {
		iMaxHealth = floatround( get_entvar(pKiller, var_max_health) )
	}

	if(iHealth >= iMaxHealth) {
		return
	}

	set_entvar(pKiller, var_health, floatmin(float(iHealth) + float(iHealthToAdd), float(iMaxHealth)))
}

bool:CheckMinRound(pKiller, iKillType) {
	new iMinRound = g_ePlayerData[pKiller][iKillType][AccessStruct__MinRound]

	switch(g_eCvar[CVAR__ROUND_MODE]) { // "Round mode: 0 - regamedll (reset on restarts); 1 - static counter; 2 - value as seconds (csdm support)"
		case 0: return ((get_member_game(m_iTotalRoundsPlayed) + 1) >= iMinRound)
		case 1: return (g_iRoundCounter >= iMinRound)
		case 2: return (floatround( get_gametime() ) >= iMinRound)
	}

	return true
}

GetKillType(pVictim, pKiller) {
	if(get_member(pVictim, m_bKilledByGrenade)) {
		return KillType__Grenade
	}

	if(get_member(pVictim, m_bHeadshotKilled)) {
		return KillType__Headshot
	}

	if(is_user_alive(pKiller) && get_user_weapon(pKiller) == CSW_KNIFE/* && !get_member(pVictim, m_bKilledByBomb)*/) {
		return KillType__Knife
	}

	return KillType__Generic
}

bool:IsTeamMateKill(pVictim, pKiller) {
	if(get_member(pVictim, m_iTeam) != get_member(pKiller, m_iTeam)) {
		return false
	}

	switch(g_eCvar[CVAR__FFA_MODE]) {
		case -1: return (g_eCvar[CVAR__FREE_FOR_ALL] == 0)
		case 0: return false
		case 1: return true
	}

	return true
}

public CSGameRules_RestartRound_Pre() {
	g_iRoundCounter++
}

stock bool:IsValidCfgString(const szString[]) {
	return (szString[0] && szString[0] != ';' && szString[0] != '/')
}

// arrayset() for 2d array: https://dev-cs.ru/threads/7762/
stock arrayset_2d(any:array[][], any:value, size1, size2) {
	arrayset(array[0], value, size1 * size2);
}

stock bind_cvar_num(const cvar[], const value[], flags = FCVAR_NONE, const desc[] = "", bool:has_min = false, Float:min_val = 0.0, bool:has_max = false, Float:max_val = 0.0, &bind) {
	bind_pcvar_num(create_cvar(cvar, value, flags, desc, has_min, min_val, has_max, max_val), bind);
}

stock bind_cvar_float(const cvar[], const value[], flags = FCVAR_NONE, const desc[] = "", bool:has_min = false, Float:min_val = 0.0, bool:has_max = false, Float:max_val = 0.0, &Float:bind) {
	bind_pcvar_float(create_cvar(cvar, value, flags, desc, has_min, min_val, has_max, max_val), bind);
}

stock bind_cvar_string(const cvar[], const value[], flags = FCVAR_NONE, const desc[] = "", bool:has_min = false, Float:min_val = 0.0, bool:has_max = false, Float:max_val = 0.0, bind[], maxlen) {
	bind_pcvar_string(create_cvar(cvar, value, flags, desc, has_min, min_val, has_max, max_val), bind, maxlen);
}

stock bind_cvar_num_by_name(const szCvarName[], &iBindVariable) {
	bind_pcvar_num(get_cvar_pointer(szCvarName), iBindVariable);
}

stock bind_cvar_float_by_name(const szCvarName[], &Float:fBindVariable) {
	bind_pcvar_float(get_cvar_pointer(szCvarName), fBindVariable);
}

public plugin_natives() {
	set_native_filter("native_filter")
}

public native_filter(const szNativeName[], iNativeID, iTrapMode) {
	return !iTrapMode // 0 if native couldn't be found, 1 if native use was attempted
}
