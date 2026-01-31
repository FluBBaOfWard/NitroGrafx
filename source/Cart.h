//
//  Cart.h
//  NitroGrafx
//
//  Created by Fredrik Ahlström on 2003-01-01.
//  Copyright © 2003-2026 Fredrik Ahlström. All rights reserved.
//
#ifndef CART_HEADER
#define CART_HEADER

#ifdef __cplusplus
extern "C" {
#endif

extern u32 g_ROM_Size;
extern u8 gHwFlags;
extern u8 gConfigSet;
extern u8 gMachineSet;
extern u8 gMachine;
extern u8 gRegion;
extern u8 gBramChanged;

extern u8 pceRAM[0x2000];
extern u8 sgxRAM[0x8000];
extern u8 pceSRAM[0x2000];
extern u8 CD_PCM_RAM[0x10000];
extern u8 SCD_RAM[0x30000];
extern u8 PCE_CD_RAM[0x10000];
extern u8 ACC_RAM[0x200000];
extern u8 ROM_Space[0x290000];
extern u8 biosSpace[0x40000];
extern void *g_BIOSBASE;

void machineInit(void);
void loadCart(void);
void ejectCart(void);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // CART_HEADER
