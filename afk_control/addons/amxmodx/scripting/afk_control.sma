/*
	This plugin is designed to control AFK players

	Данный плагин предназначен для контроля AFK-игроков
*/

/* Requirements:
	* AMXX 1.9.0 or above
	* ReAPI
*/

/* Changelog:
	1.0 (20.12.2022) by mx?!:
		* First release
	1.1 (17.05.2025) by mx?!:
		* Added support for ECD Helper ( https://fungun.net/shop/?p=show&id=150 )
*/

new const PLUGIN_VERSION[] = "1.1"

#include amxmodx
#include amxmisc
#include reapi
#include xs
#include time

// Create cvar config in 'configs/plugins' and run it?
//
// Создавать конфиг с кварами в 'configs/plugins', и запускать его?
#define AUTO_CFG

// Support for ECD Helper. Comment to disable.
//
// Поддержка плагина ECD Helper. Закомментировать для отключения.
#define ECD_HELPER_SUPPORT

// DHUD Settings https://dev-cs.ru/hud/index.html
//
// DHUD Настройки https://dev-cs.ru/hud/index.html
#define DHUD_SETTINGS 0, 255, 0, -1.0, 0.3, 0, 0.0, 3.0, 0.1, 0.3

#define CheckBit(%0,%1) (%0 & (1 << %1))
#define SetBit(%0,%1) (%0 |= (1 << %1))
#define ClearBit(%0,%1) (%0 &= ~(1 << %1))

#define IsInGame(%0) (TEAM_SPECTATOR > get_member(%0, m_iTeam) > TEAM_UNASSIGNED)

stock const SOUND__TUTOR_MSG[] = "sound/events/tutor_msg.wav"

const MENU_KEYS = MENU_KEY_1

new const MENU_IDENT_STRING[] = "AfkMenu"

const TASKID__RESET_SKIP = 1337
const TASKID__DELAY_TRANSFER = 1338

#if defined ECD_HELPER_SUPPORT
	/**
	 * Вернет 1 если игрок проходит сканирование на данный момент
	 * Используйте этот натив в плагинах AFK, чтобы добавить проверку, и не кикать игроков
	 *
	 * @param player				player
	 * @return						1 or 0
	 */
	native ecd_is_scanning(player);
#endif

enum _:CVAR_ENUM {
	Float:CVAR_F__CHECK_INTERVAL,
	Float:CVAR_F__WARN_TIME,
	CVAR__WARN_TO_WARN,
	CVAR__WARNS_TO_TRANSFER_C4,
	CVAR__C4_TRANSFER_MODE,
	CVAR__MAX_WARNS,
	CVAR__MAX_KILLED_WARNS,
	CVAR__FREE_SLOTS_TO_KICK_SPEC,
	CVAR__NOTICE_SPEC,
	CVAR__NOTICE_KICK,
	CVAR__SPEC_TRANSFER_FLAG[32],
	CVAR__SPECTATOR_TIME_FLAG[32],
	CVAR__MAX_SPEC_TIME_DEFAULT,
	CVAR__MAX_SPEC_TIME_FLAG,
	CVAR__MENU_TIME,
	Float:CVAR_F__TIME_SKIP_CHECK,
	Float:CVAR_F__MAXSPEED
}

new g_eCvar[CVAR_ENUM], Float:g_fConnectTime[MAX_PLAYERS + 1], Float:g_fSpecStartTime[MAX_PLAYERS + 1]
new g_iMenuID, g_szMenu[MAX_MENU_LENGTH], g_iMaxPlayers
new g_iTimerWarns[MAX_PLAYERS + 1], g_iKilledWarns[MAX_PLAYERS + 1], g_bitPlToSkip, g_bitChecked, bool:g_bOnGround[MAX_PLAYERS + 1]
new g_iSpawnOrigin[MAX_PLAYERS + 1][3]

