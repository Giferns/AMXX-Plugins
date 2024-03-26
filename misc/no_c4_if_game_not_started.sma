new const PLUGIN_VERSION[] = "1.0"

#include amxmodx
#include reapi

public plugin_init() {
	register_plugin("No C4 if game not started", PLUGIN_VERSION, "mx?!")

	RegisterHookChain(RG_CSGameRules_GiveC4, "CSGameRules_GiveC4_Pre")
}

public CSGameRules_GiveC4_Pre() {
	if(!get_member_game(m_bGameStarted)) {
		SetHookChainReturn(ATYPE_INTEGER, 0)
		return HC_SUPERCEDE
	}

	return HC_CONTINUE
}