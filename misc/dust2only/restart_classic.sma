#include <amxmodx>
#include <reapi>

#define rg_get_current_round() (get_member_game(m_iTotalRoundsPlayed) + 1)

const RESTART_ROUND = 20;
const RESTART_ROUND_DELAY = 1;

public plugin_init()
{
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGRules_RestartRound_Post", .post = true);
}

public CSGRules_RestartRound_Post()
{
	if(rg_get_current_round() >= RESTART_ROUND)
	{
		rg_swap_all_players();
		server_cmd("sv_restartround %d", RESTART_ROUND_DELAY)
	}
	else
	{
		client_print_color(0, print_team_default, "^4* ^1Рестарт через ^4%d ^1раунд(а,ов)", RESTART_ROUND - rg_get_current_round());
	}
}