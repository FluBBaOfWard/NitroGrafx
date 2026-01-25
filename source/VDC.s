//
//  VDC.s
//  NitroGrafx Hudson/NEC HuC6270 Video Display Controller emulator
//
//  Created by Fredrik Ahlström on 2003-01-01.
//  Copyright © 2003-2026 Fredrik Ahlström. All rights reserved.
//
#ifdef __arm__

#include "Shared/nds_asm.h"
#include "Equates.h"
#include "ARMH6280/H6280mac.h"

#define vdcStateSize (vdcStateEnd-vdcState)

	.global vdcState
	.global scanline
	.global hCenter
	.global vdcRegister
	.global vdcAdrInc
	.global vdcWriteAdr
	.global vdcCtrl1
	.global vdcMWReg
	.global vdcScroll
	.global vdcBurst
	.global vdcEndFrameLine
	.global vdcLastScanline
	.global vdcSpriteRam

	.global vdcReset
	.global vdcSaveState
	.global vdcLoadState
	.global VDCDoScanline

	.global VDC_R
	.global VDC_W
	.global VDC0W

	.global newFrame
	.global newX
	.global newVDCCR
	.global vdcCtrl1Finish
	.global calcVBL
	.global calcHDW
	.global mirrorPCE



;@----------------------------------------------------------------------------
	.syntax unified
	.arm

	.section .text
	.align 2
;@----------------------------------------------------------------------------
vdcReset:					;@ Called from gfxReset
	.type vdcReset STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}

	ldr r0,=vdcState
	mov r1,#0
	mov r2,#vdcStateSize/4
	bl memset_					;@ Clear VDC regs

	ldr r0,=gMachineSet
	ldrb r0,[r11]
	cmp r0,#HW_AUTO
	moveq r3,#0
	movne r3,#-1
	mov r2,r3,lsl#16
	mov r3,r3,lsr#16
	ldr r0,vramPtr				;@ Clear VDC RAM.
	mov r1,#0x10000/8
vramLoop:
	subs r1,r1,#1
	stmiapl r0!,{r2,r3}
	bhi vramLoop

	ldr r0,=vdcStateTable
	adr r1,VDCLineStateTable
	mov r2,#(VDCLineStateTableEnd-VDCLineStateTable)/4
	bl memcpy_

	ldr r0,=vdcStateTable+4
	str r0,vdcLineState

	ldr r0,=defaultScanlineHook
	str r0,vdcScanlineHook

	mov r0,#240
	str r0,vdcVDW
	bl calcVBL
	mov r0,#0
	bl mirrorPCE

	mov r0,#1
	strb r0,vdcAdrInc

	mov r0,#-1
	str r0,vdcRasterCompareCPU
	ldr r0,=261					;@ NTSC (261-262) number of lines=262+1
	str r0,vdcLastScanline
	mov r0,#239
	str r0,vdcEndFrameLine
	str r0,vdcVBlLine
	add r0,r0,#1
	str r0,vdcVBlEndLine

	ldr r1,=0x80000080			;@ H start-end
	str r1,Window0HValue

	ldmfd sp!,{lr}
	bx lr
;@----------------------------------------------------------------------------
vdcSaveState:
;@----------------------------------------------------------------------------
	bx lr
;@----------------------------------------------------------------------------
vdcLoadState:
;@----------------------------------------------------------------------------
	bx lr

VDCLineStateTable:
	.long 0, fakeFrame			;@ vdcZeroLine
	.long 96, midFrame
	.long 239, endFrame			;@ vdcEndFrameLine
	.long 239, startVbl			;@ vdcVBlLine
	.long 240, vblHook			;@ vdcVBlEndLine
//	.long 260, secondLastScanline	;@ vdc2ndLastScanline
	.long 261, frameEndHook		;@ vdcLastScanline
//	.long 262, frameEndHook		;@ vdcMinus1Scanline
VDCLineStateTableEnd:

;@----------------------------------------
VDCDoScanline:
	stmfd sp!,{r4,r5,lr}
	ldr r5,scanline
	add r5,r5,#1
	str r5,scanline
	ldr r4,vdcNextLineChange
line0Ret:
	cmp r5,r4
	ldrmi pc,vdcScanlineHook
	ldr r2,vdcLineState
	ldmia r2!,{r0,r4}
	str r2,vdcLineState
	str r4,vdcNextLineChange
	adr lr, line0Ret
	bx r0

;@----------------------------------------------------------------------------
borderScanlineHook:
;@----------------------------------------------------------------------------
	ldr r1,=vceDMACyclesPerScanline
	ldrb r0,[r1]

	ldrb r1,vdcDoSprDMA
	cmp r1,#0
	blne sprDMA_W

	cmp r0,#0
	ldrbne r1,vdcDoVramDMA
	cmpne r1,#0
	blne vramDMA_W
