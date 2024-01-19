#include amxmodx

// Звуки для прекеша (без /sound в пути; только .wav)
new const SOUNDS[][] = {
	"misc/some1.wav",
	"misc/some2.wav"
}

public plugin_precache() {
	register_plugin("Precache Sounds", "1.0", "mx?!")

	for(new i; i < sizeof(SOUNDS); i++) {
		precache_sound(SOUNDS[i])
	}
}