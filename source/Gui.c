#include <nds.h>

#include "Gui.h"
#include "Shared/EmuMenu.h"
#include "Shared/EmuSettings.h"
#include "Main.h"
#include "FileHandling.h"
#include "Equates.h"
#include "Cart.h"
#include "cdrom.h"
#include "Gfx.h"
#include "io.h"
#include "ARMH6280/Version.h"

#define EMUVERSION "V0.9.0 2023-06-27"

// Asm functions
extern void paletteTxAll(void);		// VCE.s
extern void calcVBL(void);			// VDC.s

const fptr fnMain[] = {nullUI, subUI, subUI, subUI, subUI, subUI, subUI, subUI, subUI, subUI};

const fptr fnList0[] = {uiDummy};
const fptr fnList1[] = {selectGame, selectCDROM, loadState, saveState, saveSettings, ejectGame, powerOnOff, resetGame, ui8};
const fptr fnList2[] = {ui4, ui5, ui6, ui7};
const fptr fnList3[] = {uiDummy};
const fptr fnList4[] = {multiTapSet, controllerSet, joypadButtonSet, autoBSet, autoASet, swapABSet, rffSet};
const fptr fnList5[] = {scalingSet, flickSet, ycbcrSet, gammaSet, colorSet, bgrlayerSet, sprlayerSet};
const fptr fnList6[] = {countrySet, machineSet, selectBios, collisionSet};
const fptr fnList7[] = {speedSet, autoStateSet, autoSettingsSet, autoNVRAMSet, autoPauseGameSet, powerSaveSet, screenSwapSet, debugTextSet, sleepSet};
const fptr fnList8[] = {exitEmulator, backOutOfMenu};
const fptr fnList9[] = {uiDummy};
const fptr *const fnListX[] = {fnList0, fnList1, fnList2, fnList3, fnList4, fnList5, fnList6, fnList7, fnList8, fnList9};
u8 menuXItems[] = {ARRSIZE(fnList0), ARRSIZE(fnList1), ARRSIZE(fnList2), ARRSIZE(fnList3), ARRSIZE(fnList4), ARRSIZE(fnList5), ARRSIZE(fnList6), ARRSIZE(fnList7), ARRSIZE(fnList8), ARRSIZE(fnList9)};
const fptr drawUIX[] = {uiNullNormal, uiFile, uiOptions, uiAbout, uiController, uiDisplay, uiMachine, uiSettings, uiYesNo, uiDummy};

u8 gGammaValue = 0;

static const char *const autoTxt[]={"Off", "On", "With R"};
static const char *const speedTxt[]={"Normal", "Fast", "Max", "Slowmo"};
static const char *const brighTxt[]={"I", "II", "III", "IIII", "IIIII"};
static const char *const sleepTxt[]={"5min", "10min", "30min", "Off"};
static const char *const ctrlTxt[]={"P1", "P2", "P3", "P4", "P5"};
static const char *const joypadTxt[]={"2 Button", "6 Button"};
static const char *const dispTxt[]={"Scaled 1:1", "Scaled to fit", "Scaled to aspect"};
static const char *const flickTxt[]={"No Flicker", "Flicker"};
static const char *const machTxt[]={"Auto", "PC-Engine", "CD-ROM", "Super CD-ROM", "Arcade CD-ROM", "Super Grafx", "Super CD-ROM Card", "TurboGrafx-16"};
static const char *const cntrTxt[]={"US", "Japan"};
static const char *const biosTxt[]={"Off", "Auto"};
static const char *const rgbTxt[]={"RGB", "Composite"};


void setupGUI() {
	emuSettings = AUTOPAUSE_EMULATION | AUTOSLEEP_OFF;
	keysSetRepeat(25, 4);	// Delay, repeat.
	menuXItems[1] = ARRSIZE(fnList1) - (enableExit?0:1);
	openMenu();
}

/// This is called when going from emu to ui.
void enterGUI() {
}

/// This is called going from ui to emu.
void exitGUI() {
}

