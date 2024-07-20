#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#define NAME		"BLOCK PLANT ROUND END"
#define VERSION	"1.0"
#define AUTHOR	"Albertio"

#define BIT(%0)	(1<<(%0))

enum SignalState
{
    SIGNAL_BUY       = BIT(0),
    SIGNAL_BOMB      = BIT(1),
    SIGNAL_RESCUE    = BIT(2),
    SIGNAL_ESCAPE    = BIT(3),
    SIGNAL_VIPSAFETY = BIT(4),
};

new HamHook:g_pHook_Weapon_PrimaryAttack;

const m_pPlayer = 41; // CBasePlayer *
stock m_flNextPrimaryAttack = 46; // float

enum _:BombSpotTypes
{
	InfoBombTarget,
	FuncBombTarget
}

new const g_szClassNames[BombSpotTypes][] =
{
	"info_bomb_target",
	"func_bomb_target"
}

new bool:g_bBombZone[BombSpotTypes];

public plugin_init()
{
	register_plugin(NAME, VERSION, AUTHOR);

	register_dictionary("block_plant_round_end.txt");

	g_bBombZone[InfoBombTarget] = (engfunc(EngFunc_FindEntityByString, FM_NULLENT, "classname", g_szClassNames[InfoBombTarget]) > 0);
	g_bBombZone[FuncBombTarget] = (engfunc(EngFunc_FindEntityByString, FM_NULLENT, "classname", g_szClassNames[FuncBombTarget]) > 0);

	if(g_bBombZone[InfoBombTarget] || g_bBombZone[FuncBombTarget])
	{
		DisableHamForward((g_pHook_Weapon_PrimaryAttack = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_c4", "C4_PrimaryAttack_Post", true)));

		register_event("HLTV", "event_start_round", "a", "1=0", "2=0")
		register_logevent("logevent_round_end",2,"1=Round_End");
	}
}

public C4_PrimaryAttack_Post(const pItem)
{
	if(!pev_valid(pItem))
		return;

	new pPlayer = get_pdata_cbase(pItem, m_pPlayer, 4);

	if(pev_valid(pPlayer))
		client_print(pPlayer, print_center, "%l", "BRT__CANT_PLANT_END_ROUND");
}

public event_start_round()
{
	SetSolid(g_bBombZone[InfoBombTarget], g_szClassNames[InfoBombTarget], SOLID_TRIGGER);
	SetSolid(g_bBombZone[FuncBombTarget], g_szClassNames[FuncBombTarget], SOLID_TRIGGER);
	DisableHamForward(g_pHook_Weapon_PrimaryAttack);
}

SetSolid(bHave, const szClassName[], iSolid)
{
	if(!bHave) {
		return;
	}

	new pEnt = FM_NULLENT;

	while((pEnt = engfunc(EngFunc_FindEntityByString, pEnt, "classname", szClassName)) > 0)
	{
		set_pev(pEnt, pev_solid, iSolid);
	}
}

public logevent_round_end()
{
	SetSolid(g_bBombZone[InfoBombTarget], g_szClassNames[InfoBombTarget], SOLID_NOT);
	SetSolid(g_bBombZone[FuncBombTarget], g_szClassNames[FuncBombTarget], SOLID_NOT);
	EnableHamForward(g_pHook_Weapon_PrimaryAttack);
}

stock bool:fm_get_user_bombzone(const pPlayer)
{
	return bool:((get_pdata_int(pPlayer, 235) & _:SIGNAL_BOMB));
}