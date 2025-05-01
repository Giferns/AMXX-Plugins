/* Change history:
	0.1 (07.10.2019) by mx?!:
		* First release
	0.2 (03.11.2019) by mx?!:
		* Added check for IPs and domain names
	0.3 (27.09.2023) by mx?!:
		* Minor improvement
	0.4 (01.05.2025) by mx?!:
		* Added is_user_connected() check in OnSetClientUserInfoName_Pre()
*/

new const PLUGIN_VERSION[] = "0.4"

//native ucc_is_client_gaged(pPlayer, &iExpTime, szGagReason[], &iGagType)
//native is_client_gaged(pPlayer)

/* -------------------- */

// Name flood cooldown (in seconds)
const Float:NAME_ANTIFLOOD_TIME = 10.0

// Name flood count to ban player
const MAX_WARNS_COUNT = 5

// Ban time in minutes
const BAN_TIME_IN_MINUTES = 10080 // 1 week

// Ban reason
new const BAN_REASON[] = "Name Flood"

// Ban action macro
#define BAN_MACRO server_cmd("amx_ban %i #%i ^"%s^"", BAN_TIME_IN_MINUTES, get_user_userid(pPlayer), BAN_REASON)

/* -------------------- */

#include <amxmodx>
#include <reapi>
#include <regex>

#define chx charsmax

new const SOUND__ERROR[] = "sound/buttons/button2.wav"

new const g_szPatternIPs[] = "((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)"
new const g_szPatternDomains[] = "(https?\:\/\/)?([a-z0-9]{1})((\.[a-z0-9-])|([a-z0-9-]))*\.([a-z]{2,4})(\/?)$"

new Float:g_fNextNameChange[MAX_PLAYERS + 1]
new Regex:g_hRegExDomains
new Regex:g_hRegExIPs

/* -------------------- */

public plugin_init() {
	register_plugin("Name Control", PLUGIN_VERSION, "mx?!")
	register_dictionary("name_control.txt")

	RegisterHookChain(RG_CBasePlayer_SetClientUserInfoName, "OnSetClientUserInfoName_Pre")

	g_hRegExDomains = regex_compile_ex(g_szPatternDomains, PCRE_CASELESS)
	g_hRegExIPs = regex_compile_ex(g_szPatternIPs)
}

/* -------------------- */

// https://github.com/s1lentq/ReGameDLL_CS/blob/fd06d655ec62a623d27178dc015a25f472c6ab03/regamedll/dlls/player.cpp#L163
// https://github.com/s1lentq/ReGameDLL_CS/blob/fd06d655ec62a623d27178dc015a25f472c6ab03/regamedll/dlls/client.cpp#L3627
public OnSetClientUserInfoName_Pre(pPlayer, szInfoBuffer[], szNewName[]) {
	if(is_user_bot(pPlayer) || is_user_hltv(pPlayer)) {
		SetHookChainReturn(ATYPE_BOOL, true)
		return HC_SUPERCEDE
	}
	
	if(!is_user_connected(pPlayer)) {
		return HC_CONTINUE
	}

	//new iExpTime, szGagReason[64], iGagType

	//if(ucc_is_client_gaged(pPlayer, iExpTime, szGagReason, iGagType)) {
	/*if(is_client_gaged(pPlayer)) {
		//func_SetOldName(pPlayer)
		//SetHookChainReturn(ATYPE_BOOL, false)
		//return HC_SUPERCEDE
		return HC_CONTINUE // пропускаем, GagMenu.sma отработает сам
	}*/

	static iWarns[MAX_PLAYERS + 1]

	new Float:fGameTime = get_gametime()
	new Float:fNextChange = g_fNextNameChange[pPlayer]

	g_fNextNameChange[pPlayer] = fGameTime + NAME_ANTIFLOOD_TIME

	if(fNextChange > fGameTime) {
		if(++iWarns[pPlayer] == MAX_WARNS_COUNT) {
			BAN_MACRO
		}
		else {
			rg_send_audio(pPlayer, SOUND__ERROR)
			console_print(pPlayer, "%l", "NAME_CONTROL__DO_NOT_SPAM", NAME_ANTIFLOOD_TIME)
		}

		func_SetOldName(pPlayer)
		SetHookChainReturn(ATYPE_BOOL, false)
		return HC_SUPERCEDE
	}

	/* --- */

	// as it will be stripped from spaces
	new szCheckName[MAX_NAME_LENGTH]
	copy(szCheckName, chx(szCheckName), szNewName)

	if(IsBadName(szCheckName)) {
		rg_send_audio(pPlayer, SOUND__ERROR)
		console_print(pPlayer, "%l", "NAME_CONTROL__WRONG_NAME")
		func_SetOldName(pPlayer)
		SetHookChainReturn(ATYPE_BOOL, false)
		return HC_SUPERCEDE
	}

	/* --- */

	iWarns[pPlayer] = 0

	client_print_color(0, pPlayer, "%L", LANG_PLAYER, "NAME_CONTROL__CHANGE_NAME_PATTERN", pPlayer, szNewName)

	log_message("^"%N^" changed name to ^"%s^"", pPlayer, szNewName)

	SetHookChainReturn(ATYPE_BOOL, true)
	return HC_SUPERCEDE
}

/* -------------------- */

public client_connect(pPlayer) {
	if(is_user_bot(pPlayer) || is_user_hltv(pPlayer)) {
		return
	}

	new szName[MAX_NAME_LENGTH]
	get_user_info(pPlayer, "name", szName, chx(szName))

	if(IsBadName(szName)) {
		set_user_info(pPlayer, "name", fmt("Player #%i", random_num(100, 1000)))
	}
}

/* -------------------- */

bool:IsBadName(szName[MAX_NAME_LENGTH]) {
	if(
		func_CheckName(szName, g_hRegExDomains, .bTrimSpaces = false)
			||
		func_CheckName(szName, g_hRegExIPs, .bTrimSpaces = true)
	) {
		return true
	}

	return false
}

/* -------------------- */

bool:func_CheckName(szName[MAX_NAME_LENGTH], Regex:hRegExHandle, bool:bTrimSpaces) {
	if(bTrimSpaces) {
		replace_string(szName, chx(szName), " ", "", .caseSensitive = true)
	}

	return bool:(regex_match_c(szName, hRegExHandle) > 1)
}

/* -------------------- */

func_SetOldName(pPlayer) {
	new szOldName[MAX_NAME_LENGTH]
	get_entvar(pPlayer, var_netname, szOldName, charsmax(szOldName))
	set_user_info(pPlayer, "name", szOldName)
}

/* -------------------- */

public client_disconnected(pPlayer) {
	g_fNextNameChange[pPlayer] = 0.0
}

/* -------------------- */

public plugin_natives() {
	set_native_filter("native_filter")
}

/* -------------------- */

public native_filter(szNativeName[], iNativeID, iTrapMode) {
	return PLUGIN_HANDLED
}