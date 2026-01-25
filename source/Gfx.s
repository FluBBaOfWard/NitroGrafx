//
//  Gfx.s
//  NitroGrafx
//
//  Created by Fredrik Ahlström on 2003-01-01.
//  Copyright © 2003-2026 Fredrik Ahlström. All rights reserved.
//
#ifdef __arm__

#include "Shared/nds_asm.h"
#include "Equates.h"
#include "ARMH6280/H6280.i"

	.global antWars
	.global gfxInit
	.global gfxReset
	.global gfxSetupAfterLoadState
	.global setupScaling
	.global buildSpriteScaling
	.global setVDPMode
	.global paletteInit
	.global transferVRAM
	.global clearDirtyTiles
	.global midFrame
	.global endFrame
	.global gfxState
	.global gColorValue
	.global gTwitch
	.global gFlicker
	.global gGfxMask
	.global gScalingSet
	.global gRgbYcbcr
	.global sprCollision
	.global vblIrqHandler
	.global yStart

	.global DIRTYTILES
	.global DELAYED_TILEMAP
	.global scrollBuff
	.global BG_SCALING_TO_FIT
	.global BG_SCALING_TBL
	.global BG_SCALING_WIN
	.global BG_SCALING_OFS
	.global scaleSprParam

	.global PCE_VRAM
	.global EMUPALBUFF			;@ Needs to be flushed before dma copied.
//	.global WININBUFF			;@ Needs to be flushed after vblirq
	.global dmaOamBuffer

	.syntax unified
	.arm

	.section .text
	.align 2
;@----------------------------------------------------------------------------
flipsizeTable:	;@ Convert from PCE spr to GBA obj.
;@----------------------------------------------------------------------------
;@	    width=16	width=32
	.long 0x40000000,0x80004000,0x40000000,0x80004000,0x40000000,0x80004000,0x40000000,0x80004000		;@ height 16
	.long 0x50000000,0x90004000,0x50000000,0x90004000,0x50000000,0x90004000,0x50000000,0x90004000		;@ hor flip
	.long 0x80008000,0x80000000,0x80008000,0x80000000,0x80008000,0x80000000,0x80008000,0x80000000		;@ height 32
	.long 0x90008000,0x90000000,0x90008000,0x90000000,0x90008000,0x90000000,0x90008000,0x90000000
	.long 0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000		;@ height 64 (must be 32 wide)
	.long 0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000
	.long 0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000
	.long 0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000

	.long 0x40000000,0x80004000,0x40000000,0x80004000,0x40000000,0x80004000,0x40000000,0x80004000		;@ height 16
	.long 0x50000000,0x90004000,0x50000000,0x90004000,0x50000000,0x90004000,0x50000000,0x90004000		;@ hor flip
	.long 0x80008000,0x80000000,0x80008000,0x80000000,0x80008000,0x80000000,0x80008000,0x80000000		;@ height 32
	.long 0x90008000,0x90000000,0x90008000,0x90000000,0x90008000,0x90000000,0x90008000,0x90000000
	.long 0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000		;@ height 64 (must be 32 wide)
	.long 0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000
	.long 0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000
	.long 0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000

	.long 0x60000000,0xa0004000,0x60000000,0xa0004000,0x60000000,0xa0004000,0x60000000,0xa0004000		;@ height 16, ver flip
	.long 0x70000000,0xb0004000,0x70000000,0xb0004000,0x70000000,0xb0004000,0x70000000,0xb0004000		;@ hor flip
	.long 0xa0008000,0xa0000000,0xa0008000,0xa0000000,0xa0008000,0xa0000000,0xa0008000,0xa0000000		;@ height 32
	.long 0xb0008000,0xb0000000,0xb0008000,0xb0000000,0xb0008000,0xb0000000,0xb0008000,0xb0000000
	.long 0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000		;@ height 64 (must be 32 wide)
	.long 0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000
	.long 0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000
	.long 0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000

	.long 0x60000000,0xa0004000,0x60000000,0xa0004000,0x60000000,0xa0004000,0x60000000,0xa0004000		;@ height 16
	.long 0x70000000,0xb0004000,0x70000000,0xb0004000,0x70000000,0xb0004000,0x70000000,0xb0004000		;@ hor flip
	.long 0xa0008000,0xa0000000,0xa0008000,0xa0000000,0xa0008000,0xa0000000,0xa0008000,0xa0000000		;@ height 32
	.long 0xb0008000,0xb0000000,0xb0008000,0xb0000000,0xb0008000,0xb0000000,0xb0008000,0xb0000000
	.long 0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000		;@ height 64 (must be 32 wide)
	.long 0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000
	.long 0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000
	.long 0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000

;@----------------------------------------------------------------------------
copyExtPalette:
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r11,lr}
	ldr r12,=VRAM_F_CR
	mov r0,#0x80
	strb r0,[r12]				;@ so we can write to VRAM_F

	ldr r0,=VRAM_F				;@ dst, Palette transfer:
	add r1,r0,#0x2000			;@ Slot 0 & 1 for BG2 & BG3
	ldr r2,=EMUPALBUFF			;@ src, Palette transfer:
	mov r3,#16
xPalLoop:
	ldmia r2!,{r4-r11}
	stmia r1,{r4-r11}
	stmia r0,{r4-r11}
	add r1,r1,#0x200
	add r0,r0,#0x200
	subs r3,r3,#1
	bne xPalLoop

	mov r0,#0x8C				;@ VRAM enable, MST=4, OFS=1.
	strb r0,[r12]				;@ so we can write to VRAM_F

	ldmfd sp!,{r4-r11,lr}
	bx lr

;@----------------------------------------------------------------------------
antSeed:
	.long 0x800000
;@----------------------------------------------------------------------------
antWars:
	.type   antWars STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r4,lr}

	mov r0,#0x00
	ldr r1,=gGfxMask
	strb r0,[r1]

	ldr r1,=EMUPALBUFF			;@ Setup palette for antWars.
	strh r0,[r1]
	ldr r0,=0x7FFF
	strh r0,[r1,#0x1E]

	ldr r3,=BGoffset1
	ldr r4,[r3],#4
	mov r0,#BG_GFX
	add r4,r0,r4,lsl#3
	mov r0,#0
	ldr r1,antSeed
	and r1,r1,#0x1F
tmLoop:
	add r1,r1,#1
	bic r1,r1,#0x3FC00
	strh r1,[r4],#2
	add r0,r0,#1
	cmp r0,#1024*4
	bne tmLoop

	mov r0,r4
	ldr r1,=0x03000300
	mov r2,#0x800/4
	bl memset_					;@ BG2 clear

	ldr r0,=BG_GFX+0x10000
	ldr r3,antSeed
	ldr r1,=0x1E31*2
antLoop0:
	mov r2,#4
antLoop1:
	movs r3,r3,lsr#1
	eorcs r3,r3,#0xE10000
	mov r4,r4,lsl#8
	orrcs r4,r4,#0x0F
	subs r2,r2,#1
	bne antLoop1
	str r4,[r0],#4
	subs r1,r1,#1
	bne antLoop0

	str r3,antSeed
	ldmfd sp!,{r4,lr}
	bx lr
;@----------------------------------------------------------------------------
defaultScroll:
	.long 0x00000000,0x01003C3C,0x80000080,0x00000000
;@----------------------------------------------------------------------------
gfxInit:					;@ (called from main.c) only need to call once
	.type   gfxInit STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}

	ldr r0,=BG_GFX
	mov r1,#0
	mov r2,#0x10000
	bl memset_					;@ Clear NDS VRAM

	ldr r0,=SPR_DECODE			;@ Destination, 0x400
	mov r1,#0xffffff00			;@ Build chr decode tbl
