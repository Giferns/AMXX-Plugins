new const PLUGIN_VERSION[] = "1.0"

// Перечислить amxx-флаги доступа, при наличии которых при покупке оружия будет автоматически пополняться запас патронов для этого оружия
// Чтобы пополение работало, требуется наличие любого из перечисленных флагов
new const VIP_FLAGS[] = "d"

#include amxmodx
#include reapi
#include cstrike

new g_bitVipFlags, g_iBuyerId, g_iBuyCSW, Float:g_fBuyTime

public plugin_init() {
	register_plugin("Refill Buyed Weapons", PLUGIN_VERSION, "mx?!")

	g_bitVipFlags = read_flags(VIP_FLAGS)

	RegisterHookChain(RG_CBasePlayer_AddPlayerItem, "CBasePlayer_AddPlayerItem_Post", true)
}

/**
 * Called when a client purchases an item.
 *
 * @note This is called right before the user receives the item and before the
 *       money is deducted from their cash reserves.
 * @note For a list of possible item ids see the CSI_* constants.
 *
 * @param index     Client index
 * @param item      Item id
 *
 * @return          PLUGIN_CONTINUE to let the buy continue
 *                  PLUGIN_HANDLED to block the buy
 */
public CS_OnBuy(index, item) {
	g_iBuyerId = index
	g_iBuyCSW = item
	g_fBuyTime = get_gametime()
}

public CBasePlayer_AddPlayerItem_Post(pPlayer, pItem) {
	if(is_nullent(pItem) || !(get_user_flags(pPlayer) & g_bitVipFlags) || g_iBuyerId != pPlayer || g_fBuyTime != get_gametime()) {
		return
	}

	g_iBuyerId = 0
	g_fBuyTime = 0.0

	new iCSW = get_member(pItem, m_iId)

	if(g_iBuyCSW != iCSW) {
		g_iBuyCSW = 0
		return
	}

	g_iBuyCSW = 0

	new iAmmo = rg_get_iteminfo(pItem, ItemInfo_iMaxClip)
	new iBpAmmo = rg_get_iteminfo(pItem, ItemInfo_iMaxAmmo1)

	if(iAmmo > 0) {
		rg_set_user_ammo(pPlayer, any:iCSW, iAmmo)
	}

	if(iBpAmmo > 0) {
		rg_set_user_bpammo(pPlayer, any:iCSW, iBpAmmo)
	}
}
