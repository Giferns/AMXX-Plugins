/*
	2.0 (08.02.2026 by mx?!):
		* Первая версия
*/

#include <amxmodx>
#include <amxmisc>
#include <reapi>

new const PLUGIN_VERSION[] = "2.0"

// Путь до файла конфигурации. Закомментировать для отключения.
new const CFG_FILENAME[] = "plugins/voice_control.cfg"

stock const SOUND__BLIP1[] = "sound/buttons/blip1.wav"
stock const SOUND__BLIP2[] = "sound/buttons/blip2.wav"
stock const SOUND__BELL1[] = "sound/buttons/bell1.wav"
stock const SOUND__ERROR[] = "sound/buttons/button2.wav"

// csstats.inc
native get_user_stats(index, stats[STATSX_MAX_STATS], bodyhits[MAX_BODYHITS]);

// CSstatsX SQL by serfreeman1337
native get_user_stats_sql(index, stats[8], bodyhits[8])

// CsStats MySQL by SKAJIbnEJIb
//
// Получает статистику игрока по id.
// Возвратит место в статистике, или ошибку
native csstats_get_user_stats(id, stats[22])

// AES [fork 0.5.9]
/**
* Returns current player level
*
* @param player			player id
*
* @return				current player level or -1 if player not tracked yet
*/
native aes_get_player_level(player);
/**
* Returns level name for level num.
*
* @param level			level number
* @param level[]		Buffer to copy level name output to
* @param len			Maximum size of buffer
* @param idLang			language id
*
* @return 				len
*/
native aes_get_level_name(level,level_name[],len,idLang = LANG_SERVER);

// Army Ranks Ultimate by SKAJIbnEJIb
//
// Возвратит уровень игрока и название звания
native ar_get_user_level(id, string[] = "", len = 0)
// Возвратит название уровня из его номера.
native ar_get_levelname(level, string[], len)

enum {
	CAN_SPEAK_NO,
	CAN_SPEAK_AUTH,
	CAN_SPEAK_YES
}

enum ( <<= 1 ) {
	BLOCK__VOICE = 1,
	BLOCK__TEXT
}

enum _:PCVAR_ENUM {
	PCVAR__BLOCK_MODE,
	PCVAR__IMMUNITY_FLAGS
}

enum _:CVAR_ENUM {
	CVAR__STATS_MODE,
	CVAR__BLOCK_MODE,
	CVAR__TARGET_VALUE,
	CVAR__IMMUNITY_FLAGS,
	Float:CVAR_F__INIT_DELAY,
	CVAR__USE_SOUNDS
}

new g_pCvar[PCVAR_ENUM]
new g_eCvar[CVAR_ENUM]
new g_iCanSpeak[MAX_PLAYERS + 1]
new HookChain:g_hCanPlayerHearPlayer

public plugin_precache() {
	register_plugin("Voice Control", PLUGIN_VERSION, "mx?!")
	register_dictionary("voice_control.txt")
	
	g_hCanPlayerHearPlayer = RegisterHookChain(RG_CSGameRules_CanPlayerHearPlayer, "CSGameRules_CanPlayerHearPlayer_Pre")
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true)

	register_clcmd("say", "clcmd_Say")
	register_clcmd("say_team", "clcmd_Say")

	RegCvars()
#if defined CFG_FILENAME
	new szPath[240]
	get_configsdir(szPath, charsmax(szPath))
	server_cmd("exec %s/%s", szPath, CFG_FILENAME)
#endif
}

RegCvars() {
	new pCvar, szValue[32]

	bind_pcvar_num(create_cvar("vc_stats_mode", "1"), g_eCvar[CVAR__STATS_MODE])

	pCvar = create_cvar("vc_block_mode", "ab")
	hook_cvar_change(pCvar, "hook_CvarChange")
	get_pcvar_string(pCvar, szValue, charsmax(szValue))
	g_eCvar[CVAR__BLOCK_MODE] = read_flags(szValue)
	g_pCvar[PCVAR__BLOCK_MODE] = pCvar
	if( !(g_eCvar[CVAR__BLOCK_MODE] & BLOCK__VOICE) ) {
		DisableHookChain(g_hCanPlayerHearPlayer)
	}
	
	bind_pcvar_num(create_cvar("vc_target_value", "10"), g_eCvar[CVAR__TARGET_VALUE])
	
	pCvar = create_cvar("vc_immunity_flags", "dt")
	hook_cvar_change(pCvar, "hook_CvarChange")
	get_pcvar_string(pCvar, szValue, charsmax(szValue))
	g_eCvar[CVAR__IMMUNITY_FLAGS] = read_flags(szValue)
	g_pCvar[PCVAR__IMMUNITY_FLAGS] = pCvar
	
	bind_pcvar_float(create_cvar("vc_init_delay", "1.0"), g_eCvar[CVAR_F__INIT_DELAY])
	
	bind_pcvar_num(create_cvar("vc_use_sounds", "1"), g_eCvar[CVAR__USE_SOUNDS])
}

