#ifndef CART_HEADER
#define CART_HEADER

#ifdef __cplusplus
extern "C" {
#endif

extern u32 g_ROM_Size;
extern u8 gHwFlags;
extern u8 gConfigSet;
extern u8 gScalingSet;
extern u8 gMachineSet;
extern u8 gMachine;
extern u8 gRegion;
extern u8 gBramChanged;

extern u8 EMU_SRAM[0x2000];
extern u8 ROM_Space[0x280200];
extern u8 BIOS_Space[0x40000];
extern void *g_BIOSBASE;

void loadCart(void);
void ejectCart(void);

/// This runs all save state functions for each chip.
int packState(u32 *statePtr);

/// This runs all load state functions for each chip.
void unpackState(u32 *statePtr);

/// Gets the total state size in bytes.
int getStateSize(void);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // CART_HEADER
