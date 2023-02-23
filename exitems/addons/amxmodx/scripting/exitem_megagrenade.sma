/*
	This plugin serves as an alternative implementation of the MegaGrenade weapon for the 'AES' and 'BonusMenu RBS' systems

	Данный плагин служит альтернативным вариантом реализации оружия MegaGrenade для систем 'AES' и 'BonusMenu RBS'
*/

/* Requirements:
	* AMXX 1.9.0 or above
	* ReAPI
	* AES (https://dev-cs.ru/resources/362/) or BonusMenu RBS (https://fungun.net/shop/?p=show&id=106)
*/

/*
	How to use:
		* AES:
			On your server go to 'amxmodx/configs/aes/bonus.ini', find pointBonus_GiveMegaGrenade and change in current block
			plugin = aes_bonus_cstrike.amxx
				to
			plugin = exitem_megagrenade.amxx

		* BonusMenu RBS:
			Scroll down to SRVCMD_BONUSMENU_RBS

	--------------------------------------------------------------

	Инструкция:
		* AES:
			На сервере в 'amxmodx/configs/aes/bonus.ini' найдите pointBonus_GiveMegaGrenade и замените в данном блоке
			plugin = aes_bonus_cstrike.amxx
				на
			plugin = exitem_megagrenade.amxx

		* BonusMenu RBS:
			Пролистайте вниз до SRVCMD_BONUSMENU_RBS
*/

/* Changelog:
	1.0 (23.02.2023) by mx?!:
		* First release
	1.1 (23.02.2023) by mx?!:
		* Added autoequip feature (cvars 'exitem_mgren_autoequip_flags', 'exitem_mgren_autoequip_min_round', and 'exitem_mgren_autoequip_per_round')
*/

new const PLUGIN_NAME[] = "ExItem: MegaGrenade";
new const PLUGIN_VERSION[] = "1.1";

#pragma semicolon 1

// Debug mode. Should be commented.
//
// Режим отладки. Должен быть закомментирован.
//#define DEBUG

// Create cvar config in 'configs/plugins' and run it?
//
// Создавать конфиг с кварами в 'configs/plugins', и запускать его?
#define AUTO_CFG

// Weapon impulse value. Must me unique for each type of custom weapon.
//
// Импульс. Должен быть уникальным для каждого типа кастомного оружия.
const WEAPON_IMPULSE = 6776231;

// Custom weapon models. Uncomment the required ones, and enter the path to the .mdl
//
// Нестандартные модели оружия. Раскомментриуйте требуемые, и впишите путь к .mdl
//new const V_MODEL[] = "models/v_hegrenade.mdl";
//new const P_MODEL[] = "models/p_hegrenade.mdl";
//new const W_MODEL_FLOOR[] = "models/w_hegrenade.mdl";
//new const W_MODEL_THROW[] = "models/w_hegrenade.mdl";

// Base weapon
//
// Оружие-основа
new const WEAPON_NAME[] = "weapon_hegrenade";

// 'BonusMenu RBS' support: https://fungun.net/shop/?p=show&id=106
//
// Серверная команда для внешней выдачи через 'BonusMenu RBS'
// Формат "Команда #%userid% цена мин_раунд куллдаун доступ"
//
// Куллдаун - Задержка повторной покупки в раундах. Например, поставьте 1 чтобы можно было покупать один раз за раунд.
//  Доступ - Флаги доступа, при наличии любого из которых игрок может совершить покупку. Поставьте 0 чтобы доступ был для всех.
//
// Чтобы добавить оружие в BonusMenu RBS
// Вам необходимо добавить в bonusmenu_rbs.ini (где "666" в обоих случаях - цена предмета; поставьте своё значение)
// "srvcmd"   "666"   "!mgren_bmrbs #%userid% 666 1 1 0"   ""   "0"   "0"   "Мега граната \r(\y+300%% урона\r)"
//
new const SRVCMD_BONUSMENU_RBS[] = "mgren_bmrbs";

#include <amxmodx>
#include <reapi>
#include <hamsandwich>
#if defined W_MODEL_THROW
	#include <fakemeta>
#endif

