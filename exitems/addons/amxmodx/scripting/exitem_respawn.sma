/*
	This plugin serves as an alternative implementation of the Respawn feature for the 'AES' and 'BonusMenu RBS' systems

	Данный плагин служит альтернативным вариантом реализации возрождения для систем 'AES' и 'BonusMenu RBS'
*/

/* Requirements:
	* AMXX 1.9.0 or above
	* ReAPI
	* AES (https://dev-cs.ru/resources/362/) or BonusMenu RBS (https://fungun.net/shop/?p=show&id=106)
*/

/*
	How to use:
		* AES:
			On your server go to 'amxmodx/configs/aes/bonus.ini', find section [items] and add (also change points value to your price):
			plugin = exitem_respawn.amxx
			name = Respawn
			function = pointBonus_MakeRespawn
			value = 1
			points = 1

		* BonusMenu RBS:
			Scroll down to SRVCMD_BONUSMENU_RBS

	--------------------------------------------------------------

	Инструкция:
		* AES:
			На сервере в 'amxmodx/configs/aes/bonus.ini' найдите раздел [items] и добавьте (изменив цену, т.е. значение points):
			<call>
			plugin = exitem_respawn.amxx
			name = Возрождение
			function = pointBonus_MakeRespawn
			value = 1
			points = 1

		* BonusMenu RBS:
			Пролистайте вниз до SRVCMD_BONUSMENU_RBS
*/

/* Changelog:
	1.0 (27.08.2024) by mx?!:
		* First release
	1.1 (28.08.2024) by mx?!:
		* Fixed exitem_resp_block_suicide cvar logic, as state did not affect behavior
*/

new const PLUGIN_NAME[] = "ExItem: Respawn";
new const PLUGIN_VERSION[] = "1.1";

#pragma semicolon 1

// Debug mode. Should be commented.
//
// Режим отладки. Должен быть закомментирован.
//#define DEBUG

// Config file path inside 'amxmodx/configs'
//
// Путь к конфигу относительно 'amxmodx/configs'
new const CFG_PATH[] = "plugins/plugin-exitem_respawn.cfg";

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
// "srvcmd"   "666"   "!resp_bmrbs #%userid% 666 1 1 0"   ""   "0"   "0"   "Возрождение"
//
new const SRVCMD_BONUSMENU_RBS[] = "resp_bmrbs";

#include <amxmodx>
#include <reapi>
#include <fakemeta>

// BonusMenu RBS https://fungun.net/shop/?p=show&id=106
native bonusmenu_get_user_points(id);
native bonusmenu_add_user_points(id, points);

#define rg_get_current_round() (get_member_game(m_iTotalRoundsPlayed) + 1)

enum _:CVAR_ENUM {
	CVAR__ENABLED,
	CVAR__BUY_COOLDOWN_SECS,
	CVAR__BUY_COOLDOWN_ROUNDS,
	CVAR__MAX_PER_ROUND,
	CVAR__RESP_MODE,
	CVAR__UNSTUCK,
	Float:CVAR_F__FLASH,
	Float:CVAR_F__DEATH_DELAY,
	Float:CVAR_F__DEATH_EXPIRATION,
	Float:CVAR_F__ROUND_START_TIME,
	Float:CVAR_F__ROUND_END_TIME,
	CVAR__BLOCK_SUICIDE,
	CVAR__RESPAWN_SOUND[96],
	CVAR__BLOCK_LAST_TEAMMATE,
	CVAR__BLOCK_DUEL,
	CVAR__BLOCK_BOMB,
	CVAR__MIN_PLAYERS
};

new g_eCvar[CVAR_ENUM];
new g_iCooldown[MAX_PLAYERS + 1];
new g_iLastBuyTime[MAX_PLAYERS + 1];
new g_iUsedInRound[MAX_PLAYERS + 1];
new HookChain:g_hGetPlayerSpawnSpot;
new Float:g_fCorplseOrigin[MAX_PLAYERS + 1][3];
new g_msgRadar;
new g_msgBombPickup;
new g_msgScreenFade;
new g_iTeam[MAX_PLAYERS + 1];
new Float:g_fDeathTime[MAX_PLAYERS + 1];
new bool:g_bSuicide[MAX_PLAYERS + 1];

public plugin_precache() {
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, "mx?!");
	/*register_dictionary("aes.txt");
	register_dictionary("bonusmenu_rbs.txt");*/
	register_dictionary("exitems.txt");

