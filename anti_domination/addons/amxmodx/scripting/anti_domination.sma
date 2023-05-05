/*
	This plugin is designed to balance the strength of teams by weakening the dominant team,
	and strengthening the losing team. The plugin will be useful primarily to those who do not use
	plugins that balance players based on their flags/skill.

    Данный плагин предназначен для балансировки сил команд путём ослабления доминирующей команды,
	и усиления проигрывающей команды. Плагин будет полезен в первую очередь тем, кто не пользуется
	плагинами, балансирующими игроков на основе их флагов/скилла.
*/

/* Requirements:
    * AMXX 1.9.0 or above
    * ReAPI
*/

/* Changelog:
    1.0 (08.02.2023) by mx?!:
        * First release
	1.1 (05.04.2023) by mx?!:
		* Added cvar 'ad_equip_delay'
*/

new const PLUGIN_VERSION[] = "1.1"

#include <amxmodx>
#include <reapi>

// Create cvar config in 'configs/plugins' and run it?
//
// Создавать конфиг с кварами в 'configs/plugins', и запускать его?
#define AUTO_CFG

// List of map prefixes/map names on which the plugin will not work (comment out to disable)
//
// Список префиксов карт/имён карт, на которых плагин не будет работать (закомментируйте для отключения)
new const DISABLED_MAPS[][] = {
	"awp_",
	"fy_",
	"aim_",
	"gg_",
	"35hp_",
	"100hp_",
	"1hp_",
	"$"
}

#include <amxmodx>
#include <reapi>

const TASKID__EQUIP = 1337

enum _:CVAR_ENUM {
	CVAR__ENABLED,
	CVAR__WIN_DIFFERENCE,
	CVAR__BONUS_ROUNDS,
	CVAR__REWARD_PERCENTAGE_LOOSER,
	CVAR__REWARD_PERCENTAGE_WINNER,
	CVAR__DAMAGE_PERCENTAGE_LOOSER,
	CVAR__DAMAGE_PERCENTAGE_WINNER,
	CVAR__BONUS_WEAPON_TT[32],
	CVAR__BONUS_WEAPON_CT[32],
	CVAR__EQUIP_EACH_SPAWN,
	Float:CVAR_F__EQUIP_DELAY
}

new g_eCvar[CVAR_ENUM], HookChain:g_hAddAccount, HookChain:g_hSpawn, HookChain:g_hTakeDamage
new g_iBonusRounds, TeamName:g_iDominationTeam, bool:g_bHooksEnabled

public plugin_init() {
	register_plugin("Anti-Domination", PLUGIN_VERSION, "mx?!")
	register_dictionary("anti_domination.txt")

#if defined DISABLED_MAPS
	if(ShouldStop()) {
		return
	}
#endif

	RegCvars()

	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre")

	g_hAddAccount = RegisterHookChain(RG_CBasePlayer_AddAccount, "CBasePlayer_AddAccount_Pre")
	DisableHookChain(g_hAddAccount)

	g_hTakeDamage = RegisterHookChain(RG_CBasePlayer_TakeDamage, "CBasePlayer_TakeDamage_Pre")
	DisableHookChain(g_hTakeDamage)

	g_hSpawn = RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true)
	DisableHookChain(g_hSpawn)
}