// BonusMenu RBS https://fungun.net/shop/?p=show&id=106
native bonusmenu_get_user_points(id);
native bonusmenu_add_user_points(id, points);

#define INVALID_SLOT -1
#define rg_get_current_round() (get_member_game(m_iTotalRoundsPlayed) + 1)

enum _:CVAR_ENUM {
	Float:CVAR_F__DMG_MULTIPLIER,
	CVAR__ONE_ROUND,
	CVAR__STRICT_PICKUP,
	CVAR__BUY_ANYWHERE_SELF,
	CVAR__BUY_ANYWHERE_ORIG,
	CVAR__BUY_TIME,
	CVAR__AUTOEQUIP_FLAGS[32],
	CVAR__AUTOEQUIP_MIN_ROUND,
	CVAR__AUTOEQUIP_PER_ROUND
};

new g_eCvar[CVAR_ENUM];
new g_iWeaponSlot = INVALID_SLOT;
new any:g_iWeaponId;
new g_iCooldown[MAX_PLAYERS + 1];

public plugin_precache() {
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, "mx?!");
	/*register_dictionary("aes.txt");
	register_dictionary("bonusmenu_rbs.txt");*/
	register_dictionary("exitems.txt");

#if defined DEBUG
	register_clcmd("give_mgren", "pointBonus_GiveMegaGrenade");
#endif

	register_srvcmd(SRVCMD_BONUSMENU_RBS, "srvcmd_GiveItem_BonusMenuRBS");

	RegCvars();
	Precache();

	RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "CBasePlayer_OnSpawnEquip_Post", true);
}

RegCvars() {
	bind_cvar_float("exitem_mgren_dmg_mult", "3.0", .desc = "Множитель урона", .bind = g_eCvar[CVAR_F__DMG_MULTIPLIER]);
	bind_cvar_num("exitem_mgren_one_round", "1", .desc = "Забирать в новом раунде?", .bind = g_eCvar[CVAR__ONE_ROUND]);
	bind_cvar_num("exitem_mgren_strict_pickup", "1", .desc = "Запретить подбирать другим игрокам?", .bind = g_eCvar[CVAR__STRICT_PICKUP]);

	bind_cvar_num( "exitem_mgren_buy_anywhere", "-1",
		.desc = "Возможность покупки не только в buyzone^n\
		-1 - Подчиняться квару mp_buy_anywhere (см. game.cfg)^n\
		0 - выкл.^n\
		1 - обе команды^n\
		2 - только ТТ^n\
		3 - только КТ",
		.bind = g_eCvar[CVAR__BUY_ANYWHERE_SELF]
	);

	bind_cvar_num( "exitem_mgren_obey_buytime", "-2",
		.desc = "Время на покупку^n\
		-2 - Подчиняться квару mp_buytime^n\
		-1 - Без ограничений^n\
		0 - Выкл. покупку^n\
		1 и более - Время в секундах",
		.bind = g_eCvar[CVAR__BUY_TIME]
	);

	bind_cvar_string( "exitem_mgren_autoequip_flags", "t",
		.desc = "Флаги автоматической экипировки при спавне. Требуется любой из. (^"^" - для всех)",
		.bind = g_eCvar[CVAR__AUTOEQUIP_FLAGS], .maxlen = charsmax(g_eCvar[CVAR__AUTOEQUIP_FLAGS])
	);

	bind_cvar_num( "exitem_mgren_autoequip_min_round", "0",
		.desc = "С какого раунда экипировать автоматически (0 - выкл.) ?",
		.bind = g_eCvar[CVAR__AUTOEQUIP_MIN_ROUND]
	);

	bind_cvar_num( "exitem_mgren_autoequip_per_round", "1",
		.desc = "Поддержка Revive Teammates. Сколько раз за раунд можно автоэкпипироваться (0 - выкл.) ?",
		.bind = g_eCvar[CVAR__AUTOEQUIP_PER_ROUND]
	);

	bind_cvar_num_by_name("mp_buy_anywhere", g_eCvar[CVAR__BUY_ANYWHERE_ORIG]);

#if defined AUTO_CFG
	AutoExecConfig(/*.name = "PluginName"*/);
#endif
}

