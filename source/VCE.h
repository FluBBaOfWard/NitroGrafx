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

/**
 * Saves the state of the VCE to the destination.
 * @param  *destination: Where to save the state.
 * @param  *chip: The VCE chip to save.
 * @return The size of the state.
 */
int vceSaveState(void *destination, const VCECore *chip);

/**
 * Loads the state of the VCE from the source.
 * @param  *chip: The VCE chip to load a state into.
 * @param  *source: Where to load the state from.
 * @return The size of the state.
 */
int vceLoadState(VCECore *chip, const void *source);

/**
 * Gets the state size of a VCE chip.
 * @return The size of the state.
 */
int vceGetStateSize(void);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // VCE_HEADER
