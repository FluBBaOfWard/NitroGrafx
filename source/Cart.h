#ifndef CART_HEADER
#define CART_HEADER

#ifdef __cplusplus
extern "C" {
#endif

extern u32 g_ROM_Size;
extern u8 g_hwFlags;
extern u8 g_configSet;
extern u8 g_scalingSet;
extern u8 g_machineSet;
extern u8 g_machine;
extern u8 g_region;
extern u8 g_bramChanged;

extern u8 EMU_SRAM[0x2000];
extern u8 ROM_Space[0x280200];
extern u8 BIOS_Space[0x40000];
extern void *g_BIOSBASE;

void loadCart(void);
void ejectCart(void);
int packState(u32 *statePtr);
void unpackState(u32 *statePtr);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // CART_HEADER