;@----------------------------------------------------------------------------
defaultScanlineHook:
;@----------------------------------------------------------------------------
	ldr r2,vdcRasterCompareCPU
	cmp r5,r2					;@ r5 is scanline
	bne noRasterIrq

	ldrb r0,vdcCtrl1
	ands r0,r0,#0x04
	beq noRasterIrq

	ldrb r0,vdcStat
	orr r0,r0,#0x04				;@ Raster compare irq
	strb r0,vdcStat
	setIrqPin VDCIRQ_F
noRasterIrq:

	mov r0,#0
	ldmfd sp!,{r4,r5,pc}
;@----------------------------------------------------------------------------

frameEndHook:
	mov r0,#0
	str r0,vdcNextLineChange
	ldr r0,=vdcStateTable+4
	str r0,vdcLineState

	mov r0,#1
	ldmfd sp!,{r4,r5,pc}

fakeFrame:
	ldrb r0,vdcBurst
	cmp r0,#0
	ldrne r0,=defaultScanlineHook
	strne r0,vdcScanlineHook
	bx lr


;@----------------------------------------------------------------------------
startVbl:
;@----------------------------------------------------------------------------
	ldr r0,=borderScanlineHook
	str r0,vdcScanlineHook

	ldrb r0,vdcDoSprDMA
	ldrb r2,vdcDMACR
	and r2,r2,#0x10				;@ Check for DMA repetition
	orrs r0,r0,r2
	strb r0,vdcDoSprDMA
	mov r1,#0x100
	strne r1,vdcSatLen

	ldrb r0,vdcCtrl1
	tst r0,#0x08				;@ vbl IRQ?
	bxeq lr
	mov r0,#0x20				;@ VBlank bit
	strb r0,vdcPrimedVBl
	bx lr

;@----------------------------------------------------------------------------
vblHook:					;@ 193/240
;@----------------------------------------------------------------------------
	mov r0,#0
	ldrb r2,vdcPrimedVBl
	strb r0,vdcPrimedVBl		;@ Clear byte.
	ldrb r0,vdcStat
	orrs r0,r0,r2				;@ VBlank bit
	strb r0,vdcStat				;@ VBL irq.
	bxeq lr
	setIrqPin VDCIRQ_F
	bx lr
;@----------------------------------------------------------------------------
newFrame:					;@ Called before line 0
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}

;@--------------------------
	mov r0,#-1
	str r0,scanline				;@ Reset scanline count
	mov r0,#0
	str r0,vdcScrollLine
	str r0,vdcCtrl1Line
