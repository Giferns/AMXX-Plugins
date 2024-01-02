#include <amxmodx>
#include <reapi>

public plugin_init() {
	register_plugin("Unlimited Change Team", "1.0", "mx?!")

	register_clcmd("chooseteam", "clcmd_ChooseTeam")
}

public clcmd_ChooseTeam(id) {
	if(is_user_connected(id)) {
		set_member(id, m_bTeamChanged, false)
	}

	return PLUGIN_CONTINUE
}