Precache() {
#if defined V_MODEL
	precache_model(V_MODEL);
#endif

#if defined P_MODEL
	precache_model(P_MODEL);
#endif

#if defined W_MODEL_FLOOR
	precache_model(W_MODEL_FLOOR);
#endif

#if defined W_MODEL_THROW
	precache_model(W_MODEL_THROW);
#endif
}

public HamTouchWeaponbox_Pre(pTouched, pToucher) {
	if(!g_eCvar[CVAR__STRICT_PICKUP] || !is_user_alive(pToucher) || !is_entity(pTouched) || get_entvar(pTouched, var_impulse) != WEAPON_IMPULSE) {
		return HAM_IGNORED;
	}

	return (get_entvar(pTouched, var_owner) == pToucher) ? HAM_IGNORED : HAM_SUPERCEDE;
}

public CWeaponBox_SetModel_Pre(pWeaponBox, const szModelName[]) {
	if(!is_entity(pWeaponBox)/* || g_iWeaponSlot == INVALID_SLOT*/) {
		return;
	}

	new pWeapon = get_member(pWeaponBox, m_WeaponBox_rgpPlayerItems, g_iWeaponSlot);

	if(is_nullent(pWeapon) || !IsCustomWeapon(pWeapon)) {
		return;
	}

#if defined DEBUG
	client_print(0, print_chat, "SetModel: entity %i", pWeapon);
#endif

	set_entvar(pWeaponBox, var_impulse, WEAPON_IMPULSE);

#if defined W_MODEL_FLOOR
	SetHookChainArg(2, ATYPE_STRING, W_MODEL_FLOOR);
#endif
}

#if defined V_MODEL || defined P_MODEL
	public HamItemDeploy_Post(pWeapon) {
		if(!is_entity(pWeapon) || get_entvar(pWeapon, var_impulse) != WEAPON_IMPULSE) {
			return;
		}

		new pPlayer = get_member(pWeapon, m_pPlayer);

	#if defined V_MODEL
		set_entvar(pPlayer, var_viewmodel, V_MODEL);
	#endif

	#if defined P_MODEL
		set_entvar(pPlayer, var_weaponmodel, P_MODEL);
	#endif
	}
#endif

public CSGameRules_RestartRound_Pre() {
	/*if(g_iWeaponSlot == INVALID_SLOT) {
		return;
	}*/

	for(new i; i < sizeof(g_iCooldown); i++) {
		if(g_iCooldown[i]) {
			g_iCooldown[i]--;
		}
	}

	if(g_eCvar[CVAR__ONE_ROUND] && !get_member_game(m_bCompleteReset)) {
		new pPlayers[MAX_PLAYERS], iPlCount;
		get_players(pPlayers, iPlCount, "a");

		for(new i; i < iPlCount; i++) {
			RemoveCustomWeapon(pPlayers[i]);
		}
	}
}

public ThrowHeGrenade_Post(pPlayer, Float:vecStart[3], Float:vecVelocity[3], Float:time, const team, const usEvent) {
	/*if(g_iWeaponSlot == INVALID_SLOT) {
		return;
	}*/

	new pWeapon = get_member(pPlayer, m_pActiveItem);

#if defined DEBUG
	client_print(0, print_chat, "throw m_pActiveItem %i | custom %i", pWeapon, IsCustomWeapon(pWeapon));
#endif

	if(is_nullent(pWeapon) || !IsCustomWeapon(pWeapon)) {
		return;
	}

	new pGrenade = GetHookChainReturn(ATYPE_INTEGER);

#if defined DEBUG
	client_print(0, print_chat, "pGrenade %i | is_nullent %i", pGrenade, is_nullent(pGrenade));
#endif

	if(is_nullent(pGrenade)) {
		return;
	}

	set_entvar(pGrenade, var_impulse, WEAPON_IMPULSE);

#if defined W_MODEL_THROW
	engfunc(EngFunc_SetModel, pGrenade, W_MODEL_THROW);
#endif
}

