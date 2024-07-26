#include <amxmodx>
#include <reapi>
#include <hamsandwich>

#define AWP_SWITCH_DELAY	0.75
#define SCOUT_SWITCH_DELAY	0.75

new bool:gbFastZoom[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin("Fast Sniper Switch", "1.3.1", "Numb");

	register_clcmd("say /fz", "CmdFastZoom");
	register_clcmd("say_team /fz", "CmdFastZoom");

	RegisterHam(Ham_Item_Deploy, "weapon_awp",   "Ham_Item_Deploy_Post", 1);
	RegisterHam(Ham_Item_Deploy, "weapon_scout", "Ham_Item_Deploy_Post", 1);
}

public client_putinserver(id)
{
	if(!(get_user_flags(id) & ADMIN_LEVEL_H))
		return;

	new szFZ[3];
	if(get_user_info(id, "fz", szFZ, charsmax(szFZ)))
		gbFastZoom[id] = str_to_num(szFZ) ? true : false;
	else	gbFastZoom[id] = true;
}

public CmdFastZoom(id)
{
	if(!(get_user_flags(id) & ADMIN_LEVEL_H))
		return;

	gbFastZoom[id] = !gbFastZoom[id];
	client_print_color(id, print_team_default, "^4• ^1Режим 'Fast Sniper' : ^3%s", gbFastZoom[id] ? "Включено" : "Выключено");

	set_user_info(id, "fz", gbFastZoom[id] ? "1" : "0");
	client_cmd(id, "setinfo ^"fz^" ^"%s^"", gbFastZoom[id] ? "1" : "0");
}

public Ham_Item_Deploy_Post(iEnt)
{
	if(is_nullent(iEnt))
		return;

	new iPlrId = get_member(iEnt, m_pPlayer);

	if(!is_user_alive(iPlrId) || !(get_user_flags(iPlrId) & ADMIN_LEVEL_H) || !gbFastZoom[iPlrId] || iEnt != get_member(iPlrId, m_pActiveItem) || get_member(iEnt, m_Weapon_flDecreaseShotsFired) != get_gametime())
		return;

	switch(get_member(iEnt, m_iId))
	{
		case CSW_AWP:
		{
			set_member(iEnt, m_Weapon_flNextPrimaryAttack, AWP_SWITCH_DELAY);
			set_member(iEnt, m_Weapon_flNextSecondaryAttack, AWP_SWITCH_DELAY);
			set_member(iPlrId, m_flNextAttack, AWP_SWITCH_DELAY);
		}
		case CSW_SCOUT:
		{
			set_member(iEnt, m_Weapon_flNextPrimaryAttack, SCOUT_SWITCH_DELAY);
			set_member(iEnt, m_Weapon_flNextSecondaryAttack, SCOUT_SWITCH_DELAY);
			set_member(iPlrId, m_flNextAttack, SCOUT_SWITCH_DELAY);
		}
	}
}