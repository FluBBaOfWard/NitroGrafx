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
	u8 LBA0;
	u8 LBA1;
	u8 LBA2;
	u32 start;
} CD_TRACK;

typedef struct {
	char magic[8];				// TGCD0100
	u32 padding0;
	u8 trackCount;
	u8 endLBA0;
	u8 endLBA1;
	u8 endLBA2;
	CD_TRACK tracks[];
} CD_ROM_TOC;

extern u32 currentPos;
extern u8 currentTrack;
extern u8 cdInserted;
extern int cdFileSize;
extern void *tgcdBase;
extern char TGCD_D_Header[];
extern char TGCD_M_Header[];
extern CD_ROM_TOC cdRomToc;

void cdInit(void);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // !CDROM_HEADER
