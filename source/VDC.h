//
//  VDC.h
//  NitroGrafx
//
//  Created by Fredrik Ahlström on 2003-01-01.
//  Copyright © 2003-2026 Fredrik Ahlström. All rights reserved.
//
#ifndef VDC_HEADER
#define VDC_HEADER

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
	u32 lineState;
	u32 nextLineChange;
	u32 scanline;
	u32 writeAdr;
//	u8 adrInc;
	u32 readAdr;			// vdcReadAdr (temp)
	u32 readLatch;			//
	u32 rasterCompare;		//
	u32 rasterCompareCPU;	//
	u32 scroll[2];			//
	u32 satAdr;				// Sprite Attribute Table address
	u32 satLen;				// VRAM DMA SPR Length
	u32 dmaSrc;				// VRAM DMA Source
	u32 dmaDst;				// VRAM DMA Destination
	u32 dmaLen;				// VRAM DMA Length
	u32 vdw;
	u32 hCenter;

	u8 writeLatch;
	u8 Register;
	u8 AdrIncOld;
	u8 Stat;				//
	u8 MWReg;				// Memory width register
	u8 Burst[2];
	u8 Ctrl1;				//
	u8 HDW;					// Horizontal Display Width
	u8 VDS;					// Vertical Display Start
	u8 VSW;					// Vertical Sync Width
	u8 VCR;					// Vertical Display End Reg
	u8 DMACR;				// DMA Control Reg
	u8 DoSprDMA;			//
	u8 DoVramDMA;			//
	u8 PrimedVBl;			//
	u32 LatchTime;			// 1504*CYCLE /1552
	u32 ScanlineHook;

// StateTable
	u32 zeroLine;
	u32 midFrameLine;
	u32 endFrameLine;
	u32 vblLine;
	u32 vblEndLine;
	u32 lastScanline;
	u16 spriteRam[0x100];
} VDCCore;

extern VDCCore vdcState;

void vdcSaveState(void);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // VDC_HEADER
