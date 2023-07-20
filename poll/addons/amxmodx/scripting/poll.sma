/* История обновлений:
	1.0 (15.07.2023):
		* Открытый релиз
	1.1 (16.07.2023):
		* Фикс компиляции на amxx 190
*/

#include <amxmodx>
#include <reapi>
#include <sqlx>

new const PLUGIN_VERSION[] = "1.1" // Based on the idea of a plugin 'Poll' by Nunfy https://dev-cs.ru/resources/574/

/* ----------------------- */

// Debug filename in 'amxmodx/logs'. Should be commented by default.
//
// Имя логфайла отладки в 'amxmodx/logs'. По-умолчанию должно быть закомментировано.
//new const DEBUG[] = "PollDebug.log"

// Create config with cvars in 'configs/plugins' and execute it?
// Also here you can set the name of the config (do not use dots and spaces!). Empty value = default name.
//
// Создавать конфиг с кварами в 'configs/plugins', и запускать его?
// Так же здесь можно задать имя конфига (не используйте точки и пробелы!). Пустое значение = имя по-умолчанию.
new const AUTO_CFG[] = ""

// Dictionary file and at the same time, config, in 'data/lang'
//
// Файл словаря и одновременно, конфиг, в 'data/lang'
new const LANG_FILE[] = "poll.txt"

// Main log filename in 'amxmodx/logs'
//
// Имя основного логфайла в 'amxmodx/logs'
new const MAINLOG_FILENAME[] = "poll_main.log"

// SQL errorlog filename in 'amxmodx/logs'
//
// Имя логфайла ошибок работы с базой данных в 'amxmodx/logs'
new const SQLERRLOG_FILENAME[] = "poll_sql_errors.log"

// Plugin initialization delay. Do not change without understanding the consequences!
//
// Задержка инициализации плагина. Не меняйте без понимания последствий!
const Float:SYSTEM_INIT_DELAY = 4.0

/* ----------------------- */

// CSstatsX SQL 0.7.4+2 https://dev-cs.ru/resources/179/
//
// Returns player played time in seconds
//	@return - played time in seconds
//			-1 if no played time recorded
//
native get_user_gametime(id)

// CsStats MySQL https://fungun.net/shop/?p=show&id=3
// Вернет значение пункта статистики(ident)
#define GAMETIME	14	// Время в игре (в секундах)
native csstats_get_user_value(id, ident)

// Simple Online Logger https://dev-cs.ru/resources/430/field?field=source
native sol_get_user_time(id)

/* ----------------------- */

#define MAX_QD_KEY_LEN 64
#define ALL_KEYS 1023

new const MENU_IDENT_STRING[] = "PollMenu"
enum { _PAGE1_, _PAGE2_, _PAGE3_, _PAGE4_, _PAGE5_, _PAGE6_, _PAGE7_, _PAGE8_, _PAGE9_, _PAGE10_ }
enum { _KEY1_, _KEY2_, _KEY3_, _KEY4_, _KEY5_, _KEY6_, _KEY7_, _KEY8_, _KEY9_, _KEY0_ }

enum {
	QUERY__INIT_SYSTEM,
	QUERY__LOAD_PLAYER,
	QUERY__INSERT_ANSWER
}

enum _:SQL_DATA_STRUCT {
	SQL_DATA__QUERY_TYPE,
	SQL_DATA__USERID
}

enum _:QUESTION_DATA_STRUCT {
	QD__KEY[MAX_QD_KEY_LEN],
	QD__COUNT
}

enum _:CVAR_ENUM {
	CVAR__SQL_HOST[64],
	CVAR__SQL_USER[64],
	CVAR__SQL_PASSWORD[64],
	CVAR__SQL_DATABASE[64],
	CVAR__SQL_TABLE[64],
	CVAR__SQL_TIMEOUT,
	CVAR__SQL_AUTOCREATE,
	CVAR__POLLS_ENABLED,
	CVAR__NATIVE_TIME_MODE,
	Float:CVAR_F__KILLED_DELAY,
	CVAR__RANDOM_POLL,
	CVAR__OVERRIDE_MENUS,
	CVAR__MIN_OVERALL_TIME,
	CVAR__MIN_SESSION_TIME,
	CVAR__GLOBAL_COOLDOWN,
	CVAR__LOCAL_COOLDOWN,
	CVAR__MAX_POLLS_PER_MAP,
	CVAR__ALOW_EXIT_MENU_ITEM,
	CVAR__SHIFT_MENU_ITEMS
}

