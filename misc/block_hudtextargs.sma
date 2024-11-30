/* История изменений:
	1.0 (05.11.2020) by mx?!:
		* Первый релиз
*/

new const PLUGIN_VERSION[] = "1.0"

#include <amxmodx>

public plugin_init() {
	register_plugin("Block HudTextArgs", PLUGIN_VERSION, "mx?!")

	set_msg_block(get_user_msgid("HudTextArgs"), BLOCK_SET)
}