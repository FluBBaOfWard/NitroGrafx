//
//  cpu.s
//  NitroGrafx
//
//  Created by Fredrik Ahlström on 2003-01-01.
//  Copyright © 2003-2026 Fredrik Ahlström. All rights reserved.
//
#ifdef __arm__

#include "Shared/nds_asm.h"
#include "ARMH6280/H6280.i"

#define CYCLE_PSL (455)

	.global cpuReset
	.global run
	.global frameTotal

	.syntax unified
	.arm

	.section .text
	.align 2
;@----------------------------------------------------------------------------
run:		;@ return after 1 frame
	.type run STT_FUNC
;@----------------------------------------------------------------------------

	stmfd sp!,{r4-r11,lr}

	ldr h6280ptr,=h6280OpTable
;@----------------------------------------------------------------------------
runStart:
;@----------------------------------------------------------------------------
	ldr r0,=EMUinput
	ldr r0,[r0]

	ldr r2,=yStart
	ldrb r1,[r2]
	tst r0,#0x200				;@ L?
	subsne r1,#1
	movmi r1,#0
	tst r0,#0x100				;@ R?
	addne r1,#1
	cmp r1,#224-SCREEN_HEIGHT
	movpl r1,#224-SCREEN_HEIGHT
//	strb r1,[r2]

	bl refreshEMUjoypads		;@ Z=1 if communication ok

	bl newFrame					;@ Display update
	bl updateCDROM				;@ Update CD counters and stuff
@	bl updateSound

	add r0,h6280ptr,#h6280Regs
	ldmia r0,{h6280nz-h6280pc,h6280zpage}	;@ Restore H6280 state

//	mov r11,r11					;@ No$GBA breakpoint.
	ldr r0,[h6280ptr,#h6280NextTimeout]
	bx r0
//	ldr r0,scanlineCycles
//	b h6280RunXCycles

;@----------------------------------------
SGXFrameLoop:
	bl VDCDoScanline
;@----------------------------------------
PCEFrameLoop:
	bl VDCDoScanline
	cmp r0,#0
	ldreq r0,scanlineCycles
	beq h6280RunXCycles
;@----------------------------------------------------------------------------

	add r0,h6280ptr,#h6280Regs
	stmia r0,{h6280nz-h6280pc,h6280zpage}	;@ Save H6280 state

	ldr r1,=fpsValue
	ldr r0,[r1]
	add r0,r0,#1
	str r0,[r1]

	ldr r0,frameTotal
	add r0,r0,#1
	str r0,frameTotal

	ldmfd sp!,{r4-r11,lr}		;@ Exit here:
	bx lr						;@ Return to rommenu()


;@----------------------------------------------------------------------------

/*
lineVBL:	;@------------------------
	ldr r0,[h6280ptr,#h6280_cyclesPerScanline]
	sub r0,r0,#1024*CYCLE
	add cycles,cycles,r0
	ldr r0,frameTotal
	add r0,r0,#1
	str r0,frameTotal

	adr addy,vdcCheck
	str addy,[h6280ptr,#h6280_nextTimeout]
	str addy,[h6280ptr,#h6280_nextTimeout_]

;@-------------------------------------------------
	bl endFrame					;@ display update
;@-------------------------------------------------
	ldr r0,=scanline
	ldr r1,[r0]
	add r1,r1,#1
	str r1,[r0]
	ldr pc,scanlineHook

vdcCheck:
	ldr r0,=vdcCtrl1
	ldrb r0,[r0]
	tst r0,#0x08				;@ VBl IRQ?
	movne r2,#0x20				;@ VBlank bit
//	ldrne addy,=vdcStat			;@ VBl irq
	strbne r2,[addy]

	add cycles,cycles,#7*4*CYCLE

	adr addy,vblCheck
	str addy,[h6280ptr,#h6280_nextTimeout]
	str addy,[h6280ptr,#h6280_nextTimeout_]
	b h6280CheckIrqs

vblCheck:
	add cycles,cycles,#1024*CYCLE
	sub cycles,cycles,#7*4*CYCLE

	adr addy,lineVBL_to_SPR
	str addy,[h6280ptr,#h6280_nextTimeout]
	str addy,[h6280ptr,#h6280_nextTimeout_]

	ldr r0,=vdcCtrl1
	ldrb r0,[r0]
	tst r0,#0x08				;@ vbl IRQ?
	beq h6280CheckIrqs

	setIrqPin VDCIRQ_F
	b h6280CheckIrqs


lineVBL_to_SPR: ;@------------------------
	ldr r0,[h6280ptr,#h6280_cyclesPerScanline]
	add cycles,cycles,r0

	ldr r0,=scanline
	ldr r1,[r0]
	add r1,r1,#1
	str r1,[r0]
//	ldr r2,vblScanlineCpu
	add r2,r2,#3
	cmp r1,r2
	ldrmi pc,scanlineHook
;@---------------------
	adr addy,lineSPR_to_end
	str addy,[h6280ptr,#h6280_nextTimeout]
	str addy,[h6280ptr,#h6280_nextTimeout_]

//	bl sprDMA_W
	ldr pc,scanlineHook

lineSPR_to_end: ;@------------------------
	ldr r0,[h6280ptr,#h6280_cyclesPerScanline]
	add cycles,cycles,r0

	ldr r0,=scanline
	ldr r1,[r0]
	add r1,r1,#1
	str r1,[r0]
//	ldr r2,vblScanlineCpu
	add r2,r2,#8
	cmp r1,r2
//	bleq vramDMA_W

//	ldr r2,lastScanline
	cmp r1,r2
	adrpl addy,line0
	strpl addy,[h6280ptr,#h6280_nextTimeout]
	strpl addy,[h6280ptr,#h6280_nextTimeout_]

	ldr pc,scanlineHook
*/
;@----------------------------------------------------------------------------
scanlineCycles:		.long CYCLE_PSL
frameTotal:			;@ Let Gui.c see frame count for savestates
					.long 0

;@----------------------------------------------------------------------------
cpuReset:					;@ Called by loadcart/resetGame
	.type cpuReset STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}

	ldr r0,=CYCLE_PSL			;@ 455
	str r0,scanlineCycles

	adr r0,PCEFrameLoop
	str r0,[h6280ptr,#h6280NextTimeout]
	str r0,[h6280ptr,#h6280NextTimeout_]

//	bl h6280Hacks
	bl h6280Reset

	ldmfd sp!,{lr}
	bx lr
;@----------------------------------------------------------------------------
	.end
#endif // #ifdef __arm__