RegCvars() {
	bind_cvar_num( "ad_enabled", "1", .desc = "Включить (1) или выключить (0) работу плагина",
		.bind = g_eCvar[CVAR__ENABLED] );

	bind_cvar_num( "ad_win_difference", "3", .desc = "Разница в очках победы для запуска бонусных раундов",
		.bind = g_eCvar[CVAR__WIN_DIFFERENCE] );

	bind_cvar_num( "ad_bonus_rounds", "1", .desc = "Кол-во бонусных раундов при достижении разницы в очках победы (ad_win_difference)",
		.bind = g_eCvar[CVAR__BONUS_ROUNDS] );

	bind_cvar_num( "ad_reward_percentage_looser", "150", .desc = "На сколько процентов изменять заработок игрокам проигрывающей команды (100 - не изменять)",
		.bind = g_eCvar[CVAR__REWARD_PERCENTAGE_LOOSER] );

	bind_cvar_num( "ad_reward_percentage_winner", "50", .desc = "На сколько процентов изменять заработок игрокам доминирующей команды (100 - не изменять)",
		.bind = g_eCvar[CVAR__REWARD_PERCENTAGE_WINNER] );

	bind_cvar_num( "ad_damage_percentage_looser", "110", .desc = "На сколько процентов изменять урон игрокам проигрывающей команды (100 - не изменять)",
		.bind = g_eCvar[CVAR__DAMAGE_PERCENTAGE_LOOSER] );

	bind_cvar_num( "ad_damage_percentage_winner", "90", .desc = "На сколько процентов изменять урон игрокам доминирующей команды (100 - не изменять)",
		.bind = g_eCvar[CVAR__DAMAGE_PERCENTAGE_WINNER] );

	bind_cvar_string( "ad_bonus_weapon_tt", "weapon_ak47", .desc = "Бонусное оружие для проигрывающей команды террористов (^"^" - выкл.)",
		.bind = g_eCvar[CVAR__BONUS_WEAPON_TT], .maxlen = charsmax(g_eCvar[CVAR__BONUS_WEAPON_TT]) );

	bind_cvar_string( "ad_bonus_weapon_ct", "weapon_m4a1", .desc = "Бонусное оружие для проигрывающей команды контр-террористов (^"^" - выкл.)",
		.bind = g_eCvar[CVAR__BONUS_WEAPON_CT], .maxlen = charsmax(g_eCvar[CVAR__BONUS_WEAPON_CT]) );

	bind_cvar_num( "ad_equip_each_spawn", "0", .desc = "Экипировать игрока только при его первом спавне за раунд (0), либо каждый спавн (1) (учёт Revive Teammates)",
		.bind = g_eCvar[CVAR__EQUIP_EACH_SPAWN] );

	bind_cvar_float( "ad_equip_delay", "0.0", .desc = "Задержка выдачи оружия, в секундах (режим совместимости)",
		.bind = g_eCvar[CVAR_F__EQUIP_DELAY] );

#if defined AUTO_CFG
	AutoExecConfig(/*.name = "PluginName"*/)
#endif
}

TeamName:GetDominationTeam() {
	new iWinsTT = get_member_game(m_iNumTerroristWins)
	new iWinsCT = get_member_game(m_iNumCTWins)

	if(iWinsTT - iWinsCT >= g_eCvar[CVAR__WIN_DIFFERENCE]) {
		return TEAM_TERRORIST
	}

	if(iWinsCT - iWinsTT >= g_eCvar[CVAR__WIN_DIFFERENCE]) {
		return TEAM_CT
	}

	return TEAM_UNASSIGNED
}

DisableHooks() {
	if(!g_bHooksEnabled) {
		return
	}

	g_bHooksEnabled = false
	DisableHookChain(g_hAddAccount)
	DisableHookChain(g_hTakeDamage)
	DisableHookChain(g_hSpawn)
}

EnableHooks() {
	if(g_bHooksEnabled) {
		return
	}

	g_bHooksEnabled = true
	EnableHookChain(g_hAddAccount)
	EnableHookChain(g_hTakeDamage)
	EnableHookChain(g_hSpawn)
}

public CSGameRules_RestartRound_Pre() {
	remove_task(TASKID__EQUIP)

	if(get_member_game(m_bCompleteReset) || !g_eCvar[CVAR__ENABLED]) {
		g_iBonusRounds = 0
		DisableHooks()
		return
	}

	if(g_iBonusRounds && --g_iBonusRounds) {
		return
	}

	g_iDominationTeam = GetDominationTeam()

	if(g_iDominationTeam == TEAM_UNASSIGNED) {
		DisableHooks()
		return
	}

	g_iBonusRounds = g_eCvar[CVAR__BONUS_ROUNDS]
	EnableHooks()
}

