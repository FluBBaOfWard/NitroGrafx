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