void quickSelectGame(void) {
	selectGame();
	closeMenu();
}

void uiNullNormal() {
	uiNullDefault();
}

void uiFile() {
	setupMenu();
	drawMenuItem("Load Hucard");
	drawMenuItem("Load CDROM");
	drawMenuItem("Load State");
	drawMenuItem("Save State");
	drawMenuItem("Save Settings");
	drawMenuItem("Eject Game");
	drawMenuItem("Power On/Off");
	drawMenuItem("Reset Game");
	if (enableExit) {
		drawMenuItem("Quit Emulator");
	}
}

void uiOptions() {
	setupMenu();
	drawMenuItem("Controller");
	drawMenuItem("Display");
	drawMenuItem("Machine");
	drawMenuItem("Settings");
}

void uiAbout() {
	cls(1);
	drawTabs();
	drawMenuText("NitroGrafx", 4, 0);
	drawMenuText("NEC PC-Engine/TurboGrafx-16 emu", 5, 0);

	drawMenuText("B:      Button 2", 7, 0);
	drawMenuText("A:      Button 1", 8, 0);
	drawMenuText("Start:  Start button", 9, 0);
	drawMenuText("Select: Select button", 10, 0);
	drawMenuText("DPad:   Move character", 11, 0);

	drawMenuText("NitroGrafx   " EMUVERSION, 21,0);
	drawMenuText("ARMH6280     " ARMH6280VERSION, 22,0);
}

void uiController() {
	setupSubMenu("Controller Settings");
	drawSubItem("MultiTap:  ", autoTxt[(joyCfg>>26)&1]);
	drawSubItem("Controller:", ctrlTxt[(joyCfg>>28)&7]);
	drawSubItem("Joypad:    ", joypadTxt[(joyCfg>>27)&1]);
	drawSubItem("B Autofire:", autoTxt[autoB]);
	drawSubItem("A Autofire:", autoTxt[autoA]);
	drawSubItem("Swap A-B:  ", autoTxt[(joyCfg>>10)&1]);
	drawSubItem("Use R as FastForward:", autoTxt[(gConfigSet>>4)&1]);
}

void uiDisplay() {
	setupSubMenu("Display Settings");
	drawSubItem("Display:", dispTxt[gScalingSet]);
	drawSubItem("Scaling:", flickTxt[gFlicker]);
	drawSubItem("Output:", rgbTxt[gRgbYcbcr]);
	drawSubItem("Gamma:", brighTxt[gGammaValue]);
	drawSubItem("Color:", brighTxt[gColorValue]);
	drawSubItem("Disable Background:", autoTxt[gGfxMask&1]);
	drawSubItem("Disable Sprites:", autoTxt[(gGfxMask>>4)&1]);
}

void uiMachine() {
	int machine = gMachineSet;
	if (machine == HW_PCENGINE && gRegion == REGION_US) {
		machine = HW_TURBOGRAFX;
	}
	setupSubMenu("Machine Settings");
	drawSubItem("Region:", cntrTxt[gRegion]);
	drawSubItem("Machine:", machTxt[machine]);
	drawSubItem("Select BIOS", NULL);
	drawSubItem("Fake Spritecollision:", autoTxt[(sprCollision>>5)&1]);
}

void uiSettings() {
	setupSubMenu("Settings");
	drawSubItem("Speed:", speedTxt[(emuSettings>>6)&3]);
	drawSubItem("Autoload State:", autoTxt[(emuSettings>>2)&1]);
	drawSubItem("Autosave Settings:", autoTxt[(emuSettings>>9)&1]);
	drawSubItem("Autosave BRAM:", autoTxt[(emuSettings>>10)&1]);
	drawSubItem("Autopause Game:", autoTxt[emuSettings&1]);
	drawSubItem("Powersave 2nd Screen:", autoTxt[(emuSettings>>1)&1]);
	drawSubItem("Emulator on Bottom:", autoTxt[(emuSettings>>8)&1]);
	drawSubItem("Debug Output:", autoTxt[gDebugSet&1]);
	drawSubItem("Autosleep:", sleepTxt[(emuSettings>>4)&3]);
}