;@	strb r0,vdcstat				;@ VBL clear, sprite0 clear, Tatsujin needs this.
;@	strb r0,irqPending


	ldrb r0,vdcCtrl1
	and r0,r0,#0xC0				;@ Burst mode?
	strb r0,vdcBurst

	ldr r0,vdcScroll
	mov r0,r0,lsr#16
	ldr r1,=scrollOld
	strh r0,[r1,#2]

	bl paletteTxAll

	ldmfd sp!,{lr}
	bx lr

;@----------------------------------------------------------------------------
//	.section .itcm, "ax", %progbits
	.section .text
	.align 2
;@----------------------------------------------------------------------------
VDC_R:						;@ 0000-03FF
;@----------------------------------------------------------------------------
	eatcycles 1					;@ VDC & VCE takes 1 more cycle to access
	ands r1,addy,#3
	beq _VDC0R
	cmp r1,#2
	bhi _VDC3R
	ldrbeq r0,vdcReadLatch		;@ _VDC2R
	movmi r0,#0
	bx lr
;@----------------------------------------------------------------------------
_VDC0R:						;@ VDC Register
;@----------------------------------------------------------------------------
	clearirqpin VDCIRQ_F		;@ Clear VDC interrupt pending
	ldrb r0,vdcStat
	strb h6280a,vdcStat			;@ Lower 8bits allways zero
	ldrb r1,vdcPrimedVBl
	cmp r1,#0
	bxeq lr

	cmp cycles,#7*4*CYCLE
	orrmi r0,r0,#0x20			;@ VBlank bit
	strbmi h6280a,vdcPrimedVBl
	bx lr
;@----------------------------------------------------------------------------
;@_VDC2R					;@ VDC Data L
;@----------------------------------------------------------------------------
;@	ldrb r0,vdcReadLatch
;@	bx lr
;@----------------------------------------------------------------------------
_VDC3R:						;@ VDC Data H
;@----------------------------------------------------------------------------
	ldrb r0,vdcReadLatch+1

	ldrb r1,vdcRegister			;@ What function
	cmp r1,#2					;@ Only VRAM Read increases address.
	bxne lr
fillRLatch:
	ldr r2,vdcReadAdr
	ldrb r1,vdcAdrInc
	add r1,r2,r1,lsl#16
	str r1,vdcReadAdr

	movs r2,r2,asr#15
	ldrpl r1,vramPtr
	ldrhpl r1,[r1,r2]			;@ Read from virtual PCE_VRAM
	str r1,vdcReadLatch

	bx lr

;@----------------------------------------------------------------------------
VDCWriteTbl:
;@----------------------------------------------------------------------------
	.long MAWR_L_W				;@ 00 Mem Adr Write Reg
	.long MAWR_H_W				;@ 00 Mem Adr Write Reg
	.long MARR_L_W				;@ 01 Mem Adr Read Reg
	.long MARR_H_W				;@ 01 Mem Adr Read Reg
	.long VRAM_L_W				;@ 02 VRAM write
	.long VRAM_H_W				;@ 02 VRAM write
	.long emptyIOW				;@ 03
	.long emptyIOW				;@ 03
	.long emptyIOW				;@ 04
	.long emptyIOW				;@ 04
	.long VDC_CR_L_W			;@ 05 Interuppt, sync, increment width...
	.long VDC_CR_H_W			;@ 05 Interuppt, sync, increment width...
	.long RstCmp_L_W			;@ 06 Raster compare
	.long RstCmp_H_W			;@ 06 Raster compare
	.long ScrolX_L_W			;@ 07 Scroll X
	.long ScrolX_H_W			;@ 07 Scroll X
	.long ScrolY_L_W			;@ 08 Scroll Y
	.long ScrolY_H_W			;@ 08 Scroll Y
	.long MemWid_L_W			;@ 09 Memory Width (Bgr virtual size)
	.long MemWid_H_W			;@ 09 Memory Width (Bgr virtual size)
	.long VdcHsr_L_W			;@ 0A Horizontal Sync Reg
	.long VdcHsr_H_W			;@ 0A Horizontal Sync Reg
	.long VdcHDW_L_W			;@ 0B Horizontal Display Width
	.long VdcHDW_H_W			;@ 0B Horizontal Display Reg
	.long VdcVpr_L_W			;@ 0C Vertical Sync Reg
	.long VdcVpr_H_W			;@ 0C Vertical Sync Reg
	.long VdcVdw_L_W			;@ 0D Vertical Display Reg
	.long VdcVdw_H_W			;@ 0D Vertical Display Reg
	.long VdcVcr_L_W			;@ 0E Vertical Display End Reg
	.long VdcVcr_H_W			;@ 0E Vertical Display End Reg
	.long DMACtl_L_W			;@ 0F DMA Control Reg
	.long DMACtl_H_W			;@ 0F DMA Control Reg
	.long DMASrc_L_W			;@ 10 DMA Source Reg
	.long DMASrc_H_W			;@ 10 DMA Source Reg
	.long DMADst_L_W			;@ 11 DMA Destination Reg
	.long DMADst_H_W			;@ 11 DMA Destination Reg
	.long DMALen_L_W			;@ 12 DMA Length Reg
	.long DMALen_H_W			;@ 12 DMA Length Reg
	.long DMAOAM_L_W			;@ 13 DMA Sprite Attribute Table
	.long DMAOAM_H_W			;@ 13 DMA Sprite Attribute Table
	.long emptyIOW				;@ 14
	.long emptyIOW				;@ 14
	.long emptyIOW				;@ 15
	.long emptyIOW				;@ 15
	.long emptyIOW				;@ 16
	.long emptyIOW				;@ 16
	.long emptyIOW				;@ 17
	.long emptyIOW				;@ 17
	.long emptyIOW				;@ 18
	.long emptyIOW				;@ 18
	.long emptyIOW				;@ 19
	.long emptyIOW				;@ 19
	.long emptyIOW				;@ 1A
	.long emptyIOW				;@ 1A
	.long emptyIOW				;@ 1B
	.long emptyIOW				;@ 1B
	.long emptyIOW				;@ 1C
	.long emptyIOW				;@ 1C
	.long emptyIOW				;@ 1D
	.long emptyIOW				;@ 1D
	.long emptyIOW				;@ 1E
	.long emptyIOW				;@ 1E
	.long emptyIOW				;@ 1F
	.long emptyIOW				;@ 1F

;@----------------------------------------------------------------------------
VDC_W:						;@ 0000-03FF
;@----------------------------------------------------------------------------
	eatcycles 1					;@ VDC & VCE takes 1 more cycle to access
	and r1,addy,#3
	ldr pc,[pc,r1,lsl#2]		;@ VDC, what function
	.long 0
	.long VDC0W					;@ VDC0
	.long emptyIOW				;@ VDC1
vdcRegPtrL:						;@ VDC2
	.long emptyIOW
vdcRegPtrH:						;@ VDC3
	.long emptyIOW

;@----------------------------------------------------------------------------
VDC0W:						;@ VDC Register
;@----------------------------------------------------------------------------
	adr r2,VDCWriteTbl
	and r0,r0,#0x1f
	strb r0,vdcRegister			;@ What function
	ldr r0,[r2,r0,lsl#3]!
	ldr r1,[r2,#4]
	strd r0,r1,vdcRegPtrL
	add r2,h6280ptr,#h6280ST1Func
	strd r0,r1,[r2]
	bx lr
;@----------------------------------------------------------------------------
MAWR_L_W:					;@ 00
;@----------------------------------------------------------------------------
	strb r0,vdcWriteAdr+2		;@ Write low address
	bx lr
;@----------------------------------------------------------------------------
MAWR_H_W:					;@ 00
;@----------------------------------------------------------------------------
	strb r0,vdcWriteAdr+3		;@ Write high address
	bx lr
;@----------------------------------------------------------------------------
MARR_L_W:					;@ 01
;@----------------------------------------------------------------------------
	strb r0,vdcReadAdr+2		;@ Read low address
	bx lr
;@----------------------------------------------------------------------------
MARR_H_W:					;@ 01
;@----------------------------------------------------------------------------
	strb r0,vdcReadAdr+3		;@ Read high address
	b fillRLatch
;@----------------------------------------------------------------------------
VRAM_L_W:					;@ 02
;@----------------------------------------------------------------------------
	strb r0,vdcWriteLatch		;@ Data low
	bx lr
;@----------------------------------------------------------------------------
VRAM_H_W:					;@ 02
;@----------------------------------------------------------------------------
	ldrb r1,vdcWriteLatch
	orr r0,r1,r0,lsl#8

	ldr r2,vdcWriteAdr
	add r1,r2,r2,lsl#16
	str r1,vdcWriteAdr

	movs r2,r2,asr#15
	ldrpl r1,vramPtr
	strhpl r0,[r1,r2]			;@ Write to virtual PCE_VRAM
	ldrpl r1,=DIRTYTILES
	strbpl h6280a,[r1,r2,lsr#7]	;@ Write to dirtymap
	bx lr

vdcCtrl1Old:	.long 0x01003C3C	;@ Last write
vdcCtrl1Line:	.long 0 		;@ When?
;@----------------------------------------------------------------------------
VDC_CR_L_W:					;@ 05
;@----------------------------------------------------------------------------
	strb r0,vdcCtrl1
newVDCCR:
	ldrb r0,vdcCtrl1
	ands r1,r0,#0x80			;@ Bg en? clear r1
	movne r1,#0x0C				;@ Bg2 & bg3
	tst r0,#0x40				;@ Obj en?
	orrne r1,r1,#0x30
	orr r1,r1,r1,lsl#8
	ldr r0,vdcCtrl1Old			;@ r0=lastval
	strh r1,vdcCtrl1Old

	ldr addy,scanline
	ldr r2,vdcLatchTime			;@ 1552
	cmp r2,cycles
	addcs addy,addy,#1
	cmp addy,#260
	movhi addy,#260
	adr r2,vdcCtrl1Line
	swp r1,addy,[r2]			;@ r1=lastline, lastline=scanline
vdcCtrl1Finish:
	ldr r2,=scrollBuff
	ldr r2,[r2]
	add r2,r2,#8
	add r1,r2,r1,lsl#4
	add r2,r2,addy,lsl#4
	ldr addy,Window0HOld
vdc1:
	cmp r2,r1
	str addy,[r2],#-4			;@ Fill backwards from scanline to lastline
	str r0,[r2],#-12			;@ Fill backwards from scanline to lastline
	bhi vdc1
	ldr addy,Window0HValue
	str addy,Window0HOld
	bx lr

;@----------------------------------------------------------------------------
VDC_CR_H_W:					;@ 05
;@----------------------------------------------------------------------------
	and r2,r0,#0x18
	adr r1,incTbl
	ldrb r0,[r1,r2,lsr#3]
	strb r0,vdcAdrInc
	bx lr
;@----------------------------------------------------------------------------
incTbl:
	.byte 1,32,64,128

;@----------------------------------------------------------------------------
RstCmp_L_W:					;@ 06 Raster compare
;@----------------------------------------------------------------------------
	strb r0,vdcRasterCompare
	b rasterfix
;@----------------------------------------------------------------------------
RstCmp_H_W:					;@ 06 Raster compare
;@----------------------------------------------------------------------------
	and r0,r0,#3
	strb r0,vdcRasterCompare+1
;@------------------
rasterfix:
;@------------------
	ldr r0,vdcRasterCompare
	sub r0,r0,#0x40
	str r0,vdcRasterCompareCPU
	bx lr

;@----------------------------------------------------------------------------
ScrolX_L_W:					;@ 07
;@----------------------------------------------------------------------------
	strb r0,vdcScroll
	b newX
;@----------------------------------------------------------------------------
ScrolX_H_W:					;@ 07
;@----------------------------------------------------------------------------
	and r0,r0,#3
	strb r0,vdcScroll+1
newX:							;@ ctrl0_W, loadstate jumps here
	ldr r1,scanline
	ldr r2,vdcLatchTime			;@ 1552
	cmp r2,cycles
	addcs r1,r1,#1
	ldr r2,vdcScroll
	ldrh r0,scrollOld+2			;@ r2 = lastval
	orr r2,r0,r2,lsl#16
	mov r2,r2,ror#16
scrollCont:
	ldr r0,hCenter
	add r2,r2,r0
	ldr r0,scrollMask
	and addy,r2,r0
	ldr r2,scrollOld			;@ r2 = lastval
	str addy,scrollOld

	cmp r1,#260
	movhi r1,#260
	ldr r0,vdcScrollLine
	subs r0,r1,r0
	strhi r1,vdcScrollLine
	ldr addy,=scrollBuff
	ldr addy,[addy]
	add r1,addy,r1,lsl#4		;@ r1 = base
sx1:
	strhi r2,[r1,#-16]!			;@ Fill backwards from scanline to lastline
	subshi r0,r0,#1
	bhi sx1
	bx lr

scrollMask:		.long 0x01FF00FF	;@ scrollmask
scrollOld:		.long 0			;@ Last write
vdcScrollLine:	.long 0			;@ ..was when?

;@----------------------------------------------------------------------------
ScrolY_L_W:					;@ 08
;@----------------------------------------------------------------------------
	strb r0,vdcScroll+2
	b newY
;@----------------------------------------------------------------------------
ScrolY_H_W:					;@ 08
;@----------------------------------------------------------------------------
	and r0,r0,#0x1
	strb r0,vdcScroll+3
newY:
	ldr r1,scanline
	ldr r2,vdcLatchTime			;@ 1552
	cmp r2,cycles
	addcs r1,r1,#1
	ldr r2,vdcScroll
	add r2,r2,#0x10000			;@ Extra Y
	sub r2,r2,r1,lsl#16			;@ y -= scanline
	b scrollCont
;@----------------------------------------------------------------------------
MemWid_L_W:					;@ 09 Memory Width (Bgr virtual size)
;@----------------------------------------------------------------------------
	strb r0,vdcMWReg
	b mirrorPCE
;@----------------------------------------------------------------------------
VdcHDW_L_W:					;@ 0B Horizontal Display Width.
;@----------------------------------------------------------------------------
	and r0,r0,#0x7f
	strb r0,vdcHDW

;@----------------------------------------------------------------------------
calcHDW:
	ldrb r0,vdcHDW
	add r0,r0,#1
	ldr r2,=vcePixelClock
	ldrb r2,[r2]
	cmp r2,#1
	movmi r0,r0,lsl#2
	addeq r0,r0,r0,lsl#1		;@ Multiply with 3
	movhi r0,r0,lsl#1
	sub r0,r0,#128
	mov r1,r0
	addeq r1,r1,r1,lsr#2		;@ Add 1/3 (in this case 1/4)
	movhi r1,r1,lsl#1
	str r1,hCenter

	cmp r0,#0
	movpl r0,#0
	and r1,r0,#0x00FF
	orr r1,r1,#0x8000
	rsb r0,r0,#0
	and r0,r0,#0xFF
	mov r0,r0,lsl#8
	orr r0,r0,#0x0080
	orr r0,r0,r1,lsl#16
	ldr r1,Window0HValue
	str r0,Window0HValue
	str r1,Window0HOld

//	bx lr
//newVCECR:
	mov r1,#0x0100				;@ 1 Xpixel per X
	cmp r2,#1					;@ vcePixelClock
	orreq r1,#0x0056			;@ 1.1/3 Xpixel per X
	movhi r1,#0x0200			;@ 2 Xpixel per X

	ldr r2,=vdcCtrl1Old
	ldr r0,[r2]					;@ r0=lastval
	strh r1,[r2,#2]

	ldr addy,scanline
	cmp addy,#260
	movhi addy,#260
	adr r2,vdcCtrl1Line
	swp r1,addy,[r2]			;@ r1=lastline, lastline=scanline
vceCtrl1Finish:
	ldr r2,=scrollBuff
	ldr r2,[r2]
	add r2,r2,#8
	add r1,r2,r1,lsl#4
	add r2,r2,addy,lsl#4
	ldr addy,Window0HOld
vct1:
	cmp r2,r1
	str addy,[r2],#-4			;@ Fill backwards from scanline to lastline
	str r0,[r2],#-12			;@ Fill backwards from scanline to lastline
	bhi vct1
	ldr addy,Window0HValue
	str addy,Window0HOld
	bx lr
Window0HValue:
	.long 0x80000080
Window0HOld:
	.long 0
;@----------------------------------------------------------------------------
VdcVpr_L_W:					;@ 0C Vertical Sync Reg, Vertical Synch Width
;@----------------------------------------------------------------------------
	and r0,r0,#0x1f
	strb r0,vdcVSW
	b calcVBL
;@----------------------------------------------------------------------------
VdcVpr_H_W:					;@ 0C Vertical Sync Reg, Vertical Display Start
;@----------------------------------------------------------------------------
	strb r0,vdcVDS
	b calcVBL
;@----------------------------------------------------------------------------
VdcVdw_L_W:					;@ 0D Vertical Display Reg
;@----------------------------------------------------------------------------
	strb r0,vdcVDW
	b calcVBL
;@----------------------------------------------------------------------------
VdcVdw_H_W:					;@ 0D Vertical Display Reg, display height
;@----------------------------------------------------------------------------
	and r0,r0,#1
	strb r0,vdcVDW+1

;@----------------------------------------------------------------------------
calcVBL:
.type   calcVBL STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r3,r4,lr}
	ldrb r0,vdcVSW
	ldrb r2,vdcVDS
	add r2,r2,r0
	cmp r2,#14
	movmi r2,#14
	ldr r0,vdcVDW
	add r0,r0,#1
	add r1,r0,r2
	cmp r1,#256
;@	sub r0,r0,r2
	rsbhi r0,r2,#256
	str r0,vdcEndFrameLine
	str r0,vdcVBlLine
	add r1,r0,#1
	str r1,vdcVBlEndLine


	ldr r4,=BG_SCALING_TBL
	sub r1,r0,#SCREEN_HEIGHT	;@ Screen size of DS.
	movs r1,r1,asr#1
	str r1,[r4,#0x18]			;@ OFS, for centering in unscaled mode.vertical
	movpl r1,#0
	rsb r1,r1,#0
	strb r1,[r4,#0x0D]			;@ WIN

	sub r1,r0,#218				;@ Screen size in scale to aspect.
	movs r1,r1,asr#1
	str r1,[r4,#0x20]			;@ OFS, for centering in scaled to aspect mode.vertical
	movpl r1,#0					;@ r1 should be multiplied?
	rsb r1,r1,#0
	ldr r3,[r4,#0x08]			;@ Scale factor
	mul r1,r3,r1
	mov r1,r1,asr#16
	strb r1,[r4,#0x15]			;@ WIN

	mov r3,r0
	cmp r3,#SCREEN_HEIGHT
	movmi r3,#SCREEN_HEIGHT
	cmp r3,#224
	movpl r3,#224
	subs r1,r0,r3				;@ Max screen size in scale to fit.
	mov r0,r3
	movs r1,r1,asr#1
	str r1,[r4,#0x1C]			;@ OFS, for centering in scaled to fit mode.vertical
	movpl r1,#0
	rsb r1,r1,#0
	strb r1,[r4,#0x11]			;@ WIN

	stmfd sp!,{r0}
	mov r1,r0
	mov r0,#SCREEN_HEIGHT<<16	;@ 192 << 16
	swi #0x090000
	ldr r1,=0xFFFF
	cmp r0,r1
	movpl r0,r1
	str r0,[r4,#4]				;@ Scale value, scale to fit
	bl setVDPMode

	ldmfd sp!,{r0}
	ldr r1,=0x15555				;@ 1/192
	mul r1,r0,r1
	add r0,r1,#0x40
	cmp r0,#0x1000000
	movmi r0,#0x1000000
	mov r0,r0,lsr#16
	ldr r2,=BG_SCALING_TO_FIT
	str r0,[r2,#0x00]
	rsb r0,r0,#0
	strh r0,[r2,#0x04]
	bl setupScaling

	ldmfd sp!,{r3,r4,lr}
	bx lr

;@----------------------------------------------------------------------------
VdcVcr_L_W:					;@ 0E Vertical Display End Reg, how much is blanked after the display (+3)
;@----------------------------------------------------------------------------
	strb r0,vdcVCR
;@----------------------------------------------------------------------------
MemWid_H_W:					;@ 09 Memory Width (Bgr virtual size)
;@----------------------------------------------------------------------------
;@----------------------------------------------------------------------------
VdcHsr_L_W:					;@ 0A Horizontal Sync Reg
;@----------------------------------------------------------------------------
;@----------------------------------------------------------------------------
VdcHsr_H_W:					;@ 0A Horizontal Sync Reg
;@----------------------------------------------------------------------------
;@----------------------------------------------------------------------------
VdcHDW_H_W:					;@ 0B Horizontal Display Width
;@----------------------------------------------------------------------------
;@----------------------------------------------------------------------------
VdcVcr_H_W:					;@ 0E Vertical Display End Reg
;@----------------------------------------------------------------------------
;@----------------------------------------------------------------------------
DMACtl_H_W:					;@ 0F DMA Control Reg
;@----------------------------------------------------------------------------
	bx lr
;@----------------------------------------------------------------------------
DMACtl_L_W:					;@ 0F DMA Control Reg
;@ SDMA_AUTO_ON	equ	%10000		; Auto SPR_DMA
;@ VDMA_DES_INC	equ	%00000
;@ VDMA_DES_DEC	equ	%01000
;@ VDMA_SRC_INC	equ	%00000
;@ VDMA_SRC_DEC	equ	%00100
;@ VDMA_VINT_ON	equ	%00010		; Interrupt when VRAM DMA is finnished.
;@ SDMA_VINT_ON	equ	%00001		; Interrupt when SPR DMA is finnished.
;@----------------------------------------------------------------------------
	strb r0,vdcDMACR
	bx lr
;@----------------------------------------------------------------------------
DMASrc_L_W:					;@ 10 DMA Source Reg
;@----------------------------------------------------------------------------
	strb r0,vdcDMASrc+2
	bx lr
;@----------------------------------------------------------------------------
DMASrc_H_W:					;@ 10 DMA Source Reg
;@----------------------------------------------------------------------------
	strb r0,vdcDMASrc+3
	bx lr
;@----------------------------------------------------------------------------
DMADst_L_W:					;@ 11 DMA Destination Reg
;@----------------------------------------------------------------------------
	strb r0,vdcDMADst+2
	bx lr
;@----------------------------------------------------------------------------
DMADst_H_W:					;@ 11 DMA Destination Reg
;@----------------------------------------------------------------------------
	strb r0,vdcDMADst+3
	bx lr
;@----------------------------------------------------------------------------
DMALen_L_W:					;@ 12 DMA Length Reg
;@----------------------------------------------------------------------------
	strb r0,vdcDMALen+2
	bx lr
;@----------------------------------------------------------------------------
DMALen_H_W:					;@ 12 DMA Length Reg, this starts the transfer.
;@----------------------------------------------------------------------------
;@dmadum:	b dmadum			;@ For testing of VRAM DMA (Davis Cup Tennis, Gaia no Monsho, Legendary Axe II, Magical Chase, Ninja Warriors).
	strb r0,vdcDMALen+3
	mov r0,#-1
	strb r0,vdcDoVramDMA
	bx lr
;@----------------------------------------------------------------------------
DMAOAM_L_W:						;@ 13 DMA Sprite Attribute Table
;@----------------------------------------------------------------------------
	strb r0,vdcSatAdr
	bx lr
;@----------------------------------------------------------------------------
DMAOAM_H_W:						;@ 13 DMA Sprite Attribute Table
;@----------------------------------------------------------------------------
	strb r0,vdcSatAdr+1
	mov r0,#-1
	strb r0,vdcDoSprDMA
	bx lr

;@----------------------------------------------------------------------------
maskTable:
	.long 0x00FF00FF,0x00FF01FF,0x00FF03FF,0x00FF03FF,0x01FF00FF,0x01FF01FF,0x01FF03FF,0x01FF03FF
;@----------------------------------------------------------------------------
mirrorPCE:
	and r0,r0,#0x70
	adr r1,maskTable
	ldr r1,[r1,r0,lsr#2]
	str r1,scrollMask
	bx lr

;@ VRAM DMA is 81-85 WORDs per scanline in 5.37MHz mode,
;@ 108-113 WORDS in 7.16MHz mode and 162-170 WORDS in 10.74MHz mode.
;@----------------------------------------------------------------------------
sprDMA_W:			;@ Sprite DMA transfer, should be called during VBlank
;@----------------------------------------------------------------------------
	stmfd sp!,{r3-r5}

	ldr r5,vdcSatAdr
	ldr r1,vramPtr
	add r1,r1,r5,lsl#1			;@ r1=DMA source
	ldr r4,=vdcSpriteRam		;@ Destination
	ldr r2,vdcSatLen			;@ Length
	rsb r3,r2,#0x100			;@ How much is already done
	add r1,r1,r3,lsl#1
	add r4,r4,r3,lsl#1
sprDMALoop:
	subs r0,r0,#1
	subspl r2,r2,#1
	ldrhpl r3,[r1],#2
	strhpl r3,[r4],#2
	bhi sprDMALoop
	ldmfd sp!,{r3-r5}

	str r2,vdcSatLen
	cmp r2,#0
	bxhi lr

	strb r2,vdcDoSprDMA
	ldrb r1,vdcDMACR
	tst r1,#0x01				;@ Spr IRQ?
	bxeq lr
	ldrb r1,vdcStat
	orr r1,r1,#0x08				;@ Spr DMA done.
	strb r1,vdcStat
	setIrqPin VDCIRQ_F

	bx lr
;@----------------------------------------------------------------------------
vramDMA_W:			;@ VRAM to VRAM DMA transfer, r0=cycles to run
;@----------------------------------------------------------------------------
	stmfd sp!,{r3-r9,lr}

	ldrb r12,vdcDMACR
	mov r7,#0x00010000			;@ Source increase
	mov r8,#0x00010000			;@ Destination increase
	movs r1,r12,lsl#29
	rsbmi r7,r7,#0				;@ Source decrease
	rsbcs r8,r8,#0				;@ Destination decrease
	ldr r5,vramPtr
	ldr r6,=DIRTYTILES
	ldr r1,vdcDMASrc
	ldr r2,vdcDMADst
	ldr r3,vdcDMALen
vramDmaLoop:
	mov r1,r1,lsr#15
	movs r2,r2,asr#15
	ldrhpl r9,[r5,r1]			;@ Read from virtual PCE_VRAM
	strhpl r9,[r5,r2]			;@ Write to virtual PCE_VRAM
	strbpl r3,[r6,r2,lsr#7]		;@ Write to dirtymap, r3 low byte=0.

	add r1,r7,r1,lsl#15
	add r2,r8,r2,lsl#15
	subs r3,r3,#0x10000
	subsne r0,r0,#1
	bne vramDmaLoop

	str r1,vdcDMASrc
	str r2,vdcDMADst
	str r3,vdcDMALen
	cmp r3,#0
	ldmfd sp!,{r3-r9,lr}
	bxne lr

	strb r2,vdcDoVramDMA		;@ r2 low byte=0 here.

	tst r12,#0x02				;@ VRAM DMA IRQ?
	bxeq lr
	ldrb r2,vdcStat
	orr r2,r2,#0x10				;@ VRAM DMA done.
	strb r2,vdcStat
	setIrqPin VDCIRQ_F

	bx lr
;@----------------------------------------------------------------------------


vramPtr:
	.long PCE_VRAM

vdcState:
vdcLineState:
	.long 0
vdcNextLineChange:
	.long 0
scanline:
	.long 0
vdcWriteAdr:
vdcAdrInc:
	.long 0						;@ vdcWriteAdr
vdcReadAdr:
	.long 0						;@ vdcReadAdr (temp)
vdcReadLatch:
	.long 0						;@ 
vdcRasterCompare:
	.long 0						;@ 
vdcRasterCompareCPU:
	.long -1					;@ 
vdcScroll:
	.long 0						;@ 
	.long 0						;@
vdcSatAdr:
	.long 0						;@ Sprite Attribute Table address
vdcSatLen:
	.long 0x100					;@ VRAM DMA SPR Length
vdcDMASrc:
	.long 0						;@ VRAM DMA Source
vdcDMADst:
	.long 0						;@ VRAM DMA Destination
vdcDMALen:
	.long 0						;@ VRAM DMA Length
vdcVDW:
	.long 0
hCenter:
	.long 0

vdcWriteLatch:
	.byte 0		;@ 
vdcRegister:
	.byte 0		;@ 
vdcAdrIncOld:
	.byte 1		;@
vdcStat:
	.byte 0						;@ 
vdcMWReg:
	.byte 0						;@ Memory width register
vdcBurst:
	.byte 0						;@ 
	.byte 0
vdcCtrl1:
	.byte 0						;@ 
vdcHDW:
	.byte 0						;@ Horizontal Display Width
vdcVDS:
	.byte 0						;@ Vertical Display Start
vdcVSW:
	.byte 0						;@ Vertical Sync Width
vdcVCR:
	.byte 0						;@ Vertical Display End Reg
vdcDMACR:
	.byte 0						;@ DMA Control Reg
vdcDoSprDMA:
	.byte 0						;@ 
vdcDoVramDMA:
	.byte 0						;@
vdcPrimedVBl:
	.byte 0						;@
vdcLatchTime:
	.long 1504*CYCLE			;@ 1552
vdcScanlineHook:	.long 0

vdcStateTable:
vdcZeroLine:		.long 0, newFrame
//vdcScrStartLine:	.long 0, earlyFrame
vdcMidFrameLine:	.long 96, midFrame
vdcEndFrameLine:	.long 239, endFrame
vdcVBlLine:			.long 239, startVbl
vdcVBlEndLine:		.long 240, vblHook
//vdc2ndLastScanline:	.long 260, secondLastScanline
vdcLastScanline:	.long 261, frameEndHook
//vdcMinus1Scanline:	.long 262, frameEndHook
vdcSpriteRam:
	.space 0x200
vdcStateEnd:

;@----------------------------------------------------------------------------
	.end
#endif // #ifdef __arm__
