/*
	1.0 (02.01.2024)
		* Первая версия
	1.1 (02.01.2024)
		* Добавлена опция ACCESS_FLAG
*/

new const PLUGIN_VERSION[] = "1.1"

#include <amxmodx>
#include <reapi>

const ACCESS_FLAG = ADMIN_BAN

public plugin_init() {
	register_plugin("Unlimited Change Team", PLUGIN_VERSION, "mx?!")

	register_clcmd("chooseteam", "clcmd_ChooseTeam")
}

public clcmd_ChooseTeam(id) {
	if(is_user_connected(id) && (get_user_flags(id) & ACCESS_FLAG)) {
		set_member(id, m_bTeamChanged, false)
	}

	return PLUGIN_CONTINUE
}