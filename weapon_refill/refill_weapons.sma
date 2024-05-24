new const PLUGIN_VERSION[] = "1.0"

// Раскомментировать чтобы пополнение происходило не только при респавне в новом раунде (начало раунда), но и при каждом респавне игрока
#define EVERY_SPAWN

#include amxmodx
#include reapi
#include ultimate_weapons

stock HookChain:g_hSpawnPost

public plugin_init() {
	register_plugin("Refill Weapons", PLUGIN_VERSION, "mx?!")


#if !defined EVERY_SPAWN
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre")
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Post", true)
	g_hSpawnPost = RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true)
	DisableHookChain(g_hSpawnPost)
#else
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true)
#endif
}

#if !defined EVERY_SPAWN
	public CSGameRules_RestartRound_Pre() {
		EnableHookChain(g_hSpawnPost)
	}

	public CSGameRules_RestartRound_Post() {
		DisableHookChain(g_hSpawnPost)
	}
#endif

public CBasePlayer_Spawn_Post(pPlayer) {
	if(!is_user_alive(pPlayer)) {
		return
	}

	new ultimates[32], iCSW, iAmmo, iBpAmmo, bitUWs

	// Запишет в массив ultimate оружия игрока, которые он имеет при себе
	// Ячейка массива равняется CSW_ оригинального оружия
	// Само значение ячейки это uid оружия
	// -1 в ячейке говорит, что такого оружия у игрока нет
	weapons_get_user_ultimate(pPlayer, ultimates)

	for(new i; i < sizeof(ultimates); i++) {
		if(ultimates[i] == -1) {
			continue
		}

		// Вернет данные оружия, по его uid
		// Смотрите константы ULTIMATE_DATA_* для type
		// Числовые данные возвратятся в return, а строки в аргументе string[]
		// Если в return вернуло отрицательное число, значит это ошибка ULTIMATE_ERROR_*
		// Пример:
		//	new weapon=weapons_get_weapons_data(uid, ULTIMATE_DATA_WEAPON);
		//	new buy_name[32]; weapons_get_weapons_data(uid, ULTIMATE_DATA_BUYNAME, buy_name,31);
		iCSW = weapons_get_weapons_data(ultimates[i], ULTIMATE_DATA_WEAPON)
		iAmmo = weapons_get_weapons_data(ultimates[i], ULTIMATE_DATA_AMMO)
		iBpAmmo = weapons_get_weapons_data(ultimates[i], ULTIMATE_DATA_BPAMMO)

		bitUWs |= BIT(iCSW)

		if(iAmmo > 0) {
			rg_set_user_ammo(pPlayer, any:iCSW, iAmmo)
		}

		if(iBpAmmo > 0) {
			rg_set_user_bpammo(pPlayer, any:iCSW, iBpAmmo)
		}
	}

	for(new any:i = PRIMARY_WEAPON_SLOT, pItem; i <= PISTOL_SLOT; i++) {
		do {
			pItem = get_member(pPlayer, m_rgpPlayerItems, i)

			if(pItem < 1) {
				break
			}

			iCSW = get_member(pItem, m_iId)

			if(bitUWs & BIT(iCSW)) {
				pItem = get_member(pItem, m_pNext)
				continue
			}

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
