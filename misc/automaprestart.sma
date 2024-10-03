/*
	1.1:
		* get_mapname() changed to rh_get_mapname()
*/

#pragma semicolon 1

#include <amxmodx>
#include <reapi>

// Лимит раундов (счётчик НЕ сбрасывается при рестартах и game commencing)
const MAXROUNDS = 5;

public plugin_init() {
	register_plugin("AutoMapRestart", "1.1", "mx?!");

	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound", .post = true);
}

public CSGameRules_RestartRound(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay) {
	static iRoundsPlayed;
	
	iRoundsPlayed++;
	
	if(iRoundsPlayed == MAXROUNDS) {
		set_task(1.0, "task_ChangeLevel");
		return;
	}

	client_print_color(0, print_team_red, "^4* ^1Текущий раунд: ^3%i^4/^3%i", iRoundsPlayed, MAXROUNDS);
}

public task_ChangeLevel() {
	new szMapName[64];
	rh_get_mapname(szMapName, charsmax(szMapName), MNT_TRUE);
	server_cmd("changelevel %s", szMapName);
}