#if defined DEBUG
	register_clcmd("make_resp", "pointBonus_MakeRespawn");
#endif

	register_srvcmd(SRVCMD_BONUSMENU_RBS, "srvcmd_GiveItem_BonusMenuRBS");

	RegCvars();

	if(g_eCvar[CVAR__RESPAWN_SOUND][0]) {
		precache_sound(g_eCvar[CVAR__RESPAWN_SOUND]);
	}

	g_hGetPlayerSpawnSpot = RegisterHookChain(RG_CSGameRules_GetPlayerSpawnSpot, "CSGameRules_GetPlayerSpawnSpot_Pre");
	DisableHookChain(g_hGetPlayerSpawnSpot);

	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Pre");
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Pre");
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre");

	 // Used hardcoded value insted of get_user_msgid("ClCorpse") as we reg msg in precache(), so first run (server cold start) will fail to obtain msgid from get_user_msgid()
	const iClCorpseMsgId = 122; //get_user_msgid("ClCorpse");
	register_message(iClCorpseMsgId, "msg_ClCorpse");

	g_msgRadar = 112; //get_user_msgid("Radar");
	g_msgBombPickup = 121; //get_user_msgid("BombPickup");
	g_msgScreenFade = 98; //get_user_msgid("ScreenFade");
}

RegCvars() {
	bind_cvar_num( "exitem_resp_enabled", "1",
		.desc = "Функция возрождения доступна?",
		.bind = g_eCvar[CVAR__ENABLED]
	);

	bind_cvar_num( "exitem_resp_buy_cooldown_secs", "0",
		.desc = "Не давать покупать чаще одного раза каждые # секунд (0 - без ограничения)",
		.bind = g_eCvar[CVAR__BUY_COOLDOWN_SECS]
	);

	bind_cvar_num( "exitem_resp_buy_cooldown_rounds", "0",
		.desc = "[Только AES] Не давать покупать чаще одного раза каждые # раундов (0 - без ограничения) ?",
		.bind = g_eCvar[CVAR__BUY_COOLDOWN_ROUNDS]
	);

	bind_cvar_num( "exitem_resp_max_per_round", "1",
		.desc = "[Только AES] Сколько раз за раунд можно возродиться (0 - без ограничения) ?",
		.bind = g_eCvar[CVAR__MAX_PER_ROUND]
	);

	bind_cvar_num( "exitem_resp_mode", "1",
		.desc = "Режим возрождения: 0 - на респе (классический); 1 - на месте смерти",
		.bind = g_eCvar[CVAR__RESP_MODE]
	);

	bind_cvar_num( "exitem_resp_unstuck", "1",
		.desc = "Делать unstuck после возрождения (рекомендуется при exitem_resp_mode ^"1^") ?",
		.bind = g_eCvar[CVAR__UNSTUCK]
	);

	bind_cvar_float( "exitem_resp_flash", "1.25",
		.desc = "Слепить возродившегося игрока на # секунд (0 - не слепить)",
		.bind = g_eCvar[CVAR_F__FLASH]
	);

	bind_cvar_float( "exitem_resp_death_delay", "0",
		.desc = "Через сколько секунд после смерти доступно возрождение (0 - без ограничения)",
		.bind = g_eCvar[CVAR_F__DEATH_DELAY]
	);

	bind_cvar_float( "exitem_resp_death_expiration", "30",
		.desc = "В течение скольки секунд после смерти доступно возрождение (0 - без ограничения)",
		.bind = g_eCvar[CVAR_F__DEATH_EXPIRATION]
	);

	bind_cvar_float( "exitem_resp_round_start_time", "0",
		.desc = "Время с начала раунда (в секундах), начиная с которого МОЖНО использовать возрождение (0 - без ограничения)",
		.bind = g_eCvar[CVAR_F__ROUND_START_TIME]
	);

	bind_cvar_float( "exitem_resp_round_end_time", "0",
		.desc = "Время с начала раунда (в секундах), начиная с которого НЕЛЬЗЯ использовать возрождение (0 - без ограничения)",
		.bind = g_eCvar[CVAR_F__ROUND_END_TIME]
	);

	bind_cvar_num( "exitem_resp_block_suicide", "1",
		.desc = "Блокировать возрождение, если игрок убил сам себя (kill), разбился, умер от trigger_hurt, и т.п.",
		.bind = g_eCvar[CVAR__BLOCK_SUICIDE]
	);

	bind_cvar_string( "exitem_resp_sound", "items/smallmedkit1.wav",
		.desc = " Звук возрождения (^"^" - отключить)",
		.bind = g_eCvar[CVAR__RESPAWN_SOUND], .maxlen = charsmax(g_eCvar[CVAR__RESPAWN_SOUND])
	);

	bind_cvar_num( "exitem_resp_block_last_teammate", "1",
		.desc = "Блокировать возрождение, если в одной из команд остался один игрок?",
		.bind = g_eCvar[CVAR__BLOCK_LAST_TEAMMATE]
	);

	bind_cvar_num( "exitem_resp_block_duel", "1",
		.desc = "Блокировать возрождение, если в обеих командах осталось по одному игроку?",
		.bind = g_eCvar[CVAR__BLOCK_DUEL]
	);

	bind_cvar_num( "exitem_resp_block_bomb", "1",
		.desc = "Блокировать возрождение, если установлена бомба?",
		.bind = g_eCvar[CVAR__BLOCK_BOMB]
	);

	bind_cvar_num( "exitem_resp_min_players", "0",
		.desc = "Минимальное кол-во играющих (без зрителей) для работы функции (0 - без ограничения)",
		.bind = g_eCvar[CVAR__MIN_PLAYERS]
	);

	new szPath[240];
	get_localinfo("amxx_configsdir", szPath, charsmax(szPath));
	server_cmd("exec %s/%s", szPath, CFG_PATH);
	server_exec();
}

