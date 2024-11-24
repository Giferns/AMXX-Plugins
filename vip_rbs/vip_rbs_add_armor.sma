/*
		Плагин для VIP RBS [ https://fungun.net/shop/?p=show&id=39 ], для выдачи брони
			методом добавления к текущему значению, через тип srvcmd
*/

/*
	Инструкция по добавлению в VIP RBS:
	
		Добавить в vip_rbs.ini пункт:
		"srvcmd" "t" "viprbs_add_armor #%userid% 50 200"	"0"	"Добавить броню (+50)"
		
		Где
		"t" - флаг доступа
		"50" - сколько брони добавить
		"200" - максимум брони
*/

new const PLUGIN_VERSION[] = "1.0"

#include amxmodx
#include reapi

public plugin_init() {
	register_plugin("[VIP RBS] Add Armor", PLUGIN_VERSION, "mx?!")
	
	register_srvcmd("viprbs_add_armor", "srvcmd_AddArmor")
}

public srvcmd_AddArmor() {
	enum { arg_userid = 1, arg_value, arg_maximum }

	new szUserId[16]
	read_argv(arg_userid, szUserId, charsmax(szUserId))

	new pPlayer = find_player("k", str_to_num(szUserId[1]))

	if(!pPlayer) {
		abort(AMX_ERR_GENERAL, "[1] Player '%s' not found", szUserId[1])
	}

	new iValueToAdd = read_argv_int(arg_value)

	if(iValueToAdd < 1) {
		abort(AMX_ERR_GENERAL, "[1] Wrong value %i", iValueToAdd)
	}

	if(!is_user_alive(pPlayer)) {
		return PLUGIN_HANDLED
	}

	new iMaximum = read_argv_int(arg_maximum)
	
	new ArmorType:iArmorType
	new iValue = rg_get_user_armor(pPlayer, iArmorType)
	
	if(iValue >= iMaximum) {
		return PLUGIN_HANDLED
	}
	
	if(iArmorType == ARMOR_NONE) {
		iArmorType = ARMOR_VESTHELM
	}
	
	rg_set_user_armor(pPlayer, min(iMaximum, iValue + iValueToAdd), iArmorType)

	return PLUGIN_HANDLED
}