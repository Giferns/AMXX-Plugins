/*
	This plugin is designed to block the movement of the player using the duck bind on the mouse wheel

	Данный плагин предназначен для блокировки передвижения игрока с использованием бинда приседания на колесо мыши
*/

// NOTE: Based on 'Anti DD Scroll' version '1.0 Fixed' by Empower
// https://c-s.net.ua/forum/topic85081.html?view=findpost&p=982144

/* Requirements:
	* AMXX 1.9.0 or above
	* ReAPI
*/

/* Changelog:
	1.0 (28.10.2022) by mx?!:
		* First release
*/

new const PLUGIN_VERSION[] = "1.0"

#include <amxmodx>
#include <reapi>

/* -------------------- */

// Count of warns before punishing (player will be stopped)
// Will be set at first plugin load, then you can use cvar 'bdds_max_dd_warns'
// Set to 0 to punish player at first DD move
// Set to 1 to give ability to make only one DD move (second will be punished)
// Set above than 1 to give ability to make # DD moves
//
// Кол-во предупреждений до наказания (наказанием является остановка игрока)
// Устанавливается при первом запуске плагина, далее можно использовать квар 'bdds_max_dd_warns'
// Значение 0 наказывает игрока сразу (без предупреждений)
// Значение 1 позволяет сделать один DD без предупреждений, потом наказывает
// Значение > 1 выводит предупреждения позволяя сделать указанное кол-во DD
new const MAX_DD_WARNS[] = "3"

// Inverval between two DD moves to increase warn counter
// Will be set at first plugin load, then you can use cvar 'bdds_warn_time'
//
// Интервал между двумя DD (в секундах), в пределах которого начисляются предупреждения
// Устанавливается при первом запуске плагина, далее можно использовать квар 'bdds_warn_time'
new const WARN_TIME[] = "1.0"

/* -------------------- */

new bool:g_bAlive[MAX_PLAYERS + 1], g_iMaxWarns, Float:g_fWarnTime

public plugin_init() {
	register_plugin("Block DD Spam", PLUGIN_VERSION, "mx?!")

	register_dictionary("block_dd_spam.txt")

	bind_pcvar_num(create_cvar("bdds_max_dd_warns", MAX_DD_WARNS), g_iMaxWarns)
	bind_pcvar_float(create_cvar("bdds_warn_time", WARN_TIME), g_fWarnTime)

	RegisterHookChain(RG_PM_Move, "PM_Move_Post", true)
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true)
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", true)
}

public PM_Move_Post(pPlayer) {
	static bool:bLastStand[MAX_PLAYERS + 1], Float:fDuckStartTime[MAX_PLAYERS + 1]
	static Float:fNextDuckTime[MAX_PLAYERS + 1], Float:fLastWarnTime[MAX_PLAYERS + 1], iDuckWarns[MAX_PLAYERS + 1]

	if(!g_bAlive[pPlayer]) {
		return
	}

	if(get_pmove(pm_bInDuck)) {
		if(bLastStand[pPlayer] && (get_pmove(pm_flags) & FL_ONGROUND)) {
			fDuckStartTime[pPlayer] = get_gametime()
			bLastStand[pPlayer] = false
		}

		return
	}

	if(!bLastStand[pPlayer]) {
		new Float:fGameTime = get_gametime()

		// 0.018 doesn't work properly with fps_max 60, 0.050 is enough for fps_max 40
		if(fGameTime - fDuckStartTime[pPlayer] < 0.050) {
			if(g_iMaxWarns < 1) {
				func_PunishPlayer(pPlayer)
			}
			else {
				if(fGameTime < fNextDuckTime[pPlayer]) {
					if(fGameTime - fLastWarnTime[pPlayer] > 0.15) {
						fLastWarnTime[pPlayer] = fGameTime

						if(++iDuckWarns[pPlayer] >= g_iMaxWarns) {
							func_PunishPlayer(pPlayer)
						}
						else {
							client_print(pPlayer, print_center, "%l", "BDDS__WARN", iDuckWarns[pPlayer], g_iMaxWarns)
						}
					}
				}
				else {
					iDuckWarns[pPlayer] = 0
					fLastWarnTime[pPlayer] = fGameTime
				}

				fNextDuckTime[pPlayer] = fGameTime + g_fWarnTime
			}
		}
	}

	bLastStand[pPlayer] = true
}

func_PunishPlayer(pPlayer) {
	new Float:fVelocity[3]
	get_pmove(pm_velocity, fVelocity)
	fVelocity[0] = fVelocity[1] = 0.0
	set_pmove(pm_velocity, fVelocity)
	client_print(pPlayer, print_center, "%l", "BDDS__DONT_SPAM")
}

public CBasePlayer_Spawn_Post(pPlayer) {
	if(is_user_alive(pPlayer)) {
		g_bAlive[pPlayer] = true
	}
}

public CBasePlayer_Killed_Post(pVictim, pKiller, iGib) {
	g_bAlive[pVictim] = false
}

public client_disconnected(pPlayer) {
	g_bAlive[pPlayer] = false
}