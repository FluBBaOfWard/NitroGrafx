//
//  cdrom.h
//  NitroGrafx
//
//  Created by Fredrik Ahlström on 2004-04-23.
//  Copyright © 2004-2026 Fredrik Ahlström. All rights reserved.
//
#ifndef CDROM_HEADER
#define CDROM_HEADER

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
	u8 mode;
	u8 LBA_0;
	u8 LBA_1;
	u8 LBA_2;
	u32 start;
} CD_TRACK;

typedef struct {
	char magic[8];				// TGCD0100
	u32 padding0;
	u8 trackCount;
	u8 padding1[3];
	CD_TRACK tracks[];
} CD_ROM_TOC;

extern u32 currentPos;			// cdrom.s
extern u32 currentTrack;		// cdrom.s
extern u8 cdInserted;			// cdrom.s
extern int cdFileSize;			// cdrom.s
extern void *tgcdBase;			// cdrom.s
extern char TGCD_D_Header[];	// cdrom.s
extern char TGCD_M_Header[];	// cdrom.s
extern CD_ROM_TOC cdRomToc;		// cdrom.s

void cdInit(void);				// cdrom.s

#ifdef __cplusplus
} // extern "C"
#endif

#endif // !CDROM_HEADER