public CSGameRules_RestartRound_Pre() {
	for(new i; i < sizeof(g_iCooldown); i++) {
		if(g_iCooldown[i]) {
			g_iCooldown[i]--;
		}
	}

	arrayset(g_iUsedInRound, 0, sizeof(g_iUsedInRound));
	arrayset(_:g_fDeathTime, 0, sizeof(g_fDeathTime));
}

public client_disconnected(pPlayer) {
	g_iCooldown[pPlayer] = 0;
	g_iLastBuyTime[pPlayer] = 0;
	g_iUsedInRound[pPlayer] = 0;
	g_fDeathTime[pPlayer] = 0.0;
}

// AES by serfreeman1337 (sonyx fork) https://dev-cs.ru/resources/362/
public pointBonus_MakeRespawn(pPlayer) {
	if(!g_eCvar[CVAR__ENABLED]) {
		client_print_color(pPlayer, print_team_default, "%l %l", "AES_TAG", "EXITEMS__FUNC_UNA");
		return false;
	}

	if(is_user_alive(pPlayer)) {
		client_print_color(pPlayer, print_team_default, "%l %l", "AES_TAG", "EXITEMS__ONLY_DEAD");
		return false;
	}

	if(
		!(TEAM_SPECTATOR > get_member(pPlayer, m_iTeam) > TEAM_UNASSIGNED)
			||
		get_member(pPlayer, m_iMenu) == Menu_ChooseAppearance
			||
		get_member(pPlayer, m_iJoiningState) == PICKINGTEAM
	) {
		return false;
	}

	if(g_bSuicide[pPlayer] || !g_fDeathTime[pPlayer] || get_member_game(m_bRoundTerminating)) {
		client_print_color(pPlayer, print_team_default, "%l %l", "AES_TAG", "EXITEMS__FUNC_UNA");
		return false;
	}

	if(g_iTeam[pPlayer] != get_member(pPlayer, m_iTeam)) {
		client_print_color(pPlayer, print_team_default, "%l %l", "AES_TAG", "EXITEMS__TEAM_CHANGED");
		return false;
	}

	if(g_iUsedInRound[pPlayer] >= g_eCvar[CVAR__MAX_PER_ROUND]) {
		client_print_color(pPlayer, print_team_default, "%l %l", "AES_TAG", "EXITEMS__MAX_PER_ROUND");
		return false;
	}

	new iCoolDownSecs = GetCoolDownSecs(pPlayer);

	if(iCoolDownSecs) {
		client_print_color(pPlayer, print_team_default, "%l %l", "AES_TAG", "EXITEMS__BUY_COOLDOWN", iCoolDownSecs);
		return false;
	}

	if(g_iCooldown[pPlayer]) {
		client_print_color(pPlayer, print_team_default, "%l %l", "AES_TAG", "EXITEMS__BUY_CD_ROUNDS", g_iCooldown[pPlayer]);
		return false;
	}

	if(!CheckDeathExpiration(pPlayer)) {
		client_print_color(pPlayer, print_team_default, "%l %l", "AES_TAG", "EXITEMS__TIME_EXPIRED");
		return false;
	}

	if(g_eCvar[CVAR__BLOCK_BOMB] && IsBombPlanted()) {
		client_print_color(pPlayer, print_team_default, "%l %l", "AES_TAG", "EXITEMS__FUNC_UNA");
		return false;
	}

	if(!CheckAlivePlayersRules()) {
		client_print_color(pPlayer, print_team_default, "%l %l", "AES_TAG", "EXITEMS__FUNC_UNA");
		return false;
	}

	if(!CheckRoundStartTime(pPlayer, true)) {
		return false;
	}

	if(!CheckRoundEndTime()) {
		client_print_color(pPlayer, print_team_default, "%l %l", "AES_TAG", "EXITEMS__TIME_EXPIRED");
		return false;
	}

	if(!CheckDeathDelay(pPlayer, true)) {
		return false;
	}

	g_iUsedInRound[pPlayer]++;
	g_iLastBuyTime[pPlayer] = get_systime();
	g_iCooldown[pPlayer] = g_eCvar[CVAR__BUY_COOLDOWN_ROUNDS];

	RespawnPlayer(pPlayer);

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

	if(!g_eCvar[CVAR__ENABLED]) {
		client_print_color(pPlayer, print_team_default, "%l", "EXITEMS__FUNC_UNA");
		return PLUGIN_HANDLED;
	}

	if(is_user_alive(pPlayer)) {
		client_print_color(pPlayer, print_team_default, "%l", "EXITEMS__ONLY_DEAD");
		return PLUGIN_HANDLED;
	}

	if(
		!(TEAM_SPECTATOR > get_member(pPlayer, m_iTeam) > TEAM_UNASSIGNED)
			||
		get_member(pPlayer, m_iMenu) == Menu_ChooseAppearance
			||
		get_member(pPlayer, m_iJoiningState) == PICKINGTEAM
	) {
		return PLUGIN_HANDLED;
	}

	new szFlag[32];
	read_argv(arg_access_flag, szFlag, charsmax(szFlag));

	new bitFlag = read_flags(szFlag);

	if(bitFlag && szFlag[0] != '0' && !(get_user_flags(pPlayer) & bitFlag)) {
		client_print_color(pPlayer, print_team_default, "%l", "EXITEMS__NO_ACCESS");
		return PLUGIN_HANDLED;
	}

	if(g_bSuicide[pPlayer] || !g_fDeathTime[pPlayer] || get_member_game(m_bRoundTerminating)) {
		client_print_color(pPlayer, print_team_default, "%l", "EXITEMS__FUNC_UNA");
		return PLUGIN_HANDLED;
	}

	new iMinRound = read_argv_int(arg_min_round);
	new iCurrentRound = rg_get_current_round();

	if(iCurrentRound < iMinRound) {
		client_print_color(pPlayer, print_team_default, "%l", "EXITEMS__FIRSTROUND", iMinRound, iCurrentRound);
		return PLUGIN_HANDLED;
	}

	if(g_iTeam[pPlayer] != get_member(pPlayer, m_iTeam)) {
		client_print_color(pPlayer, print_team_default, "%l", "EXITEMS__TEAM_CHANGED");
		return PLUGIN_HANDLED;
	}

	new iCoolDownSecs = GetCoolDownSecs(pPlayer);

	if(iCoolDownSecs) {
		client_print_color(pPlayer, print_team_default, "%l", "EXITEMS__BUY_COOLDOWN", iCoolDownSecs);
		return PLUGIN_HANDLED;
	}

	if(g_iCooldown[pPlayer]) {
		client_print_color(pPlayer, print_team_default, "%l", "EXITEMS__BUY_CD_ROUNDS", g_iCooldown[pPlayer]);
		return PLUGIN_HANDLED;
	}

	new iPrice = read_argv_int(arg_price);

	if(iPrice && bonusmenu_get_user_points(pPlayer) < iPrice) {
		client_print_color(pPlayer, print_team_default, "%l", "EXITEMS__INSUFFICIENTLY");
		return PLUGIN_HANDLED;
	}

	if(!CheckDeathExpiration(pPlayer)) {
		client_print_color(pPlayer, print_team_default, "%l", "EXITEMS__TIME_EXPIRED");
		return PLUGIN_HANDLED;
	}

	if(g_eCvar[CVAR__BLOCK_BOMB] && IsBombPlanted()) {
		client_print_color(pPlayer, print_team_default, "%l", "EXITEMS__FUNC_UNA");
		return PLUGIN_HANDLED;
	}

	if(!CheckAlivePlayersRules()) {
		client_print_color(pPlayer, print_team_default, "%l", "EXITEMS__FUNC_UNA");
		return PLUGIN_HANDLED;
	}

	if(!CheckRoundStartTime(pPlayer, false)) {
		return PLUGIN_HANDLED;
	}

	if(!CheckRoundEndTime()) {
		client_print_color(pPlayer, print_team_default, "%l", "EXITEMS__TIME_EXPIRED");
		return PLUGIN_HANDLED;
	}

	if(!CheckDeathDelay(pPlayer, false)) {
		return PLUGIN_HANDLED;
	}

	g_iUsedInRound[pPlayer]++;
	g_iLastBuyTime[pPlayer] = get_systime();
	g_iCooldown[pPlayer] = read_argv_int(arg_cooldown);

	if(iPrice) {
		bonusmenu_add_user_points(pPlayer, -iPrice);
	}

	RespawnPlayer(pPlayer);

	return PLUGIN_HANDLED;
}

