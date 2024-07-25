#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#define NAME		"BLOCK PLANT ROUND END"
#define VERSION	"1.2"
#define AUTHOR	"Albertio"

new HamHook:g_pHook_Weapon_PrimaryAttack;

const m_pPlayer = 41; // CBasePlayer *
stock m_flNextPrimaryAttack = 46; // float
stock m_pActiveItem = 373 // CBasePlayerItem *
stock m_iId = 43 // int

public plugin_init()
{
	register_plugin(NAME, VERSION, AUTHOR);

	register_dictionary("block_plant_round_end.txt");

	if((engfunc(EngFunc_FindEntityByString, FM_NULLENT, "classname", "info_bomb_target") > 0) || (engfunc(EngFunc_FindEntityByString, FM_NULLENT, "classname", "func_bomb_target") > 0))
	{
		DisableHamForward((g_pHook_Weapon_PrimaryAttack = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_c4", "C4_PrimaryAttack_Pre")));

		register_event("HLTV", "event_start_round", "a", "1=0", "2=0")
		register_logevent("logevent_round_end",2,"1=Round_End");
	}
}

public C4_PrimaryAttack_Pre(const pItem)
{
	if(!pev_valid(pItem))
		return HAM_IGNORED;

	new pPlayer = get_pdata_cbase(pItem, m_pPlayer, 4);

	if(pev_valid(pPlayer)) {
		set_pdata_float(pItem, m_flNextPrimaryAttack, 1.0, 4);
		client_print(pPlayer, print_center, "%l", "BRT__CANT_PLANT_END_ROUND");
	}

	return HAM_SUPERCEDE;
}

public event_start_round()
{
	DisableHamForward(g_pHook_Weapon_PrimaryAttack);
}

public logevent_round_end()
{
	EnableHamForward(g_pHook_Weapon_PrimaryAttack);

	new pPlayers[MAX_PLAYERS], iPlCount, pWeapon;
	get_players(pPlayers, iPlCount, "ae", "TERRORIST");
	for(new i; i < iPlCount; i++) {
		pWeapon = get_pdata_cbase(pPlayers[i], m_pActiveItem, 5);

		if(pWeapon > 0 && pev_valid(pWeapon) == 2 && get_pdata_int(pWeapon, m_iId, 4) == CSW_C4 && get_ent_data(pWeapon, "CC4", "m_bStartedArming")) {
			ExecuteHamB(Ham_Weapon_RetireWeapon, pWeapon);
		}
	}
}