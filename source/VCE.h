//
//  VCE.h
//  NitroGrafx
//
//  Created by Fredrik Ahlström on 2003-01-01.
//  Copyright © 2003-2026 Fredrik Ahlström. All rights reserved.
//
#ifndef VCE_HEADER
#define VCE_HEADER

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
	u32 address;
	u8 control;
	u8 pixelClock;
	u8 dmaCyclesPerScanline;
	u8 padding[1];
	u16 paletteRam[0x200];
} VCECore;

extern VCECore vceState;

void vceSaveState(void);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // VCE_HEADER