public CBasePlayer_AddAccount_Pre(pPlayer, iAmt, RewardType:iType, bool:bTrackChange) {
	if(iAmt < 1) {
		return HC_CONTINUE
	}

	new TeamName:iTeam = get_member(pPlayer, m_iTeam)

	if( !(TEAM_SPECTATOR > iTeam > TEAM_UNASSIGNED) ) {
		return HC_CONTINUE
	}

	switch(iType) {
		case RT_ROUND_BONUS, RT_HOSTAGE_TOOK, RT_HOSTAGE_RESCUED, RT_ENEMY_KILLED, RT_VIP_KILLED, RT_VIP_RESCUED_MYSELF: {
			new bool:bWinnerTeam = (iTeam == g_iDominationTeam)
			new iPercent = g_eCvar[ bWinnerTeam ? CVAR__REWARD_PERCENTAGE_WINNER : CVAR__REWARD_PERCENTAGE_LOOSER ];

			if(iPercent == 100) {
				return HC_CONTINUE
			}

			new iModifiedValue = floatround( (float(iAmt) / 100.0) * float(iPercent) )

			SetHookChainArg(2, ATYPE_INTEGER, iModifiedValue)
			client_print_color(pPlayer, print_team_red, "%l", bWinnerTeam ? "AD__WINNER_MONEY_INFO" : "AD__LOOSER_MONEY_INFO", iModifiedValue, iAmt)
		}
	}

	return HC_CONTINUE
}

public CBasePlayer_TakeDamage_Pre(pVictim, pInflictor, pAttacker, Float:fDamage, bitDamageType) {
	if(!is_user_connected(pAttacker) || pVictim == pAttacker || (bitDamageType & DMG_BLAST)) {
		return HC_CONTINUE
	}

	new TeamName:iTeam = get_member(pAttacker, m_iTeam)

	if( !(TEAM_SPECTATOR > iTeam > TEAM_UNASSIGNED) || iTeam == get_member(pVictim, m_iTeam) ) {
		return HC_CONTINUE
	}

	new iPercent = g_eCvar[ (iTeam == g_iDominationTeam) ? CVAR__DAMAGE_PERCENTAGE_WINNER : CVAR__DAMAGE_PERCENTAGE_LOOSER ];

	if(iPercent == 100) {
		return HC_CONTINUE
	}

	SetHookChainArg(4, ATYPE_FLOAT, (fDamage / 100.0) * float(iPercent))

	return HC_CONTINUE
}

bool:AlreadySpawned(pPlayer) {
	return (!g_eCvar[CVAR__EQUIP_EACH_SPAWN] && get_member(pPlayer, m_iNumSpawns) > 1)
}

public CBasePlayer_Spawn_Post(pPlayer) {
	if(!is_user_alive(pPlayer) || AlreadySpawned(pPlayer)) {
		return HC_CONTINUE
	}

	new TeamName:iTeam = get_member(pPlayer, m_iTeam)

	if( !(TEAM_SPECTATOR > iTeam > TEAM_UNASSIGNED) ) {
		return HC_CONTINUE
	}

	new bool:bWinnerTeam = (iTeam == g_iDominationTeam)

	if(!bWinnerTeam) {
		if(g_eCvar[CVAR_F__EQUIP_DELAY]) {
			new iData[1]; iData[0] = get_user_userid(pPlayer)
			set_task(g_eCvar[CVAR_F__EQUIP_DELAY], "task_EquipDelay", TASKID__EQUIP, iData, sizeof(iData))
		}
		else {
			TryGiveWeapon(pPlayer, iTeam)
		}
	}

	TryShowDmgInfo(pPlayer, bWinnerTeam)

	return HC_CONTINUE
}

