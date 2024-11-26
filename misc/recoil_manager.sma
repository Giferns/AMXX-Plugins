/*
	[26.11.2024 by mx?!] 1.0.1f на базе оригинала 1.0.0:
		* Настройки отдачи выведены в авто-конфиг 'amxmodx/configs/plugins/recoil_manager.cfg'
		* Косметические изменения логики
*/

new const PLUGIN_VERSION[] = "1.0.1f";

#pragma semicolon 1

#include <amxmodx>
#include <hamsandwich>
#include <reapi>

// Создавать и запускать авто-конфиг в 'amxmodx/configs/plugins' ?
// Закомментировать для отключения
#define AUTO_CFG "recoil_manager"

new const Float:WEAPONS_RECOIL[CSW_LAST_WEAPON + 1] =
{
	1.0, // WEAPON_NONE
	1.0, // WEAPON_P228
	1.0, // WEAPON_GLOCK
	1.0, // WEAPON_SCOUT
	1.0, // WEAPON_HEGRENADE
	1.0, // WEAPON_XM1014
	1.0, // WEAPON_C4
	1.0, // WEAPON_MAC10
	1.0, // WEAPON_AUG
	1.0, // WEAPON_SMOKEGRENADE
	1.0, // WEAPON_ELITE
	1.0, // WEAPON_FIVESEVEN
	1.0, // WEAPON_UMP45
	1.0, // WEAPON_SG550
	1.0, // WEAPON_GALIL
	1.0, // WEAPON_FAMAS
	1.0, // WEAPON_USP
	1.0, // WEAPON_GLOCK18
	1.0, // WEAPON_AWP
	1.0, // WEAPON_MP5N
	1.0, // WEAPON_M249
	1.0, // WEAPON_M3
	1.0, // WEAPON_M4A1
	1.0, // WEAPON_TMP
	1.0, // WEAPON_G3SG1
	1.0, // WEAPON_FLASHBANG
	1.0, // WEAPON_DEAGLE
	1.0, // WEAPON_SG552
	1.0, // WEAPON_AK47
	1.0, // WEAPON_KNIFE
	1.0 // WEAPON_P90
};

new Float:g_fCvars[ sizeof(WEAPONS_RECOIL) ];

public plugin_init()
{
	register_plugin("recoil_manager", PLUGIN_VERSION, "fl0wer");

	new weaponName[24];

	for (new i = CSW_NONE + 1; i <= CSW_LAST_WEAPON ; i++)
	{
		if ((1<<i) & ((1<<2) | (1<<CSW_KNIFE) | (1<<CSW_HEGRENADE) | (1<<CSW_FLASHBANG) | (1<<CSW_SMOKEGRENADE) | (1<<CSW_C4)))
			continue;

		rg_get_weapon_info(WeaponIdType:i, WI_NAME, weaponName, charsmax(weaponName));
		
		bind_pcvar_float( create_cvar( fmt("rm_%s", weaponName), fmt("%f", WEAPONS_RECOIL[i]) ), g_fCvars[i] );
		
		RegisterHam(Ham_Weapon_PrimaryAttack, weaponName, "@CBasePlayerWeapon_PrimaryAttack_Post", true);
	}
	
	AutoExecConfig(.name = AUTO_CFG);
}

@CBasePlayerWeapon_PrimaryAttack_Post(id)
{
	new weaponId = get_member(id, m_iId);

	if (g_fCvars[weaponId] == 1.0)
		return;

	new player = get_member(id, m_pPlayer);

	new Float:vecPunchAngle[3];
	get_entvar(player, var_punchangle, vecPunchAngle);

	for (new i = 0; i < 3; i++)
		vecPunchAngle[i] *= g_fCvars[weaponId];

	set_entvar(player, var_punchangle, vecPunchAngle);
}