public CBasePlayer_TakeDamage_Pre(pVictim, pInflictor, pAttacker, Float:fDamage, bitDamageType) {
	/*if(g_iWeaponSlot == INVALID_SLOT) {
		return;
	}*/

	if(is_nullent(pInflictor) || !FClassnameIs(pInflictor, "grenade") || get_entvar(pInflictor, var_impulse) != WEAPON_IMPULSE) {
		return;
	}

#if defined DEBUG
	client_print(0, print_chat, "old dmg %f | new dmg %f", fDamage, fDamage * g_eCvar[CVAR_F__DMG_MULTIPLIER]);
#endif
	SetHookChainArg(4, ATYPE_FLOAT, fDamage * g_eCvar[CVAR_F__DMG_MULTIPLIER]);
}

public CBasePlayer_OnSpawnEquip_Post(pPlayer) {
	if(!is_user_alive(pPlayer) || !g_eCvar[CVAR__AUTOEQUIP_MIN_ROUND] || rg_get_current_round() < g_eCvar[CVAR__AUTOEQUIP_MIN_ROUND]) {
		return;
	}

	if(get_member(pPlayer, m_iNumSpawns) > g_eCvar[CVAR__AUTOEQUIP_PER_ROUND]) {
		return;
	}

	new bitAcess = read_flags(g_eCvar[CVAR__AUTOEQUIP_FLAGS]);

	if(bitAcess && !( get_user_flags(pPlayer) & bitAcess )) {
		return;
	}

	GiveItem(pPlayer);
}

public client_disconnected(pPlayer) {
	g_iCooldown[pPlayer] = 0;
}

RemoveCustomWeapon(pPlayer) {
	if(GetCustomWeapon(pPlayer)) {
		rg_remove_item(pPlayer, WEAPON_NAME);
	}
}

GetCustomWeapon(pPlayer) {
	if(g_iWeaponSlot == INVALID_SLOT) {
		return 0;
	}

	static pWeapon; pWeapon = get_member(pPlayer, m_rgpPlayerItems, g_iWeaponSlot);

	while(!is_nullent(pWeapon)) {
		if(IsCustomWeapon(pWeapon)) {
			return pWeapon;
		}

		pWeapon = get_member(pWeapon, m_pNext);
	}

	return 0;
}

bool:IsCustomWeapon(pWeapon) {
	return (get_entvar(pWeapon, var_impulse) == WEAPON_IMPULSE && get_member(pWeapon, m_iId) == g_iWeaponId);
}

GiveItem(pPlayer) {
	rg_remove_item(pPlayer, WEAPON_NAME);
	new pWeapon = rg_give_item(pPlayer, WEAPON_NAME, GT_APPEND);

	if(is_nullent(pWeapon)) {
		return 0;
	}

	if(g_iWeaponSlot == INVALID_SLOT) {
		g_iWeaponSlot = rg_get_iteminfo(pWeapon, ItemInfo_iSlot) + 1;
	#if defined DEBUG
		client_print(0, print_chat, "Slot is %i", g_iWeaponSlot);
	#endif
		g_iWeaponId = get_member(pWeapon, m_iId);
		RegisterHookChain(RG_CWeaponBox_SetModel, "CWeaponBox_SetModel_Pre");
	#if defined V_MODEL || defined P_MODEL
		RegisterHam(Ham_Item_Deploy, WEAPON_NAME, "HamItemDeploy_Post", true);
	#endif
		RegisterHam(Ham_Touch, "weaponbox", "HamTouchWeaponbox_Pre");
		RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre");
		RegisterHookChain(RG_ThrowHeGrenade, "ThrowHeGrenade_Post", true);
		RegisterHookChain(RG_CBasePlayer_TakeDamage, "CBasePlayer_TakeDamage_Pre");
	}

	//rg_set_user_bpammo(pPlayer, g_iWeaponId, rg_get_iteminfo(pWeapon, ItemInfo_iMaxAmmo1));
	//set_member(pWeapon, m_Weapon_flBaseDamage, Float:get_member(pWeapon, m_Weapon_flBaseDamage) * g_eCvar[CVAR_F__DMG_MULTIPLIER]);
	set_entvar(pWeapon, var_impulse, WEAPON_IMPULSE);

#if defined V_MODEL || defined P_MODEL
	if(get_member(pPlayer, m_pActiveItem) == pWeapon) {
	#if defined V_MODEL
		set_entvar(pPlayer, var_viewmodel, V_MODEL);
	#endif

	#if defined P_MODEL
		set_entvar(pPlayer, var_weaponmodel, P_MODEL);
	#endif
	}
#endif

	return pWeapon;
}