RespawnPlayer(pPlayer) {
	if(!g_eCvar[CVAR__RESP_MODE]) {
		rg_round_respawn(pPlayer);
	}
	else {
		EnableHookChain(g_hGetPlayerSpawnSpot);
		rg_round_respawn(pPlayer);
		DisableHookChain(g_hGetPlayerSpawnSpot);

		set_entvar(pPlayer, var_flags, get_entvar(pPlayer, var_flags) | FL_DUCKING);
		// https://github.com/s1lentq/ReGameDLL_CS/blob/b9cccc691bdabbf9cb573be8ee5e39c9a4f70c4a/regamedll/pm_shared/pm_shared.cpp#L1921
		set_entvar(pPlayer, var_view_ofs, Float:{ 0.0, 0.0, 12.0 }); // https://github.com/s1lentq/ReGameDLL_CS/blob/f57d28fe721ea4d57d10c010d15d45f05f2f5bad/regamedll/dlls/util.h#L88
	}

	if(g_eCvar[CVAR__RESPAWN_SOUND][0]) {
		rh_emit_sound2(pPlayer, 0, CHAN_STATIC, g_eCvar[CVAR__RESPAWN_SOUND], VOL_NORM, ATTN_NORM - 0.20, 0, PITCH_NORM, 0);
	}

	FixRadar(pPlayer);

	if(g_eCvar[CVAR_F__FLASH]) {
		set_task(0.2, "task_FlashPlayer", pPlayer);
	}

	client_print_color(0, print_team_default, "%l", "EXITEMS__RESPAWN_INFO_ALL", pPlayer);
}

