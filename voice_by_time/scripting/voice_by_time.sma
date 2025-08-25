/*
	1.0 (25.08.2025 by mx?!):
		* First release
*/

new const PLUGIN_VERSION[] = "1.0"

#include amxmodx
#include reapi
#include nvault
#include time

// Создавать и загружать автоконфиг (amxmodx/configs/plugins) ? Закомментировать для отключения функции.
// Значение опции = имя конфига (без .cfg); можно задать "" для имени по умолчанию (plugin-%plugin_name%.cfg)
#define AUTO_CFG "voice_by_time"

// Игроки, не заходившие # дней, удаляются из хранилища. Закомментировать для отключения очистки.
#define PRUNE_DAYS 30

new const VAULT_NAME[] = "voice_by_time"

#define GetTime(%0) get_user_time(%0, .flag = 1)

enum _:CVAR_ENUM {
	CVAR__SECONDS_TO_SPEAK,
	CVAR__IMMUNITY_FLAG[32]
}

stock const SOUND__BLIP1[] = "sound/buttons/blip1.wav"
stock const SOUND__BLIP2[] = "sound/buttons/blip2.wav"
stock const SOUND__BELL1[] = "sound/buttons/bell1.wav"
stock const SOUND__ERROR[] = "sound/buttons/button2.wav"

new g_eCvar[CVAR_ENUM]
new g_hVault
new bool:g_bCanVoice[MAX_PLAYERS + 1]
new g_iTime[MAX_PLAYERS + 1]
new bool:g_bBot[MAX_PLAYERS + 1]
new bool:g_bHLTV[MAX_PLAYERS + 1]
new bool:g_bLoaded[MAX_PLAYERS + 1]

public plugin_precache() {
	register_plugin("[VTC] Voice By Time", PLUGIN_VERSION, "mx?!")
	register_dictionary("voice_by_time.txt")
	
	if(!has_vtc()) {
		set_fail_state("VTC not available!")
		return
	}
	
	RegisterHookChain(RG_CSGameRules_CanPlayerHearPlayer, "CSGameRules_CanPlayerHearPlayer_Pre")
}

public plugin_init() {	
	RegCvars()

	g_hVault = nvault_open(VAULT_NAME)
#if defined PRUNE_DAYS
	nvault_prune(g_hVault, 0, get_systime() - (PRUNE_DAYS * SECONDS_IN_DAY))
#endif	
}

RegCvars() {
	bind_pcvar_num( create_cvar( "vbt_seconds_to_speak", "300",
		.description = "Секунд в игре (без учёта спектров) для доступа к микрофону" ),
		g_eCvar[CVAR__SECONDS_TO_SPEAK]
	);
	
	bind_pcvar_string( create_cvar("vbt_immunity_flags", "d", .description = "Флаги иммунитета (требуется любой из)"),
		g_eCvar[CVAR__IMMUNITY_FLAG], charsmax(g_eCvar[CVAR__IMMUNITY_FLAG]) );
	
#if defined AUTO_CFG
	AutoExecConfig(.name = AUTO_CFG)
#endif
}

public client_putinserver(pPlayer) {
	g_bLoaded[pPlayer] = true
	
	if(is_user_hltv(pPlayer)) {
		g_bHLTV[pPlayer] = true
		return
	}

	if(is_user_bot(pPlayer)) {
		g_bCanVoice[pPlayer] = true
		g_bBot[pPlayer] = true
		return
	}
	
	new szAuthID[64]
	get_user_authid(pPlayer, szAuthID, charsmax(szAuthID))
	g_iTime[pPlayer] = nvault_get(g_hVault, szAuthID)
	
	g_bCanVoice[pPlayer] = ((g_iTime[pPlayer] + GetTime(pPlayer) >= g_eCvar[CVAR__SECONDS_TO_SPEAK]) || (get_user_flags(pPlayer) & read_flags(g_eCvar[CVAR__IMMUNITY_FLAG])))
}

public client_disconnected(pPlayer) {
	if(!g_bLoaded[pPlayer]) {
		return
	}
	
	g_bLoaded[pPlayer] = false
	g_bCanVoice[pPlayer] = false
	
	if(g_bBot[pPlayer] || g_bHLTV[pPlayer]) {
		g_bBot[pPlayer] = false
		g_bHLTV[pPlayer] = false
		return
	}
	
	new iTime = GetTime(pPlayer)
	
	if(iTime) {
		static szAuthID[64]
		get_user_authid(pPlayer, szAuthID, charsmax(szAuthID))
		nvault_set(g_hVault, szAuthID, fmt("%i", g_iTime[pPlayer] + iTime))
	}
	
	g_iTime[pPlayer] = 0
}

public VTC_OnClientStartSpeak(const pPlayer) {
	if(g_bCanVoice[pPlayer] || !g_bLoaded[pPlayer] || g_bHLTV[pPlayer]) {
		return
	}

	new iTime = g_iTime[pPlayer] + GetTime(pPlayer)
	
	if(iTime < g_eCvar[CVAR__SECONDS_TO_SPEAK] && !(get_user_flags(pPlayer) & read_flags(g_eCvar[CVAR__IMMUNITY_FLAG]))) {	
		static Float:fLastTime[MAX_PLAYERS + 1]
		new Float:fGameTime = get_gametime()
		
		if(fGameTime - fLastTime[pPlayer] > 1.0) {
			fLastTime[pPlayer] = fGameTime
			iTime = g_eCvar[CVAR__SECONDS_TO_SPEAK] - iTime
			rg_send_audio(pPlayer, SOUND__ERROR)
			client_print_color(pPlayer, print_team_red, "%l", "VBT__CHAT_UNAVAILABLE", iTime / 60, iTime % 60)
		}
		
		return
	}

	g_bCanVoice[pPlayer] = true
	rg_send_audio(pPlayer, SOUND__BELL1)
	client_print_color(pPlayer, print_team_default, "%l", "VBT__CHAT_ACCESS")
}

public CSGameRules_CanPlayerHearPlayer_Pre(pListener, pSender) {
	if(g_bCanVoice[pSender] || g_bBot[pSender]) {
		return HC_CONTINUE
	}
	
	if(g_bHLTV[pSender] || !g_bLoaded[pSender]) {
		SetHookChainReturn(ATYPE_BOOL, false)
		return HC_BREAK
	}

	return HC_CONTINUE
}
