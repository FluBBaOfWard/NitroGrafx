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

#define EMUVERSION "V0.9.0 2026-01-27"

// Asm functions
extern void paletteTxAll(void);		// VCE.s
extern void calcVBL(void);			// VDC.s

static void gammaChange(void);
static void collisionSet(void);
static const char *getCollisionText(void);
static void countrySet(void);
static const char *getCountryText(void);
static void machineSet(void);
static const char *getMachineText(void);
static void controllerSet(void);
static const char *getControllerText(void);
static void swapABSet(void);
static const char *getSwapABText(void);
static void joypadButtonSet(void);
static const char *getJoypadButtonText(void);
static void rffSet(void);
static const char *getRFFText(void);
static void multiTapSet(void);
static const char *getMultiTapText(void);
static void scalingSet(void);
static const char *getScalingText(void);
static void colorSet(void);
static const char *getColorText(void);
static void ycbcrSet(void);
static const char *getYCbCrText(void);
static void bgrLayerSet(void);
static const char *getBgrLayerText(void);
static void sprLayerSet(void);
static const char *getSprLayerText(void);

const MItem dummyItems[] = {
	{"", uiDummy},
};
const MItem fileItems[] = {
	{"Load Hucard", selectGame},
	{"Load CDROM", selectCDROM},
	{"Load State", loadState},
	{"Save State", saveState},
	{"Save Settings", saveSettings},
	{"Eject Game", ejectGame},
	{"Power On/Off", powerOnOff},
	{"Reset Game", resetGame},
	{"Quit Emulator", ui9},
};
const MItem optionItems[] = {
	{"Controller", ui4},
	{"Display", ui5},
	{"Machine", ui6},
	{"Settings", ui7},
	{"Debug", ui8},
};
const MItem ctrlItems[] = {
	{"MultiTap:  ", multiTapSet, getMultiTapText},
	{"Controller:", controllerSet, getControllerText},
	{"Joypad:    ", joypadButtonSet, getJoypadButtonText},
	{"B Autofire:", autoBSet, getAutoBText},
	{"A Autofire:", autoASet, getAutoAText},
	{"Swap A-B:  ", swapABSet, getSwapABText},
	{"Use R as FastForward:", rffSet, getRFFText},
};
const MItem displayItems[] = {
	{"Display:", scalingSet, getScalingText},
	{"Scaling:", flickSet, getFlickText},
	{"Output:", ycbcrSet, getYCbCrText},
	{"Gamma:", gammaChange, getGammaText},
	{"Color:", colorSet, getColorText},
};
const MItem machineItems[] = {
	{"Region:", countrySet, getCountryText},
	{"Machine:", machineSet, getMachineText},
	{"Select BIOS", selectBios},
	{"Fake Spritecollision:", collisionSet, getCollisionText},
};
const MItem setItems[] = {
	{"Speed:", speedSet, getSpeedText},
	{"Autoload State:", autoStateSet, getAutoStateText},
	{"Autoload NVRAM:", autoNVRAMSet, getAutoNVRAMText},
	{"Autosave Settings:", autoSettingsSet, getAutoSettingsText},
	{"Autopause Game:", autoPauseGameSet, getAutoPauseGameText},
	{"Powersave 2nd Screen:", powerSaveSet, getPowerSaveText},
	{"Emulator on Bottom:", screenSwapSet, getScreenSwapText},
//	{"Autosleep:", sleepSet, getSleepText},
};
const MItem debugItems[] = {
	{"Debug Output:", debugTextSet, getDebugText},
	{"Disable Background:", bgrLayerSet, getBgrLayerText},
	{"Disable Sprites:", sprLayerSet, getSprLayerText},
	//{"Step Frame", stepFrame},
};
const MItem quitItems[] = {
	{"Yes ", exitEmulator},
	{"No ", backOutOfMenu},
};

const Menu menu0 = MENU_M("", uiNullNormal, dummyItems);
Menu menu1 = MENU_M("", uiAuto, fileItems);
const Menu menu2 = MENU_M("", uiAuto, optionItems);
const Menu menu3 = MENU_M("", uiAbout, dummyItems);
const Menu menu4 = MENU_M("Controller Settings", uiAuto, ctrlItems);
const Menu menu5 = MENU_M("Display Settings", uiAuto, displayItems);
const Menu menu6 = MENU_M("Machine Settings", uiAuto, machineItems);
const Menu menu7 = MENU_M("Settings", uiAuto, setItems);
const Menu menu8 = MENU_M("Debug", uiAuto, debugItems);
const Menu menu9 = MENU_M("Quit Emulator?", uiAuto, quitItems);
const Menu menu10 = MENU_M("", uiDummy, dummyItems);

