#include amxmodx
#include reapi

public plugin_init() {
	register_plugin("Only knife", "1.1", "mx?!")

	RegisterHookChain(RG_CBasePlayer_HasRestrictItem, "OnHasRestrictItem_Pre")
	RegisterHookChain(RG_CSGameRules_CanHavePlayerItem, "CSGameRules_CanHavePlayerItem_Pre")
	RegisterHookChain(RG_CBasePlayer_AddPlayerItem, "RG_CBasePlayer_AddPlayerItem_Pre")
}

public OnHasRestrictItem_Pre(pPlayer, ItemID:iItem, ItemRestType:iRestType) {
	if(iItem != ITEM_KNIFE) {
		SetHookChainReturn(ATYPE_BOOL, true) // ATYPE_INTEGER
		return HC_SUPERCEDE
	}

	return HC_CONTINUE
}

public CSGameRules_CanHavePlayerItem_Pre(pPlayer, pItem) {
	if(is_entity(pItem) && get_member(pItem, m_iId) != WEAPON_KNIFE) {
		SetHookChainReturn(ATYPE_INTEGER, 0)
		return HC_SUPERCEDE
	}

	return HC_CONTINUE
}

public RG_CBasePlayer_AddPlayerItem_Pre(pPlayer, pItem) {
	if(is_entity(pItem) && get_member(pItem, m_iId) != WEAPON_KNIFE) {
		SetHookChainReturn(ATYPE_INTEGER, 0)
		return HC_SUPERCEDE
	}

	return HC_CONTINUE
}