public CBasePlayer_Spawn_Pre(pPlayer) {
	remove_task(pPlayer);
}

public CBasePlayer_Killed_Pre(pVictim, pKiller, iGibType) {
	g_bSuicide[pVictim] = (g_eCvar[CVAR__BLOCK_SUICIDE] && (pVictim == pKiller || !is_user_connected(pKiller)));
	g_iTeam[pVictim] = get_member(pVictim, m_iTeam);
	g_fDeathTime[pVictim] = get_gametime();
}

public task_FlashPlayer(pPlayer) {
	if(is_user_alive(pPlayer) && g_eCvar[CVAR_F__FLASH]) {
		new Float:fScale = float(1<<12);
		message_begin(MSG_ONE, g_msgScreenFade, .player = pPlayer);
		write_short(FixedUnsigned16(2.0, fScale)); // duration
		write_short(FixedUnsigned16(g_eCvar[CVAR_F__FLASH], fScale)); // holdtime
		write_short(0); // flags
		write_byte(255);
		write_byte(255);
		write_byte(255);
		write_byte(255);
		message_end();
	}
}

// https://github.com/s1lentq/ReGameDLL_CS/blob/dc16b12d7976f03d20b81f9a2491ee7dddbb9b8e/regamedll/dlls/util.cpp#L473
FixedUnsigned16(Float:value, Float:scale) {
	new output = floatround(value * scale);
	if (output < 0)
		output = 0;

	if (output > 65535)
		output = 65535;

	return output;
}

