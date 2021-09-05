#ifndef CDROM_HEADER
#define CDROM_HEADER

#ifdef __cplusplus
extern "C" {
#endif

extern u32 currentPos;			// cdrom.s
extern u32 currentTrack;		// cdrom.s
extern u8 cdInserted;			// cdrom.s
extern int cdFileSize;			// cdrom.s
extern void *tgcdBase;			// cdrom.s
extern char TGCD_D_Header[];	// cdrom.s
extern char TGCD_M_Header[];	// cdrom.s
extern char CDROM_TOC[8*128];	// cdrom.s

void cdInit(void);				// cdrom.s

#ifdef __cplusplus
} // extern "C"
#endif

#endif // CDROM_HEADER
