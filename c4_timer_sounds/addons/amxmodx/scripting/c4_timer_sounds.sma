#include amxmodx
#include reapi

new const PLUGIN_VERSION[] = "1.1"

enum _:SoundsEnum {
	SOUND__1,
	SOUND__2,
	SOUND__3,
	SOUND__4,
	SOUND__5,
	SOUND__6,
	SOUND__7,
	SOUND__8,
	SOUND__9,
	SOUND__10,
	SOUND__20,
	SOUND__PLANT,
	SOUND__EXPLODE
}

new const g_szSounds[SoundsEnum][] = {
	"sound/bts/1_sec.mp3",
	"sound/bts/2_sec.mp3",
	"sound/bts/3_sec.mp3",
	"sound/bts/4_sec.mp3",
	"sound/bts/5_sec.mp3",
	"sound/bts/6_sec.mp3",
	"sound/bts/7_sec.mp3",
	"sound/bts/8_sec.mp3",
	"sound/bts/9_sec.mp3",
	"sound/bts/10_sec.mp3",
	"sound/bts/20_sec.mp3",
	"bts/jopki3.wav",
	"bts/finish3.wav"
}

const TASKID__TIMER = 1337

new HookChain:g_hRestartRound, g_iTimer

public plugin_precache() {
	register_plugin("C4 Timer Sounds", PLUGIN_VERSION, "mx?!")

	precache_sound(g_szSounds[SOUND__PLANT])
	precache_sound(g_szSounds[SOUND__EXPLODE])

	for(new i = SOUND__20; i > 0; i--) {
		precache_generic(g_szSounds[i])
	}
}

public plugin_init() {
	if(!get_member_game(m_bMapHasBombTarget) && !get_member_game(m_bMapHasBombZone)) {
		pause("ad")
		return
	}

	RegisterHookChain(RG_PlantBomb, "PlantBomb_Post", true)
	RegisterHookChain(RG_CGrenade_ExplodeBomb, "CGrenade_ExplodeBomb_Post", true)
	RegisterHookChain(RG_CGrenade_DefuseBombEnd, "CGrenade_DefuseBombEnd_Post", true)
	g_hRestartRound = RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre")
	DisableHookChain(g_hRestartRound)
}

public PlantBomb_Post(const index, Float:vecStart[3], Float:vecVelocity[3]) {
	if(is_nullent(GetHookChainReturn(ATYPE_INTEGER))) {
		return
	}

	EnableHookChain(g_hRestartRound)
	client_cmd(0, "spk %s", g_szSounds[SOUND__PLANT])
	g_iTimer = get_member_game(m_iC4Timer)
	set_task(1.0, "task_Timer", TASKID__TIMER, .flags = "b")
}

public task_Timer() {
	g_iTimer--

	switch(g_iTimer) {
		case 20: client_cmd(0, "mp3 play %s", g_szSounds[SOUND__20])
		case 1..10: {
			client_cmd(0, "mp3 play %s", g_szSounds[g_iTimer - 1])

			if(g_iTimer == 1) {
				remove_task(TASKID__TIMER)
			}
		}
	}
}

public CGrenade_ExplodeBomb_Post(const this, tracehandle, const bitsDamageType) {
	set_task(1.5, "task_PlayExplode")
}

public task_PlayExplode() {
	client_cmd(0, "spk %s", g_szSounds[SOUND__EXPLODE])
}

public CGrenade_DefuseBombEnd_Post(const this, const player, bool:bDefused) {
	if(bDefused) {
		remove_task(TASKID__TIMER)
	}
}

public CSGameRules_RestartRound_Pre() {
	DisableHookChain(g_hRestartRound)
	remove_task(TASKID__TIMER)
}