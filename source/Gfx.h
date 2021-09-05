#ifndef GFX_HEADER
#define GFX_HEADER

#ifdef __cplusplus
extern "C" {
#endif

extern u8 g_flicker;
extern u8 g_twitch;
extern u8 g_gfxMask;
extern u8 g_colorValue;
extern u8 g_rgb_ycbcr;
extern u8 sprCollision;

extern u16 EMUPALBUFF[200];
extern void *dmaOamBuffer;

void gfxInit(void);
void vblIrqHandler(void);
void paletteInit(u8 gammaVal);
void antWars(void);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // GFX_HEADER