// AES by serfreeman1337 (sonyx fork) https://dev-cs.ru/resources/362/
public pointBonus_GiveMegaGrenade(pPlayer) {
	if(!is_user_alive(pPlayer)) {
		client_print_color(pPlayer, print_team_default, "%l %l", "AES_TAG", "AES_ANEW_ALIVE");
		return false;
	}

	if(GetCustomWeapon(pPlayer)) {
		client_print_color(pPlayer, print_team_default, "%l %l", "AES_TAG", "EXITEMS__ALREADY_WEAPON");
		return false;
	}

	if(!CheckBuyzone(pPlayer)) {
		client_print_color(pPlayer, print_team_default, "%l", "EXITEMS__ONLY_BUYZONE");
		return false;
	}

	switch(g_eCvar[CVAR__BUY_TIME]) {
		case -2: {
			if(IsBuyTimeOver()) {
				client_print_color(pPlayer, print_team_default, "%l", "EXITEMS__BUYTIME_OVER");
				return false;
			}
		}
		case -1: {
			// nothing
		}
		default: {
			if(get_gametime() - Float:get_member_game(m_fRoundStartTime) > float(g_eCvar[CVAR__BUY_TIME])) {
				client_print_color(pPlayer, print_team_default, "%l", "EXITEMS__BUYTIME_OVER");
				return false;
			}
		}
	}

	new pWeapon = GiveItem(pPlayer);

	if(!pWeapon) {
		client_print_color(pPlayer, print_team_default, "%l %l", "AES_TAG", "AES_ANEW_CALL_PROBLEM");
		return false;
	}

	client_print_color(pPlayer, print_team_default, "%l %l", "AES_TAG", "AES_BONUS_GET_MEGAGRENADE");

	return true;
}

// BonusMenu RBS: https://fungun.net/shop/?p=show&id=106
public srvcmd_GiveItem_BonusMenuRBS() {
	enum { arg_userid = 1, arg_price, arg_min_round, arg_cooldown, arg_access_flag };

	new szUserId[32];
	read_argv(arg_userid, szUserId, charsmax(szUserId));

	new pPlayer = find_player("k", str_to_num(szUserId[1]));

	if(!pPlayer) {
		abort(AMX_ERR_GENERAL, "[1] Player '%s' not found", szUserId[1]);
	}

	if(!is_user_alive(pPlayer)) {
		client_print_color(pPlayer, print_team_default, "%l", "BONUSMENU_ALIVE");
		return PLUGIN_HANDLED;
	}

	new szFlag[32];
	read_argv(arg_access_flag, szFlag, charsmax(szFlag));

	new bitFlag = read_flags(szFlag);

	if(bitFlag && szFlag[0] != '0' && !(get_user_flags(pPlayer) & bitFlag)) {
		client_print_color(pPlayer, print_team_default, "%l", "EXITEMS__NO_ACCESS");
		return PLUGIN_HANDLED;
	}

	if(GetCustomWeapon(pPlayer)) {
		client_print_color(pPlayer, print_team_default, "%l", "EXITEMS__ALREADY_WEAPON");
		return PLUGIN_HANDLED;
	}

	new iMinRound = read_argv_int(arg_min_round);

	if(rg_get_current_round() < iMinRound) {
		client_print_color(pPlayer, print_team_default, "%l", "BONUSMENU_FIRSTROUND", iMinRound);
		return PLUGIN_HANDLED;
	}

	if(g_iCooldown[pPlayer]) {
		client_print_color(pPlayer, print_team_default, "%l", "BONUSMENU_BLOCKROUNDS", g_iCooldown[pPlayer]);
		return PLUGIN_HANDLED;
	}

	if(!CheckBuyzone(pPlayer)) {
		client_print_color(pPlayer, print_team_default, "%l", "EXITEMS__ONLY_BUYZONE");
		return PLUGIN_HANDLED;
	}

	switch(g_eCvar[CVAR__BUY_TIME]) {
		case -2: {
			if(IsBuyTimeOver()) {
				client_print_color(pPlayer, print_team_default, "%l", "EXITEMS__BUYTIME_OVER");
				return PLUGIN_HANDLED;
			}
		}
		case -1: {
			// nothing
		}
		default: {
			if(get_gametime() - Float:get_member_game(m_fRoundStartTime) > float(g_eCvar[CVAR__BUY_TIME])) {
				client_print_color(pPlayer, print_team_default, "%l", "EXITEMS__BUYTIME_OVER");
				return PLUGIN_HANDLED;
			}
		}
	}

	new iPrice = read_argv_int(arg_price);

	if(iPrice && bonusmenu_get_user_points(pPlayer) < iPrice) {
		client_print_color(pPlayer, print_team_default, "%l", "BONUSMENU_INSUFFICIENTLY");
		return PLUGIN_HANDLED;
	}

	if(!GiveItem(pPlayer)) {
		client_print_color(pPlayer, print_team_default, "%l", "BONUSMENU_GAMECMS_ERROR");
		return PLUGIN_HANDLED;
	}

	g_iCooldown[pPlayer] = read_argv_int(arg_cooldown);

	if(iPrice) {
		bonusmenu_add_user_points(pPlayer, -iPrice);
	}

	return PLUGIN_HANDLED;
}