new g_eCvar[CVAR_ENUM]
new Handle:g_hSqlTuple
new bool:g_bPluginEnded
new g_szQuery[1024]
new g_eSqlData[SQL_DATA_STRUCT]
new g_szSqlErrLogFile[96]
new g_szMainLogFile[96]
new bool:g_bWaitLoad[MAX_PLAYERS + 1]
new Array:g_aQuestionData[MAX_PLAYERS + 1]
new g_iQuestionsCount[MAX_PLAYERS + 1]
new g_iGlobalPollTime[MAX_PLAYERS + 1]
new g_iSessionPollTime[MAX_PLAYERS + 1]
new g_iPollsCount[MAX_PLAYERS + 1]
new g_iMenuID
new g_szMapName[64]
new g_iTimeDiff
new Trie:g_tSessionPolls
new Trie:g_tPollsCount
new g_iPollDataPos[MAX_PLAYERS + 1]
new g_iMenuPage[MAX_PLAYERS + 1]
new g_szMenu[512]
new bool:g_bSystemInitialized

public plugin_init() {
	register_plugin("Poll", PLUGIN_VERSION, "mx?!")
	register_dictionary(LANG_FILE)

	get_mapname(g_szMapName, charsmax(g_szMapName))

#if defined DEBUG
	log_to_file(DEBUG, "Mapchange to %s", g_szMapName)
#endif

	RegCvars()

	new iLen = get_localinfo("amxx_logs", g_szMainLogFile, charsmax(g_szMainLogFile))
	formatex(g_szMainLogFile[iLen], charsmax(g_szMainLogFile) - iLen, "/%s", MAINLOG_FILENAME)

	g_tSessionPolls = TrieCreate()
	g_tPollsCount = TrieCreate()

	g_aQuestionData[0] = ArrayCreate(QUESTION_DATA_STRUCT)
	LoadPollList()

	set_task(SYSTEM_INIT_DELAY, "task_InitSystem")
}

LoadPollList() {
	new szPath[240]
	new iLen = get_localinfo("amxx_datadir", szPath, charsmax(szPath))
	formatex(szPath[iLen], charsmax(szPath) - iLen, "/lang/%s", LANG_FILE)

	new hFile = fopen(szPath, "r")

	if(!hFile) {
		set_fail_state("Can't %s '%s'", file_exists(szPath) ? "read" : "find", szPath)
	}

	new szString[128], szLangKey[MAX_QD_KEY_LEN], eQuestionData[QUESTION_DATA_STRUCT], iBracket

	while(fgets(hFile, szString, charsmax(szString))) {
		trim(szString)

		if(!szString[0]) {
			continue
		}

		if(szString[0] == '[') { // work with first lang block and stop when next block is discovered
			iBracket++

			if(iBracket == 2) {
				break
			}
		}

		parse(szString, szLangKey, charsmax(szLangKey))

	#if defined DEBUG
		log_to_file(DEBUG, "szString: %s", szString)
		log_to_file(DEBUG, "szLangKey: %s", szLangKey)
	#endif

		if(contain(szLangKey, "QUESTION") != -1) {
			if(eQuestionData[QD__COUNT]) {
				ArrayPushArray(g_aQuestionData[0], eQuestionData)
				eQuestionData[QD__COUNT] = 0
			}

			copy(eQuestionData[QD__KEY], charsmax(eQuestionData[QD__KEY]), szLangKey)
		}
		else if(contain(szLangKey, "ANSWER") != -1) {
			eQuestionData[QD__COUNT]++
		}
	}

	if(eQuestionData[QD__COUNT]) {
		ArrayPushArray(g_aQuestionData[0], eQuestionData)
	}

	g_iQuestionsCount[0] = ArraySize(g_aQuestionData[0])

#if defined DEBUG
	log_to_file(DEBUG, "LoadPollList() Questions count: %i", g_iQuestionsCount[0])
#endif

	fclose(hFile)
}