GetCoolDownSecs(pPlayer) {
	if(!g_iLastBuyTime[pPlayer]) {
		return 0;
	}

	new iElapsed = get_systime() - g_iLastBuyTime[pPlayer];

	return max(0, g_eCvar[CVAR__BUY_COOLDOWN_SECS] - iElapsed);
}

bool:CheckDeathDelay(pPlayer, bool:bAesMode) {
	// https://github.com/s1lentq/ReGameDLL_CS/blob/dc16b12d7976f03d20b81f9a2491ee7dddbb9b8e/regamedll/dlls/player.cpp#L4696
	// https://github.com/s1lentq/ReGameDLL_CS/blob/dc16b12d7976f03d20b81f9a2491ee7dddbb9b8e/regamedll/dlls/player.h#L472
	if(get_entvar(pPlayer, var_iuser1) == OBS_NONE || !(get_member(pPlayer, m_afPhysicsFlags) & PFLAG_OBSERVER)) {
		if(bAesMode) {
			client_print_color(pPlayer, print_team_default, "%l %l", "AES_TAG", "EXITEMS__DELAY_OBSERVER");
		}
		else {
			client_print_color(pPlayer, print_team_default, "%l", "EXITEMS__DELAY_OBSERVER");
		}

		return false;
	}

	new Float:fElapsed = get_gametime() - g_fDeathTime[pPlayer];

	if(fElapsed >= g_eCvar[CVAR_F__DEATH_DELAY]) {
		return true;
	}

	new iRemainingSecs = max(1, floatround(g_eCvar[CVAR_F__DEATH_DELAY] - fElapsed));

	if(bAesMode) {
		client_print_color(pPlayer, print_team_default, "%l %l", "AES_TAG", "EXITEMS__DELAY_SECS", iRemainingSecs);
	}
	else {
		client_print_color(pPlayer, print_team_default, "%l", "EXITEMS__DELAY_SECS", iRemainingSecs);
	}

	return false;
}

bool:CheckDeathExpiration(pPlayer) {
	if(!g_eCvar[CVAR_F__DEATH_EXPIRATION]) {
		return true;
	}

	new Float:fElapsed = get_gametime() - g_fDeathTime[pPlayer];

	if(fElapsed >= g_eCvar[CVAR_F__DEATH_EXPIRATION]) {
		return false;
	}

	return true;
}

bool:CheckRoundStartTime(pPlayer, bool:bAesMode) {
	if(!g_eCvar[CVAR_F__ROUND_START_TIME]) {
		return true;
	}

	if(get_member_game(m_bFreezePeriod)) {
		return false;
	}

	new Float:fElapsed = get_gametime() - Float:get_member_game(m_fRoundStartTimeReal);

	if(fElapsed >= g_eCvar[CVAR_F__ROUND_START_TIME]) {
		return true;
	}

	new iSeconds = max(1, floatround(g_eCvar[CVAR_F__ROUND_START_TIME] - fElapsed));

	if(bAesMode) {
		client_print_color(pPlayer, print_team_default, "%l %l", "AES_TAG", "EXITEMS__DELAY_SECS", iSeconds);
	}
	else {
		client_print_color(pPlayer, print_team_default, "%l", "EXITEMS__DELAY_SECS", iSeconds);
	}

	return false;
}

bool:CheckRoundEndTime() {
	if(!g_eCvar[CVAR_F__ROUND_END_TIME]) {
		return true;
	}

	if(get_member_game(m_bFreezePeriod)) {
		return false;
	}

	new Float:fElapsed = get_gametime() - Float:get_member_game(m_fRoundStartTimeReal);

	if(fElapsed < g_eCvar[CVAR_F__ROUND_END_TIME]) {
		return true;
	}

	return false;
}

public msg_ClCorpse(iMsgId, iMsgDest, iMsgEnt) {
	new pVictim = get_msg_arg_int(12);

	g_fCorplseOrigin[pVictim][0] = float(get_msg_arg_int(2) / 128);
	g_fCorplseOrigin[pVictim][1] = float(get_msg_arg_int(3) / 128);
	g_fCorplseOrigin[pVictim][2] = float(get_msg_arg_int(4) / 128);

	return PLUGIN_CONTINUE;
}

