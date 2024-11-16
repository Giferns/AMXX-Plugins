#include amxmodx
#include reapi

new const PLUGIN_VERSION[] = "1.1"

// Перечислить все флаги, которвые нужно выдавать
new g_szFlagsToGive[] = "t";

new g_bitFlagsToGive, bool:g_bMember[MAX_PLAYERS + 1];

public plugin_init() {
	register_plugin("Flag for GameCMS Registration", PLUGIN_VERSION, "mx?!");
	
	g_bitFlagsToGive = read_flags(g_szFlagsToGive);
	
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Pre");
}

public CBasePlayer_Spawn_Pre(pPlayer) {
	if(g_bMember[pPlayer]) {
		set_user_flags(pPlayer,g_bitFlagsToGive);
	}
}

public OnAPIAdminConnected(id, const szName[], adminID, Flags) {
	CBasePlayer_Spawn_Pre(id);
}


public client_disconnected(id) {
	g_bMember[id] = false;
}

public OnAPIMemberConnected(id, memberId, memberName[]) {
	g_bMember[id] = true;
}

