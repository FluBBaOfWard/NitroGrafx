#ifndef EMUBASE
#define EMUBASE

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {				//(config struct)
	char magic[4];				//="CFG",0
	int emuSettings;
	int sleepTime;				// autoSleepTime
	u8 scaling;					// from gfx.s
	u8 flicker;					// from gfx.s
	u8 gammaValue;				// from gfx.s
	u8 sprites;					// from gfx.s
	u8 glasses;					// from gfx.s
	u8 config;					// from cart.s
	u8 controller;				// from io.s
	u8 dipSwitch0;				// from io.s
	char currentPath[256];
	char biosPath[256];
} ConfigData;

#ifdef __cplusplus
} // extern "C"
#endif

#endif // EMUBASE
