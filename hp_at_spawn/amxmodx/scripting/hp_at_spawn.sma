new const PLUGIN_VERSION[] = "1.0"

#include <amxmodx>
#include <amxmisc>
#include <reapi>

new const CFG_FILENAME[] = "hp_at_spawn.ini"

const MAX_ELEMENTS = 16

enum _:DATA_STRUCT {
	DATA__BIT_ACCESS,
	Float:DATA__F_VALUE,
	DATA__MIN_ROUND
}

new g_eData[MAX_ELEMENTS + 1][DATA_STRUCT]
new Trie:g_tData, g_iDataCount
new g_ePlayerData[MAX_PLAYERS + 1][DATA_STRUCT], bool:g_bBySteamID[MAX_PLAYERS + 1]
new g_bitLastFlags[MAX_PLAYERS + 1]

public plugin_init() {
	register_plugin("HP at Spawn", PLUGIN_VERSION, "mx?!")
	
	g_tData = TrieCreate()
	LoadCfg()
	
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true)
}

LoadCfg() {
	new szPath[240]
	new iLen = get_configsdir(szPath, charsmax(szPath))
	formatex(szPath[iLen], charsmax(szPath) - iLen, "/%s", CFG_FILENAME)
	
	new hFile = fopen(szPath, "r")
	
	if(!hFile) {
		set_fail_state("Can't %s '%s'", file_exists(szPath) ? "read" : "find", szPath)
		return
	}
	
	new szAccess[MAX_AUTHID_LENGTH], szValue[8], szMinRound[6], eData[DATA_STRUCT]
	
	while(fgets(hFile, szPath, charsmax(szPath))) {
		trim(szPath)
		
		if(!szPath[0] || szPath[0] == ';' || szPath[0] == '/') {
			continue
		}
		
		parse(szPath, szAccess, charsmax(szAccess), szValue, charsmax(szValue), szMinRound, charsmax(szMinRound))
		
		if(szAccess[0] == 'S' || szAccess[0] == 'V' || szAccess[0] == 'B') { // STEAM_, VALVE_, BOT
			eData[DATA__F_VALUE] = str_to_float(szValue)
			eData[DATA__MIN_ROUND] = str_to_num(szMinRound)
			TrieSetArray(g_tData, szAccess, eData, sizeof(eData))
			continue
		}
		
		g_eData[g_iDataCount][DATA__BIT_ACCESS] = read_flags(szAccess)
		g_eData[g_iDataCount][DATA__F_VALUE] = str_to_float(szValue)
		g_eData[g_iDataCount][DATA__MIN_ROUND] = str_to_num(szMinRound)
		g_iDataCount++
	}
	
	fclose(hFile)
}

public client_putinserver(pPlayer) {
	g_bitLastFlags[pPlayer] = -1337

	new szAuthID[MAX_AUTHID_LENGTH]
	get_user_authid(pPlayer, szAuthID, charsmax(szAuthID))

	if(TrieGetArray(g_tData, szAuthID, g_ePlayerData[pPlayer], sizeof(g_ePlayerData[]))) {
		g_bBySteamID[pPlayer] = true
		return
	}
	
	g_bBySteamID[pPlayer] = false
	ResetPlayerData(pPlayer)
}

ResetPlayerData(pPlayer) {
	g_ePlayerData[pPlayer][DATA__F_VALUE] = 0.0
	g_ePlayerData[pPlayer][DATA__MIN_ROUND] = 0
}

public CBasePlayer_Spawn_Post(pPlayer) {
	if(!is_user_alive(pPlayer)) {
		return
	}
	
	if(g_bBySteamID[pPlayer]) {
		SetHealth(pPlayer)
		return
	}
	
	new bitFlags = get_user_flags(pPlayer)
	
	if(bitFlags != g_bitLastFlags[pPlayer]) {
		g_bitLastFlags[pPlayer] = bitFlags
		ResetPlayerData(pPlayer)
		
		for(new i; i < g_iDataCount; i++) {
			if((bitFlags & g_eData[i][DATA__BIT_ACCESS]) == g_eData[i][DATA__BIT_ACCESS]) {
				g_ePlayerData[pPlayer][DATA__F_VALUE] = g_eData[i][DATA__F_VALUE]
				g_ePlayerData[pPlayer][DATA__MIN_ROUND] = g_eData[i][DATA__MIN_ROUND]
				break
			}
		}
	}
	
	SetHealth(pPlayer)   
}

SetHealth(pPlayer) {
	if(!g_ePlayerData[pPlayer][DATA__F_VALUE] || get_member_game(m_iTotalRoundsPlayed) + 1 < g_ePlayerData[pPlayer][DATA__MIN_ROUND]) {
		return
	}
	
	set_entvar(pPlayer, var_health, g_ePlayerData[pPlayer][DATA__F_VALUE])
}