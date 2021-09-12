#ifndef FILEHANDLING_HEADER
#define FILEHANDLING_HEADER

#ifdef __cplusplus
extern "C" {
#endif

#define FILEEXTENSIONS ".pce.sgx"

extern bool biosLoaded;
extern bool hucardLoaded;

int loadSettings(void);
void saveSettings(void);
int loadNVRAM(void);
int loadBRAM(void);
void saveNVRAM(void);
void saveBRAM(void);
void loadGame(const char *pceName);
int loadPCEROM(void *dest, const char *fName, const int maxSize);
int loadBIOS(void *dest, const char *fPath, const int maxSize);
void loadState();
void saveState(void);
void selectGame(void);
void selectCDROM(void);
void selectBios(void);
int loadUSBIOS(void);

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

#endif // FILEHANDLING_HEADER
