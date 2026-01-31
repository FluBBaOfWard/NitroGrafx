#include <nds.h>
#include <stdio.h>
#include <string.h>

#include "FileHandling.h"
#include "Main.h"
#include "Shared/EmuMenu.h"
#include "Shared/EmuSettings.h"
#include "Shared/FileHelper.h"
#include "Gui.h"
#include "Equates.h"
#include "cueparser/cue2toc.h"
#include "cdrom.h"
#include "Gfx.h"
#include "io.h"

#define STATESIZE (0x2000+0x2000+0x10600+0x40+80+0x160+4)
static const char *const folderName = "nitrografx";
static const char *const settingName = "settings.cfg";
static const char *const bramName = "nitrografx.brm";

bool biosLoaded = false;
bool hucardLoaded = false;

int cdReadPtr;
int cdIsBinCue;
char cdBuffer[0x4000];

static FILE *cdFile = NULL;
static int cdWritePtr;
static int cdDataLeft;
static int cdDatatrackMode;

ConfigData cfg;

static char cdGamePath[FILEPATH_MAX_LENGTH];

//---------------------------------------------------------------------------------
void applyConfigData(void) {
	emuSettings  = cfg.emuSettings & ~EMUSPEED_MASK; // Clear speed setting.
	sprCollision = cfg.sprites;
	gConfigSet   = cfg.config;
	gScalingSet  = cfg.scaling & 3;
	gFlicker     = cfg.flicker & 1;
	gGammaValue  = cfg.gammaValue & 0x7;
	gColorValue  = (cfg.gammaValue >> 4) & 0x7;
	sleepTime    = cfg.sleepTime;
	joyCfg       = (joyCfg &~ 0x04000400) | ((cfg.controller & 1) << 10) | ((cfg.controller & 2) << 25); // SwapAB & multitap.
	strlcpy(currentDir, cfg.currentPath, sizeof(currentDir));
	pauseEmulation = emuSettings & AUTOPAUSE_EMULATION;
}

void updateConfigData(void) {
	strcpy(cfg.magic, "cfg");
	cfg.emuSettings = emuSettings & ~EMUSPEED_MASK; // Clear speed setting.
//	cfg.dipSwitch0  = gDipSwitch0;
	cfg.sprites     = sprCollision;
	cfg.config      = gConfigSet;
	cfg.scaling     = gScalingSet & 3;
	cfg.flicker     = gFlicker & 1;
	cfg.gammaValue  = (gGammaValue & 0x7) | ((gColorValue & 0x7) << 4);
	cfg.sleepTime   = sleepTime;
	cfg.controller  = ((joyCfg >> 10) & 1) | ((joyCfg >> 25) & 2);
	strlcpy(cfg.currentPath, currentDir, sizeof(cfg.currentPath));
}

void initSettings() {
	memset(&cfg, 0, sizeof(cfg));
	cfg.emuSettings = AUTOPAUSE_EMULATION | AUTOSLEEP_OFF;
	cfg.sprites     = 0x20;
	cfg.config      = 0x80; // Bios on
	cfg.scaling     = SCALED_ASPECT;
	cfg.flicker     = 1;
	cfg.gammaValue  = 0x40; // ColorValue = 4
	cfg.sleepTime   = 60*60*5;

	applyConfigData();
}

int loadSettings() {
	FILE *file;
	if (!findFolder(folderName)
		&& (file = fopen(settingName, "r"))) {
		int len = fread(&cfg, 1, sizeof(ConfigData), file);
		fclose(file);
		if (strstr(cfg.magic, "cfg") && len == sizeof(ConfigData)) {
			applyConfigData();
			infoOutput("Settings loaded.");
			return 0;
		}
		updateConfigData();
		infoOutput("Error in settings file.");
	}
	else {
		infoOutput("Couldn't open file:");
		infoOutput(settingName);
	}
	return 1;
}

int saveSettings() {
	updateConfigData();

	FILE *file;
	if (!findFolder(folderName)
		&& (file = fopen(settingName, "w"))) {
		int len = fwrite(&cfg, 1, sizeof(ConfigData), file);
		fclose(file);
		if (len == sizeof(ConfigData)) {
			infoOutput("Settings saved.");
			return 0;
		}
		infoOutput("Couldn't save settings.");
	}
	else {
		infoOutput("Couldn't open file:");
		infoOutput(settingName);
	}
	return 1;
}