void nullUINormal(int key) {
	static int oldCdPos = 0;

	if (key & KEY_TOUCH) {
		openMenu();
		return;
	}
	if (cdInserted) {
		if (oldCdPos != currentPos) {
			oldCdPos = currentPos;
			drawText("CD Access: *",0,0);
		} else {
			drawText("CD Access:  ",0,0);
		}
	}
}

void nullUIDebug(int key) {
	char dbgtxt[32];

	if (key&KEY_TOUCH) {
		openMenu();
		return;
	}
	if (cdInserted) {
		strcpy(dbgtxt, "CD Track: ");
		char2HexStr(&dbgtxt[10], currentTrack);
		drawText(dbgtxt, 1, 0);
		strcpy(dbgtxt, "CD LBA: ");
		char2HexStr(&dbgtxt[8], currentPos>>11);
		drawText(dbgtxt, 2, 0);
	}

}

void setupKeyboard(void) {
/*	int i = 0;

	memcpy(BG_GFX_SUB+0x2000, kbTiles, sizeof(kbTiles));
	memcpy(BG_PALETTE_SUB+0x80, kbPalette, sizeof(kbPalette));
	for (i = 0; i < sizeof(kbMap)/2; i++) {
		map0sub[i] = kbMap[i] | 0x8200;
	}
*/
}


void powerOnOff() {
	if ( (powerButton = !powerButton) ) {
		if (!hucardLoaded && !biosLoaded) {
			loadUSBIOS();
		}
	}
	loadCart();
}

void ejectGame() {
	cdInserted = 0;
	if (!biosLoaded) {
		loadUSBIOS();
	}
//	ejectCart();
}

void resetGame() {
	loadCart();
}

//---------------------------------------------------------------------------------
void controllerSet() {				// See io.s: refreshEMUjoypads
	int i = joyCfg & 0x70000000;
	i += 0x10000000;
	if (i > 0x40000000 || !(joyCfg & 0x04000000)) {
		i = 0;
	}
	joyCfg = (joyCfg & ~0x70000000) | i;
}

void swapABSet() {
	joyCfg ^= 0x400;
}

/// Use R for FastForward
void rffSet() {
	gConfigSet ^= 0x10;
	settingsChanged = true;
}

void joypadButtonSet() {			// See io.s: refreshEMUjoypads
	joyCfg ^= 0x08000000;
}

void multiTapSet() {				// See io.s: refreshEMUjoypads
	joyCfg ^= 0x04000000;
	joyCfg &= ~0x70000000;
	settingsChanged = true;
}


void scalingSet(){
	gScalingSet++;
	if (gScalingSet >= 3) {
		gScalingSet = 0;
	}
	calcVBL();
	settingsChanged = true;
}

/// Change gamma (brightness).
void gammaSet() {
	gGammaValue++;
	if (gGammaValue > 4) {
		gGammaValue = 0;
	}
	paletteInit(gGammaValue);
	paletteTxAll();					// Make new palette visible
	setupMenuPalette();
	settingsChanged = true;
}

/// Change color saturation.
void colorSet() {
	gColorValue++;
	if (gColorValue > 4) {
		gColorValue = 0;
	}
	paletteInit(gGammaValue);
	paletteTxAll();					// Make new palette visible
	settingsChanged = true;
}

void ycbcrSet() {
	gRgbYcbcr ^= 0x01;
	paletteInit(gGammaValue);
	paletteTxAll();					// Make new palette visible
}

void bgrlayerSet() {
	gGfxMask ^= 0x03;
}

void sprlayerSet() {
	gGfxMask ^= 0x10;
}


void collisionSet() {
	sprCollision ^= 0x20;
}

void countrySet() {
	gRegion ^= 0x01;
}

void machineSet() {
	gMachineSet++;
	if (gMachineSet > 4){
		gMachineSet = 0;
	}
}