public hook_CvarChange(pCvar, const szOldVal[], const szNewVal[]) {
	if(pCvar == g_pCvar[PCVAR__BLOCK_MODE]) {	
		g_eCvar[CVAR__BLOCK_MODE] = read_flags(szNewVal)
			
		if(g_eCvar[CVAR__BLOCK_MODE] & BLOCK__VOICE) {
			EnableHookChain(g_hCanPlayerHearPlayer)
		}
		else {
			DisableHookChain(g_hCanPlayerHearPlayer)
		}
		
		return
	}
	
	if(pCvar == g_pCvar[PCVAR__IMMUNITY_FLAGS]) {
		g_eCvar[CVAR__IMMUNITY_FLAGS] = read_flags(szNewVal)
		return
	}
}

public client_connect(pPlayer) {
	g_iCanSpeak[pPlayer] = CAN_SPEAK_AUTH
}

public client_putinserver(pPlayer) {
	set_task(g_eCvar[CVAR_F__INIT_DELAY], "task_InitPlayer", pPlayer)
}

public client_disconnected(pPlayer) {
	remove_task(pPlayer)
}

public task_InitPlayer(pPlayer) {
	if(is_user_connected(pPlayer)) {
		g_iCanSpeak[pPlayer] = CanPlayerSpeak(pPlayer) ? CAN_SPEAK_YES : CAN_SPEAK_NO;
	}
}

bool:CanPlayerSpeak(pPlayer) {
	return (!g_eCvar[CVAR__STATS_MODE] || !g_eCvar[CVAR__BLOCK_MODE] || GetPlayerValue(pPlayer) >= g_eCvar[CVAR__TARGET_VALUE] || HaveImmunity(pPlayer))
}

HaveImmunity(pPlayer) {
	return (get_user_flags(pPlayer) & g_eCvar[CVAR__IMMUNITY_FLAGS])
}

// Режим работы со статистикой
// 0 - Выключено (плагин бездействует)
// 1 - Фраги из CSX (стандартная статистика Amx Mod X)
// 2 - Фраги из CSStatsX SQL by serfreeman1337
// 3 - Фраги из CsStats MySQL by SKAJIbnEJIb
// 4 - Звания из AES [fork 0.5.9]
// 5 - Звания из Army Ranks Ultimate by SKAJIbnEJIb
GetPlayerValue(pPlayer) {
	switch(g_eCvar[CVAR__STATS_MODE]) {
		case 1: {
			new stats[STATSX_MAX_STATS], bodyhits[MAX_BODYHITS]
			get_user_stats(pPlayer, stats, bodyhits)
			return stats[0]
		}
		case 2: {
			new stats[STATSX_MAX_STATS], bodyhits[MAX_BODYHITS]
			get_user_stats_sql(pPlayer, stats, bodyhits)
			return stats[0]
		}
		case 3: {
			new stats[22]
			csstats_get_user_stats(pPlayer, stats)
			return stats[0]
		}
		case 4: {
			return aes_get_player_level(pPlayer)
		}
		case 5: {
			return ar_get_user_level(pPlayer)
		}
	}
	
	return 0
}

public CBasePlayer_Spawn_Post(pPlayer) {
	if(g_iCanSpeak[pPlayer] == CAN_SPEAK_NO) {
		CheckCondition(pPlayer, .bSilentUnlock = false, .bShowRemaining = false)
	}
}

bool:CheckCondition(pPlayer, bool:bSilentUnlock, bool:bShowRemaining) {
	if(CanPlayerSpeak(pPlayer)) {
		g_iCanSpeak[pPlayer] = CAN_SPEAK_YES

		if(!bSilentUnlock) {
			SendAudio(pPlayer, SOUND__BLIP2)
			SendUnlockMsg(pPlayer)
		}

		return true
	}
	
	if(bShowRemaining) {
		ShowRemaining(pPlayer)
	}

	return false
}

