new const PLUGIN_VERSION[] = "1.0"

// Перечислить буквы amxx-флагов, при наличии любого из которых игрок получает
//		при первом спавне в раунде щипцы и броню
new const VIP_FLAGS[] = "d"

#include amxmodx
#include reapi

new g_bitVipFlags, g_bBombScenario

public plugin_init() {
	register_plugin("VIP Equipment", PLUGIN_VERSION, "mx?!")

	g_bitVipFlags = read_flags(VIP_FLAGS)

	g_bBombScenario = (get_member_game(m_bMapHasBombTarget) || get_member_game(m_bMapHasBombZone))

	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true)
}

public CBasePlayer_Spawn_Post(pPlayer) {
	if(!is_user_alive(pPlayer) || !(get_user_flags(pPlayer) & g_bitVipFlags) || get_member(pPlayer, m_iNumSpawns) > 1) {
		return
	}

	rg_set_user_armor(pPlayer, 100, ARMOR_VESTHELM)

	if(g_bBombScenario && get_member(pPlayer, m_iTeam) == TEAM_CT) {
		rg_give_defusekit(pPlayer)
	}
}