ppi0:
	movs r2,r1,lsl#31
	movne r2,#0x10000000
	orrcs r2,r2,#0x01000000
	tst r1,r1,lsl#29
	orrmi r2,r2,#0x00100000
	orrcs r2,r2,#0x00010000
	tst r1,r1,lsl#27
	orrmi r2,r2,#0x00001000
	orrcs r2,r2,#0x00000100
	tst r1,r1,lsl#25
	orrmi r2,r2,#0x00000010
	orrcs r2,r2,#0x00000001
	str r2,[r0],#4
	adds r1,r1,#1
	bne ppi0

	ldr r0,=BGR_DECODE			;@ Destination 0x400*2
	mov r1,#0xffffff00			;@ Build chr decode tbl
ppi1:
	movs r3,r1,lsl#31
	movne r3,#0x01000000
	orrcs r3,r3,#0x00010000
	tst r1,r1,lsl#29
	orrmi r3,r3,#0x00000100
	orrcs r3,r3,#0x00000001
	ands r2,r1,#0x10
	movne r2,#0x01000000
	tst r1,#0x20
	orrne r2,r2,#0x00010000
	tst r1,r1,lsl#25
	orrmi r2,r2,#0x00000100
	orrcs r2,r2,#0x00000001
	strd r2,r3,[r0],#8
	adds r1,r1,#1
	bne ppi1

	bl resetScrollBuffers
	bl vceInit

	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
