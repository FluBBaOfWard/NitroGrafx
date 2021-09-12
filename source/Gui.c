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

#define EMUVERSION "V0.9.0 2021-09-12"

// Asm functions
extern void paletteTxAll(void);		// VCE.s
extern void calcVBL(void);			// vdc.s

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
u8 menuXitems[] = {ARRSIZE(fnList0), ARRSIZE(fnList1), ARRSIZE(fnList2), ARRSIZE(fnList3), ARRSIZE(fnList4), ARRSIZE(fnList5), ARRSIZE(fnList6), ARRSIZE(fnList7), ARRSIZE(fnList8), ARRSIZE(fnList9)};
const fptr drawuiX[] = {uiNullNormal, uiFile, uiOptions, uiAbout, uiController, uiDisplay, uiMachine, uiSettings, uiYesNo, uiDummy};
const u8 menuXback[] = {0,0,0,0,2,2,2,2,1,8};

u8 g_gammaValue = 0;

static const char *const autoTxt[]={"Off","On","With R"};
static const char *const speedTxt[]={"Normal","Fast","Max","Slowmo"};
static const char *const sleepTxt[]={"5min","10min","30min","Off"};
static const char *const brighTxt[]={"I","II","III","IIII","IIIII"};
static const char *const ctrlTxt[]={"P1","P2","P3","P4","P5"};
static const char *const joypadTxt[]={"2 button","6 button"};
static const char *const dispTxt[]={"Scaled 1:1","Scaled to fit","Scaled to aspect"};
static const char *const flickTxt[]={"No Flicker","Flicker"};
static const char *const cntrTxt[]={"US","Japan"};
static const char *const machTxt[]={"Auto","PC-Engine","CD-ROM","Super CD-ROM","Arcade CD-ROM","Super Grafx","Super CD-ROM Card","TurboGrafx-16"};
static const char *const biosTxt[]={"Off","Auto"};
static const char *const rgbTxt[]={"RGB","Composite"};


void setupGUI() {
	emuSettings = AUTOPAUSE_EMULATION | AUTOSLEEP_OFF;
	keysSetRepeat(25, 4);	// Delay, repeat.
	menuXitems[1] = ARRSIZE(fnList1) - (enableExit?0:1);
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
	drawText(" NitroGrafx", 4, 0);
	drawText(" NEC PC-Engine/TurboGrafx-16 emu", 5, 0);

	drawText(" B:      Button 2", 7, 0);
	drawText(" A:      Button 1", 8, 0);
	drawText(" Start:  Start button", 9, 0);
	drawText(" Select: Select button", 10, 0);
	drawText(" DPad:   Move character", 11, 0);

	drawText(" NitroGrafx   " EMUVERSION,21,0);
	drawText(" ARMH6280     " ARMH6280VERSION,22,0);
}

void uiController() {
	setupSubMenu(" Controller Settings");
	drawSubItem("MultiTap:   ", autoTxt[(joyCfg>>26)&1]);
	drawSubItem("Controller: ", ctrlTxt[(joyCfg>>28)&7]);
	drawSubItem("Joypad:     ", joypadTxt[(joyCfg>>27)&1]);
	drawSubItem("B Autofire: ", autoTxt[autoB]);
	drawSubItem("A Autofire: ", autoTxt[autoA]);
	drawSubItem("Swap A-B:   ", autoTxt[(joyCfg>>10)&1]);
	drawSubItem("Use R as FastForward: ", autoTxt[(g_configSet>>4)&1]);
}

void uiDisplay() {
	setupSubMenu(" Display Settings");
	drawSubItem("Display: ", dispTxt[g_scalingSet]);
	drawSubItem("Scaling: ", flickTxt[g_flicker]);
	drawSubItem("Output: ", rgbTxt[g_rgb_ycbcr]);
	drawSubItem("Gamma: ", brighTxt[g_gammaValue]);
	drawSubItem("Color: ", brighTxt[g_colorValue]);
	drawSubItem("Disable Background: ", autoTxt[g_gfxMask&1]);
	drawSubItem("Disable Sprites: ", autoTxt[(g_gfxMask>>4)&1]);
}

void uiMachine() {
	int machine = g_machineSet;
	if (machine == HW_PCENGINE && g_region == REGION_US) {
		machine = HW_TURBOGRAFX;
	}
	setupSubMenu(" Machine Settings");
	drawSubItem("Region: ", cntrTxt[g_region]);
	drawSubItem("Machine: ", machTxt[machine]);
	drawSubItem("Select BIOS", 0);
	drawSubItem("Fake Spritecollision: ", autoTxt[(sprCollision>>5)&1]);
}

void uiSettings() {
	setupSubMenu(" Settings");
	drawSubItem("Speed: ", speedTxt[(emuSettings>>6)&3]);
	drawSubItem("Autoload State: ", autoTxt[(emuSettings>>2)&1]);
	drawSubItem("Autosave Settings: ", autoTxt[(emuSettings>>9)&1]);
	drawSubItem("Autosave BRAM: ", autoTxt[(emuSettings>>10)&1]);
	drawSubItem("Autopause Game: ", autoTxt[emuSettings&1]);
	drawSubItem("Powersave 2nd Screen: ", autoTxt[(emuSettings>>1)&1]);
	drawSubItem("Emulator on Bottom: ", autoTxt[(emuSettings>>8)&1]);
	drawSubItem("Debug Output: ", autoTxt[g_debugSet&1]);
	drawSubItem("Autosleep: ", sleepTxt[(emuSettings>>4)&3]);
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
	g_configSet ^= 0x10;
	settingsChanged = 1;
}

void joypadButtonSet() {			// See io.s: refreshEMUjoypads
	joyCfg ^= 0x08000000;
}

void multiTapSet() {				// See io.s: refreshEMUjoypads
	joyCfg ^= 0x04000000;
	joyCfg &= ~0x70000000;
	settingsChanged = 1;
}


void scalingSet(){
	g_scalingSet++;
	if (g_scalingSet >= 3) {
		g_scalingSet = 0;
	}
	calcVBL();
	settingsChanged = 1;
}

/// Change gamma (brightness).
void gammaSet() {
	g_gammaValue++;
	if (g_gammaValue > 4) {
		g_gammaValue = 0;
	}
	paletteInit(g_gammaValue);
	paletteTxAll();					// Make new palette visible
	setupMenuPalette();
	settingsChanged = 1;
}

/// Change color saturation.
void colorSet() {
	g_colorValue++;
	if (g_colorValue > 4) {
		g_colorValue = 0;
	}
	paletteInit(g_gammaValue);
	paletteTxAll();					// Make new palette visible
	settingsChanged = 1;
}

void ycbcrSet() {
	g_rgb_ycbcr ^= 0x01;
	paletteInit(g_gammaValue);
	paletteTxAll();					// Make new palette visible
}

void bgrlayerSet() {
	g_gfxMask ^= 0x03;
}

void sprlayerSet() {
	g_gfxMask ^= 0x10;
}


void collisionSet() {
	sprCollision ^= 0x20;
}

void countrySet() {
	g_region ^= 0x01;
}

void machineSet() {
	g_machineSet++;
	if (g_machineSet > 4){
		g_machineSet = 0;
	}
}