RegCvars() {
	bind_cvar_string( "poll_sql_host", "127.0.0.1", FCVAR_PROTECTED,
		.desc = "Database host",
		.bind = g_eCvar[CVAR__SQL_HOST], .maxlen = charsmax(g_eCvar[CVAR__SQL_HOST])
	);

	bind_cvar_string( "poll_sql_user", "root", FCVAR_PROTECTED,
		.desc = "Database user",
		.bind = g_eCvar[CVAR__SQL_USER], .maxlen = charsmax(g_eCvar[CVAR__SQL_USER])
	);

	bind_cvar_string( "poll_sql_password", "", FCVAR_PROTECTED,
		.desc = "Database password",
		.bind = g_eCvar[CVAR__SQL_PASSWORD], .maxlen = charsmax(g_eCvar[CVAR__SQL_PASSWORD])
	);

	bind_cvar_string( "poll_sql_database", "database", FCVAR_PROTECTED,
		.desc = "Database name",
		.bind = g_eCvar[CVAR__SQL_DATABASE], .maxlen = charsmax(g_eCvar[CVAR__SQL_DATABASE])
	);

	bind_cvar_string( "poll_sql_table", "polls", FCVAR_PROTECTED,
		.desc = "Database table",
		.bind = g_eCvar[CVAR__SQL_TABLE], .maxlen = charsmax(g_eCvar[CVAR__SQL_TABLE])
	);

	bind_cvar_num( "poll_sql_timeout", "7",
		.desc = "Timeout value for sql requests (set to 0 to use global default value (60s))",
		.bind = g_eCvar[CVAR__SQL_TIMEOUT]
	);

	bind_cvar_num( "poll_sql_autocreate", "1",
		.desc = "Create sql table automatically?",
		.bind = g_eCvar[CVAR__SQL_AUTOCREATE]
	);

	bind_cvar_num( "poll_polls_enabled", "1",
		.desc = "Polls enabled (1) or disabled (0) ?",
		.bind = g_eCvar[CVAR__POLLS_ENABLED]
	);

	bind_cvar_num( "poll_native_time_mode", "-1",
		.desc = "Which plugin will be used to get overall gametime:^n\
		-1 - Do not use anything^n\
		0 - 'CSstatsX SQL' by serfreeman1337^n\
		1 - 'CsStats MySQL' by SKAJIbnEJIb^n\
		2 - 'Simple Online Logger' by mx?!",
		.has_min = true, .min_val = -1.0,
		.has_max = true, .max_val = 2.0,
		.bind = g_eCvar[CVAR__NATIVE_TIME_MODE]
	);

	bind_cvar_float( "poll_killed_delay", "3.0",
		.desc = "Delay between death and creating poll",
		.has_min = true, .min_val = 0.1,
		.bind = g_eCvar[CVAR_F__KILLED_DELAY]
	);

	bind_cvar_num( "poll_random_poll", "1",
		.desc = "Randomize polls?",
		.bind = g_eCvar[CVAR__RANDOM_POLL]
	);

	bind_cvar_num( "poll_override_menus", "0",
		.desc = "Override other menus?",
		.bind = g_eCvar[CVAR__OVERRIDE_MENUS]
	);

	bind_cvar_num( "poll_min_overall_time", "60",
		.desc = "Minimal overall player online in minutes to create polls",
		.bind = g_eCvar[CVAR__MIN_OVERALL_TIME]
	);

	bind_cvar_num( "poll_min_session_time", "70",
		.desc = "Minimal session player online in seconds to create polls",
		.bind = g_eCvar[CVAR__MIN_SESSION_TIME]
	);

	bind_cvar_num( "poll_global_cooldown", "0",
		.desc = "Global cooldown in seconds for each player between polls",
		.bind = g_eCvar[CVAR__GLOBAL_COOLDOWN]
	);

	bind_cvar_num( "poll_local_cooldown", "60",
		.desc = "'Per map' cooldown in seconds for each player between polls",
		.bind = g_eCvar[CVAR__LOCAL_COOLDOWN]
	);

	bind_cvar_num( "poll_max_polls_per_map", "5",
		.desc = "Max polls count per map for each player (0 - without limit)",
		.bind = g_eCvar[CVAR__MAX_POLLS_PER_MAP]
	);

	bind_cvar_num( "poll_allow_exit_menu_item", "0",
		.desc = "Allow EXIT menu item (1/0) ?",
		.bind = g_eCvar[CVAR__ALOW_EXIT_MENU_ITEM]
	);

	bind_cvar_num( "poll_shift_menu_items", "6",
		.desc = "Menu items will be shifted by this value",
		.has_min = true, .min_val = 1.0,
		.has_max = true, .max_val = 7.0,
		.bind = g_eCvar[CVAR__SHIFT_MENU_ITEMS]
	);

	/* --- */

#if defined AUTO_CFG
	AutoExecConfig(.name = AUTO_CFG)
#endif
}

public task_InitSystem() {
	if(!SQL_SetAffinity("mysql")) {
		set_fail_state("Failed to set affinity to 'mysql' (module not loaded?)")
	}

	g_hSqlTuple = SQL_MakeDbTuple( g_eCvar[CVAR__SQL_HOST], g_eCvar[CVAR__SQL_USER], g_eCvar[CVAR__SQL_PASSWORD],
		g_eCvar[CVAR__SQL_DATABASE], g_eCvar[CVAR__SQL_TIMEOUT] );

	SQL_SetCharset(g_hSqlTuple, "utf8")

	InitializeSystem()
}