// Режим работы со статистикой
// 0 - Выключено (плагин бездействует)
// 1 - Фраги из CSX (стандартная статистика Amx Mod X)
// 2 - Фраги из CSStatsX SQL by serfreeman1337
// 3 - Фраги из CsStats MySQL by SKAJIbnEJIb
// 4 - Звания из AES [fork 0.5.9]
// 5 - Звания из Army Ranks Ultimate by SKAJIbnEJIb
ShowRemaining(pPlayer) {
	SendAudio(pPlayer, SOUND__ERROR)

	new iPlayerValue = GetPlayerValue(pPlayer)

	switch(g_eCvar[CVAR__STATS_MODE]) {
		case 1, 2, 3: {
			new szNeed[32], iNeed = g_eCvar[CVAR__TARGET_VALUE] - iPlayerValue
			func_GetEnding(iNeed, "VC__FRAGS_1", "VC__FRAGS_2", "VC__FRAGS_3", szNeed, charsmax(szNeed))
			client_print_color(pPlayer, print_team_red, "%l", "VC__FRAGS_REMAINING", iNeed, szNeed)
		}
		case 4: {
			new szPlayerLevel[64], szNeededLevel[64]
			aes_get_level_name(iPlayerValue, szPlayerLevel, charsmax(szPlayerLevel), pPlayer)
			aes_get_level_name(g_eCvar[CVAR__TARGET_VALUE], szNeededLevel, charsmax(szNeededLevel), pPlayer)
			client_print_color(pPlayer, print_team_red, "%l", "VC__NEEDED_LEVEL", szNeededLevel, g_eCvar[CVAR__TARGET_VALUE], szPlayerLevel, iPlayerValue)
		}
		case 5: {
			new szPlayerLevel[64], szNeededLevel[64]
			ar_get_levelname(iPlayerValue, szPlayerLevel, charsmax(szPlayerLevel))
			ar_get_levelname(g_eCvar[CVAR__TARGET_VALUE], szNeededLevel, charsmax(szNeededLevel))
			client_print_color(pPlayer, print_team_red, "%l", "VC__NEEDED_LEVEL", szNeededLevel, g_eCvar[CVAR__TARGET_VALUE], szPlayerLevel, iPlayerValue)
		}
	}
}

SendAudio(pPlayer, const szSound[]) {
	if(g_eCvar[CVAR__USE_SOUNDS]) {
		rg_send_audio(pPlayer, szSound)
	}
}

SendUnlockMsg(pPlayer) {
	if(g_eCvar[CVAR__BLOCK_MODE] & (BLOCK__TEXT|BLOCK__VOICE) == (BLOCK__TEXT|BLOCK__VOICE)) {
		client_print_color(pPlayer, print_team_default, "%l", "VC__VOICE_TEXT_UNLOCK")
		return
	}
	
	if(g_eCvar[CVAR__BLOCK_MODE] & BLOCK__VOICE) {
		client_print_color(pPlayer, print_team_default, "%l", "VC__VOICE_UNLOCK")
		return
	}
	
	if(g_eCvar[CVAR__BLOCK_MODE] & BLOCK__TEXT) {
		client_print_color(pPlayer, print_team_default, "%l", "VC__TEXT_UNLOCK")
		return
	}
}

stock func_GetEnding(iValue, const szA[], const szB[], const szC[], szBuffer[], iMaxLen) {
	new iValue100 = iValue % 100, iValue10 = iValue % 10;

	if(iValue100 >= 5 && iValue100 <= 20 || iValue10 == 0 || iValue10 >= 5 && iValue10 <= 9) {
		copy(szBuffer, iMaxLen, szA)
		return
	}

	if(iValue10 == 1) {
		copy(szBuffer, iMaxLen, szB)
		return
	}

	/*if(iValue10 >= 2 && iValue10 <= 4) {
		copy(szBuffer, iMaxLen, szC)
	}*/

	copy(szBuffer, iMaxLen, szC)
}

public clcmd_Say(pPlayer) {
	if(g_iCanSpeak[pPlayer] == CAN_SPEAK_YES || !(g_eCvar[CVAR__BLOCK_MODE] & BLOCK__TEXT)) {
		return PLUGIN_CONTINUE
	}

	new szBuffer[64]
	read_args(szBuffer, charsmax(szBuffer))
	remove_quotes(szBuffer)

	if(szBuffer[0] == '/') {
		return PLUGIN_HANDLED_MAIN
	}

	switch(g_iCanSpeak[pPlayer]) {
		case CAN_SPEAK_AUTH: {
			return PLUGIN_HANDLED
		}
		case CAN_SPEAK_NO: {
			if(!CheckCondition(pPlayer, .bSilentUnlock = true, .bShowRemaining = true)) {
				return PLUGIN_HANDLED
			}
		}
	}

	return PLUGIN_CONTINUE
}

public CSGameRules_CanPlayerHearPlayer_Pre(const listener, const sender) {
	if(g_iCanSpeak[sender] != CAN_SPEAK_YES) {
		SetHookChainReturn(ATYPE_BOOL, false)
		return HC_SUPERCEDE
	}

	return HC_CONTINUE
}

public VTC_OnClientStartSpeak(const pPlayer) {
	if(g_iCanSpeak[pPlayer] == CAN_SPEAK_NO && (g_eCvar[CVAR__BLOCK_MODE] & BLOCK__VOICE)) {
		CheckCondition(pPlayer, .bSilentUnlock = true, .bShowRemaining = true)
	}	
}

public plugin_natives() {
	set_native_filter("native_filter")
}

// trap        - 0 if native couldn't be found, 1 if native use was attempted
public native_filter(const szNativeName[], iNativeID, iTrapMode) {
	if(iTrapMode) { // native use was attempted
		if(task_exists(1337)) {
			return PLUGIN_HANDLED
		}
		
		set_task(0.1, "task_FailState", 1337, szNativeName, strlen(szNativeName))
	}
	
	return PLUGIN_HANDLED
}

public task_FailState(szNativeName[], iTaskId) {
	set_fail_state("Can't use native '%s'", szNativeName)
}
