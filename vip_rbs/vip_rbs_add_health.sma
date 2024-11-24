/*
		Пробный плагин для VIP RBS [ https://fungun.net/shop/?p=show&id=39 ], призванный изменить принцип
		действия бонуса IDENT_MENU_HEALTH с установки	на замещение, т.е. HP должно не изменяться на
		указанное значение, а указанное значение должно прибавляться к текущему значению HP игрока.
*/

new const PLUGIN_VERSION[] = "1.3"

#include amxmodx
#include reapi

// -----------------------------------------------

// Максимум, выше которого нельзя пополнить здоровье
// При значении 0 использует значение квара vip_max_health из vip_rbs.cfg
// Если закомментировано, использует var_max_health игрока (обычно равно 100, но может меняться другими плагинами)
#define MAX_HEALTH 200

// Режим отладки. В рабочей версии должен быть выключен.
//#define DEBUG "vip_rbs_add_health.log"

// -----------------------------------------------

// Не менять, это не настройки!
#define IDENT_MENU_HEALTH			4	// "health" - установить HP
#define VIP_DATA_MENU_VALUE		4	// [string] [menu] "дополнительное значение"
#define VIP_DATA_MENU_IDENT		0	// [int]    [menu] "идентификатор"

// Вернет данные бонуса
// Смотрите константы VIP_DATA_* для type
// Числовые данные возвратяться в return, а строки и массивы в аргументе data[]
// Пример:
//	new res=vip_get_item_data(label, VIP_DATA_MENU_IDENT);
//	new flags[32]; vip_get_item_data(label, VIP_DATA_MENU_FLAGS, flags,31);
native vip_get_item_data(label, type, data[]="", len=0);

new Float:g_fHealth, Float:g_fMaxHealth

public plugin_init() {
	register_plugin("[VIP RBS] Add Health", PLUGIN_VERSION, "mx?!")
}

// Вызывается при взятии пункта в меню
//	label - ярлык бонуса (с помощью него можно узнать данные бонуса нативом vip_get_item_data)
//	post - false если до взятия, true уже после
public vip_menu_got(id, label, bool:post) {
	if(vip_get_item_data(label, VIP_DATA_MENU_IDENT) != IDENT_MENU_HEALTH || !is_user_alive(id)) {
		return PLUGIN_CONTINUE
	}
	
	if(!post) {
		g_fHealth = get_entvar(id, var_health)
	
	#if !defined MAX_HEALTH
		g_fMaxHealth = get_entvar(id, var_max_health)
	#elseif MAX_HEALTH == 0
		g_fMaxHealth = get_cvar_float("vip_max_health")
	#else
		g_fMaxHealth = MAX_HEALTH.0
	#endif
	
	#if defined DEBUG
		log_to_file(DEBUG, "PRE: %n g_fHealth %f, g_fMaxHealth %f", id, g_fHealth, g_fMaxHealth)
	#endif
	
		if(g_fMaxHealth && g_fHealth >= g_fMaxHealth) {
		#if defined DEBUG
			log_to_file(DEBUG, "PRE: Block, as g_fHealth >= g_fMaxHealth")
		#endif
			return PLUGIN_HANDLED
		}
	}
	else {
		new szValue[14]
		vip_get_item_data(label, VIP_DATA_MENU_VALUE, szValue, charsmax(szValue))
		new Float:fHealthToAdd = str_to_float(szValue)
		
	#if defined DEBUG
		log_to_file(DEBUG, "POST: %n szValue '%s', g_fHealth %f, g_fMaxHealth %f", id, szValue, g_fHealth, g_fMaxHealth)
		log_to_file(DEBUG, "POST: fHealthToAdd %f (real hp %f)", fHealthToAdd, get_entvar(id, var_health))
	#endif
	
		if(g_fMaxHealth) {
			set_entvar(id, var_health, floatmin(g_fMaxHealth, g_fHealth + fHealthToAdd))
		}
		else {
			set_entvar(id, var_health, g_fHealth + fHealthToAdd)
		}
		
	#if defined DEBUG
		log_to_file(DEBUG, "Health after add: %f", get_entvar(id, var_health))
	#endif
	}
	
	return PLUGIN_CONTINUE
}