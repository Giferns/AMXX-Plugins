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

	1.1 (14.01.2023) by mx?!:
		* Added cvars 'ping_dec_ping_warns', 'ping_warn_fluctuation', 'ping_max_fluctuation_warns', 'ping_dec_fluctuation_warns', 'ping_average_count'

	1.2 (23.01.2023) by mx?!:
		* Added cvar 'ping_ema_mode' (thx to wopox1337)
*/

new const PLUGIN_VERSION[] = "1.2"

#include amxmodx
#include reapi

// Create cvar config in 'configs/plugins' and run it?
//
// Создавать конфиг с кварами в 'configs/plugins', и запускать его?
#define AUTO_CFG

// Minimal ping tests count for EMA mode (cvar 'ping_ema_mode')
//
// Минимальное кол-во тестов для режима средней скользящей (квар 'ping_ema_mode')
#define MIN_EMA_TESTS 3

enum _:CVAR_ENUM {
	Float:CVAR_F__CHECK_INTERVAL,
	CVAR__WARN_PING,
	CVAR__WARN_LOSS,
	CVAR__MAX_WARNS,
	CVAR__BAN_MINS,
	CVAR__NOTICE_PUNISH,
	CVAR__IMMUNITY_FLAG[32],
	CVAR__DEC_PING_WARNS,
	CVAR__WARN_FLUCTUATION,
	CVAR__MAX_FLUCTUATION_WARNS,
	CVAR__DEC_FLUCTUATION_WARNS,
	CVAR__AVERAGE_COUNT,
	CVAR__EMA_MODE
}

new g_eCvar[CVAR_ENUM], g_iPingWarns[MAX_PLAYERS + 1], g_iPingSum[MAX_PLAYERS + 1], g_iPingTests[MAX_PLAYERS + 1]
new g_iLastPing[MAX_PLAYERS + 1], g_iFluctuationWarns[MAX_PLAYERS + 1], g_iDecFluctCounter[MAX_PLAYERS + 1]
new g_iDecPingCounter[MAX_PLAYERS + 1], Float:g_fPlayerPingEMA[MAX_PLAYERS + 1]

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
		.has_min = true, .min_val = 1.0,
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

	bind_cvar_string( "ping_immunity_flag", "",
		.desc = "Флаги иммунитета к наказанию (требуется любой из; ^"^" - выкл.)",
		.bind = g_eCvar[CVAR__IMMUNITY_FLAG], .maxlen = charsmax(g_eCvar[CVAR__IMMUNITY_FLAG])
	);

	bind_cvar_num( "ping_dec_ping_warns", "6",
		.desc = "Уменьшать счётчик предупреждений ping/loss каждые # успешных проверок игрока (0 - не уменьшать)",
		.bind = g_eCvar[CVAR__DEC_PING_WARNS]
	);

	bind_cvar_num( "ping_warn_fluctuation", "60",
		.desc = "Если скачок пинга игрока # или выше, игрок получает предупреждение",
		.bind = g_eCvar[CVAR__WARN_FLUCTUATION]
	);

	bind_cvar_num( "ping_max_fluctuation_warns", "5",
		.has_min = true, .min_val = 0.0,
		.desc = "Через сколько предупреждений игрок будет наказан (0 - выкл.)",
		.bind = g_eCvar[CVAR__MAX_FLUCTUATION_WARNS]
	);

	bind_cvar_num( "ping_dec_fluctuation_warns", "6",
		.desc = "Уменьшать счётчик скачков пинга каждые # успешных проверок игрока (0 - не уменьшать)",
		.bind = g_eCvar[CVAR__DEC_FLUCTUATION_WARNS]
	);

	bind_cvar_num( "ping_average_count", "0",
		.desc = "Режим подсчёта по среднему пингу (как у h1k3). # - кол-во проверок до начала расчёта (0 - выкл.)",
		.bind = g_eCvar[CVAR__AVERAGE_COUNT]
	);

	// https://gist.github.com/wopox1337/41b7f97e49f3fceb707fba1031edb7d6
	// https://ru.wikipedia.org/wiki/%D0%A1%D0%BA%D0%BE%D0%BB%D1%8C%D0%B7%D1%8F%D1%89%D0%B0%D1%8F_%D1%81%D1%80%D0%B5%D0%B4%D0%BD%D1%8F%D1%8F
	// https://youtu.be/3-4CwYfphXc
	bind_cvar_num( "ping_ema_mode", "0",
		.desc = "Использовать среднее скользящее для сглаживания скачков при расчёте пинга?",
		.bind = g_eCvar[CVAR__EMA_MODE]
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

		g_iPingTests[pPlayer]++

		GetUserPing(pPlayer, iPing, iLoss)

		if(CheckPing(pPlayer, iPing, iLoss) || CheckFluctuation(pPlayer, iPing)) {
			PunishPlayer(pPlayer)
		}
	}
}