public plugin_init() {
	register_plugin("AFK Control", PLUGIN_VERSION, "mx?!")
	register_dictionary("afk_control.txt")

	func_RegCvars()

	g_iMaxPlayers = get_maxplayers()

	RegisterHookChain(RG_CBasePlayer_GetIntoGame, "CBasePlayer_GetIntoGame_Post", true)
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Pre", true)
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Pre")
	RegisterHookChain(RG_CBasePlayer_StartObserver, "CBasePlayer_StartObserver_Post", true)
	RegisterHookChain(RG_HandleMenu_ChooseTeam, "HandleMenu_ChooseTeam_Post", true)

	g_iMenuID = register_menuid(MENU_IDENT_STRING)
	register_menucmd(g_iMenuID, MENU_KEYS, "func_Menu_Handler")

	set_task(3.5, "func_SetTask")
}

func_RegCvars() {
	bind_cvar_float( "afk_time_check", "10",
		.has_min = true, .min_val = 1.0,
		.desc = "Интервал между проверками (в секундах)",
		.bind = g_eCvar[CVAR_F__CHECK_INTERVAL]
	);

	bind_cvar_float( "afk_warn_time", "10",
		.has_min = true, .min_val = 1.0,
		.desc = "Если игрок не двигается # секунд, это считается за AFK",
		.bind = g_eCvar[CVAR_F__WARN_TIME]
	);

	bind_cvar_num( "afk_warn_to_warn", "2",
		.has_min = true, .min_val = 0.0,
		.desc = "На каком # предупреждения за AFK отправить игроку предупреждение о наказании? (0 - не предупреждать)",
		.bind = g_eCvar[CVAR__WARN_TO_WARN]
	);

	bind_cvar_num( "afk_max_warns", "3",
		.has_min = true, .min_val = 0.0,
		.desc = "Через сколько предупреждений по таймеру игрок будет переведён в зрители",
		.bind = g_eCvar[CVAR__MAX_WARNS]
	);

	bind_cvar_num( "afk_max_killed_warns", "3",
		.has_min = true, .min_val = 0.0,
		.desc = "Сколько раз нужно умереть на точке спавна для того, чтобы произошло наказание за AFK (0 - выкл.)",
		.bind = g_eCvar[CVAR__MAX_KILLED_WARNS]
	);

	bind_cvar_num( "afk_warns_to_transfer_c4", "2",
		.has_min = true, .min_val = 0.0,
		.desc = "Через сколько предупреждений передавать бомбу ближайшему тиммейту (0 - не передавать)",
		.bind = g_eCvar[CVAR__WARNS_TO_TRANSFER_C4]
	);

	bind_cvar_num( "afk_c4_transfer_mode", "1",
		.has_min = true, .min_val = 0.0,
		.has_max = true, .max_val = 1.0,
		.desc = "Режим передачи бомбы^n\
		0 - Выбросить^n\
		1 - Передать ближайшему тиммейту",
		.bind = g_eCvar[CVAR__C4_TRANSFER_MODE]
	);

	bind_cvar_num( "afk_free_slots_to_kick_spec", "3",
		.has_min = true, .min_val = -1.0,
		.has_max = true, .max_val = 32.0,
		.desc = "Когда на сервере остаётся # или менее свободных слотов, плагин будет пытаться кикать зрителей",
		.bind = g_eCvar[CVAR__FREE_SLOTS_TO_KICK_SPEC]
	);

	bind_cvar_num( "afk_notice_spec", "1",
		.has_min = true, .min_val = 0.0,
		.has_max = true, .max_val = 1.0,
		.desc = "Включить оповещение в чат о переводе игрока за наблюдателей",
		.bind = g_eCvar[CVAR__NOTICE_SPEC]
	);

	bind_cvar_num( "afk_notice_kick", "1",
		.has_min = true, .min_val = 0.0,
		.has_max = true, .max_val = 1.0,
		.desc = "Включить оповещение в чат о кике с сервера",
		.bind = g_eCvar[CVAR__NOTICE_KICK]
	);

	bind_cvar_string( "afk_spec_transfer_flag", "abcdefghijklmnopqrstuvwxyz",
		.desc = "Флаг, при наличии которого AFK-игрок сначала переводится в зрители (иначе кикается) (^"^" - кикать всех)",
		.bind = g_eCvar[CVAR__SPEC_TRANSFER_FLAG],
		.maxlen = charsmax(g_eCvar[CVAR__SPEC_TRANSFER_FLAG])
	);

	bind_cvar_string( "afk_spectator_time_flag", "",
		.desc = "Флаг доступа для логики квара afk_max_spec_time_flag (^"^" - выкл.)",
		.bind = g_eCvar[CVAR__SPECTATOR_TIME_FLAG],
		.maxlen = charsmax(g_eCvar[CVAR__SPECTATOR_TIME_FLAG])
	);

	bind_cvar_num( "afk_max_spec_time_default", "60",
		.has_min = true, .min_val = 0.0,
		.desc = "Сколько секунд зритель без afk_spectator_time_flag может быть AFK до запроса активности (0 - без запроса)",
		.bind = g_eCvar[CVAR__MAX_SPEC_TIME_DEFAULT]
	);

	bind_cvar_num( "afk_max_spec_time_flag", "300",
		.has_min = true, .min_val = 0.0,
		.desc = "Сколько секунд зритель с afk_spectator_time_flag может быть AFK до запроса активности (0 - без запроса)",
		.bind = g_eCvar[CVAR__MAX_SPEC_TIME_FLAG]
	);

	bind_cvar_num( "afk_menu_time", "15",
		.desc = "Сколько секунд даётся игроку на ответ на запрос активности (меню 'вы здесь?')",
		.bind = g_eCvar[CVAR__MENU_TIME]
	);

	bind_cvar_float( "afk_time_skip_check", "20",
		.has_min = true, .min_val = 0.0,
		.desc = "Сколько секунд давать игроку на выбор команды после захода на сервер, до того, как начнётся проверка зрителя",
		.bind = g_eCvar[CVAR_F__TIME_SKIP_CHECK]
	);

	bind_pcvar_float(get_cvar_pointer("sv_maxspeed"), g_eCvar[CVAR_F__MAXSPEED])

#if defined AUTO_CFG
	AutoExecConfig(/*.name = "PluginName"*/)
#endif
}

