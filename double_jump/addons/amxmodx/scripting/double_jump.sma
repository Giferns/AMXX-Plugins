#include <amxmodx>
#include <reapi>

new const PLUGIN_VERSION[] = "1.0"

// Default access value for cvar "dj_access". Set to "" to access for all.
new const DEFAULT_ACCESS[] = ""

// Jump sound. Comment to disable.
new const SOUND__MULTIJUMP[] = "dj/jumpjump.wav"

new g_bitAccess

#if defined SOUND__MULTIJUMP
	public plugin_precache() {
		precache_sound(SOUND__MULTIJUMP)
	}
#endif

public plugin_init() {
	register_plugin("Double Jump", PLUGIN_VERSION, "mx?!")
	
	new pCvar = create_cvar("dj_access", DEFAULT_ACCESS, .description = "Access to double jump. ^"^" - access for all.")
	new szValue[32]; get_pcvar_string(pCvar, szValue, charsmax(szValue))
	hook_CvarChange(pCvar, "", szValue)
	hook_cvar_change(pCvar, "hook_CvarChange")

	RegisterHookChain(RG_CBasePlayer_Jump, "OnPlayerJump_Pre")
}

public hook_CvarChange(pCvar, const szOldVal[], const szNewVal[]) {
	g_bitAccess = read_flags(szNewVal)
}

public OnPlayerJump_Pre(pPlayer) {
	if(g_bitAccess && !(get_user_flags(pPlayer) & g_bitAccess)) {
		return
	}

	static Float:fLastJumpTime[MAX_PLAYERS + 1], bool:bitJumped[MAX_PLAYERS + 1]

	if(get_entvar(pPlayer, var_flags) & FL_ONGROUND) {
		fLastJumpTime[pPlayer] = get_gametime()
		bitJumped[pPlayer] = false
		return
	}

	static Float:fGameTime

	if(
		( get_member(pPlayer, m_afButtonLast) & IN_JUMP )
			||
		bitJumped[pPlayer]
			||
		(((fGameTime = get_gametime()) - fLastJumpTime[pPlayer]) < 0.2)
	) {
		return
	}

	fLastJumpTime[pPlayer] = fGameTime
	new Float:fVelocity[3]
	get_entvar(pPlayer, var_velocity, fVelocity)
	fVelocity[2] = 268.0
	set_entvar(pPlayer, var_velocity, fVelocity)
	bitJumped[pPlayer] = true
#if defined SOUND__MULTIJUMP
	emit_sound(pPlayer, CHAN_STATIC, SOUND__MULTIJUMP, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
#endif
}