public task_EquipDelay(iData[1], iTaskID) {
	new pPlayer = find_player("k", iData[0])

	if(!is_user_alive(pPlayer)) {
		return
	}

	new TeamName:iTeam = get_member(pPlayer, m_iTeam)

	if( !(TEAM_SPECTATOR > iTeam > TEAM_UNASSIGNED) ) {
		return
	}

	if(iTeam == g_iDominationTeam) {
		TryGiveWeapon(pPlayer, iTeam)
	}
}

TryGiveWeapon(pPlayer, TeamName:iTeam) {
	new iPtr = (iTeam == TEAM_TERRORIST) ? CVAR__BONUS_WEAPON_TT : CVAR__BONUS_WEAPON_CT;

	if(!g_eCvar[iPtr]) {
		return
	}

	if( !is_nullent( get_member(pPlayer, m_rgpPlayerItems, PRIMARY_WEAPON_SLOT) ) ) {
		return
	}

	new pWeapon = rg_give_item(pPlayer, g_eCvar[iPtr])

	if(is_nullent(pWeapon)) {
		return
	}

	new WeaponIdType:iWeaponID = get_member(pWeapon, m_iId)
	rg_set_user_bpammo(pPlayer, iWeaponID, rg_get_weapon_info(iWeaponID, WI_MAX_ROUNDS))

	client_print_color(pPlayer, print_team_red, "%l", "AD__BONUS_WEAPON_INFO")
}

TryShowDmgInfo(pPlayer, bool:bWinnerTeam) {
	new iPercent = g_eCvar[ bWinnerTeam ? CVAR__DAMAGE_PERCENTAGE_WINNER : CVAR__DAMAGE_PERCENTAGE_LOOSER ];

	if(iPercent != 100) {
		client_print_color(pPlayer, print_team_red, "%l", bWinnerTeam ? "AD__WINNER_DAMAGE_INFO" : "AD__LOOSER_DAMAGE_INFO", iPercent)
	}
}

#if defined DISABLED_MAPS
	#define INVALID_STOP_POS -1

	bool:ShouldStop() {
		new iStopByPos = GetPosInMapNameArray()

		if(iStopByPos != INVALID_STOP_POS) {
			log_amx("Stop by prefix/mapname '%s'", DISABLED_MAPS[iStopByPos])
			return true
		}

		return false
	}

	GetPosInMapNameArray() {
		new szMapName[64]
		get_mapname(szMapName, charsmax(szMapName))

		for(new i; i < sizeof(DISABLED_MAPS); i++) {
			if(equali(szMapName, DISABLED_MAPS[i], strlen(DISABLED_MAPS[i]))) {
				return i
			}
		}

		return INVALID_STOP_POS
	}
#endif

stock bind_cvar_num(const cvar[], const value[], flags = FCVAR_NONE, const desc[] = "", bool:has_min = false, Float:min_val = 0.0, bool:has_max = false, Float:max_val = 0.0, &bind) {
	bind_pcvar_num(create_cvar(cvar, value, flags, desc, has_min, min_val, has_max, max_val), bind)
}

stock bind_cvar_float(const cvar[], const value[], flags = FCVAR_NONE, const desc[] = "", bool:has_min = false, Float:min_val = 0.0, bool:has_max = false, Float:max_val = 0.0, &Float:bind) {
	bind_pcvar_float(create_cvar(cvar, value, flags, desc, has_min, min_val, has_max, max_val), bind)
}

stock bind_cvar_string(const cvar[], const value[], flags = FCVAR_NONE, const desc[] = "", bool:has_min = false, Float:min_val = 0.0, bool:has_max = false, Float:max_val = 0.0, bind[], maxlen) {
	bind_pcvar_string(create_cvar(cvar, value, flags, desc, has_min, min_val, has_max, max_val), bind, maxlen)
}

stock bind_cvar_num_by_name(const szCvarName[], &iBindVariable) {
	bind_pcvar_num(get_cvar_pointer(szCvarName), iBindVariable)
}

stock bind_cvar_float_by_name(const szCvarName[], &Float:fBindVariable) {
	bind_pcvar_float(get_cvar_pointer(szCvarName), fBindVariable)
}