public func_SetTask() {
	set_task(g_eCvar[CVAR_F__CHECK_INTERVAL], "task_Check")
}

public task_Check() {
	func_SetTask()

	new iAliveTT, iAliveCT, iDeadTT, iDeadCT, bool:bKicked
	rg_initialize_player_counts(iAliveTT, iAliveCT, iDeadTT, iDeadCT)
	new iInGame = iAliveTT + iAliveCT + iDeadTT + iDeadCT

	new pPlayers[MAX_PLAYERS], iPlCount
	get_players(pPlayers, iPlCount)

	if(iInGame > 1) {
		bKicked = CheckAllAlivePlayersForAfk(pPlayers, iPlCount)
	}

	if(bKicked || g_iMaxPlayers - iPlCount > g_eCvar[CVAR__FREE_SLOTS_TO_KICK_SPEC]) {
		return
	}

	CheckAllSpectatorsForAfk(pPlayers, iPlCount)
}

bool:CheckAllAlivePlayersForAfk(const pPlayers[MAX_PLAYERS], iPlCount) {
	if(g_eCvar[CVAR_F__MAXSPEED] <= 2.0) {
		return false
	}

	new bool:bKicked, Float:fGameTime = get_gametime()

	for(new i; i < iPlCount; i++) {
		if(CheckPlayerForAfk(pPlayers[i], fGameTime)) {
			bKicked = true
		}
	}

	g_bitChecked = 0

	return bKicked
}

