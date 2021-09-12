#include <nds.h>
#include <fat.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/dir.h>
//#include <dirent.h>

#include "FileHandling.h"
#include "Emubase.h"
#include "Main.h"
#include "Shared/EmuMenu.h"
#include "Shared/EmuSettings.h"
#include "Gui.h"
#include "Equates.h"
#include "cueparser/cue2toc.h"
#include "Cart.h"
#include "cdrom.h"
#include "Gfx.h"
#include "io.h"

#define STATESIZE (0x2000+0x2000+0x10600+0x40+80+0x160+4)
static const char *const folderName = "nitrografx";
static const char *const settingName = "settings.cfg";
static const char *const bramName = "nitrografx.brm";

int biosLoaded = 0;
int hucardLoaded = 0;

FILE *cdFile = NULL;
int cdWritePtr;
int cdReadPtr;
int cdDataLeft;
int cdDatatrackMode;
int cdIsBinCue;
char cdBuffer[0x4000];

configdata cfg;

static char cdGamePath[FILEPATHMAXLENGTH];

//---------------------------------------------------------------------------------

int loadSettings() {
	FILE *file;

	cfg.currentPath[0] = 0;
	cfg.biosPath[0] = 0;
	if (findFolder(folderName)) {
		return 1;
	}
	if ( (file = fopen(settingName, "r")) ) {
		fread(&cfg, 1, sizeof(configdata), file);
		fclose(file);
		if (!strstr(cfg.magic,"cfg")) {
			infoOutput("Error in settings file.");
			return 1;
		}
	} else {
		infoOutput("Couldn't open file:");
		infoOutput(settingName);
		return 1;
	}

	sprCollision  = cfg.sprites;
	g_configSet   = cfg.config;
	g_scalingSet  = cfg.scaling & 3;
	g_flicker     = cfg.flicker & 1;
	g_gammaValue  = cfg.gammaValue & 0x7;
	g_colorValue  = (cfg.gammaValue>>4) & 0x7;
	emuSettings   = cfg.emuSettings & ~EMUSPEED_MASK;	// Clear speed setting.
	sleepTime     = cfg.sleepTime;
	joyCfg        = (joyCfg &~ 0x04000400) | ((cfg.controller & 1)<<10) | ((cfg.controller & 2)<<25);		// SwapAB & multitap.
	strlcpy(currentDir, cfg.currentPath, sizeof(currentDir));

	infoOutput("Settings loaded.");
	return 0;
}

void saveSettings() {
	FILE *file;

	strcpy(cfg.magic,"cfg");
//	cfg.dipswitch0  = g_dipswitch0;
	cfg.sprites     = sprCollision;
	cfg.config      = g_configSet;
	cfg.scaling     = g_scalingSet&3;
	cfg.flicker     = g_flicker&1;
	cfg.gammaValue  = (g_gammaValue&0x7)|((g_colorValue&0x7)<<4);
	cfg.emuSettings = emuSettings & ~EMUSPEED_MASK;		// Clear speed setting.
	cfg.sleepTime   = sleepTime;
	cfg.controller  = ((joyCfg>>10)&1) | ((joyCfg>>25)&2);
	strlcpy(cfg.currentPath, currentDir, sizeof(cfg.currentPath));

	if (findFolder(folderName)) {
		return;
	}
	if ( (file = fopen(settingName, "w")) ) {
		fwrite(&cfg, 1, sizeof(configdata), file);
		fclose(file);
		infoOutput("Settings saved.");
	} else {
		infoOutput("Couldn't open file:");
		infoOutput(settingName);
	}
}

int loadNVRAM() {
	return loadBRAM();
}
int loadBRAM() {
	FILE *file;

	if (findFolder(folderName)) {
		return 1;
	}
	if ( (file = fopen(bramName, "r")) ) {
		fread(EMU_SRAM, 1, sizeof(EMU_SRAM), file);
		fclose(file);
	} else {
		return 1;
	}

	return 0;
}

void saveNVRAM() {
	saveBRAM();
}
void saveBRAM() {
	FILE *file;

	if (!g_bramChanged) {
		return;
	}
	if (findFolder(folderName)) {
		return;
	}
	if ( (file = fopen(bramName, "w")) ) {
		fwrite(EMU_SRAM, 1, sizeof(EMU_SRAM), file);
		fclose(file);
		g_bramChanged = 0;
	} else {
		infoOutput("Couldn't open file:");
		infoOutput(bramName);
	}
}