GetUserPing(pPlayer, &iPing, &iLoss) {
	get_user_ping(pPlayer, iPing, iLoss)

	if(!g_eCvar[CVAR__EMA_MODE]) {
		return
	}

	static Float:fAlpha

	fAlpha = 2.0 / g_iPingTests[pPlayer]
	g_fPlayerPingEMA[pPlayer] = (fAlpha * iPing) + (1.0 - fAlpha) * g_fPlayerPingEMA[pPlayer]

	if(g_iPingTests[pPlayer] < MIN_EMA_TESTS) {
		iPing = 0
		return
	}

	iPing = floatround(g_fPlayerPingEMA[pPlayer])
}

bool:CheckPing(pPlayer, iPing, iLoss) {
	if(g_eCvar[CVAR__AVERAGE_COUNT]) {
		return CheckAveragePing(pPlayer, iPing, iLoss)
	}

	return CheckInstantPing(pPlayer, iPing, iLoss)
}

bool:CheckAveragePing(pPlayer, iPing, iLoss) {
	g_iPingSum[pPlayer] += iPing

	if(g_iPingTests[pPlayer] >= g_eCvar[CVAR__AVERAGE_COUNT]) {
		if(g_eCvar[CVAR__EMA_MODE]) {
			if(iPing >= g_eCvar[CVAR__WARN_PING]) {
				return true
			}
		}
		else if(g_iPingSum[pPlayer] / g_iPingTests[pPlayer] >= g_eCvar[CVAR__WARN_PING]) {
			return true
		}
	}

	if(iLoss < g_eCvar[CVAR__WARN_LOSS]) {
		DecrementPingWarns(pPlayer)
		return false
	}

	return (++g_iPingWarns[pPlayer] >= g_eCvar[CVAR__MAX_WARNS])
}

bool:CheckInstantPing(pPlayer, iPing, iLoss) {
	if(iPing < g_eCvar[CVAR__WARN_PING] && iLoss < g_eCvar[CVAR__WARN_LOSS]) {
		DecrementPingWarns(pPlayer)
		return false
	}

	return (++g_iPingWarns[pPlayer] >= g_eCvar[CVAR__MAX_WARNS])
}

DecrementPingWarns(pPlayer) {
	if(g_iPingWarns[pPlayer] && g_eCvar[CVAR__DEC_PING_WARNS] && ++g_iDecPingCounter[pPlayer] >= g_eCvar[CVAR__DEC_PING_WARNS]) {
		g_iPingWarns[pPlayer]--
		g_iDecPingCounter[pPlayer] = 0
	}
}

bool:CheckFluctuation(pPlayer, iPing) {
	if(!g_eCvar[CVAR__MAX_FLUCTUATION_WARNS]) {
		return false
	}

	if(!g_iLastPing[pPlayer]) {
		g_iLastPing[pPlayer] = iPing
		return false
	}

	new iOldLastPing = g_iLastPing[pPlayer]
	g_iLastPing[pPlayer] = iPing

	if(abs(iOldLastPing - iPing) < g_eCvar[CVAR__WARN_FLUCTUATION]) {
		if(g_iFluctuationWarns[pPlayer] && g_eCvar[CVAR__DEC_FLUCTUATION_WARNS] && ++g_iDecFluctCounter[pPlayer] >= g_eCvar[CVAR__DEC_FLUCTUATION_WARNS]) {
			g_iFluctuationWarns[pPlayer]--
			g_iDecFluctCounter[pPlayer] = 0
		}

		return false
	}

	return (++g_iFluctuationWarns[pPlayer] >= g_eCvar[CVAR__MAX_FLUCTUATION_WARNS])
}

PunishPlayer(pPlayer) {
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

public task_BanIP(const szIP[], iBanMins) {
	server_cmd("addip %i %s", iBanMins, szIP)
}

public client_connect(pPlayer) {
	g_iPingWarns[pPlayer] = g_iPingSum[pPlayer] = g_iPingTests[pPlayer] = 0
	g_iLastPing[pPlayer] = g_iFluctuationWarns[pPlayer] = g_iDecFluctCounter[pPlayer] = 0
	g_iDecPingCounter[pPlayer] = 0
	g_fPlayerPingEMA[pPlayer] = 1.0
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