CheckAllSpectatorsForAfk(const pPlayers[MAX_PLAYERS], iPlCount) {
	new pPlayer, pPlayerToKick, Float:fAfkTime, Float:fMostTime = -1.0, Float:fGameTime = get_gametime()
	new bitSpecFlags = read_flags(g_eCvar[CVAR__SPECTATOR_TIME_FLAG])
	new iMaxSpecTime

	for(new i; i < iPlCount; i++) {
		pPlayer = pPlayers[i]

		if(
			CheckBit(g_bitPlToSkip, pPlayer)
				||
			is_user_bot(pPlayer)
				||
			is_user_hltv(pPlayer)
				||
			is_user_alive(pPlayer)
				||
			IsInGameEx(pPlayer)
				||
			IsPlayerJustConnected(pPlayer, fGameTime)
		) {
			continue
		}
		
	#if defined ECD_HELPER_SUPPORT
		if(ecd_is_scanning(pPlayer)) {
			continue
		}
	#endif

		iMaxSpecTime = g_eCvar[ (get_user_flags(pPlayer) & bitSpecFlags) ? CVAR__MAX_SPEC_TIME_FLAG : CVAR__MAX_SPEC_TIME_DEFAULT ];

		if(!iMaxSpecTime) {
			fAfkTime = fGameTime - g_fSpecStartTime[pPlayer]

			if(fAfkTime > fMostTime) {
				fMostTime = fAfkTime
				pPlayerToKick = pPlayer
			}
		}
		else {
			new iAfkTime = floatround(fGameTime - Float:get_member(pPlayer, m_fLastMovement))

			new iMenuID, iKeys
			get_user_menu(pPlayer, iMenuID, iKeys)

			if(iMenuID == g_iMenuID) {
				if(iAfkTime >= g_eCvar[CVAR__MENU_TIME]) {
					pPlayerToKick = pPlayer
					break
				}
			}
			else {
				if(iAfkTime < iMaxSpecTime) {
					continue
				}

				set_member(pPlayer, m_fLastMovement, get_gametime())

				formatex( g_szMenu, charsmax(g_szMenu),
					"%L", pPlayer, "AFK__ARE_YOU_THERE" );

				show_menu(pPlayer, MENU_KEYS, g_szMenu, -1, MENU_IDENT_STRING)
			}
		}
	}

	if(pPlayerToKick) {
		KickPlayer(pPlayerToKick, "AFK__SPEC_AFK")
	}
}

public func_Menu_Handler(pPlayer, iKey) {
	if(is_user_connected(pPlayer)) {
		set_member(pPlayer, m_fLastMovement, get_gametime())
	}

	return PLUGIN_HANDLED
}

bool:IsPlayerJustConnected(pPlayer, Float:fGameTime) {
	return (
		//!IsInGame(pPlayer)
		get_member(pPlayer, m_iTeam) == TEAM_UNASSIGNED
			&&
		fGameTime - g_fConnectTime[pPlayer] < g_eCvar[CVAR_F__TIME_SKIP_CHECK]
	);
}

bool:CheckPlayerForAfk(pPlayer, Float:fGameTime) {
	SetBit(g_bitChecked, pPlayer)

	if(!is_user_alive(pPlayer) || is_user_bot(pPlayer) || CheckBit(g_bitPlToSkip, pPlayer)) {
		return false
	}

	if(!IsPlayerAfk(pPlayer, fGameTime, true)) {
		g_iTimerWarns[pPlayer] = 0
		return false
	}

	g_iTimerWarns[pPlayer]++

	if(g_iTimerWarns[pPlayer] >= g_eCvar[CVAR__WARNS_TO_TRANSFER_C4]) {
		TryTransferC4(pPlayer)
	}

	if(g_eCvar[CVAR__WARN_TO_WARN] && g_iTimerWarns[pPlayer] == min(g_eCvar[CVAR__WARN_TO_WARN], g_eCvar[CVAR__MAX_WARNS] - 1)) {
		rg_send_audio(pPlayer, SOUND__TUTOR_MSG)
		client_print(pPlayer, print_center, "%l", "AFK__WARN_CENTER")
		client_print_color(pPlayer, print_team_red, "%l", "AFK__WARN_CHAT")
		return false
	}

	if(g_iTimerWarns[pPlayer] >= g_eCvar[CVAR__MAX_WARNS]) {
		TryTransferC4(pPlayer)
		return func_PunishForAFK(pPlayer)
	}

	return false
}

KickPlayer(pPlayer, const szLangKey[]) {
	SetSkip(pPlayer)

	if(g_eCvar[CVAR__NOTICE_KICK]) {
		client_print_color(0, pPlayer, "%L", LANG_PLAYER, "AFK__KICK_AFK_ALL", pPlayer)
	}

	server_cmd("kick #%i ^"%L^"", get_user_userid(pPlayer), pPlayer, szLangKey)
}