// CBasePlayer::Spawn() ->
// https://github.com/s1lentq/ReGameDLL_CS/blob/15e7d4a11e9279693e528b571a5dba606900f98c/regamedll/dlls/player.cpp#L5624
// https://github.com/s1lentq/ReGameDLL_CS/blob/15e7d4a11e9279693e528b571a5dba606900f98c/regamedll/dlls/multiplay_gamerules.cpp#L4342 (NOTE: ломает FireTargets(), см. ссылку)
// https://github.com/s1lentq/ReGameDLL_CS/blob/f57d28fe721ea4d57d10c010d15d45f05f2f5bad/regamedll/dlls/gamerules.cpp#L49
// https://github.com/s1lentq/ReGameDLL_CS/blob/5dec3bad326b543e9d6007b9eaca05c03d267884/regamedll/dlls/player.cpp#L5278
// https://github.com/s1lentq/ReGameDLL_CS/blob/5dec3bad326b543e9d6007b9eaca05c03d267884/regamedll/dlls/player.cpp#L5210
// https://github.com/s1lentq/ReGameDLL_CS/blob/5dec3bad326b543e9d6007b9eaca05c03d267884/regamedll/dlls/player.cpp#L5189
public CSGameRules_GetPlayerSpawnSpot_Pre(pPlayer) {
	engfunc(EngFunc_SetOrigin, pPlayer, g_fCorplseOrigin[pPlayer]);
	set_entvar(pPlayer, var_velocity, NULL_VECTOR);
	set_entvar(pPlayer, var_v_angle, NULL_VECTOR);

	new Float:fAngles[3];
	get_entvar(pPlayer, var_angles, fAngles);
	fAngles[0] = fAngles[2] = 0.0;
	set_entvar(pPlayer, var_angles, fAngles);

	set_entvar(pPlayer, var_punchangle, NULL_VECTOR);
	set_entvar(pPlayer, var_fixangle, 1);

	if(g_eCvar[CVAR__UNSTUCK]) {
		Unstuck(pPlayer);  // из-под досок на инферно закидывает верх на доски
	}

	SetHookChainReturn(ATYPE_INTEGER, pPlayer);
	return HC_SUPERCEDE;
}

new const Float:g_fSize[][3] = {
    {0.0, 0.0, 1.0}, {0.0, 0.0, -1.0}, {0.0, 1.0, 0.0}, {0.0, -1.0, 0.0}, {1.0, 0.0, 0.0}, {-1.0, 0.0, 0.0}, {-1.0, 1.0, 1.0}, {1.0, 1.0, 1.0}, {1.0, -1.0, 1.0}, {1.0, 1.0, -1.0}, {-1.0, -1.0, 1.0}, {1.0, -1.0, -1.0}, {-1.0, 1.0, -1.0}, {-1.0, -1.0, -1.0},
    {0.0, 0.0, 2.0}, {0.0, 0.0, -2.0}, {0.0, 2.0, 0.0}, {0.0, -2.0, 0.0}, {2.0, 0.0, 0.0}, {-2.0, 0.0, 0.0}, {-2.0, 2.0, 2.0}, {2.0, 2.0, 2.0}, {2.0, -2.0, 2.0}, {2.0, 2.0, -2.0}, {-2.0, -2.0, 2.0}, {2.0, -2.0, -2.0}, {-2.0, 2.0, -2.0}, {-2.0, -2.0, -2.0},
    {0.0, 0.0, 3.0}, {0.0, 0.0, -3.0}, {0.0, 3.0, 0.0}, {0.0, -3.0, 0.0}, {3.0, 0.0, 0.0}, {-3.0, 0.0, 0.0}, {-3.0, 3.0, 3.0}, {3.0, 3.0, 3.0}, {3.0, -3.0, 3.0}, {3.0, 3.0, -3.0}, {-3.0, -3.0, 3.0}, {3.0, -3.0, -3.0}, {-3.0, 3.0, -3.0}, {-3.0, -3.0, -3.0},
    {0.0, 0.0, 4.0}, {0.0, 0.0, -4.0}, {0.0, 4.0, 0.0}, {0.0, -4.0, 0.0}, {4.0, 0.0, 0.0}, {-4.0, 0.0, 0.0}, {-4.0, 4.0, 4.0}, {4.0, 4.0, 4.0}, {4.0, -4.0, 4.0}, {4.0, 4.0, -4.0}, {-4.0, -4.0, 4.0}, {4.0, -4.0, -4.0}, {-4.0, 4.0, -4.0}, {-4.0, -4.0, -4.0},
    {0.0, 0.0, 5.0}, {0.0, 0.0, -5.0}, {0.0, 5.0, 0.0}, {0.0, -5.0, 0.0}, {5.0, 0.0, 0.0}, {-5.0, 0.0, 0.0}, {-5.0, 5.0, 5.0}, {5.0, 5.0, 5.0}, {5.0, -5.0, 5.0}, {5.0, 5.0, -5.0}, {-5.0, -5.0, 5.0}, {5.0, -5.0, -5.0}, {-5.0, 5.0, -5.0}, {-5.0, -5.0, -5.0}
};

