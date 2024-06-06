#include amxmodx
#include reapi

public plugin_init() {
	register_plugin("Immunity at RestartRound", "1.0", "mx?!")

	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre")
}

public CSGameRules_RestartRound_Pre() {
	remove_task(1337)
	set_task(5.0, "task_Reset", 1337)
	set_cvar_float("mp_respawn_immunitytime", 3.0)
}

public task_Reset() {
	set_cvar_num("mp_respawn_immunitytime", 0)
}