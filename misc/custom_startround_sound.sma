#include amxmodx
#include reapi

// Звуки без 'sound' в пути.
// Звук выбирается случайно каждый раунд. Можно добавлять и удалять.
new const SOUNDS[][] = {
	"buttons/bell1.wav",
	"buttons/button2.wav",
	"buttons/blip2.wav"
}

new HookChain:g_hRadio

public plugin_precache() {
	register_plugin("Custom StartRound Sound", "1.0", "mx?!")
	
	for(new i; i < sizeof(SOUNDS); i++) {
		precache_sound(SOUNDS[i])
	}
}

public plugin_init() {	
	RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "CSGameRules_OnRoundFreezeEnd_Pre")
	g_hRadio = RegisterHookChain(RG_CBasePlayer_Radio, "CBasePlayer_Radio_Pre")
	DisableHookChain(g_hRadio)
	RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "CSGameRules_OnRoundFreezeEnd_Post", true)
}

public CSGameRules_OnRoundFreezeEnd_Pre() {
	EnableHookChain(g_hRadio)
}

public CBasePlayer_Radio_Pre(const this, const msg_id[], const msg_verbose[], pitch, bool:showIcon) {
	//server_print("this %i msg_id %s, msg_verbose %s showIcon %i", this, msg_id, msg_verbose, showIcon)
	rg_send_audio(0, SOUNDS[ random_num(0, sizeof(SOUNDS) - 1) ])
	return HC_BREAK
}

public CSGameRules_OnRoundFreezeEnd_Post() {
	DisableHookChain(g_hRadio)
}
