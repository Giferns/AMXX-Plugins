#include <amxmodx>

public plugin_init() {
	register_plugin("Test plugin", "1.0", "mx?!")

	server_print("It's alive!")
}