void loadState() {
	int err = 1;
	u32 *statePtr;
	FILE *file;
	char stateName[FILENAMEMAXLENGTH];

	if (findFolder(folderName)) {
		return;
	}
	strlcpy(stateName, currentFilename, sizeof(stateName)-4);
	strlcat(stateName, ".sta", sizeof(stateName));
	if ( (file = fopen(stateName, "r")) ) {
		if ( (statePtr = malloc(STATESIZE)) ) {
			cls(0);
			drawText("        Loading state...", 12, 0);
			fread(statePtr, 1, STATESIZE, file);
			unpackState(statePtr);
			free(statePtr);
			err = 0;
			cls(0);
			infoOutput("Loaded state.");
		} else {
			infoOutput("Couldn't alloc mem for state.");
		}
		fclose(file);
	} else {
		infoOutput("Couldn't open file:");
		infoOutput(stateName);
	}
	if (!err) {
		closeMenu();
	}
}
void saveState() {
	u32 *statePtr;
	FILE *file;
	char stateName[FILENAMEMAXLENGTH];

	if (findFolder(folderName)) {
		return;
	}
	strlcpy(stateName, currentFilename, sizeof(stateName)-4);
	strlcat(stateName, ".sta", sizeof(stateName));
	if ( (file = fopen(stateName, "w")) ) {
		if ( (statePtr = malloc(STATESIZE)) ) {
			cls(0);
			drawText("        Saving state...", 12, 0);
			packState(statePtr);
			fwrite(statePtr, 1, STATESIZE, file);
			free(statePtr);
			cls(0);
			infoOutput("Saved state.");
		} else {
			infoOutput("Couldn't alloc mem for state.");
		}
		fclose(file);
	} else {
		infoOutput("Couldn't open file:");
		infoOutput(stateName);
	}
}

void loadGame(const char *gameName) {
	if (gameName) {
		drawText("   Please wait, loading.", 12, 0);
		g_hwFlags &= ~(SCD_DEVICE|SCD_CARD|AC_CARD|SGX_DEVICE);
		g_ROM_Size = loadPCEROM(ROM_Space, gameName, sizeof(ROM_Space));
		cls(0);
		if (g_ROM_Size) {
			biosLoaded = 0;
			cdInserted = 0;
			hucardLoaded = 1;
			setEmuSpeed(0);
			loadCart();
			if (emuSettings & AUTOLOAD_STATE) {
				loadState();
			}
			powerButton = 1;
			closeMenu();
		}
	}
}

void selectGame() {
	pauseEmulation = 1;
	const char *gameName = browseForFileType(FILEEXTENSIONS".zip");
	cls(0);
	loadGame(gameName);
}

void selectBios() {
	const char *biosName = browseForFileType(FILEEXTENSIONS".zip");
	cls(0);
	if (biosName) {
		strlcpy(cfg.biosPath, currentDir, sizeof(cfg.biosPath));
		strlcat(cfg.biosPath, "/", sizeof(cfg.biosPath));
		strlcat(cfg.biosPath, biosName, sizeof(cfg.biosPath));
		biosLoaded = 0;
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
	char tempString[FILEPATHMAXLENGTH];
	char *sPtr;

	strcpy(tempString, fPath);
	if ( (sPtr = strrchr(tempString, '/')) ) {
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
	if (loadBIOS(BIOS_Space, cfg.biosPath, sizeof(BIOS_Space))) {
		g_BIOSBASE = BIOS_Space;
		biosLoaded = 1;
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
		} else {
			strcpy(cdGamePath, cdName);
			cdDatatrackMode = 4;
			cdIsBinCue = 0;
		}
		if (cdFile) {
			fclose(cdFile);
			cdFile = NULL;
		}
		if ( (cdFile = fopen(cdGamePath, "r")) ) {
			cdInserted = 1;
			fseek(cdFile, 0, SEEK_END);
			cdFileSize = ftell(cdFile);
			fseek(cdFile, 0, SEEK_SET);
			if (!biosLoaded) {
				loadUSBIOS();
			}
			if (biosLoaded) {
				g_ROM_Size = sizeof(BIOS_Space);
				setEmuSpeed(0);
				loadCart();
				if (emuSettings & AUTOLOAD_STATE) {
					loadState();
				}
				powerButton = 1;
				closeMenu();
			}
		} else {
			infoOutput("Couldn't open CD file:");
			cdInserted = 0;
		}
	}
}

int CD_ReadByte() {
	int i = 0;

	if (cdDataLeft == 0) {
		if (cdDatatrackMode == 8 ) {
			fread(cdBuffer, 1, 2352, cdFile);
		} else {
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
		if ( (len+ptr) > sizeof(cdBuffer) ) {
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
	if ( (binName = strrchr(cs->file, '\\')) || (binName = strrchr(cs->file, '/')) ) {
		binName += 1;
	} else {
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
		} else if (cs->tracklist[i].mode == MODE1_RAW) {
			cdDatatrackMode = CDROM_TOC[0x10 + i*8] = 8;
		} else {
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