const Menu *const menus[] = {&menu0, &menu1, &menu2, &menu3, &menu4, &menu5, &menu6, &menu7, &menu8, &menu9, &menu10 };

static const char *const ctrlTxt[]={"P1", "P2", "P3", "P4", "P5"};
static const char *const joypadTxt[]={"2 Button", "6 Button"};
static const char *const dispTxt[]={"Scaled 1:1", "Scaled to fit", "Scaled to aspect"};
static const char *const machTxt[]={"Auto", "PC-Engine", "CD-ROM", "Super CD-ROM", "Arcade CD-ROM", "Super Grafx", "Super CD-ROM Card", "TurboGrafx-16"};
static const char *const cntrTxt[]={"US", "Japan"};
static const char *const biosTxt[]={"Off", "Auto"};
static const char *const rgbTxt[]={"RGB", "Composite"};


void setupGUI() {
	keysSetRepeat(25, 4);	// Delay, repeat.
	menu1.itemCount = ARRSIZE(fileItems) - (enableExit?0:1);
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

void uiAbout() {
	cls(1);
	drawTabs();
	drawMenuText("NitroGrafx", 4, 0);
	drawMenuText("NEC PC-Engine/TurboGrafx-16 emu", 5, 0);

	drawMenuText("B:      TG16 Button 2", 7, 0);
	drawMenuText("A:      TG16 Button 1", 8, 0);
	drawMenuText("Start:  TG16 Start button", 9, 0);
	drawMenuText("Select: TG16 Select button", 10, 0);
	drawMenuText("DPad:   TG16 DPad", 11, 0);

	drawMenuText("NitroGrafx   " EMUVERSION, 21,0);
	drawMenuText("ARMH6280     " ARMH6280VERSION, 22,0);
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
			drawText("CD Access: *", 0, 0);
		}
		else {
			drawText("CD Access:  ", 0, 0);
		}
	}
}

void nullUIDebug(int key) {
	char dbgtxt[32];

	if (key & KEY_TOUCH) {
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
	if ((powerIsOn = !powerIsOn)) {
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
const char *getControllerText() {
	return ctrlTxt[(joyCfg >> 28) & 7];
}

void swapABSet() {
	joyCfg ^= 0x400;
}
const char *getSwapABText() {
	return autoTxt[(joyCfg >> 10) & 1];
}

/// Use R for FastForward
void rffSet() {
	gConfigSet ^= 0x10;
	settingsChanged = true;
}
const char *getRFFText() {
	return autoTxt[(gConfigSet >> 4) & 1];
}

void joypadButtonSet() {			// See io.s: refreshEMUjoypads
	joyCfg ^= 0x08000000;
}
const char *getJoypadButtonText() {
	return joypadTxt[(joyCfg >> 27 ) & 1];
}

void multiTapSet() {				// See io.s: refreshEMUjoypads
	joyCfg ^= 0x04000000;
	joyCfg &= ~0x70000000;
	settingsChanged = true;
}
const char *getMultiTapText() {
	return autoTxt[(joyCfg >> 26) & 1];
}

void scalingSet(){
	gScalingSet++;
	if (gScalingSet >= 3) {
		gScalingSet = 0;
	}
	calcVBL();
	refreshSprites();
	settingsChanged = true;
}
const char *getScalingText() {
	return dispTxt[gScalingSet];
}

/// Change gamma (brightness).
void gammaChange() {
	gammaSet();
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
const char *getColorText() {
	return brighTxt[gColorValue];
}

void ycbcrSet() {
	gRgbYcbcr ^= 0x01;
	paletteInit(gGammaValue);
	paletteTxAll();					// Make new palette visible
}
const char *getYCbCrText() {
	return rgbTxt[gRgbYcbcr];
}

/// Turn on/off rendering of background
void bgrLayerSet() {
	gGfxMask ^= 0x0C;
}
const char *getBgrLayerText() {
	return autoTxt[(gGfxMask >> 2) & 1];
}
/// Turn on/off rendering of sprites
void sprLayerSet() {
	gGfxMask ^= 0x10;
}
const char *getSprLayerText() {
	return autoTxt[(gGfxMask >> 4) & 1];
}

void collisionSet() {
	sprCollision ^= 0x20;
}
const char *getCollisionText() {
	return autoTxt[(sprCollision >> 5) & 1];
}

void countrySet() {
	gRegion ^= 0x01;
}
const char *getCountryText() {
	return cntrTxt[gRegion];
}

void machineSet() {
	gMachineSet++;
	if (gMachineSet > 4){
		gMachineSet = 0;
	}
}
const char *getMachineText() {
	int machine = gMachineSet;
	if (machine == HW_PCENGINE && gRegion == REGION_US) {
		machine = HW_TURBOGRAFX;
	}
	return machTxt[machine];
}
