/*
	This plugin is designed to control players with high ping/loss

	Данный плагин предназначен для контроля игроков с высоким пингом/потерями
*/

/* Requirements:
	* AMXX 1.9.0 or above
	* ReAPI
*/

/* Changelog:
	1.0 (22.12.2022) by mx?!:
		* First release
*/

new const PLUGIN_VERSION[] = "1.0"

#include amxmodx
#include reapi

// Create cvar config in 'configs/plugins' and run it?
//
// Создавать конфиг с кварами в 'configs/plugins', и запускать его?
#define AUTO_CFG

enum _:CVAR_ENUM {
	Float:CVAR_F__CHECK_INTERVAL,
	CVAR__WARN_PING,
	CVAR__WARN_LOSS,
	CVAR__MAX_WARNS,
	CVAR__BAN_MINS,
	CVAR__NOTICE_PUNISH,
	CVAR__IMMUNITY_FLAG[32]
}

new g_eCvar[CVAR_ENUM], g_iWarns[MAX_PLAYERS + 1]

public plugin_init() {
	register_plugin("Ping Control", PLUGIN_VERSION, "mx?!")
	register_dictionary("ping_control.txt")

	func_RegCvars()

	set_task(4.0, "func_SetTask")
}

func_RegCvars() {
	bind_cvar_float( "ping_time_check", "10",
		.has_min = true, .min_val = 1.0,
		.desc = "Интервал между проверками (в секундах)",
		.bind = g_eCvar[CVAR_F__CHECK_INTERVAL]
	);

	bind_cvar_num( "ping_warn_ping", "120",
		.desc = "Если пинг игрока # или выше, игрок получает предупреждение",
		.bind = g_eCvar[CVAR__WARN_PING]
	);

	bind_cvar_num( "ping_warn_loss", "25",
		.desc = "Если потери пакетов игрока # или выше, игрок получает предупреждение",
		.bind = g_eCvar[CVAR__WARN_LOSS]
	);

	bind_cvar_num( "ping_max_warns", "3",
		.has_min = true, .min_val = 0.0,
		.desc = "Через сколько предупреждений игрок будет наказан",
		.bind = g_eCvar[CVAR__MAX_WARNS]
	);

	bind_cvar_num( "ping_ban_mins", "1",
		.has_min = true, .min_val = 0.0,
		.desc = "На сколько минут банить игрока (0 - кикать)",
		.bind = g_eCvar[CVAR__BAN_MINS]
	);

	bind_cvar_num( "ping_notice_punish", "1",
		.has_min = true, .min_val = 0.0,
		.has_max = true, .max_val = 1.0,
		.desc = "Включить оповещение в чат о наказании игрока",
		.bind = g_eCvar[CVAR__NOTICE_PUNISH]
	);

	bind_cvar_string( "ping_immunity_flag", "y",
		.desc = "Флаги иммунитета к наказанию (требуется любой из; ^"^" - выкл.)",
		.bind = g_eCvar[CVAR__IMMUNITY_FLAG], .maxlen = charsmax(g_eCvar[CVAR__IMMUNITY_FLAG])
	);

#if defined AUTO_CFG
	AutoExecConfig(/*.name = "PluginName"*/)
#endif
}

public func_SetTask() {
	set_task(g_eCvar[CVAR_F__CHECK_INTERVAL], "task_Check")
}

public task_Check() {
	func_SetTask()

	new pPlayers[MAX_PLAYERS], iPlCount, pPlayer, bitImmunity = read_flags(g_eCvar[CVAR__IMMUNITY_FLAG])
	get_players(pPlayers, iPlCount, "ch")

	for(new i, iPing, iLoss; i < iPlCount; i++) {
		pPlayer = pPlayers[i]

		if(get_user_flags(pPlayer) & bitImmunity) {
			continue
		}

		get_user_ping(pPlayer, iPing, iLoss)

		if(iPing < g_eCvar[CVAR__WARN_PING] && iLoss < g_eCvar[CVAR__WARN_LOSS]) {
			if(g_iWarns[pPlayer]) {
				g_iWarns[pPlayer]--
			}

			continue
		}

		if(++g_iWarns[pPlayer] < g_eCvar[CVAR__MAX_WARNS]) {
			continue
		}

		if(g_eCvar[CVAR__NOTICE_PUNISH]) {
			client_print_color(0, pPlayer, "%L", LANG_PLAYER, "PC__KICK_ALL", pPlayer)
		}

		if(g_eCvar[CVAR__BAN_MINS]) {
			new szIP[MAX_IP_LENGTH]
			get_user_ip(pPlayer, szIP, charsmax(szIP), .without_port = 1)
			set_task(1.0, "task_BanIP", g_eCvar[CVAR__BAN_MINS], szIP, sizeof(szIP))
		}

		server_cmd("kick #%i ^"%L^"", get_user_userid(pPlayer), pPlayer, "PC__KICK_INFO")
	}
}

public task_BanIP(const szIP[], iBanMins) {
	server_cmd("addip %i %s", iBanMins, szIP)
}

public client_connect(pPlayer) {
	g_iWarns[pPlayer] = 0
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