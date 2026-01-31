//
//  Gfx.h
//  NitroGrafx
//
//  Created by Fredrik Ahlström on 2003-01-01.
//  Copyright © 2003-2026 Fredrik Ahlström. All rights reserved.
//
#ifndef GFX_HEADER
#define GFX_HEADER

#ifdef __cplusplus
extern "C" {
#endif

extern u8 gFlicker;
extern u8 gTwitch;
extern u8 gGfxMask;
extern u8 gColorValue;
extern u8 gRgbYcbcr;
extern u8 gScalingSet;
extern u8 sprCollision;

extern u16 pceVRAM[8000];
extern u16 EMUPALBUFF[200];
extern u32 GFX_DISPCNT;

extern void *dmaOamBuffer;

void gfxInit(void);
void vblIrqHandler(void);
void paletteInit(u8 gammaVal);
void antWars(void);
void refreshSprites(void);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // GFX_HEADER
