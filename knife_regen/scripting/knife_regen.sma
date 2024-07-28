// Code based on plugin "Regen HP AP for knife" https://dev-cs.ru/resources/673/, author "I Am LeGenD"
new const PLUGIN_VERSION[] = "1.0"

#include <amxmodx>
#include <hamsandwich>
#include <reapi>

// AutoConfig name in 'amxmodx/configs/plugins', without .cfg extension.
// Comment to disable AutoConfig option
#define AUTO_CFG "knife_regen"

enum _:PCVAR_ENUM {
	PCVAR__FREQ,
	PCVAR__ACCESS_FLAGS
}

enum _:CVAR_ENUM {
	CVAR__ACCESS_FLAGS,
	CVAR__MIN_ROUND,
	Float:CVAR_F__FREQ,
	Float:CVAR_F__HEAL_AMT,
	CVAR__ARMOR_AMT,
	Float:CVAR_F__MAX_HP,
	CVAR__MAX_ARMOR
}

new g_pCvar[PCVAR_ENUM], g_eCvar[CVAR_ENUM]
new HamHook:g_hDeploy, HamHook:g_hHolster

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
		.description = "Флаги доступа к лечению (требуется наличие всех перечисленных)^nДля доступа для всех, задайте пустое значение"
	);
	hook_cvar_change(g_pCvar[PCVAR__ACCESS_FLAGS], "hook_CvarChange")
	new szFlags[32]; get_pcvar_string(g_pCvar[PCVAR__ACCESS_FLAGS], szFlags, charsmax(szFlags))
	ChangeAccessFlags(szFlags)

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

	bind_pcvar_num(
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

public hook_CvarChange(pCvar, szNewVal[], szOldVal[]) {
	if(pCvar == g_pCvar[PCVAR__FREQ]) {
		ChangeFreq(szNewVal)
		return
	}

	if(pCvar == g_pCvar[PCVAR__ACCESS_FLAGS]) {
		ChangeAccessFlags(szNewVal)
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
	new ArmorType:iArmorType
	new iArmorValue = rg_get_user_armor(pPlayer, iArmorType)

	if(iArmorType == ARMOR_NONE) {
		iArmorType = ARMOR_KEVLAR
	}

	set_entvar(pPlayer, var_health, floatmin(fHealthValue + g_eCvar[CVAR_F__HEAL_AMT], GetMaxHp(pPlayer)))
	rg_set_user_armor(pPlayer, min(iArmorValue + g_eCvar[CVAR__ARMOR_AMT], g_eCvar[CVAR__MAX_ARMOR]), iArmorType)
}

Float:GetMaxHp(pPlayer) {
	if(g_eCvar[CVAR_F__MAX_HP] == 0.0) {
		return get_entvar(pPlayer, var_max_health)
	}

	return g_eCvar[CVAR_F__MAX_HP]
}

CanAccess(pPlayer) {
	return (!g_eCvar[CVAR__ACCESS_FLAGS] || (get_user_flags(pPlayer) & g_eCvar[CVAR__ACCESS_FLAGS]) == g_eCvar[CVAR__ACCESS_FLAGS])
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

public client_disconnected(pPlayer) {
	remove_task(pPlayer)
}