int loadNVRAM() {
	return loadBRAM();
}
int loadBRAM() {
	FILE *file;

	if (findFolder(folderName)) {
		return 1;
	}
	if ((file = fopen(bramName, "r"))) {
		fread(pceSRAM, 1, sizeof(pceSRAM), file);
		fclose(file);
		return 0;
	}
	return 1;
}

void saveNVRAM() {
	saveBRAM();
}
void saveBRAM() {
	FILE *file;

	if (!gBramChanged) {
		return;
	}
	if (findFolder(folderName)) {
		return;
	}
	if ((file = fopen(bramName, "w"))) {
		fwrite(pceSRAM, 1, sizeof(pceSRAM), file);
		fclose(file);
		gBramChanged = 0;
	}
	else {
		infoOutput("Couldn't open file:");
		infoOutput(bramName);
	}
}

void loadState() {
	if (!loadDeviceState(folderName)) {
		closeMenu();
	}
}

void saveState() {
	saveDeviceState(folderName);
}

bool loadGame(const char *gameName) {
	if (gameName) {
		cls(0);
		drawText("   Please wait, loading.", 11, 0);
		gHwFlags &= ~(SCD_DEVICE|SCD_CARD|AC_CARD|SGX_DEVICE);
		g_ROM_Size = loadPCEROM(ROM_Space, gameName, sizeof(ROM_Space));
		if (g_ROM_Size) {
			biosLoaded = false;
			cdInserted = 0;
			hucardLoaded = true;
			setEmuSpeed(0);
			loadCart();
			if (emuSettings & AUTOLOAD_STATE) {
				loadState();
			}
			powerIsOn = true;
			closeMenu();
			return false;
		}
	}
	return true;
}

void selectGame() {
	pauseEmulation = true;
	ui10();
	const char *gameName = browseForFileType(FILEEXTENSIONS".zip");
	if (loadGame(gameName)) {
		backOutOfMenu();
	}
}

void selectBios() {
	const char *biosName = browseForFileType(FILEEXTENSIONS".zip");
	cls(0);
	if (biosName) {
		strlcpy(cfg.biosPath, currentDir, sizeof(cfg.biosPath));
		strlcat(cfg.biosPath, "/", sizeof(cfg.biosPath));
		strlcat(cfg.biosPath, biosName, sizeof(cfg.biosPath));
		biosLoaded = false;
	}
}

int loadPCEROM(void *dest, const char *fName, const int maxSize) {
	int size = loadROM(dest, fName, maxSize);
	if ((size & 0x3FF) == 0x200) {
		size -= 0x200;
		infoOutput("Useless header, relocating ROM.");
		memcpy(dest, dest+0x200, size);
	}
	return size;
}

int loadBIOS(void *dest, const char *fPath, const int maxSize) {
	char tempString[FILEPATH_MAX_LENGTH];
	char *sPtr;

	strcpy(tempString, fPath);
	if ((sPtr = strrchr(tempString, '/'))) {
		sPtr[0] = 0;
		sPtr += 1;
		chdir("/");
		chdir(tempString);
		g_ROM_Size = loadPCEROM(dest, sPtr, maxSize);
		return g_ROM_Size;
	}
	return 0;
}

int loadUSBIOS(void) {
	if (loadBIOS(biosSpace, cfg.biosPath, sizeof(biosSpace))) {
		g_BIOSBASE = biosSpace;
		biosLoaded = true;
		return 1;
	}
	g_BIOSBASE = 0;
	return 0;
}

void selectCDROM() {
	char fileExt[8];

	pauseEmulation = 1;
	const char *cdName = browseForFileType(".iso.cue");
	cls(0);
	if (cdName) {
		getFileExtension(fileExt, cdName);
		if (strstr(fileExt, ".cue")) {
			CD_ConvertCueFile(cdName);
			cdIsBinCue = 1;
		}
		else {
			strcpy(cdGamePath, cdName);
			cdDatatrackMode = 4;
			cdIsBinCue = 0;
		}
		if (cdFile) {
			fclose(cdFile);
			cdFile = NULL;
		}
		if ((cdFile = fopen(cdGamePath, "r"))) {
			cdInserted = 1;
			fseek(cdFile, 0, SEEK_END);
			cdFileSize = ftell(cdFile);
			fseek(cdFile, 0, SEEK_SET);
			if (!biosLoaded) {
				loadUSBIOS();
			}
			if (biosLoaded) {
				g_ROM_Size = sizeof(biosSpace);
				setEmuSpeed(0);
				loadCart();
				if (emuSettings & AUTOLOAD_STATE) {
					loadState();
				}
				powerIsOn = true;
				closeMenu();
			}
		}
		else {
			infoOutput("Couldn't open CD file:");
			cdInserted = 0;
		}
	}
}