Unstuck(pPlayer) {
	new iHull = (get_entvar(pPlayer, var_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN;

	static Float:fMins[3], Float:fOrigin[3], Float:fVec[3];
	get_entvar(pPlayer, var_origin, fOrigin);

	if(is_hull_vacant(fOrigin, iHull, pPlayer) || get_entvar(pPlayer, var_movetype) == MOVETYPE_NOCLIP || get_entvar(pPlayer, var_solid) == SOLID_NOT) {
		return;
	}

	get_entvar(pPlayer, var_mins, fMins);

	for(new a; a < sizeof(g_fSize); a++) {
		fVec[0] = fOrigin[0] - fMins[0] * g_fSize[a][0];
		fVec[1] = fOrigin[1] - fMins[1] * g_fSize[a][1];
		fVec[2] = fOrigin[2] - fMins[2] * g_fSize[a][2];

		if(is_hull_vacant(fVec, iHull, pPlayer)) {
			engfunc(EngFunc_SetOrigin, pPlayer, fVec);
			set_entvar(pPlayer, var_velocity, NULL_VECTOR);
			break;
		}
	}
}

stock bool:is_hull_vacant(const Float:fOrigin[3], iHull, pPlayer) {
	new iTraceResult;

	engfunc(EngFunc_TraceHull, fOrigin, fOrigin, IGNORE_MONSTERS, iHull, pPlayer, iTraceResult);

	return (!get_tr2(iTraceResult, TR_StartSolid) || !get_tr2(iTraceResult, TR_AllSolid));
}

FixRadar(pPlayer) {
	new pPlayers[MAX_PLAYERS], iPlCount, pGamer, iOrigin[3], TeamName:iTeam = get_member(pPlayer, m_iTeam);
	get_players(pPlayers, iPlCount, "ache", (iTeam == TEAM_CT) ? "CT" : "TERRORIST");

	for(new i; i < iPlCount; i++) {
		pGamer = pPlayers[i];

		if(pGamer == pPlayer) {
			continue;
		}

		get_user_origin(pGamer, iOrigin, Origin_Client);

		message_begin(MSG_ONE, g_msgRadar, _, pPlayer);
		write_byte(pGamer);
		write_coord(iOrigin[0]);
		write_coord(iOrigin[1]);
		write_coord(iOrigin[2]);
		message_end();
	}

	if(iTeam != TEAM_TERRORIST || get_member_game(m_bBombDropped)) {
		return;
	}

	if(!IsBombPlanted()) {
		message_begin(MSG_ONE, g_msgBombPickup, _, pPlayer);
		message_end();
	}
}

bool:IsBombPlanted() {
	new pEnt;

	while((pEnt = rg_find_ent_by_class(pEnt, "grenade"))) {
		if(get_member(pEnt, m_Grenade_bIsC4)) {
			return true;
		}
	}

	return false;
}

bool:CheckAlivePlayersRules() {
	if(!g_eCvar[CVAR__BLOCK_DUEL] && !g_eCvar[CVAR__BLOCK_LAST_TEAMMATE] && !g_eCvar[CVAR__MIN_PLAYERS]) {
		return true;
	}

	new iAliveTT, iAliveCT, iDeadTT, iDeadCT;
	rg_initialize_player_counts(iAliveTT, iAliveCT, iDeadTT, iDeadCT);

	if(g_eCvar[CVAR__MIN_PLAYERS] && iAliveTT + iAliveCT + iDeadTT + iDeadCT < g_eCvar[CVAR__MIN_PLAYERS]) {
		return false;
	}

	if(g_eCvar[CVAR__BLOCK_DUEL] && iAliveTT <= 1 && iAliveCT <= 1) {
		return false;
	}

	if(g_eCvar[CVAR__BLOCK_LAST_TEAMMATE] && (iAliveTT <= 1 || iAliveCT <= 1)) {
		return false;
	}

	return true;
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