InitializeSystem() {
	new iLen = formatex(g_szQuery, charsmax(g_szQuery), "SELECT UNIX_TIMESTAMP(CURRENT_TIMESTAMP) as `unixtime`;")

	if(g_eCvar[CVAR__SQL_AUTOCREATE]) {
		formatex( g_szQuery[iLen], charsmax(g_szQuery) - iLen,
			"CREATE TABLE IF NOT EXISTS `%s` (\
				`id` int(10) unsigned NOT NULL AUTO_INCREMENT, \
				`steamid` varchar(64) NOT NULL, \
				`name` varchar(32) NOT NULL, \
				`question_id` int(10) unsigned NOT NULL, \
				`question_key` varchar(%i) NOT NULL, \
				`question_text` varchar(256) NOT NULL, \
				`answer_id` int(10) unsigned NOT NULL, \
				`answer_key` varchar(%i) NOT NULL, \
				`answer_text` varchar(256) NOT NULL, \
				`map` varchar(64) NOT NULL, \
				`timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, \
				PRIMARY KEY (`id`), \
				KEY `steamid` (`steamid`), \
				KEY `question_key` (`question_key`)\
			) ENGINE=InnoDB DEFAULT CHARSET=utf8;",

			g_eCvar[CVAR__SQL_TABLE],

			MAX_QD_KEY_LEN,
			MAX_QD_KEY_LEN
		);
	}

	MakeQuery(QUERY__INIT_SYSTEM)
}

SetSystemInitialized() {
#if defined DEBUG
	log_to_file(DEBUG, "SetSystemInitialized()")
#endif

	g_bSystemInitialized = true

	g_iMenuID = register_menuid(MENU_IDENT_STRING)
	register_menucmd(g_iMenuID, ALL_KEYS, "MenuHandler")

	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", true)
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true)

	new pPlayers[MAX_PLAYERS], iPlCount, pPlayer
	get_players(pPlayers, iPlCount, "ch")

	for(new i; i < iPlCount; i++) {
		pPlayer = pPlayers[i]

		if(g_bWaitLoad[pPlayer]) {
			g_bWaitLoad[pPlayer] = false
		#if defined DEBUG
			log_to_file(DEBUG, "Delayed load for %N", pPlayer)
		#endif
			LoadPlayerData(pPlayer)
		}
	}
}

public client_putinserver(pPlayer) {
	if(is_user_bot(pPlayer) || is_user_hltv(pPlayer)) {
		return
	}

	if(!g_bSystemInitialized) {
		g_bWaitLoad[pPlayer] = true
		return
	}

	LoadPlayerData(pPlayer)
}

LoadPlayerData(pPlayer) {
#if defined DEBUG
	log_to_file(DEBUG, "LoadPlayerData() for %N", pPlayer)
#endif

	static szAuthID[64]
	get_user_authid(pPlayer, szAuthID, charsmax(szAuthID))

	TrieGetCell(g_tSessionPolls, szAuthID, g_iSessionPollTime[pPlayer])
	TrieGetCell(g_tPollsCount, szAuthID, g_iPollsCount[pPlayer])

#if defined DEBUG
	log_to_file(DEBUG, "g_iSessionPollTime: %i", g_iSessionPollTime[pPlayer])
	log_to_file(DEBUG, "g_iPollsCount: %i", g_iPollsCount[pPlayer])
#endif

	formatex( g_szQuery, charsmax(g_szQuery),
		"SELECT `question_key`, UNIX_TIMESTAMP(`timestamp`) FROM `%s` \
		WHERE `steamid` = '%s' AND (`question_key` NOT LIKE '%%MAP%%' OR `map` = '%s') \
		ORDER BY `timestamp` DESC",

		g_eCvar[CVAR__SQL_TABLE], szAuthID, g_szMapName
	);

	g_eSqlData[SQL_DATA__USERID] = get_user_userid(pPlayer)
	MakeQuery(QUERY__LOAD_PLAYER)
}

public client_remove(pPlayer) {
	remove_task(pPlayer)

	g_bWaitLoad[pPlayer] = false

	g_iQuestionsCount[pPlayer] = 0
	g_iGlobalPollTime[pPlayer] = 0
	g_iSessionPollTime[pPlayer] = 0
	g_iPollsCount[pPlayer] = 0

	if(g_aQuestionData[pPlayer]) {
		ArrayDestroy(g_aQuestionData[pPlayer])
		g_aQuestionData[pPlayer] = Invalid_Array
	}
}

