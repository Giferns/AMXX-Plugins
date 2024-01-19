#include amxmodx
#include amxmisc

new const PLUGIN_VERSION[] = "1.0"

new const RESLIST[] = "precache_list.ini"

public plugin_precache() {
	register_plugin("Precache List", PLUGIN_VERSION, "mx?!")

	new szPath[PLATFORM_MAX_PATH]
	new iLen = get_configsdir(szPath, charsmax(szPath))
	formatex(szPath[iLen], charsmax(szPath) - iLen, "/%s", RESLIST)

	new hFile = fopen(szPath, "r")

	if(!hFile) {
		set_fail_state("Can't %s '%s'", file_exists(szPath) ? "read" : "find", szPath)
		return
	}

	while(fgets(hFile, szPath, charsmax(szPath))) {
		trim(szPath)

		if(!szPath[0] || szPath[0] == ';' || szPath[0] == '/') {
			continue
		}

		if(strfind(szPath, ".wav") != -1) {
			replace_stringex(szPath, charsmax(szPath), "sound/", "")
			precache_sound(szPath)
		}

		if(strfind(szPath, ".mdl") != -1 || strfind(szPath, ".spr") != -1) {
			precache_model(szPath)
			continue
		}

		// .txt, .mp3, .tga
		precache_generic(szPath)
	}

	fclose(hFile)
}