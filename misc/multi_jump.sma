#include <amxmodx>
#include <reapi>

new const PLUGIN_VERSION[] = "1.0"

// Default access value for cvar "mj_access". Set to "" to access for all.
new const DEFAULT_ACCESS[] = ""

new g_pCvarMaxJumps
new g_pCvarRoundDelay
new g_pCvarStartDelay

new g_bitAccess
new g_iMaxJumps
new g_iRoundDelay
new g_iStartDelay
new g_iRound

new g_iPlayerJumps[MAX_PLAYERS + 1]
new g_iPlayerStartRound[MAX_PLAYERS + 1]
new bool:g_bCanUseJumps[MAX_PLAYERS + 1]
new Float:g_fRoundStartTime

public plugin_init() {
    register_plugin("Multi Jump", PLUGIN_VERSION, "mx?! & mIDnight")
  
    new pCvar = create_cvar("mj_access", DEFAULT_ACCESS, .description = "Access to double jump. ^"^" - access for all.")
    g_pCvarMaxJumps = create_cvar("mj_max_jumps", "2", .description = "Maximum number of additional jumps allowed")
    g_pCvarRoundDelay = create_cvar("mj_round_delay", "3", .description = "Number of rounds a player must wait before getting jumps")
    g_pCvarStartDelay = create_cvar("mj_start_delay", "15.0", .description = "Delay in seconds from round start before jumps are enabled")

    new szValue[32]
    get_pcvar_string(pCvar, szValue, charsmax(szValue))
    hook_CvarChange(pCvar, "", szValue)
    hook_cvar_change(pCvar, "hook_CvarChange")

    RegisterHookChain(RG_CSGameRules_RestartRound, "@CSGameRules_RestartRound_Pre", .post = false)
    RegisterHookChain(RG_CBasePlayer_Spawn, "@CBasePlayer_Spawn_Post", .post = true)
    RegisterHookChain(RG_CBasePlayer_Jump, "OnPlayerJump_Pre", .post = false)

    g_iMaxJumps = get_pcvar_num(g_pCvarMaxJumps)
    g_iRoundDelay = get_pcvar_num(g_pCvarRoundDelay)
    g_iStartDelay = get_pcvar_num(g_pCvarStartDelay)
}

public hook_CvarChange(pCvar, const szOldVal[], const szNewVal[]) {
    g_bitAccess = read_flags(szNewVal)
}

@CSGameRules_RestartRound_Pre() {
    g_iRound = get_member_game(m_bCompleteReset) ? 0 : g_iRound + 1
    g_fRoundStartTime = get_gametime()
    
    g_iMaxJumps = get_pcvar_num(g_pCvarMaxJumps)
    g_iRoundDelay = get_pcvar_num(g_pCvarRoundDelay)
    g_iStartDelay = get_pcvar_num(g_pCvarStartDelay)

    for(new i = 1; i <= MaxClients; i++) {
        if(is_user_connected(i)) {
            g_iPlayerJumps[i] = 0
            
            if(g_iPlayerStartRound[i] > 0) {
                g_bCanUseJumps[i] = ((g_iRound - g_iPlayerStartRound[i]) >= g_iRoundDelay)
            }
        }
    }
}

@CBasePlayer_Spawn_Post(const id) {
    if(!is_user_alive(id))
        return

    g_iPlayerJumps[id] = 0
    
    if(g_iPlayerStartRound[id] == 0) {
        g_iPlayerStartRound[id] = g_iRound
        g_bCanUseJumps[id] = false
    }
}

public client_disconnected(id) {
    g_iPlayerJumps[id] = 0
    g_iPlayerStartRound[id] = 0
    g_bCanUseJumps[id] = false
}

public OnPlayerJump_Pre(const id) {
    if(g_bitAccess && !(get_user_flags(id) & g_bitAccess)) {
        return HC_CONTINUE
    }

    if(!g_bCanUseJumps[id]) {
        return HC_CONTINUE
    }

    if(get_gametime() - g_fRoundStartTime < float(g_iStartDelay)) {
        return HC_CONTINUE
    }

    static Float:fLastJumpTime[MAX_PLAYERS + 1]
    
    if(get_entvar(id, var_flags) & FL_ONGROUND) {
        fLastJumpTime[id] = get_gametime()
        g_iPlayerJumps[id] = 0
        return HC_CONTINUE
    }

    if(g_iPlayerJumps[id] >= g_iMaxJumps) {
        return HC_CONTINUE
    }

    static Float:fGameTime

    if(
        ( get_member(id, m_afButtonLast) & IN_JUMP) ||
        (((fGameTime = get_gametime()) - fLastJumpTime[id]) < 0.2)
    ) {
        return HC_CONTINUE
    }

    fLastJumpTime[id] = fGameTime
    new Float:fVelocity[3]
    get_entvar(id, var_velocity, fVelocity)
    fVelocity[2] = 268.0
    set_entvar(id, var_velocity, fVelocity)
    g_iPlayerJumps[id]++

    return HC_CONTINUE
}