public SQL_Handler(iFailState, Handle:hQueryHandle, szError[], iErrorCode, eSqlData[], iDataSize, Float:fQueryTime) {
	if(g_bPluginEnded) {
		return
	}

	if(iFailState != TQUERY_SUCCESS) {
		if(!g_szSqlErrLogFile[0]) {
			new iLen = get_localinfo("amxx_logs", g_szSqlErrLogFile, charsmax(g_szSqlErrLogFile))
			formatex(g_szSqlErrLogFile[iLen], charsmax(g_szSqlErrLogFile) - iLen, "/%s", SQLERRLOG_FILENAME)
		}

		if(iFailState == TQUERY_CONNECT_FAILED)	{
			log_to_file(g_szSqlErrLogFile, "[SQL] Can't connect to server [%.2f]", fQueryTime)
			log_to_file(g_szSqlErrLogFile, "[SQL] Error #%i, %s", iErrorCode, szError)
		}
		else /*if(iFailState == TQUERY_QUERY_FAILED)*/ {
			SQL_GetQueryString(hQueryHandle, g_szQuery, charsmax(g_szQuery))
			log_to_file(g_szSqlErrLogFile, "[SQL] Query error!")
			log_to_file(g_szSqlErrLogFile, "[SQL] Error #%i, %s", iErrorCode, szError)
			log_to_file(g_szSqlErrLogFile, "[SQL] Query: %s", g_szQuery)
		}

		return
	}

	/* --- */

	switch(eSqlData[SQL_DATA__QUERY_TYPE]) {
		case QUERY__INIT_SYSTEM: {
			new iTimeStamp = SQL_ReadResult(hQueryHandle, 0) // `unixtime`

		#if defined DEBUG
			log_to_file( DEBUG, "[QUERY__INIT_SYSTEM] iTimeStamp: %i, fQueryTime: %f, g_iTimeDiff: %i",
				iTimeStamp, fQueryTime, get_systime() - (iTimeStamp + floatround(fQueryTime)) );
		#endif

			iTimeStamp += floatround(fQueryTime)
			// TODO: Wrong! Need replace it with 'g_iTimeDiff = iTimeStamp - get_systime()'
			g_iTimeDiff = get_systime() - iTimeStamp

			SetSystemInitialized()
		}

		/* --- */

		case QUERY__LOAD_PLAYER: {
			new pPlayer = find_player("k", eSqlData[SQL_DATA__USERID])

			if(!pPlayer) {
			#if defined DEBUG
				log_to_file(DEBUG, "[QUERY__LOAD_PLAYER] Player with userid '%s' disconnected", eSqlData[SQL_DATA__USERID])
			#endif
				return
			}

			g_aQuestionData[pPlayer] = ArrayClone(g_aQuestionData[0])
			g_iQuestionsCount[pPlayer] = g_iQuestionsCount[0]

			new iNumResults = SQL_NumResults(hQueryHandle)

		#if defined DEBUG
			log_to_file(DEBUG, "[QUERY__LOAD_PLAYER] %i results for %N", iNumResults, pPlayer)
		#endif

			if(!iNumResults) {
				return
			}

			g_iGlobalPollTime[pPlayer] = SQL_ReadResult(hQueryHandle, 1) // `timestamp`

		#if defined DEBUG
			log_to_file(DEBUG, "[QUERY__LOAD_PLAYER] g_iGlobalPollTime %i", g_iGlobalPollTime[pPlayer])
		#endif

			new szLangKey[MAX_QD_KEY_LEN], i, eQuestionData[QUESTION_DATA_STRUCT]

			while(iNumResults) {
				SQL_ReadResult(hQueryHandle, 0, szLangKey, charsmax(szLangKey)) // `question_key`

		#if defined DEBUG
			log_to_file(DEBUG, "[QUERY__LOAD_PLAYER] Searching key '%s' ...", szLangKey)
		#endif

				for(i = 0; i < g_iQuestionsCount[pPlayer]; i++) {
					ArrayGetArray(g_aQuestionData[pPlayer], i, eQuestionData)

					// ArrayFindString() can find "QUESTION_1" in "QUESTION_10" so it is not suitable
					if(strcmp(szLangKey, eQuestionData[QD__KEY]) == 0) {
					#if defined DEBUG
						log_to_file(DEBUG, "[QUERY__LOAD_PLAYER] Found! Key '%s' removed", eQuestionData[QD__KEY])
					#endif
						ArrayDeleteItem(g_aQuestionData[pPlayer], i)
						g_iQuestionsCount[pPlayer]--
						break
					}
				}

				iNumResults--
				SQL_NextRow(hQueryHandle)
			}

		#if defined DEBUG
			log_to_file(DEBUG, "[QUERY__LOAD_PLAYER] Remaining polls after removing: %i", g_iQuestionsCount[pPlayer])
		#endif
		}
	}
}

stock GetGameTime(id) {
	switch(g_eCvar[CVAR__NATIVE_TIME_MODE]) {
		case 0: return get_user_gametime(id) / 60;
		case 1: return csstats_get_user_value(id, GAMETIME) / 60;
		case 2: return sol_get_user_time(id) / 60;
	}

	// NOTE: supposed to be unreachable due to cvar value bounds (0 - 2)
	return 0
}

public CBasePlayer_Spawn_Post(pPlayer) {
	if(!is_user_alive(pPlayer)) {
		return
	}

	remove_task(pPlayer)

	if(check_menu_by_menuid(pPlayer, g_iMenuID)) {
		close_menu(pPlayer)
	}
}

GetSysTime() {
	return get_systime() + g_iTimeDiff
}

