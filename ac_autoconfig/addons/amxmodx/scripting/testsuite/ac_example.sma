/*
	This test plugin was written to demonstrate the basic functionality of 'AC AutoConfig' (ac_autoconfig.inc).
	Just read the code bellow, then run plugin and examine 'addons/amxmodx/configs/plugins/ac_example.cfg'
*/

new const PLUGIN_VERSION[] = "1.0"

#include amxmodx
#pragma semicolon 1
#include ac_autoconfig

// Config filename without file extension (.cfg). Can be empty, then plugin filename will be used instead.
// With "ac_example" value, file path will be 'addons/amxmodx/configs/plugins/ac_example.cfg'
new const CfgFilename[] = "ac_example";

new IntValue, Float:FloatValue, StringValue[32];

public plugin_init() {
	register_plugin("AC AutoConfig Example", PLUGIN_VERSION, "mx?!");

	RegCvars();
}

RegCvars() {
	// 1. Build config file path dynamically using 'amxx_configsdir' variable
	new path[PLATFORM_MAX_PATH];
	ac_build_config_path(path, charsmax(path), CfgFilename);

	// 2. Open config file by file path for writing, but only if config file doesn't exist
	new AcFileHandle:file_handle = ac_try_open_config_file_handle(path);

	// 3. Register cvars and write their params to config file (if it was opened for writing in step 2)
	new pCvar;

	pCvar = ac_create_cvar(file_handle, "ac_test_int", "1", .description = "Test int value");
	bind_pcvar_num(pCvar, IntValue);

	pCvar = ac_create_cvar(file_handle, "ac_test_float", "0.5", .description = "Test float value", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0);
	bind_pcvar_float(pCvar, FloatValue);

	pCvar = ac_create_cvar(file_handle, "ac_test_string", "some value", .description = "Test string value");
	bind_pcvar_string(pCvar, StringValue, charsmax(StringValue));

	ac_create_cvar(file_handle, "ac_unnamed", "cvar value"); // just some cvar without description

	// 4. Close config file if it was opened for writing
	ac_try_close_config_file_handle(file_handle);

	// 5. Execute config file in synchronous mode (will load config file immediately)
	ac_exec_config(path);

	// 6. Try to execute map-based configs if they exists so they can override cvar values
	ExecMapBasedConfigs();

	// 7. From now on you can use actual (from config files) cvar values
	server_print("ac_test_int: %i", IntValue);
	server_print("ac_test_float: %f", FloatValue);
	server_print("ac_test_string: %s", StringValue);
}

ExecMapBasedConfigs() {
	new path[PLATFORM_MAX_PATH];

	// 1. Build map-based config file path dynamically using 'amxx_configsdir' variable, using map name prefix
	if(ac_build_map_config_path(path, charsmax(path), CfgFilename, .prefix_mode = true)) {
		// 2. Execute config file in synchronous mode (will load config file immediately)
		ac_exec_config(path);
	}

	// 3. Build map-based config file path dynamically using 'amxx_configsdir' variable, using full map name
	if(ac_build_map_config_path(path, charsmax(path), CfgFilename, .prefix_mode = false)) {
		// 4. Execute config file in synchronous mode (will load config file immediately)
		ac_exec_config(path);
	}
}