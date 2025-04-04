/*
	1.1 (11.08.2024 by mx?!):
		* Fixed cvar registration for 'amx_rk_max_hp', thx @Nord1cWarr1or
	1.2 (08.01.2025 by mx?!):
		* Fix resetting hp to maximum value when hp is already above maximum (set by another plugin), thx @Hailsane
	1.3 (05.02.2025 by mx?!):
		* Add GameCMS privilege access support
	1.4 (05.02.2025 by mx?!):
		* Add cvar 'amx_rk_access_mode` ('any of' or 'full presence' access mode by amxx flags)
	1.5 (04.04.2025 by mx?!):
		* Fixed wrong access/freq cvar values at first map (was wrong due to szOldVal and szNewVal placement)
*/

// Code based on plugin "Regen HP AP for knife" https://dev-cs.ru/resources/673/, author "I Am LeGenD"
new const PLUGIN_VERSION[] = "1.5"

#include <amxmodx>
#include <hamsandwich>
#include <reapi>

// AutoConfig name in 'amxmodx/configs/plugins', without .cfg extension.
// Comment to disable AutoConfig option
#define AUTO_CFG "knife_regen"

// GameCMS (from gamecms5.inc)
native Array:cmsapi_get_user_services(const index, const szAuth[] = "", const szService[] = "", serviceID = 0, bool:part = false);

enum _:PCVAR_ENUM {
	PCVAR__FREQ,
	PCVAR__ACCESS_FLAGS
}

enum _:CVAR_ENUM {
	CVAR__ACCESS_FLAGS,
	CVAR__ACCESS_FLAGS_STRING[64],
	CVAR__ACCESS_MODE,
	CVAR__MIN_ROUND,
	Float:CVAR_F__FREQ,
	Float:CVAR_F__HEAL_AMT,
	CVAR__ARMOR_AMT,
	Float:CVAR_F__MAX_HP,
	CVAR__MAX_ARMOR
}

new g_pCvar[PCVAR_ENUM], g_eCvar[CVAR_ENUM]
new HamHook:g_hDeploy, HamHook:g_hHolster
new bool:g_bCanAccess[MAX_PLAYERS + 1]

public plugin_init() {
	register_plugin("Regen HP AP for knife", PLUGIN_VERSION, "mx?!")

	RegCvars()

	g_hDeploy = RegisterHam(Ham_Item_Deploy, "weapon_knife", "OnItemDeploy_Post", true)
	g_hHolster = RegisterHam(Ham_Item_Holster, "weapon_knife", "OnItemHolster_Post", true)

	if(g_eCvar[CVAR_F__FREQ] == 0.0) {
		DisableHamForward(g_hDeploy)
		DisableHamForward(g_hHolster)
	}
}

RegCvars() {
	g_pCvar[PCVAR__ACCESS_FLAGS] = create_cvar( "amx_rk_access_flags", "",
		.description = "Доступ: услуга GameCMS или флаги доступа AMXX^nДля доступа для всех, задайте пустое значение"
	);
	bind_pcvar_string(g_pCvar[PCVAR__ACCESS_FLAGS], g_eCvar[CVAR__ACCESS_FLAGS_STRING], charsmax(g_eCvar[CVAR__ACCESS_FLAGS_STRING]))
	hook_cvar_change(g_pCvar[PCVAR__ACCESS_FLAGS], "hook_CvarChange")
	new szFlags[32]; get_pcvar_string(g_pCvar[PCVAR__ACCESS_FLAGS], szFlags, charsmax(szFlags))
	if(g_eCvar[CVAR__ACCESS_FLAGS_STRING][0] != '_') {
		ChangeAccessFlags(szFlags)
	}
	
	bind_pcvar_num(
		create_cvar( "amx_rk_access_mode", "0",
			.description = "Тип доступа по флагам AMXX: 0 - наличие всех перечисленных; 1 - наличие любого из"
		),
		g_eCvar[CVAR__ACCESS_MODE]
	);

	bind_pcvar_num(
		create_cvar( "amx_rk_min_round", "0",
			.description = "Минимальный раунд для работы лечения",
			.has_min = true, .min_val = 0.0
		),
		g_eCvar[CVAR__MIN_ROUND]
	);

	g_pCvar[PCVAR__FREQ] = create_cvar( "amx_rk_freq", "5.0",
		.description = "Частота лечения, в секундах (0 - отключить лечение)",
		.has_min = true, .min_val = 0.0
	);
	bind_pcvar_float(g_pCvar[PCVAR__FREQ], g_eCvar[CVAR_F__FREQ])
	hook_cvar_change(g_pCvar[PCVAR__FREQ], "hook_CvarChange")

	bind_pcvar_float(
		create_cvar( "amx_rk_heal_amt", "15",
			.description = "Объём лечения каждый тик amx_rk_freq",
			.has_min = true, .min_val = 1.0
		),
		g_eCvar[CVAR_F__HEAL_AMT]
	);

	bind_pcvar_num(
		create_cvar( "amx_rk_armor_amt", "15",
			.description = "Объём восстановления брони каждый тик amx_rk_freq",
			.has_min = true, .min_val = 1.0
		),
		g_eCvar[CVAR__ARMOR_AMT]
	);

	bind_pcvar_float(
		create_cvar( "amx_rk_max_hp", "0",
			.description = "Максимальный объём здоровья, который можно восстановить (0: использовать var_max_health)",
			.has_min = true, .min_val = 0.0
		),
		g_eCvar[CVAR_F__MAX_HP]
	);

	bind_pcvar_num(
		create_cvar( "amx_rk_max_armor", "100",
			.description = "Максимальный объём брони, который можно восстановить",
			.has_min = true, .min_val = 1.0
		),
		g_eCvar[CVAR__MAX_ARMOR]
	);

#if defined AUTO_CFG
	AutoExecConfig(.name = AUTO_CFG)
#endif
}

