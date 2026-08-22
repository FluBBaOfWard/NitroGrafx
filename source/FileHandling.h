#ifndef FILEHANDLING_HEADER
#define FILEHANDLING_HEADER

#ifdef __cplusplus
extern "C" {
#endif

#include "Emubase.h"
#include "Cart.h"

#define FILEEXTENSIONS ".pce.sgx"

extern bool biosLoaded;
extern bool hucardLoaded;

void initSettings(void);
int loadSettings(void);
int saveSettings(void);
bool loadGame(const char *pceName);
void loadState();
void saveState(void);
int packState(void *statePtr);
void unpackState(const void *statePtr);
int getStateSize(void);
int loadNVRAM(void);
int loadBRAM(void);
void saveNVRAM(void);
void saveBRAM(void);
int loadPCEROM(void *dest, const char *fName, const int maxSize);
int loadBIOS(void *dest, const char *fPath, const int maxSize);
void selectGame(void);
void selectCDROM(void);
void selectBios(void);
int loadUSBIOS(void);
void descrambleROM(void);

int CD_ReadByte(void);
int CD_FetchAudio(int len, char *dest);
int CD_FetchAudioSample(void);
void CD_FillBuffer(void);
void CD_SeekPos(int pos);
void CD_ResetBuffer(void);
void CD_ConvertCueFile(const char *fName);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // !FILEHANDLING_HEADER
