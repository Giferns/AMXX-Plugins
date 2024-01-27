new const PLUGIN_VERSION[] = "1.0"

#include amxmodx
#include reapi

new Float:g_fSpeedModifier

public plugin_init() {
	register_plugin("Speed Modifier", PLUGIN_VERSION, "mx?!")

	bind_pcvar_float(create_cvar("speed_modifier", "1.30"), g_fSpeedModifier)

	RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed, "CBasePlayer_ResetMaxSpeed_Post", true)
}

public CBasePlayer_ResetMaxSpeed_Post(pPlayer) {
	if(!is_user_alive(pPlayer)) {
		return
	}

	new Float:fMaxSpeed = get_entvar(pPlayer, var_maxspeed)

	if(fMaxSpeed <= 1.0) {
		return
	}

	set_entvar(pPlayer, var_maxspeed, fMaxSpeed * g_fSpeedModifier)
}