int CD_ReadByte() {
	int i = 0;

	if (cdDataLeft == 0) {
		if (cdDatatrackMode == 8) {
			fread(cdBuffer, 1, 2352, cdFile);
		}
		else {
			fread(&cdBuffer[16], 1, 2048, cdFile);
		}
		cdDataLeft = 2048;
	}
	i = cdBuffer[2064-cdDataLeft];
	cdDataLeft--;
	return i;
}

int CD_FetchAudio(int len, char *dest) {
	int i;
	for (i = 0; i < len; i++) {
		dest[i] = cdBuffer[(cdReadPtr & (sizeof(cdBuffer)-1))];
		cdReadPtr++;
	}
	return len;
}

int CD_FetchAudioSample(void) {
	int *ptr;
	ptr = (int *)&cdBuffer[(cdReadPtr & (sizeof(cdBuffer)-4))];
	return *ptr;
}

void CD_FillBuffer(void) {
	int ptr, len, i, dLen;
	int left = 0x1000;

	while ( (len = cdReadPtr+sizeof(cdBuffer)-cdWritePtr) > 0) {
		if (len > left) {
			len = left;
		}
		ptr = (cdWritePtr & (sizeof(cdBuffer)-1));
		if ((len+ptr) > sizeof(cdBuffer)) {
			len = sizeof(cdBuffer) - ptr;
		}
		dLen = fread(&cdBuffer[ptr], 1, len, cdFile);
		left -= dLen;
		if (len > dLen) {
			ptr += dLen;
			dLen = len - dLen;
			for (i = 0; i < dLen; i++) {
				cdBuffer[ptr++] = 0;
			}
		}
		cdWritePtr += len;
		if (left <= 0) {
			return;
		}
	}
}

void CD_SeekPos(int pos) {
	fseek(cdFile, pos, SEEK_SET);
	cdDataLeft = 0;
}

void CD_ResetBuffer(void) {
	cdReadPtr = 0;
	cdWritePtr = 0;
//	CD_FillBuffer();
}

void CD_ConvertCueFile(const char *fName) {
	int i, val = 0;
	struct cuesheet *cs;
	const char *binName;

	cs = read_cue(fName);
	if ((binName = strrchr(cs->file, '\\')) || (binName = strrchr(cs->file, '/'))) {
		binName += 1;
	}
	else {
		binName = cs->file;
	}
	strlcpy(cdGamePath, binName, sizeof(cdGamePath));

	strcpy(CDROM_TOC,"TGCD0100");
	CDROM_TOC[0x08] = 0;
	CDROM_TOC[0x09] = 0;
	CDROM_TOC[0x0A] = 0;
	CDROM_TOC[0x0B] = 0;
	CDROM_TOC[0x0C] = cs->trackcount;

	for (i = 0; i < cs->trackcount; i++) {
		if (cs->tracklist[i].mode == AUDIO) {
			CDROM_TOC[0x10 + i*8] = 0;
		}
		else if (cs->tracklist[i].mode == MODE1_RAW) {
			cdDatatrackMode = CDROM_TOC[0x10 + i*8] = 8;
		}
		else {
			cdDatatrackMode = CDROM_TOC[0x10 + i*8] = 4;
		}
		val = cs->tracklist[i].start * 2352;
		CDROM_TOC[0x14 + i*8] = val;
		CDROM_TOC[0x15 + i*8] = (val>>8);
		CDROM_TOC[0x16 + i*8] = (val>>16);
		CDROM_TOC[0x17 + i*8] = (val>>24);

		val = cs->tracklist[i].LBA;
		CDROM_TOC[0x11 + i*8] = (val>>16);
		CDROM_TOC[0x12 + i*8] = (val>>8);
		CDROM_TOC[0x13 + i*8] = val;
	}
	free(cs);
}