public hook_CvarChange(pCvar, szOldVal[], szNewVal[]) {
	if(pCvar == g_pCvar[PCVAR__FREQ]) {
		ChangeFreq(szNewVal)
		return
	}

	if(pCvar == g_pCvar[PCVAR__ACCESS_FLAGS]) {
		if(szNewVal[0] != '_') {
			ChangeAccessFlags(szNewVal)
		}
		else {
			new pPlayers[MAX_PLAYERS], iPlCount, pPlayer
			get_players(pPlayers, iPlCount, "h")
			for(new i; i < iPlCount; i++) {
				pPlayer = pPlayers[i]
				g_bCanAccess[pPlayer] = (cmsapi_get_user_services(pPlayer, "", szNewVal, 0) != Invalid_Array)
			}
		}
		
		return
	}
}

ChangeFreq(const szNewVal[]) {
	for(new pPlayer = 1; pPlayer <= MAX_PLAYERS; pPlayer++) {
		remove_task(pPlayer)
	}

	if(str_to_float(szNewVal) == 0.0) {
		DisableHamForward(g_hDeploy)
		DisableHamForward(g_hHolster)
		return
	}

	// else ->

	EnableHamForward(g_hDeploy)
	EnableHamForward(g_hHolster)

	if(CheckMinRound()) {
		for(new pPlayer = 1; pPlayer <= MAX_PLAYERS; pPlayer++) {
			if(is_user_alive(pPlayer) && get_user_weapon(pPlayer) == CSW_KNIFE) {
				SetTask(pPlayer)
			}
		}
	}
}

ChangeAccessFlags(const szNewVal[]) {
	g_eCvar[CVAR__ACCESS_FLAGS] = read_flags(szNewVal)
}

SetTask(pPlayer) {
	set_task(g_eCvar[CVAR_F__FREQ], "task_Regen", pPlayer, .flags = "b")
}

bool:CheckMinRound() {
	return (get_member_game(m_iTotalRoundsPlayed) + 1 >= g_eCvar[CVAR__MIN_ROUND])
}

public task_Regen(pPlayer) {
	if(!is_user_alive(pPlayer) || get_user_weapon(pPlayer) != CSW_KNIFE || !CheckMinRound()) {
		remove_task(pPlayer)
		return
	}

	new Float:fHealthValue = Float: get_entvar(pPlayer, var_health)
	new Float:fMaxHp = GetMaxHp(pPlayer)
	new ArmorType:iArmorType
	new iArmorValue = rg_get_user_armor(pPlayer, iArmorType)

	if(iArmorType == ARMOR_NONE) {
		iArmorType = ARMOR_KEVLAR
	}

	if(fHealthValue < fMaxHp) {
		set_entvar(pPlayer, var_health, floatmin(fHealthValue + g_eCvar[CVAR_F__HEAL_AMT], fMaxHp))
	}

	rg_set_user_armor(pPlayer, min(iArmorValue + g_eCvar[CVAR__ARMOR_AMT], g_eCvar[CVAR__MAX_ARMOR]), iArmorType)
}

Float:GetMaxHp(pPlayer) {
	if(g_eCvar[CVAR_F__MAX_HP] == 0.0) {
		return get_entvar(pPlayer, var_max_health)
	}

	return g_eCvar[CVAR_F__MAX_HP]
}

bool:CanAccess(pPlayer) {
	if(g_eCvar[CVAR__ACCESS_FLAGS_STRING][0] == '_') {
		return g_bCanAccess[pPlayer]
	}

	return AmxxAccess(pPlayer)
}

bool:AmxxAccess(pPlayer) {
	if(!g_eCvar[CVAR__ACCESS_FLAGS]) {
		return true
	}
	
	if(g_eCvar[CVAR__ACCESS_MODE]) {
		return ( (get_user_flags(pPlayer) & g_eCvar[CVAR__ACCESS_FLAGS]) > 0 )
	}
	
	return ( (get_user_flags(pPlayer) & g_eCvar[CVAR__ACCESS_FLAGS]) == g_eCvar[CVAR__ACCESS_FLAGS] )
}

public OnItemDeploy_Post(pWeapon) {
	if(!is_entity(pWeapon)) {
		return
	}

	new pPlayer = get_member(pWeapon, m_pPlayer)

	if(is_user_alive(pPlayer) && CanAccess(pPlayer) && CheckMinRound() && !task_exists(pPlayer)) {
		SetTask(pPlayer)
	}
}

public OnItemHolster_Post(pWeapon) {
	if(is_entity(pWeapon)) {
		remove_task(get_member(pWeapon, m_pPlayer))
	}
}

public client_putinserver(pPlayer) {
	if(g_eCvar[CVAR__ACCESS_FLAGS_STRING][0] == '_') {
		g_bCanAccess[pPlayer] = (cmsapi_get_user_services(pPlayer, "", g_eCvar[CVAR__ACCESS_FLAGS_STRING], 0) != Invalid_Array)
	}
}

public client_disconnected(pPlayer) {
	g_bCanAccess[pPlayer] = false
	remove_task(pPlayer)
}

public plugin_natives() {
	set_native_filter("native_filter")
}

public native_filter(const szNativeName[], iNativeID, iTrapMode) {
	return PLUGIN_HANDLED
}