#include <amxmodx>

#if AMXX_VERSION_NUM < 183
	#include <colorchat>
#endif

#define ROUND	60

new current_round;

public plugin_init()
{
	register_plugin("ONLY DUST2", "0.1", "");
	
	register_clcmd("say nextmap", "ClientCommand_NextMap");
	register_clcmd("say timeleft", "ClientCommand_TimeLeft");

	register_event("HLTV", "Event_RoundStart", "a", "1=0", "2=0");
}
	
public Event_RoundStart()
{
	current_round++;
	if(current_round == ROUND - 1)
		client_print_color(0, print_team_default, "В следующем раунде будет рестарт карты");

	if(current_round >= ROUND)
	{
		server_cmd("changelevel de_dust2_2x2");
		current_round = 0;
	}
}

public ClientCommand_NextMap(id)
{
	if(is_user_connected(id))
		client_print_color(id, print_team_default, "На сервере играют только на Dust2");
}

public ClientCommand_TimeLeft(id)
{
	if(is_user_connected(id))
	{
		if(current_round == ROUND - 1)
			client_print_color(id, print_team_default, "В следующем раунде будет рестарт карты");
		else client_print_color(id, print_team_default, "Раундов осталось: %d", ROUND - current_round);
	}
}