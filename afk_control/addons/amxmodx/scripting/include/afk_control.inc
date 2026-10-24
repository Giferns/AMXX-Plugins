#if defined _afkc_included
	#endinput
#endif
#define _afkc_included

/**
 * Called before plugin do some action (notify/kick) against specified player.
 *
 * @note Forward type: ET_STOP
 *
 * @param pPlayer    Client index
 * @param bKickMode  true if action is 'kick', false if action is 'notify'
 *
 * @return      PLUGIN_CONTINUE to allow action
 *              PLUGIN_HANDLED to block action
 */
forward AfkControl_SpecAction(pPlayer, bool:bKickMode);