public CBasePlayer_Killed_Post(pVictim) {
	if(!g_iQuestionsCount[pVictim] || !g_eCvar[CVAR__POLLS_ENABLED]) {
	#if defined DEBUG
		log_to_file(DEBUG, "No polls for %N or plugin disabled (%i)", pVictim, (g_eCvar[CVAR__POLLS_ENABLED] != 0))
	#endif
		return
	}

	if(g_eCvar[CVAR__MAX_POLLS_PER_MAP] && g_iPollsCount[pVictim] >= g_eCvar[CVAR__MAX_POLLS_PER_MAP]) {
	#if defined DEBUG
		log_to_file( DEBUG, "%N triggered 'poll_max_polls_per_map' cvar check (%i against %i)",
			pVictim, g_iPollsCount[pVictim],  g_eCvar[CVAR__MAX_POLLS_PER_MAP] );
	#else
		return
	#endif
	}

	if( g_eCvar[CVAR__GLOBAL_COOLDOWN] && g_iGlobalPollTime[pVictim]
		&& g_iGlobalPollTime[pVictim] + g_eCvar[CVAR__GLOBAL_COOLDOWN] > GetSysTime()
	) {
	#if defined DEBUG
		log_to_file( DEBUG, "%N triggered 'poll_global_cooldown' cvar check (%i against %i)",
			pVictim, g_iGlobalPollTime[pVictim] + g_eCvar[CVAR__GLOBAL_COOLDOWN], GetSysTime() );
	#else
		return
	#endif
	}

	if( g_eCvar[CVAR__LOCAL_COOLDOWN] && g_iSessionPollTime[pVictim]
		&& g_iSessionPollTime[pVictim] + g_eCvar[CVAR__LOCAL_COOLDOWN] > get_systime()
	) {
	#if defined DEBUG
		log_to_file( DEBUG, "%N triggered 'poll_local_cooldown' cvar check (%i against %i)",
			pVictim, g_iSessionPollTime[pVictim] + g_eCvar[CVAR__LOCAL_COOLDOWN], get_systime() );
	#else
		return
	#endif
	}

	/*  @param flag      If nonzero, the result will not include the time it took
	*                  the client to connect. */
	if(get_user_time(pVictim, .flag = 1) < g_eCvar[CVAR__MIN_SESSION_TIME]) {
	#if defined DEBUG
		log_to_file( DEBUG, "%N triggered 'poll_min_session_time' cvar check (%i against %i)",
			pVictim, get_user_time(pVictim, .flag = 1), g_eCvar[CVAR__MIN_SESSION_TIME] );
	#else
		return
	#endif
	}

#if !defined DEBUG
	if(g_eCvar[CVAR__NATIVE_TIME_MODE] != -1 && GetGameTime(pVictim) < g_eCvar[CVAR__MIN_OVERALL_TIME]) {
		return
	}
#endif

#if defined DEBUG
	log_to_file(DEBUG, "Set poll task (%f) for %N", g_eCvar[CVAR_F__KILLED_DELAY], pVictim)
#endif

	set_task(g_eCvar[CVAR_F__KILLED_DELAY], "task_MakePoll", pVictim)
}

public task_MakePoll(pPlayer) {
#if defined DEBUG
	log_to_file(DEBUG, "task_MakePoll() for %N. Plugin disabled? %i", pPlayer, (g_eCvar[CVAR__POLLS_ENABLED] == 0))
#endif

	if(!g_eCvar[CVAR__POLLS_ENABLED]) {
		return
	}

	if(!g_eCvar[CVAR__OVERRIDE_MENUS] && is_player_see_menu(pPlayer)) {
	#if defined DEBUG
		log_to_file(DEBUG, "%N triggered 'poll_override_menus'", pPlayer)
	#else
		return
	#endif
	}

	/*if(check_menu_by_menuid(pPlayer, g_iMenuID)) {
		return
	}*/

	g_iPollDataPos[pPlayer] = 0

	if(g_eCvar[CVAR__RANDOM_POLL]) {
		g_iPollDataPos[pPlayer] = random_num(0, g_iQuestionsCount[pPlayer] - 1)
	}

#if defined DEBUG
	log_to_file(DEBUG, "g_iPollDataPos[pPlayer]: %i", g_iPollDataPos[pPlayer])
#endif

	ShowPollPage(pPlayer, _PAGE1_)
}

GetItemsPerPage() {
	const iMaxItemsPerPage = 7
	return (iMaxItemsPerPage - g_eCvar[CVAR__SHIFT_MENU_ITEMS]) + 1
}