bool:IsPlayerAfk(pPlayer, Float:fGameTime, bool:bWriteOldAngle) {
	static Float:fOldViewAngle[MAX_PLAYERS + 1][3]

	static Float:fViewAngle[3], bool:bSameAngle
	get_entvar(pPlayer, var_v_angle, fViewAngle)

	// https://github.com/s1lentq/ReGameDLL_CS/blob/a20362389e7fe5e3fdd1a6befcc854e1f6c8caff/regamedll/dlls/API/CSPlayer.cpp#L521
	bSameAngle = (floatabs(fOldViewAngle[pPlayer][1] - fViewAngle[1]) < 0.1)

	if(bWriteOldAngle) {
		xs_vec_copy(fViewAngle, fOldViewAngle[pPlayer])
	}

	return (
		bSameAngle
			&&
		fGameTime - Float:get_member(pPlayer, m_fLastMovement) >= g_eCvar[CVAR_F__WARN_TIME]
			&&
		Float:get_entvar(pPlayer, var_maxspeed) > 2.0
	);
}

TryTransferC4(pPlayer) {
	if(!get_member(pPlayer, m_bHasC4)) {
		return
	}

	if(!g_eCvar[CVAR__C4_TRANSFER_MODE] || !g_eCvar[CVAR__WARNS_TO_TRANSFER_C4]) {
		rg_drop_item(pPlayer, "weapon_c4")
		return
	}

	new pPlayers[MAX_PLAYERS], iPlCount, pNewBomber, pTarget
	new Float:fPlayerOrigin[3], Float:fTargetOrigin[3], Float:fGameTime = get_gametime()
	new Float:fShortestDist = 999999.0

	get_entvar(pPlayer, var_origin, fPlayerOrigin)
	get_players(pPlayers, iPlCount, "ae", "TERRORIST")

	for(new i, Float:fDist; i < iPlCount; i++) {
		pTarget = pPlayers[i]

		if(pTarget == pPlayer || CheckBit(g_bitPlToSkip, pTarget)) {
			continue
		}

		if(CheckBit(g_bitChecked, pTarget)) {
			if(g_iTimerWarns[pTarget] > 0 || g_iKilledWarns[pTarget] > 0) {
				continue
			}
		}
		else if(IsPlayerAfk(pTarget, fGameTime, false)) {
			continue
		}

		get_entvar(pTarget, var_origin, fTargetOrigin)
		fDist = vector_distance(fPlayerOrigin, fTargetOrigin)

		if(fDist < fShortestDist) {
			fShortestDist = fDist
			pNewBomber = pTarget
		}
	}

	if(!pNewBomber || !rg_transfer_c4(pPlayer, pNewBomber)) {
		rg_drop_item(pPlayer, "weapon_c4")
	}
	else {
		set_dhudmessage(DHUD_SETTINGS)
		show_dhudmessage(pNewBomber, "%l", "AFK__YOU_GOT_BOMB")

		for(new i; i < iPlCount; i++) {
			pTarget = pPlayers[i]

			if(pTarget != pNewBomber) {
				client_print(pTarget, print_center, "%l", "AFK__BOMB_TRANSFERED_TO", pNewBomber)
			}
		}
	}
}

public CBasePlayer_GetIntoGame_Post(pPlayer) {
	g_iTimerWarns[pPlayer] = 0
	g_iKilledWarns[pPlayer] = 0
}

public CBasePlayer_Spawn_Pre(pPlayer) {
	g_bOnGround[pPlayer] = false
	remove_task(pPlayer)
	set_task(0.1, "task_GetOrigin", pPlayer, .flags = "b")
}

public task_GetOrigin(pPlayer) {
	if(!is_user_alive(pPlayer)) {
		remove_task(pPlayer)
		return
	}

	if( !(get_entvar(pPlayer, var_flags) & FL_ONGROUND) ) {
		return
	}

	g_bOnGround[pPlayer] = true
	remove_task(pPlayer)
	get_user_origin(pPlayer, g_iSpawnOrigin[pPlayer], Origin_Client)
}

public CBasePlayer_Killed_Pre(pVictim, pKiller, iGibType) {
	if(!g_eCvar[CVAR__MAX_KILLED_WARNS] || is_user_bot(pVictim) || !g_bOnGround[pVictim] || CheckBit(g_bitPlToSkip, pVictim)) {
		return
	}

	new iOrigin[3]
	get_user_origin(pVictim, iOrigin, Origin_Client)

	if(
		IsIntCoordsNearlyEqual(iOrigin[0], g_iSpawnOrigin[pVictim][0])
			&&
		IsIntCoordsNearlyEqual(iOrigin[1], g_iSpawnOrigin[pVictim][1])
			&&
		IsIntCoordsNearlyEqual(iOrigin[2], g_iSpawnOrigin[pVictim][2])
	) {
		if(++g_iKilledWarns[pVictim] >= g_eCvar[CVAR__MAX_KILLED_WARNS]) {
			remove_task(pVictim + TASKID__RESET_SKIP)
			SetBit(g_bitPlToSkip, pVictim)
			set_task(0.1, "task_DelayTransfer", TASKID__DELAY_TRANSFER + get_user_userid(pVictim))
		}

		return
	}

	g_iKilledWarns[pVictim] = 0
}