bool:CheckBuyzone(pPlayer) {
	new iValue = (g_eCvar[CVAR__BUY_ANYWHERE_SELF] == -1) ? g_eCvar[CVAR__BUY_ANYWHERE_ORIG] : g_eCvar[CVAR__BUY_ANYWHERE_SELF];
	return CheckBuyAnywhereValue(pPlayer, iValue);
}

bool:CheckBuyAnywhereValue(pPlayer, iValue) {
	switch(iValue) {
		case 0: {
			return rg_get_user_buyzone(pPlayer);
		}
		case 1: {
			return true;
		}
		case 2: {
			return (rg_get_user_buyzone(pPlayer) || get_member(pPlayer, m_iTeam) == TEAM_TERRORIST);
		}
		case 3: {
			return (rg_get_user_buyzone(pPlayer) || get_member(pPlayer, m_iTeam) == TEAM_CT);
		}
	}

	return rg_get_user_buyzone(pPlayer);
}

// Проверка, истёк ли байтайм
// https://github.com/s1lentq/ReGameDLL_CS/blob/2eba3b1186d5814408f4c082fd72aee637eaaac3/regamedll/dlls/player.cpp#L4231
stock bool:IsBuyTimeOver() {
	static pCvar, Float:fBuyTime;

	if(!pCvar) {
		pCvar = get_cvar_pointer("mp_buytime");
		bind_pcvar_float(pCvar, fBuyTime);
	}

	if(fBuyTime == -1.0) {
		return false;
	}

	// https://github.com/s1lentq/ReGameDLL_CS/blob/fd06d655ec62a623d27178dc015a25f472c6ab03/regamedll/dlls/player.h#L42
	const Float:MIN_BUY_TIME = 15.0;

	new Float:fTime = floatmax(MIN_BUY_TIME, fBuyTime * 60.0);

	return (get_gametime() - Float:get_member_game(m_fRoundStartTime) > fTime);
}

stock bool:rg_get_user_buyzone(pPlayer) {
	new iSignals[UnifiedSignals];
	get_member(pPlayer, m_signals, iSignals);
	return bool:(SignalState:iSignals[US_State] & SIGNAL_BUY);
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

public plugin_natives() {
	set_native_filter("native_filter");
}

/* trap        - 0 if native couldn't be found, 1 if native use was attempted
 * @note The handler should return PLUGIN_CONTINUE to let the error through the
 *       filter (which will throw a run-time error), or return PLUGIN_HANDLED */
public native_filter(const szNativeName[], iNativeID, iTrapMode) {
	return !iTrapMode;
}