ShowPollPage(pPlayer, iMenuPage) {
	new eQuestionData[QUESTION_DATA_STRUCT]
	ArrayGetArray(g_aQuestionData[pPlayer], g_iPollDataPos[pPlayer], eQuestionData)

	new iAnswersCount = eQuestionData[QD__COUNT]

	new iItemsPerPage = GetItemsPerPage()

	new i = min(iMenuPage * iItemsPerPage, iAnswersCount)
	new iStart = i - (i % iItemsPerPage)
	new iEnd = min(iStart + iItemsPerPage, iAnswersCount)

	g_iMenuPage[pPlayer] = iMenuPage = iStart / iItemsPerPage

	/* --- */

	new iQuestionID = GetQuestionID(eQuestionData[QD__KEY])

	new iMenuItem, iKeys

	SetGlobalTransTarget(pPlayer)

	new iLen = formatex(g_szMenu, charsmax(g_szMenu), "\y%l^n^n", eQuestionData[QD__KEY])

	new iShiftValue = g_eCvar[CVAR__SHIFT_MENU_ITEMS] - 1

	for(i = iStart; i < iEnd; i++) {
		iKeys |= (1 << (iMenuItem + iShiftValue))

		iMenuItem++

		iLen += formatex( g_szMenu[iLen], charsmax(g_szMenu) - iLen, "\r%i. \w%l^n",
			iMenuItem + iShiftValue, fmt("POLL_ANSWER_%i_%i", iQuestionID, i + 1) );
	}

	if(iMenuPage) {
		iKeys |= MENU_KEY_8
		iLen += formatex(g_szMenu[iLen], charsmax(g_szMenu) - iLen, "^n\r8. \w%l", "POLL_BACK")
	}

	if(iEnd < iAnswersCount) {
		iKeys |= MENU_KEY_9
		iLen += formatex(g_szMenu[iLen], charsmax(g_szMenu) - iLen, "^n\r9. \w%l", "POLL_MORE")
	}

	if(g_eCvar[CVAR__ALOW_EXIT_MENU_ITEM]) {
		iKeys |= MENU_KEY_0

		formatex( g_szMenu[iLen], charsmax(g_szMenu) - iLen, "%s^n\r0. \w%l",
			(iKeys & (MENU_KEY_8|MENU_KEY_9)) ? "^n" : "", "POLL_EXIT" );
	}

	show_menu(pPlayer, iKeys, g_szMenu, -1, MENU_IDENT_STRING)
}

GetQuestionID(const szLangKey[/*MAX_QD_KEY_LEN*/]) { // 190 compile fix
	new szString[MAX_QD_KEY_LEN]
	copy(szString, charsmax(szString), szLangKey)

	if(!replace_string(szString, charsmax(szString), "POLL_QUESTION_MAP_", "")) {
		replace_string(szString, charsmax(szString), "POLL_QUESTION_", "")
	}

	return str_to_num(szString)
}

public MenuHandler(pPlayer, iKey) {
	new iMenuPage = g_iMenuPage[pPlayer]

	switch(iKey) {
		case _KEY8_: {
			ShowPollPage(pPlayer, iMenuPage - 1)
		}
		case _KEY9_: {
			ShowPollPage(pPlayer, iMenuPage + 1)
		}
		case _KEY0_: {
			return
		}
		default: {
			//remove_task(pPlayer)

			new szAuthID[64]
			get_user_authid(pPlayer, szAuthID, charsmax(szAuthID))

			new iSysTime = get_systime()
			g_iGlobalPollTime[pPlayer] = iSysTime + g_iTimeDiff
			g_iSessionPollTime[pPlayer] = iSysTime
			g_iPollsCount[pPlayer]++
			TrieSetCell(g_tSessionPolls, szAuthID, g_iSessionPollTime[pPlayer])
			TrieSetCell(g_tPollsCount, szAuthID, g_iPollsCount[pPlayer])

			new eQuestionData[QUESTION_DATA_STRUCT]
			ArrayGetArray(g_aQuestionData[pPlayer], g_iPollDataPos[pPlayer], eQuestionData)
			ArrayDeleteItem(g_aQuestionData[pPlayer], g_iPollDataPos[pPlayer])
			g_iQuestionsCount[pPlayer]--

			new iQuestionID = GetQuestionID(eQuestionData[QD__KEY])

			new iShiftValue = g_eCvar[CVAR__SHIFT_MENU_ITEMS] - 1
			new iShiftedKey = iKey - iShiftValue
			new iAnswerID = ((iMenuPage * GetItemsPerPage()) + iShiftedKey) + 1

			new szQuestionText[128], szAnswerText[128], szAnswerKey[MAX_QD_KEY_LEN]
			formatex(szQuestionText, charsmax(szQuestionText), "%L", LANG_SERVER, eQuestionData[QD__KEY])
			formatex(szAnswerKey, charsmax(szAnswerKey), "POLL_ANSWER_%i_%i", iQuestionID, iAnswerID)
			formatex(szAnswerText, charsmax(szAnswerText), "%L", LANG_SERVER, szAnswerKey)

			log_to_file(g_szMainLogFile, "%N<%s> %s / %s", pPlayer, g_szMapName, szQuestionText, szAnswerText)

			client_print_color(pPlayer, print_team_default, "%l", "POLL_CHAT_Q", eQuestionData[QD__KEY])
			client_print_color(pPlayer, print_team_default, "%l", "POLL_CHAT_A", szAnswerKey)

			new szName[64]
			get_user_name(pPlayer, szName, charsmax(szName))
			mysql_escape_string(szName, charsmax(szName))

			mysql_escape_string(szQuestionText, charsmax(szQuestionText))
			mysql_escape_string(szAnswerText, charsmax(szAnswerText))

			formatex( g_szQuery, charsmax(g_szQuery),
				"INSERT INTO `%s` \
				(`steamid`, `name`, `question_id`, `question_key`, `question_text`, `answer_id`, `answer_key`, `answer_text`, `map`) \
					VALUES \
				('%s', '%s', %i, '%s', '%s', %i, '%s', '%s', '%s')",

				g_eCvar[CVAR__SQL_TABLE],

				szAuthID,
				szName,
				iQuestionID,
				eQuestionData[QD__KEY],
				szQuestionText,
				iAnswerID,
				szAnswerKey,
				szAnswerText,
				g_szMapName
			);

			MakeQuery(QUERY__INSERT_ANSWER)
		}
	}
}