stock bool:IsIntCoordsNearlyEqual(iCoord1, iCoord2) {
	const FLEQ_TOLERANCE = 10

	return xs_abs(iCoord1 - iCoord2) <= FLEQ_TOLERANCE

	/*if(iCoord1 == iCoord2) {
		return true
	}

	if(iCoord1 > iCoord2) {
		return _abs(iCoord1 - iCoord2) <= FLEQ_TOLERANCE
	}

	//if iCoord1 < iCoord2
	return _abs(iCoord2 - iCoord1) <= FLEQ_TOLERANCE*/
}

public task_DelayTransfer(iUserId) {
	new pPlayer = find_player("k", iUserId - TASKID__DELAY_TRANSFER)

	if(pPlayer) {
		ClearBit(g_bitPlToSkip, pPlayer)
		func_PunishForAFK(pPlayer)
	}
}

SetSkip(pPlayer) {
	remove_task(pPlayer + TASKID__RESET_SKIP)
	SetBit(g_bitPlToSkip, pPlayer)
	set_task(0.1, "ResetSkip", pPlayer + TASKID__RESET_SKIP)
}

public ResetSkip(pPlayer) {
	pPlayer -= TASKID__RESET_SKIP;
	ClearBit(g_bitPlToSkip, pPlayer)
}

bool:func_PunishForAFK(pPlayer) {
	if(get_user_flags(pPlayer) & read_flags(g_eCvar[CVAR__SPEC_TRANSFER_FLAG])) {
		if(IsInGame(pPlayer)) {
			func_MoveToSpec(pPlayer)
		}

		return false
	}

	KickPlayer(pPlayer, "AFK__KICK_AFK")
	return true
}

func_MoveToSpec(pPlayer) {
	g_iTimerWarns[pPlayer] = 0
	g_iKilledWarns[pPlayer] = 0

	SetSkip(pPlayer)

	if(g_eCvar[CVAR__NOTICE_SPEC]) {
		client_print_color(0, pPlayer, "%L", LANG_PLAYER, "AFK__TRANSFER_TO_SPEC_INFO", pPlayer)
	}

	if(is_user_alive(pPlayer)) {
		new Float:fFrags = get_entvar(pPlayer, var_frags)
		new iDeaths = get_member(pPlayer, m_iDeaths)
		user_kill(pPlayer, 0)
		set_member(pPlayer, m_iDeaths, iDeaths)
		set_entvar(pPlayer, var_frags, fFrags)
	}

	if(get_member(pPlayer,m_iMenu) == Menu_ChooseAppearance) {
		rg_internal_cmd(pPlayer, "joinclass", "5")
	}

	set_member(pPlayer, m_bTeamChanged, false)
	rg_internal_cmd(pPlayer, "jointeam", "6")
	set_member(pPlayer, m_bTeamChanged, false)
	amxclient_cmd(pPlayer, "chooseteam")
}

public client_putinserver(pPlayer) {
	g_fConnectTime[pPlayer] = g_fSpecStartTime[pPlayer] = get_gametime()
}

public CBasePlayer_StartObserver_Post(pPlayer) {
	g_fSpecStartTime[pPlayer] = get_gametime()
}

public HandleMenu_ChooseTeam_Post(pPlayer, MenuChooseTeam:iMenuSlot) {
	g_fSpecStartTime[pPlayer] = get_gametime()
}

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

stock bool:IsInGameEx(pPlayer) {
	return (
		(TEAM_SPECTATOR > get_member(pPlayer, m_iTeam) > TEAM_UNASSIGNED)
			&&
		get_member(pPlayer, m_iMenu) != Menu_ChooseAppearance
			&&
		get_member(pPlayer, m_iJoiningState) != PICKINGTEAM
	);
}