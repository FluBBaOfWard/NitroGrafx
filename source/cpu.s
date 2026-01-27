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
#include "Equates.h"

#define CYCLE_PSL (455)

	.global waitMaskIn
	.global waitMaskOut
	.global frameTotal

	.global cpuReset
	.global run

	.syntax unified
	.arm

#ifdef GBA
	.section .ewram, "ax", %progbits	;@ For the GBA
#else
	.section .text						;@ For anything else
#endif
	.align 2
;@----------------------------------------------------------------------------
run:						;@ Return after X frame(s)
	.type run STT_FUNC
;@----------------------------------------------------------------------------
	ldrh r0,waitCountIn
	add r0,r0,#1
	ands r0,r0,r0,lsr#8
	strb r0,waitCountIn
	bxne lr
	stmfd sp!,{r4-r11,lr}

	ldr h6280ptr,=h6280OpTable
;@----------------------------------------------------------------------------
runStart:
;@----------------------------------------------------------------------------
	ldr r0,=EMUinput
	ldr r0,[r0]
	tst r0,#0x300				;@ L or R?
	beq skipYPan
	ldr r1,=gScalingSet
	ldrb r1,[r1]
	cmp r1,#SCALED_1_1
	bne skipYPan
	ldr r2,=yStart
	ldr r1,[r2]
	tst r0,#0x100				;@ R?
	addne r1,#1
	tst r0,#0x200				;@ L?
	subsne r1,#1
	movmi r1,#0
	ldr r0,=vdcEndFrameLine
	ldr r0,[r0]
	sub r0,r0,#SCREEN_HEIGHT
	cmp r1,r0
	movpl r1,r0
	str r1,[r2]
skipYPan:

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

	ldr r1,=gConfigSet
	ldrb r1,[r1]
	ldr r2,=EMUinput
	ldr r2,[r2]
	and r1,r1,r2,lsr#4			;@ R button and config FF
	ands r1,r1,#0x10

	ldrh r0,waitCountOut
	orrne r0,r0,#0x0300
	add r0,r0,#1
	ands r0,r0,r0,lsr#8
	strb r0,waitCountOut
	ldmfdeq sp!,{r4-r11,lr}		;@ Exit here if doing single frame:
	bxeq lr						;@ Return to rommenu()
	b runStart

;@----------------------------------------------------------------------------

;@----------------------------------------------------------------------------
scanlineCycles:		.long CYCLE_PSL
frameTotal:			;@ Let Gui.c see frame count for savestates
					.long 0
waitCountIn:		.byte 0
waitMaskIn:			.byte 0
waitCountOut:		.byte 0
waitMaskOut:		.byte 0

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