MakeQuery(iQueryType) {
#if defined DEBUG
	log_to_file(DEBUG, "MakeQuery: %s", g_szQuery)
#endif
	g_eSqlData[SQL_DATA__QUERY_TYPE] = iQueryType
	SQL_ThreadQuery(g_hSqlTuple, "SQL_Handler", g_szQuery, g_eSqlData, sizeof(g_eSqlData))
}

public plugin_end() {
	g_bPluginEnded = true
}

public plugin_natives() {
	set_native_filter("native_filter")
}

/*  *   trap        - 0 if native couldn't be found, 1 if native use was attempted
 * @note The handler should return PLUGIN_CONTINUE to let the error through the
 *       filter (which will throw a run-time error), or return PLUGIN_HANDLED
 *       to continue operation. */
public native_filter(const szNativeName[], iNativeID, iTrapMode) {
	return !iTrapMode
}

stock bind_cvar_num(const cvar[], const value[], flags = FCVAR_NONE, const desc[] = "", bool:has_min = false, Float:min_val = 0.0, bool:has_max = false, Float:max_val = 0.0, &bind) {
	bind_pcvar_num(create_cvar(cvar, value, flags, desc, has_min, min_val, has_max, max_val), bind);
}

stock bind_cvar_float(const cvar[], const value[], flags = FCVAR_NONE, const desc[] = "", bool:has_min = false, Float:min_val = 0.0, bool:has_max = false, Float:max_val = 0.0, &Float:bind) {
	bind_pcvar_float(create_cvar(cvar, value, flags, desc, has_min, min_val, has_max, max_val), bind);
}

stock bind_cvar_string(const cvar[], const value[], flags = FCVAR_NONE, const desc[] = "", bool:has_min = false, Float:min_val = 0.0, bool:has_max = false, Float:max_val = 0.0, bind[], maxlen) {
	bind_pcvar_string(create_cvar(cvar, value, flags, desc, has_min, min_val, has_max, max_val), bind, maxlen);
}

stock bind_cvar_num_by_name(const szCvarName[], &iBindVariable) {
	bind_pcvar_num(get_cvar_pointer(szCvarName), iBindVariable);
}

stock bind_cvar_float_by_name(const szCvarName[], &Float:fBindVariable) {
	bind_pcvar_float(get_cvar_pointer(szCvarName), fBindVariable);
}

stock bool:check_menu_by_menuid(pPlayer, iMenuIdToCheck) {
	new iMenuID, iKeys
	get_user_menu(pPlayer, iMenuID, iKeys)
	return (iMenuID == iMenuIdToCheck)
}

stock bool:is_player_see_menu(pPlayer, iMenuIdToIgnore = 0) {
	new iMenuID, iKeys
	get_user_menu(pPlayer, iMenuID, iKeys)
	return (iMenuID && iMenuID != iMenuIdToIgnore)
}

stock close_menu(pPlayer) {
	show_menu(pPlayer, 0, "", 0)
}

stock mysql_escape_string(szString[], iMaxLen) {
	static const szReplaceWhat[][] = { "\\", "\x00", "\0", "\n", "\r", "\x1a", "'", "^"", "%" }
	static const szReplaceWith[][] = { "\\\\", "\\0", "\\0", "\\n", "\\r", "\\Z", "\'", "\^"", "\%" }

	for(new i; i < sizeof(szReplaceWhat); i++) {
		replace_string(szString, iMaxLen, szReplaceWhat[i], szReplaceWith[i])
	}
}