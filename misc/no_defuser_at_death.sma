#include amxmodx
#include reapi

new gmsgStatusIcon

public plugin_init() {
	register_plugin("No defuser at death", "1.1", "mx?!")
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Pre")

	gmsgStatusIcon = get_user_msgid("StatusIcon")
}

public CBasePlayer_Killed_Pre(pVictim) {
	if(is_user_connected(pVictim) && get_member(pVictim, m_bHasDefuser)) {
		set_member(pVictim, m_bHasDefuser, false)

		message_begin(MSG_ONE, gmsgStatusIcon, .player = pVictim)
		write_byte(0)
		write_string("defuser")
		message_end()
	}
}