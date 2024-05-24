new const PLUGIN_VERSION[] = "1.0"

// Перечислить amxx-флаги доступа, при наличии которых при первом спавне выполняется перезарядка/пополнение запаса патронов
// Чтобы перезарядка/пополнение работало, требуется наличие любого из перечисленных флагов
new const VIP_FLAGS[] = "d"

#include amxmodx
#include reapi

new g_bitVipFlags

public plugin_init() {
	register_plugin("Refill Weapons at 1st Spawn", PLUGIN_VERSION, "mx?!")

	g_bitVipFlags = read_flags(VIP_FLAGS)

	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true)
}

public CBasePlayer_Spawn_Post(pPlayer) {
	if(!is_user_alive(pPlayer) || !(get_user_flags(pPlayer) & g_bitVipFlags) || get_member(pPlayer, m_iNumSpawns) > 1) {
		return
	}

	new iCSW, iAmmo, iBpAmmo

	for(new any:i = PRIMARY_WEAPON_SLOT, pItem; i <= PISTOL_SLOT; i++) {
		do {
			pItem = get_member(pPlayer, m_rgpPlayerItems, i)

			if(pItem < 1) {
				break
			}

			iCSW = get_member(pItem, m_iId)

			iAmmo = rg_get_iteminfo(pItem, ItemInfo_iMaxClip)
			iBpAmmo = rg_get_iteminfo(pItem, ItemInfo_iMaxAmmo1)

			if(iAmmo > 0) {
				rg_set_user_ammo(pPlayer, any:iCSW, iAmmo)
			}

			if(iBpAmmo > 0) {
				rg_set_user_bpammo(pPlayer, any:iCSW, iBpAmmo)
			}

			pItem = get_member(pItem, m_pNext)
		}
		while(pItem > 0)
	}
}