resetScrollBuffers:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}

	ldr r0,=SCROLLBUFF1
	adr r1,defaultScroll
	ldr r2,=16
	blx memcpy
	ldr r1,=SCROLLBUFF1
	add r0,r1,#16
	ldr r2,=263*16
	blx memcpy
	ldr r0,=SCROLLBUFF2
	ldr r1,=SCROLLBUFF1
	ldr r2,=264*16
	blx memcpy

	mov r1,#REG_BASE
	mov r0,#0x0000
	strh r0,[r1,#REG_BG2PB]		;@ 0 Ypixel per X
	strh r0,[r1,#REG_BG3PB]
	strh r0,[r1,#REG_BG2PC]		;@ 0 Xpixel per Y
	strh r0,[r1,#REG_BG3PC]
	mov r0,#0x0140
	strh r0,[r1,#REG_BG2PD]		;@ 1.25 Ypixel per Y
	strh r0,[r1,#REG_BG3PD]

	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
gfxReset:					;@ Called with cpuReset
	.type gfxReset STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}

	ldr r0,=gfxState
	mov r1,#0
	mov r2,#3					;@ 3*4
	bl memset_					;@ Clear GFX regs

	ldr r0,=BG_GFX
	mov r1,#0
	mov r2,#0x5000
	bl memset_					;@ Clear NDS VRAM

	ldr r0,=wTop
	str r1,[r0]
	ldr r0,=yStart
	str r1,[r0]

	bl vdcReset
	bl vceReset

	bl setBGOffsetsNormal

	bl clearDirtyTiles
	bl clearTileMaps
	bl resetScrollBuffers


	ldr r0,=OAM_BUFFER1			;@ No stray sprites please
	mov r1,#0x200+SCREEN_HEIGHT
	mov r2,#0x200
	bl memset_
//	mov r0,#OAM
//	mov r2,#0x100
//	bl memset_

	bl setupScaling
	bl setVDPMode

	ldmfd sp!,{pc}

;@----------------------------------------------------------------------------
gfxSetupAfterLoadState:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	bl clearDirtyTiles
	bl paletteTxAll
	bl calcVBL
	bl calcHDW
	ldr r0,=vdcMWReg
	ldrb r0,[r0]
	bl mirrorPCE

	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
setBGOffsetsNormal:
;@----------------------------------------------------------------------------
	ldr r1,=BGoffset1
	mov r0,#0x0000
	str r0,[r1],#4
	mov r0,#0x0800
	str r0,[r1],#4
	mov r0,#0x1000
	str r0,[r1],#4
	bx lr
;@----------------------------------------------------------------------------
clearTileMaps:
;@----------------------------------------------------------------------------
	mov r0,#BG_GFX
	mov r1,#0
	mov r2,#0x8000/4
	b memset_
;@----------------------------------------------------------------------------
setupScaling:		;@ r0-r3, r12 modified.
;@----------------------------------------------------------------------------
	ldrb r1,gScalingSet

	adr r0,BG_SCALING_1_1
//	cmp r1,#SCALED_1_1

	cmp r1,#SCALED_FIT
	adreq r0,BG_SCALING_TO_FIT

	cmp r1,#SCALED_ASPECT
	adreq r0,BG_SCALING_ASPECT

loadScaleValues:
	ldmia r0!,{r1-r2}
	adr r12,scaleSprParam
	stmia r12,{r1-r2}

	b buildSpriteScaling

BG_SCALING_1_1:
	.long 0x0100,0x0100,0x0080
BG_SCALING_ASPECT:			;@ 192->170, 224->199, 240->213, 216->192, 9->8
	.long 0x0110,0xFEE0,0x0090
BG_SCALING_TO_FIT:	;@ 1:1, 7:6, 5:4
	.long 0x0150,0xFEB6,0x0080

BG_SCALING_TBL:
	.long 0xFFFF,0xFFFF,0xE000				;@ 0xE2AB, 0xDB6D=7:6, 224->192
BG_SCALING_WIN:
	.long 0x00C0,0x00C0,0x00C0
BG_SCALING_OFS:
	.long 0,0,0

scaleParms:
	.long OAM_BUFFER1+6
	.long 0x0000				;@ Rotate value
	.long 0x0100				;@ Normal Horizontal
	.long 0xFF01				;@ Flipped Horizontal
scaleSprParam:
	.long 0x0150				;@ Normal Vertical (Scaled)
	.long 0xFEB6				;@ Flipped Vertical (Scaled)
;@----------------------------------------------------------------------------
buildSpriteScaling:
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r6}
	adr r0,scaleParms			;@ Set sprite scaling params
	ldmia r0,{r1-r6}			;@ Get sprite scaling params

	mov r0,#2
scaleLoop:
	strh r3,[r1],#8				;@ buffer1, buffer2. Normal sprites
	strh r2,[r1],#8
	strh r2,[r1],#8
	strh r5,[r1],#232
		strh r4,[r1],#8			;@ Flipped Horizontal
		strh r2,[r1],#8
		strh r2,[r1],#8
		strh r5,[r1],#232
			strh r3,[r1],#8		;@ Flipped Vertical
			strh r2,[r1],#8
			strh r2,[r1],#8
			strh r6,[r1],#232
				strh r4,[r1],#8	;@ Flipped Vertical & Horizontal
				strh r2,[r1],#8
				strh r2,[r1],#8
				strh r6,[r1],#232
	subs r0,r0,#1
	bne scaleLoop

	ldmfd sp!,{r4-r6}
	bx lr
;@----------------------------------------------------------------------------
paletteInit:		;@ r0-r3 modified.
	.type   paletteInit STT_FUNC
;@ Called by ui.c:  void paletteInit(u8 gammaVal);
;@----------------------------------------------------------------------------
	ldrb r1,gRgbYcbcr
	cmp r1,#0
	bne vceInitPaletteMap
	stmfd sp!,{r4-r9,lr}
	ldr r6,=MAPPED_RGB
	mov r7,r0					;@ Gamma value = 0 -> 4
	ldrb r8,gColorValue			;@ Color value = 0 -> 4
	mov r4,#512*2
	sub r4,r4,#2
noMap:							;@ Map 0000000gggrrrbbb  ->  0bbbbbgggggrrrrr
	mov r0,r4,lsr#1
	mov r1,r8
	bl yPrefix
	mov r9,r0

	mov r1,r7
	mov r0,r9,lsr#16
	bl gammaConvert
	mov r5,r0

	mov r0,r9,lsr#8
	and r0,r0,#0xFF
	bl gammaConvert
	orr r5,r0,r5,lsl#5

	and r0,r9,#0xFF
	bl gammaConvert
	orr r5,r0,r5,lsl#5

	strh r5,[r6,r4]
	subs r4,r4,#2
	bpl noMap
	ldmfd sp!,{r4-r9,lr}
	bx lr

;@----------------------------------------------------------------------------
yPrefix:					;@ Takes gggrrrbbb, outputs bbbbbbbbggggggggrrrrrrrr
;@----------------------------------------------------------------------------
	and r3,r0,#0x007
	orr r3,r3,r3,lsl#6
	orr r3,r3,r3,lsr#3
	mov r3,r3,lsr#1				;@ Blue
	and r2,r0,#0x1C0
	orr r2,r2,r2,lsr#3
	orr r2,r2,r2,lsr#6
	mov r2,r2,lsr#1				;@ Green
	and r0,r0,#0x38
	orr r0,r0,r0,lsl#3
	orr r0,r0,r0,lsr#6
	mov r0,r0,lsr#1				;@ Red
;@----------------------------------------------------------------------------
yConvert:					;@ r0=Red, r1=color 0-4, r2=Green, r3=Blue
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r5}

	mov r12,#77
	mul r4,r12,r0				;@ Red
	mov r12,#151
	mla r4,r12,r2,r4			;@ Green
	mov r12,#29
	mla r4,r12,r3,r4			;@ Blue

	rsb r5,r1,#4
	mul r4,r5,r4				;@ B&W
	orr r0,r0,r0,lsl#8
	mla r0,r1,r0,r4
	mov r0,r0,lsr#10
	
	orr r3,r3,r3,lsl#8
	mla r3,r1,r3,r4
	mov r3,r3,lsr#10

	orr r2,r2,r2,lsl#8
	mla r2,r1,r2,r4
	mov r2,r2,lsr#10

	orr r0,r0,r2,lsl#8
	orr r0,r0,r3,lsl#16

	ldmfd sp!,{r4-r5}
	bx lr
;@----------------------------------------------------------------------------
gPrefix:
	orr r0,r0,r0,lsl#4
;@----------------------------------------------------------------------------
gammaConvert:	;@ Takes value in r0(0-0xFF), gamma in r1(0-4),returns new value in r0=0x1F
;@----------------------------------------------------------------------------
	rsb r2,r0,#0x100
	mul r3,r2,r2
	rsbs r2,r3,#0x10000
	rsb r3,r1,#4
	orr r0,r0,r0,lsl#8
	mul r2,r1,r2
	mla r0,r3,r0,r2
	mov r0,r0,lsr#13

	bx lr

	.pool

;@----------------------------------------------------------------------------
clearDirtyTiles:
;@----------------------------------------------------------------------------
	mov r1,#0xab
	strb r1,sprMemReload		;@ Clear spr mem reload.

	ldr r0,=DIRTYTILES
	mov r1,#0
	mov r2,#0x200/4
	b memset_

;@----------------------------------------------------------------------------
vblIrqHandler:
	.type vblIrqHandler STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r11,lr}
	bl calculateFPS

	ldr r5,dmaScrollBuff
	ldr r4,yStart
	mov r4,r4,lsl#17
	mov r4,r4,lsr#17
	ldrb r0,gScalingSet
	mov r1,#1					;@ yScale, 1.0
	cmp r0,#SCALED_FIT
	ldreq r1,scaleSprParam
	moveq r1,r1,ror#8
	cmp r0,#SCALED_ASPECT
	ldreq r1,=0x24930001		;@ yScale, 1.14 (8/7) in Ypixel per out Y

	ldrb r0,gFlicker
	ldrb r2,gTwitch
	eors r2,r2,r0
	strb r2,gTwitch
	mov r9,#0
	orrne r9,r9,#0x56			;@ H flicker.
	addne r4,r4,r1
	subne r4,r4,#1

	ldr r10,windowVValue
	orr r10,r10,r10,lsl#16
	ldr r2,=DMA0BUFF
	ldr r11,=vdcMWReg
	ldrb r11,[r11]
	tst r11,#0x40				;@ Tilemap height 256 or 512?
	mov r11,#0x0FF00
	orrne r11,r11,#0x10000
	mov r12,#SCREEN_HEIGHT
scrolLoop2:
	mov r3,r4,lsl#17
	add r3,r5,r3,asr#13

	ldmia r3,{r6-r8}
	and r3,r6,#0x03
	mov r0,r7,lsr#16			;@ xScale (PA).
	and lr,r0,#0xFF
	mla r3,lr,r3,r9
	bic lr,r7,r0,lsl#16

	mov r7,r6,lsr#16
	mul r7,r1,r7
	adds r7,r7,r4
	addscs r7,r7,r1
	subcc r7,r7,r1

	add r6,r3,r6,lsl#8
	and r7,r11,r7,lsl#8
	stmia r2!,{r0,r1,r6,r7}				;@ BG2-(PA,PB),(PC,PD), BG2X & BG2Y
	stmia r2!,{r0,r1,r6,r7,r8,r10,lr}	;@ BG3-(PA,PB),(PC,PD), BG3X & BG3Y. WINxH & WINxV. WININOUT

	adds r4,r4,r1
	addcs r4,r4,#1
	subs r12,r12,#1
	bne scrolLoop2


	mov r9,#REG_BASE
	strh r9,[r9,#REG_DMA0CNT_H]	;@ DMA0 stop
	strh r9,[r9,#REG_DMA3CNT_H]	;@ DMA3 stop

	ldr r0,=DMA0BUFF			;@ setup DMA0 buffer for scrolling:
	add r1,r9,#REG_BG2PA		;@ DMA0 always goes here
	ldmia r0!,{r2-r8,r10-r12,lr}	;@ Read
	stmia r1,{r2-r8,r10-r12,lr}	;@ set 1st value manually, HBL is AFTER 1st line
	ldr r2,=0x9660000B			;@ noIRQ hblank 32bit repeat incsrc inc_reloaddst, 11 longwords
	add r8,r9,#REG_DMA0SAD
	stmia r8,{r0-r2}			;@ DMA0 go

	add r8,r9,#REG_DMA3SAD

	ldr r0,dmaOamBuffer			;@ DMA3 src, OAM transfer:
	mov r1,#OAM					;@ DMA3 dst
	mov r4,#0x84000000			;@ noIRQ 32bit incsrc incdst
	orr r2,r4,#0x100			;@ 128 sprites (1024 bytes)
	stmia r8,{r0-r2}			;@ DMA3 go

	ldr r0,=EMUPALBUFF			;@ DMA3 src, Palette transfer:
	mov r1,#BG_PALETTE			;@ DMA3 dst
//	orr r2,r4,#0x100			;@ 256 words (1024 bytes)
	stmia r8,{r0-r2}			;@ DMA3 go
	bl copyExtPalette

	ldr r0,=DELAYED_SPRITETILES	;@ DMA3 src, Sprite tiles:
	mov r1,#BG_GFX				;@ r6=NDS BG tileset
	orr r1,r1,#0x400000			;@ Spr ram
	orr r2,r4,#0x2000			;@ 8192 words (32kbytes)
	stmia r8,{r0-r2}			;@ DMA3 go

	ldr r2,=BGoffset1
	ldr r2,[r2]
	ldr r0,=0xE002				;@ 1024x1024, wrap BG & prio.
	add r0,r0,r2
	strh r0,[r9,#REG_BG2CNT]
	orr r0,r0,#0x0010			;@ VRAM 0x06020000
	orr r0,r0,#0x1000			;@ Map @ 0x06008000
	strh r0,[r9,#REG_BG3CNT]

	blx scanKeys
	ldmfd sp!,{r4-r11,pc}

displayControl:
	.short 0x3F40,0
windowVValue:
	.long 0x00C0
;@----------------------------------------------------------------------------
bgYScaleValue:	.long 0x0000FFFF			;@ was 0xE2AB
obXScaleValue:	.long 0x00010000
gTwitch:		.byte 0
gFlicker:		.byte 1
gColorValue:	.byte 4
gGfxMask:		.byte 0
gRgbYcbcr:		.byte 0
				.byte 0,0,0

;@----------------------------------------------------------------------------
midFrame:					;@ Called at line 96
;@----------------------------------------------------------------------------
	stmfd sp!,{r1-r9,r11,lr}

	ldr r1,=hCenter				;@ (screenwidth-256)/2
	ldr r1,[r1]
	str r1,sprCenter

	ldr r1,=vcePixelClock
	ldrb r1,[r1]
	mov r0,#0x0100				;@ 1 Xpixel per X
	mov r2,#0x10000				;@ Sprite scaling
	cmp r1,#1
	orreq r0,#0x0055			;@ 1,1/3 Xpixel per X
	moveq r2,#0xC000			;@ Sprite scaling
	movhi r0,#0x0200			;@ 2 Xpixel per X
	movhi r2,#0x8000			;@ Sprite scaling
	str r0,scaleParms+8
	rsb r0,r0,#0x10000
	add r0,r0,#0x01
	str r0,scaleParms+12
	str r2,obXScaleValue
	bl buildSpriteScaling

	bl sprDMADo
	ldmfd sp!,{r1-r9,r11,pc}

;@----------------------------------------------------------------------------
endFrame:					;@ Called just before screen end (~line 192)	(r0-r2 safe to use)
;@----------------------------------------------------------------------------
	stmfd sp!,{r1,r3-r9,r11,lr}

	bl newX

	ldr r1,=vdcBurst
	ldrb r0,[r1]
	cmp r0,#0
	mov r0,#0
	strb r0,[r1]

	ldreq r0,=0x0000			;@ If burstmode, wait until next frame with enabling bgr.
	moveq r1,#0					;@ 1?
	moveq addy,#239
	adr lr,vdcRet
	beq vdcCtrl1Finish
	bne newVDCCR
vdcRet:
;@--------------------------
	ldr r0,=0x0000				;@ WININBUFF
	ldr r1,=vdcEndFrameLine
	ldr r1,[r1]
	mov addy,#239
	bl vdcCtrl1Finish
;@--------------------------
	bl tileMapFinish
;@--------------------------

	ldr r0,dmaOamBuffer
	ldr r1,tmpOamBuffer
	str r0,tmpOamBuffer
	str r1,dmaOamBuffer

	ldr r0,scrollBuff
	ldr r1,dmaScrollBuff
	str r1,scrollBuff
	str r0,dmaScrollBuff

	ldr r0,BGoffset1
	ldr r1,BGoffset2
	str r0,BGoffset2
	str r1,BGoffset1

	mov r0,#1
	str r0,oamBufferReady

	ldr r0,=windowTop			;@ Load wTop, store in wTop+4.......load wTop+8, store in wTop+12
	ldmia r0,{r1-r3}			;@ Load with post increment
	stmib r0,{r1-r3}			;@ Store with pre increment
//	mov r0,#0x00FF
//	ldr r1,=BG_PALETTE_SUB		;@ Background palette
//	strh r0,[r1]				;@ Background palette

skipVBlWait:
//	mov r0,#0x7C00
//	ldr r1,=BG_PALETTE_SUB		;@ Background palette
//	strh r0,[r1]				;@ Background palette
	bl redrawTiles

//	mov r0,#BG_GFX				;@ NDS BG tileset
//	orr r0,r0,#0x400000			;@ Spr ram
//	ldr r1,=DELAYED_SPRITETILES	;@ DMA3 src, Sprite tiles:
//	mov r2,#0x8000				;@ 32kB
//	blx memcpy

	ldmfd sp!,{r1,r3-r9,r11,lr}
	bx lr

	.pool
;@----------------------------------------------------------------------------
setVDPMode:
;@----------------------------------------------------------------------------
	mov r0,#0
	ldrb r1,gScalingSet
	cmp r1,#SCALED_FIT
	moveq r0,#1
	cmp r1,#SCALED_ASPECT
	moveq r0,#2

	ldr r2,=BG_SCALING_TBL
	ldr r1,[r2,r0,lsl#2]
	str r1,bgYScaleValue
	ldr r2,=BG_SCALING_OFS
	ldr r1,[r2,r0,lsl#2]
	str r1,yStart
	ldr r2,=BG_SCALING_WIN
	ldr r1,[r2,r0,lsl#2]
	str r1,windowVValue

	bx lr
;@----------------------------------------------------------------------------
sprDMADo:					;@ Called from midframe. YATX
;@----------------------------------------------------------------------------
;@ Word 0 : ------aaaaaaaaaa
;@ Word 1 : ------bbbbbbbbbb
;@ Word 2 : -----ccccccccccd
;@ Word 3 : e-ffg--hi---jjjj

;@ a = Sprite Y position (0-1023)
;@ b = Sprite X position (0-1023)
;@ c = Pattern index (0-1023)
;@ d = CG mode bit (0= Read bitplanes 0/1, 1= Read bitplanes 2/3)
;@ e = Vertical flip flag 
;@ f = Sprite height (CGY) (0=16 pixels, 1=32, 2/3=64)
;@ g = Horizontal flip flag
;@ h = Sprite width (CGX) (0=16 pixels, 1=32)
;@ i = Sprite priority flag (1= high priority, 0= low priority)
;@ j = Sprite palette (0-15)

#define PRIORITY	(0x800)		// 0x800=AGB OBJ priority 2
	str lr,[sp,#-4]!


	ldr r9,=SPRTILELUT
	ldrb r0,sprMemReload
	cmp r0,#0
	beq noReload
	mov r0,r9					;@ r0=destination
	mov r1,#0					;@ r1=value
	mov r2,#768					;@ 512+256 tile entries
	bl memset_					;@ Clear lut
	strb r1,sprMemReload		;@ Clear spr mem reload.
	strb r1,sprMemAlloc			;@ Clear spr mem alloc.
noReload:

	ldr addy,=vdcSpriteRam		;@ Source
	ldr r2,tmpOamBuffer			;@ Destination

	ldr r8,=DIRTYTILES

//	cmp r5,#12*256				;@ Do autoscroll
//	cmp r5,#UNSCALED_AUTO*256	;@ Do autoscroll
//	bhi dm2
//	bne dm0
//	mov r3,r1,lsr#16			;@ r3=follow value
//	tst r1,#FOLLOWMEM
//	ldrbne r0,[h6280zpage,r3]	;@ Follow memory
//	moveq r3,r3,lsl#3
//	ldrheq r0,[addy,r3]			;@ Follow sprite
//	bic r0,r0,#0xfe00
//	subs r0,r0,#104				;@ Something like that
//	movmi r0,#0
//	add r0,r0,r0,lsl#3
//	mov r0,r0,lsr#4
//	ldr r5,vblscanlinecpu		;@ <240
//	sub r5,r5,#SCREEN_HEIGHT
//	mov r5,#0
//	cmp r0,r5
//	movhi r0,r5
//	str r0,windowTop+4
//dm0:
//	ldr r0,windowTop+8
//dm2:
	ldr r5,bgYScaleValue
	ldr r6,obXScaleValue
	add r5,r5,#1				;@ 1:1 scaling is 0xFFFF

	adr lr,ret01
dm11:
	ldr r7,=0x000003ff
	ldmia addy!,{r3,r4}			;@ PCE OBJ, r3=Y & X, r4=Pattern, flip, palette, prio & size.
	ands r0,r3,r7				;@ Mask Y
	beq dm10					;@ Skip if sprite Y=0
	sub r0,r0,#0x3F				;@ 0x40 - 1
	ldr r1,sHeight
	cmp r0,r1
	bpl dm10					;@ Skip if sprite Y>=ScreenHeight
	ldr r1,sprCenter			;@ (screenwidth-256)/2
	rsb r3,r1,r3,lsr#16			;@ x = x-(32+hcenter)
	and r3,r3,r7				;@ Mask X
	sub r3,r3,#32
	tst r4,#0x21000000			;@ Check Xsize and ysize = 64.
	moveq r7,#8
	movne r7,#16
	add r3,r3,r7				;@ Add half of sprite width
	mul r3,r6,r3				;@ x = scaled x
	mov r3,r3,asr#16
	sub r3,r3,r7				;@ Sub half of sprite width
	cmp r3,#256
	bpl dm10					;@ Skip if sprite X>255

	tst r4,#0x30000000			;@ Check Ysize
	moveq r7,#1
	movne r7,#2
	tst r4,#0x20000000
	movne r7,#4					;@ Length of spr copy.

	add r0,r0,r7,lsl#3			;@ Add half of sprite height
	ldr r1,yStart				;@ First scanline?
	sub r0,r0,r1
	mul r0,r5,r0				;@ y = scaled y
	mov r0,r0,asr#16
	sub r0,r0,r7,lsl#3			;@ Sub half of sprite height
	cmp r0,#SCREEN_HEIGHT
	bpl dm10
	cmn r0,#0x40
	bmi dm10
	and r0,r0,#0xFF

	and r1,r4,#0x29000000
	cmp r1,#0x28000000			;@ 16x64 x-flipped.
	subeq r3,r3,#0x10
	bic r3,r3,#0xfe00
	orr r0,r0,r3,lsl#16

	movs r1,r4,lsr#24
	ldr r3,=flipsizeTable
	ldr r1,[r3,r1,lsl#2]
	orrcc r1,r1,#0x00000400		;@ Set Transp OBJ.
	cmp r5,#0x10000				;@ Vertical scaling?
	cmppl r6,#0x10000			;@ Horizontal scaling?
	orrmi r0,r0,#0x100			;@ Scaled sprites.
	orr r0,r0,r1
	str r0,[r2],#4				;@ Store OBJ Atr 0,1. Xpos, ypos, flip, scale/rot, size, shape, prio(transp).

	mov r1,r4,lsl#22			;@ and 0x1ff
	mov r1,r1,lsr#23
	tst r4,#0x01000000			;@ Check width
	bne VRAM_spr_32				;@ Jump to spr copy, takes tile# in r1, gives new tile# in r0
	beq VRAM_spr_16				;@ --		lr allready points to ret01
ret01:
	and r0,r0,#0xff				;@ Tile mask
	mov r0,r0,lsl#2				;@ New tile# from spr routine.
	and r1,r4,#0x000f0000		;@ Color
	orr r0,r0,r1,lsr#4
	orr r0,r0,#PRIORITY			;@ Priority
	strh r0,[r2],#4				;@ Store OBJ Atr 2. Pattern, palette.
dm9:
	ldr r0,=vdcSpriteRam+0x200
	cmp addy,r0
	bne dm11
	ldr pc,[sp],#4
dm10:
	mov r0,#0x200+SCREEN_HEIGHT	;@ Double, y=SCREEN_HEIGHT
	str r0,[r2],#8
	b dm9

;@----------------------------------------------------------------------------
VRAM_spr_16:		;@ Takes tilenumber in r1, returns new tilenumber in r0
;@----------------------------------------------------------------------------
	cmp r7,#2
	bicpl r1,r1,r7
	bichi r1,r1,r7,lsr#1
	ldr r0,[r9,r1,lsl#2]
	cmp r7,r0,lsr#16
	ble lutHit16
noLutHit16:
	ldrb r0,sprMemAlloc
	orr r0,r0,r7,lsl#16
	str r0,[r9,r1,lsl#2]
	stmfd sp!,{r0-r6,lr}

	cmp r7,#2
	addeq r4,r1,#2
	addeq r3,r0,#1				;@ r7= 1,2 or 4
	streq r3,[r9,r4,lsl#2]

	add r3,r0,r7				;@ r7= 1,2 or 4
	addhi r3,r3,r7				;@ 16x64 sprite

	strb r3,sprMemAlloc
	tst r3,#0x100
	movne r3,#0xab
	strbne r3,sprMemReload
	b do16
lutHit16:
	stmfd sp!,{r0-r6,lr}

	tst r7,#6					;@ Check sprite height.
	beq cacheHit00
	tst r7,#4					;@ Height 64.
	bne checkCache16x64
	add r3,r8,r1
	ldrb r2,[r3]				;@ Check dirtymap
	ldrb r4,[r3,#2]				;@ Check dirtymap
	and r5,r2,r4
	tst r5,#0x80
	bne cacheHit16
	orr r2,r2,#0x80
	orr r4,r4,#0x80
	strb r2,[r3]				;@ Clear dirtymap
	strb r4,[r3,#2]				;@ Clear dirtymap
	b do16
checkCache16x64:
	add r3,r8,r1
	ldrb r2,[r3]				;@ Check dirtymap
	ldrb r4,[r3,#2]				;@ Check dirtymap
	and r5,r2,r4
	orr r2,r2,#0x80
	strb r2,[r3]				;@ Clear dirtymap
	orr r4,r4,#0x80
	strb r4,[r3,#2]				;@ Clear dirtymap
	ldrb r2,[r3,#4]				;@ Check dirtymap
	and r5,r5,r2
	orr r2,r2,#0x80
	strb r2,[r3,#4]				;@ Clear dirtymap
	ldrb r2,[r3,#6]				;@ Check dirtymap
	and r5,r5,r2
	orr r2,r2,#0x80
	strb r2,[r3,#6]				;@ Clear dirtymap
	tst r5,#0x80
	bne cacheHit16
	b do16

cacheHit00:
	ldrb r2,[r8,r1]				;@ Check dirtymap
	tst r2,#0x80
	bne cacheHit16
	orr r2,r2,#0x80
	strb r2,[r8,r1]				;@ Clear dirtymap
;@-----------------------------------------
do16:
	and r0,r0,#0xff
	ldr r4,=PCE_VRAM+1
	ldr r5,=SPR_DECODE
//	mov r6,#BG_GFX				;@ r6=NDS BG tileset
//	orr r6,r6,#0x400000			;@ Spr ram
	ldr r6,=DELAYED_SPRITETILES
	add r4,r4,r1,lsl#7
	add r6,r6,r0,lsl#7

	tst r7,#4					;@ 16x64 sprite
	bne spr16x64				;@ 16x64 sprite
spr1:
	ldrb r0,[r4],#2				;@ Read 1st plane
	ldrb r1,[r4,#30]			;@ Read 2nd plane
	ldrb r2,[r4,#62]			;@ Read 3rd plane
	ldrb r3,[r4,#94]			;@ Read 4th plane

	ldr r0,[r5,r0,lsl#2]
	ldr r1,[r5,r1,lsl#2]
	ldr r2,[r5,r2,lsl#2]
	ldr r3,[r5,r3,lsl#2]
	orr r0,r0,r1,lsl#1
	orr r2,r2,r3,lsl#1
	orr r0,r0,r2,lsl#2
	str r0,[r6],#4
	tst r6,#0x1c
	bne spr1
	tst r6,#0x20
	subne r4,r4,#17
	bne spr1
	add r4,r4,#1

	tst r6,#0x40
	bne spr1

	subs r7,r7,#1				;@ nr of 16 blocks
	addne r4,r4,#224
	bne spr1

cacheHit16:
	ldmfd sp!,{r0-r6,pc}
;@----------------------------------------------------------------------------
spr16x64:
;@----------------------------------------------------------------------------
	mov r7,r7,lsl#1
do64:
	ldrb r0,[r4],#2				;@ Read 1st plane
	ldrb r1,[r4,#30]			;@ Read 2nd plane
	ldrb r2,[r4,#62]			;@ Read 3rd plane
	ldrb r3,[r4,#94]			;@ Read 4th plane

	ldr r0,[r5,r0,lsl#2]
	ldr r1,[r5,r1,lsl#2]
	ldr r2,[r5,r2,lsl#2]
	ldr r3,[r5,r3,lsl#2]
	orr r0,r0,r1,lsl#1
	orr r2,r2,r3,lsl#1
	orr r0,r0,r2,lsl#2
	str r0,[r6],#4
	tst r6,#0x1c
	bne do64
	tst r6,#0x20
	subne r4,r4,#17
	bne do64
	add r4,r4,#1

	mov r0,#0
	mov r1,#0x10
sprClr:
	str r0,[r6],#4
	subs r1,r1,#1
	bne sprClr

	sub r7,r7,#1
	tst r7,#0x01
	bne do64

	cmp r7,#0					;@ nr of 16 blocks
	addne r4,r4,#224
	bne do64

	ldmfd sp!,{r0-r6,pc}
;@----------------------------------------------------------------------------
VRAM_spr_32:		;@ Takes tilenumber in r1, returns new tilenumber in r0
;@----------------------------------------------------------------------------
	bic r1,r1,#1
	bic r1,r1,r7
	bic r1,r1,r7,lsr#1
	orr r3,r1,#0x400
	ldr r0,[r9,r3,lsl#1]
	cmp r7,r0,lsr#17
	ble lutHit32
noLutHit32:
	ldrb r0,sprMemAlloc
	orr r0,r0,r7,lsl#17
	str r0,[r9,r3,lsl#1]
	stmfd sp!,{r0-r6,lr}


	cmp r7,#2
	addpl r4,r3,#2
	addpl r5,r0,#2
	strpl r5,[r9,r4,lsl#1]

	addhi r4,r4,#2
	addhi r5,r5,#2
	strhi r5,[r9,r4,lsl#1]
	addhi r4,r4,#2
	addhi r5,r5,#2
	strhi r5,[r9,r4,lsl#1]

	add r3,r0,r7,lsl#1
	strb r3,sprMemAlloc
	tst r3,#0x100
	movne r3,#0xab
	strbne r3,sprMemReload
	b do32
lutHit32:
	stmfd sp!,{r0-r6,lr}

	ldr r5,=0x40404040
	cmp r7,#2
	bmi cacheHit01
	add r3,r8,r1
	beq cacheHit02

	ldr r2,[r3,#4]				;@ Check dirtymap
	bics r4,r5,r2
	beq cacheHit02
	orr r2,r2,r5
	str r2,[r3,#4]				;@ Clear dirtymap
	ldr r2,[r3]					;@ Check dirtymap
	orr r2,r2,r5
	str r2,[r3]					;@ Clear dirtymap
	b do32
cacheHit02:
	ldr r2,[r3]					;@ Check dirtymap
	bics r4,r5,r2
	beq cacheHit32
	orr r2,r2,r5
	str r2,[r3]					;@ Clear dirtymap
	b do32

cacheHit01:
	ldrh r2,[r8,r1]				;@ Check dirtymap
	eor r2,r2,r5,lsr#16
	tst r2,r5,lsr#16
	beq cacheHit32
	orr r2,r2,r5
	strh r2,[r8,r1]				;@ Clear dirtymap
;@-----------------------------------------------
do32:
	mov r7,r7,lsl#1
	and r0,r0,#0xff
	ldr r4,=PCE_VRAM+1
	ldr r5,=SPR_DECODE
//	mov r6,#BG_GFX				;@ r6=NDS BG tileset
//	orr r6,r6,#0x400000			;@ Spr ram
	ldr r6,=DELAYED_SPRITETILES
	add r4,r4,r1,lsl#7
	add r6,r6,r0,lsl#7

spr2:
	ldrb r0,[r4],#2				;@ Read 1st plane
	ldrb r1,[r4,#30]			;@ Read 2nd plane
	ldrb r2,[r4,#62]			;@ Read 3rd plane
	ldrb r3,[r4,#94]			;@ Read 4th plane

	ldr r0,[r5,r0,lsl#2]
	ldr r1,[r5,r1,lsl#2]
	ldr r2,[r5,r2,lsl#2]
	ldr r3,[r5,r3,lsl#2]
	orr r0,r0,r1,lsl#1
	orr r2,r2,r3,lsl#1
	orr r0,r0,r2,lsl#2
	str r0,[r6],#4
	tst r6,#0x1c
	bne spr2
	tst r6,#0x20
	subne r4,r4,#17
	bne spr2

	tst r6,#0x040
	addne r4,r4,#113
	bne spr2

	sub r7,r7,#1
	tst r7,#0x01
	subne r4,r4,#127
	bne spr2

	cmp r7,#0					;@ Nr of 16 blocks
	addne r4,r4,#97
	bne spr2

cacheHit32:
	ldmfd sp!,{r0-r6,pc}



;@----------------------------------------------------------------------------
doDTMap:
;@----------------------------------------------------------------------------
	orr r2,r0,r9,lsr#7
	str r2,[r6,r8]				;@ Write to dirtymap.
	mov r3,r8,lsl#8
	ldr r10,=0xF3FF
	b dTTest

dTStart:
dTLoop:
	ldr r0,[r4,r3,lsr#1]
	mov r1,#0

	movs r2,r0,lsl#16+6
	adcseq r0,r0,#0x0000		;@ Remap 0x400 to 0x001, always clear carry
	orrcs r1,r1,r10				;@ Map tiles 0x401-0x7FF to BG3
	mov r0,r0,ror#16

	movs r2,r0,lsl#16+6
	adcseq r0,r0,#0x0000		;@ Remap 0x400 to 0x001, always clear carry
	orrcs r1,r1,r10,lsl#16		;@ Map tiles 0x401-0x7FF to BG3

	and r1,r1,r0,ror#16
	eor r0,r1,r0,ror#16

	strd r0,r1,[r5,r3]
	add r3,r3,#8
	tst r3,#0xF8
	bne dTLoop
dTTest:
	movs r7,r7,lsr#8
	bcs dTStart
	addcc r3,r3,#0x100
	bne dTTest
	b dtiRet
;@----------------------------------------------------------------------------
tileMapFinish:					;@ End of frame...  finish up BGxCNTBUFF
;@----------------------------------------------------------------------------
	stmfd sp!,{r3-r11,lr}

	ldr r4,=PCE_VRAM
	ldr r5,=DELAYED_TILEMAP
	ldr r6,=DIRTYTILES
	ldr r9,=0x80808080
	mov r8,#0x7C
dtiLoop:
	ldr r0,[r6,r8]				;@ Read from dirtymap.
	bics r7,r9,r0,lsl#7
	bne doDTMap
dtiRet:
	subs r8,r8,#4
	bpl dtiLoop

;@----------------------------------------------------------------------------
tileMapCont:
	ldr r8,scrollBuff
	ldr r2,=vdcMWReg
	ldrb r2,[r2]
	mov lr,#0x00F80000			;@ Mask for x & y values.
	orr lr,lr,#0x000000F0		;@ Screen width 32
	tst r2,#0x40				;@ Screen height, 32 or 64 tiles.
	orrne lr,lr,#0x01000000
	tst r2,#0x10
	orrne lr,lr,#0x000001F0		;@ Screen width 64
	tst r2,#0x20
	orrne lr,lr,#0x000003F0		;@ Screen width 128
	mov lr,lr,lsr#1

	mov r4,#0
	ldr r1,=vdcEndFrameLine
	ldr r3,[r1]
	str r3,sHeight

	mov r9,#BG_GFX
	ldr r0,BGoffset2
	add r9,r9,r0,lsl#3
	str r9,tMapAdr

	mov r6,#-1

;@----------------------------------------------------------------------------
;@chrFinish2	;End of frame...  finish up BGxCNTBUFF
;@----------------------------------------------------------------------------
tslo2:
	ldr r0,[r8],#16				;@ X & Y offset
	add r0,r0,r4,lsl#16
	and r0,r0,lr,lsl#1			;@ lr = Width & height mask
	cmp r6,r0
	bne tsbo2
tsbo1:
	add r4,r4,#1
	cmp r4,r3					;@ Last scanline.
	bmi tslo2

	ldmfd sp!,{r3-r11,pc}

tsbo2:
	ldrh r1,[r8,#-10]			;@ Pixel clock
	and r1,r1,#0x3F0
	cmp r1,#0x150
	movmi r7,#16+2
	moveq r7,#21+2
	movhi r7,#32+2
	mov r6,r0

	add r1,lr,#0x80
	mov r1,r1,lsr#8
	and r1,r1,#0x3				;@ 1 or 2
	rsb r1,r1,#12
	add r10,r5,r0,lsr r1

	add r11,r9,r0,lsr#11
	add r12,r11,#0x00008000
	mov r2,r0,lsl#22			;@ r2 = x startpos
trLoop:
	and r1,lr,r2,lsr#23
	ldrd r0,r1,[r1,r10]			;@ Read from virtual delayed tilemap

	str r0,[r11,r2,lsr#24]		;@ Write to NDS tilemap
	str r1,[r12,r2,lsr#24]		;@ Write to NDS tilemap
	add r2,r2,#0x04000000
	subs r7,r7,#1
	bne trLoop
	b tsbo1

;@----------------------------------------------------------------------------
redrawTiles:
;@----------------------------------------------------------------------------
	stmfd sp!,{r3-r11,lr}
	ldr r4,=PCE_VRAM
	ldr r5,=BGR_DECODE
	mov r6,#BG_GFX				;@ r6=NDS BG tileset
	add r6,r6,#0x10000			;@ Tile ram 2
	ldr r7,=DIRTYTILES
	ldr r9,=0x20202020
	mov r11,#0xFF
	mov r11,r11,lsl#3
	mov r8,#0x1FC
tiLoop:
	ldr r0,[r7,r8]				;@ Read from dirtymap.
	bics r1,r9,r0
	blne doTiles
	subs r8,r8,#4
	bpl tiLoop

;@ Remap tile 1024 to 1.

	add r4,r4,#0x8000
	sub r4,r4,#0x0020
	movs r8,#0
	mov r10,#1
	bl cleanUpTile
	ldmfd sp!,{r3-r11,pc}

doTiles:
	orr r2,r0,r9
	str r2,[r7,r8]				;@ Write to dirtymap.

	tst r8,#0xFC
	movne r10,#0x10
	moveq r10,#0x0F
cleanUpTile:
	stmfd sp!,{r4,r6,r7,lr}
	addeq r4,r4,#0x0020
	addeq r6,r6,#0x0040
	add r4,r4,r8,lsl#7
	add r6,r6,r8,lsl#8

chr1:
	ldr r7,[r4],#4				;@ Read 1st & 2nd plane
	ldr r12,[r4,#12]			;@ Read 3rd & 4th plane

	and lr,r11,r7,lsl#3
	ldrd r0,r1,[r5,lr]

	ands lr,r11,r7,lsr#5
	ldrdne r2,r3,[r5,lr]
	orrne r0,r0,r2,lsl#1
	orrne r1,r1,r3,lsl#1

	ands lr,r11,r12,lsl#3
	ldrdne r2,r3,[r5,lr]
	orrne r0,r0,r2,lsl#2
	orrne r1,r1,r3,lsl#2

	ands lr,r11,r12,lsr#5
	ldrdne r2,r3,[r5,lr]
	orrne r0,r0,r2,lsl#3
	orrne r1,r1,r3,lsl#3

	strd r0,r1,[r6],#8

	and lr,r11,r7,lsr#13
	ldrd r0,r1,[r5,lr]

	ands lr,r11,r7,lsr#21
	ldrdne r2,r3,[r5,lr]
	orrne r0,r0,r2,lsl#1
	orrne r1,r1,r3,lsl#1

	ands lr,r11,r12,lsr#13
	ldrdne r2,r3,[r5,lr]
	orrne r0,r0,r2,lsl#2
	orrne r1,r1,r3,lsl#2

	ands lr,r11,r12,lsr#21
	ldrdne r2,r3,[r5,lr]
	orrne r0,r0,r2,lsl#3
	orrne r1,r1,r3,lsl#3

	strd r0,r1,[r6],#8

	tst r6,#0x30
	bne chr1
	addeq r4,r4,#0x10
	subs r10,r10,#1
	bne chr1

	ldmfd sp!,{r4,r6,r7,pc}
;@----------------------------------------------------------------------------
tmpOamBuffer:		.long OAM_BUFFER1
dmaOamBuffer:		.long OAM_BUFFER2

scrollBuff:			.long SCROLLBUFF1
dmaScrollBuff:		.long SCROLLBUFF2

oamBufferReady:		.long 0
;@----------------------------------------------------------------------------

				.long 0
sHeight:		.long 0
tMapAdr:		.long BG_GFX
sprCenter:		.long 0

adjustBlend:
	.long 1
windowTop:
	.long 0
wTop:
	.long 0,0,0		;@ windowTop  (this label too)   L/R scrolling in unscaled mode
BGoffset1:		.long 0
BGoffset2:		.long 0
BGoffset333:	.long 0

gfxState:
yStart:
	.long 0

sprMemAlloc:
	.byte 0
sprMemReload:
	.byte 0
	.skip 8

gScalingSet:
	.byte SCALED_ASPECT		;@ scalemode(saved display type), default scale to fit
sprCollision:		.byte 0x20
	.pool

	.section .bss
	.align 8					;@ Align to 256 bytes for RAM
PCE_VRAM:
	.space 0x10000
DELAYED_TILEMAP:
	.space 0x4000*2
DELAYED_SPRITETILES:
	.space 0x8000
	.space 0x400
DirtyTilesBackup:
	.space 0x200

SPRTILELUT:
	.space 768*4

	.space 128*16				;@ Emptybuffer.
SCROLLBUFF1:
	.space 264*16				;@ Scrollbuffer.
	.space 128*16				;@ Emptybuffer.
SCROLLBUFF2:
	.space 264*16				;@ Scrollbuffer.

DMA0BUFF:
	.space 200*4*11				;@ Scroll reg buffer 0
EMUPALBUFF:
	.space 0x400
OAM_BUFFER1:
	.space 0x400
OAM_BUFFER2:
	.space 0x400

#ifdef NDS
	.section .sbss				;@ This is DTCM on NDS with devkitARM
#elif GBA
	.section .bss				;@ This is IWRAM on GBA with devkitARM
#else
	.section .bss
#endif
	.align 2
DIRTYTILES:						;@ bit0 = mode0 bgr, bit1 = mode1 bgr
	.space 0x200
SPR_DECODE:
	.space 0x400
BGR_DECODE:
	.space 0x400*2				;@ double longs.

;@----------------------------------------------------------------------------
	.end
#endif // #ifdef __arm__
