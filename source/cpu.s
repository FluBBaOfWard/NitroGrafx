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
#include "Shared/EmuMenu.i"

#define CYCLE_PSL (455)

	.global waitMaskIn
	.global waitMaskOut
	.global frameTotal

	.global run
	.global stepFrame
	.global cpuReset

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
	tst r0,#ACT_SCRL_DOWN|ACT_SCRL_UP
	beq skipYPan
	ldr r1,=gScalingSet
	ldrb r1,[r1]
	cmp r1,#SCALED_1_1
	bne skipYPan
	ldr r2,=yStart
	ldr r1,[r2]
	tst r0,#ACT_SCRL_DOWN
	addne r1,#1
	tst r0,#ACT_SCRL_UP
	subsne r1,#1
	movmi r1,#0
	ldr r0,=vdcEndFrameLine
	ldr r0,[r0]
	sub r0,r0,#SCREEN_HEIGHT
	cmp r1,r0
	movpl r1,r0
	str r1,[r2]
skipYPan:

	bl refreshEMUjoypads

	add r0,h6280ptr,#h6280Regs
	ldmia r0,{h6280nz-h6280pc,h6280zpage}	;@ Restore H6280 state

;@----------------------------------------
SGXFrameLoop:
//	bl VDCDoScanline
;@----------------------------------------
PCEFrameLoop:
	bl updateCDROM				;@ Update CD counters and stuff
	ldr r0,scanlineCycles
	bl h6280RunXCycles
#ifdef SAMPLE_PLAYING
	bl soundUpdate
#endif
	bl VDCDoScanline
	cmp r0,#0
	beq PCEFrameLoop
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
stepFrame:					;@ Return after 1 frame
	.type stepFrame STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r11,lr}
	ldr h6280ptr,=h6280OpTable
	bl updateCDROM				;@ Update CD counters and stuff
	add r0,h6280ptr,#h6280Regs
	ldmia r0,{h6280nz-h6280pc,h6280zpage}	;@ Restore H6280 state
;@----------------------------------------------------------------------------
stepLoop:
;@----------------------------------------------------------------------------
	ldr r0,scanlineCycles
	bl h6280RunXCycles
#ifdef SAMPLE_PLAYING
	bl soundUpdate
#endif
	bl VDCDoScanline
	cmp r0,#0
	beq stepLoop
;@----------------------------------------------------------------------------
	add r0,h6280ptr,#h6280Regs
	stmia r0,{h6280nz-h6280pc,h6280zpage}	;@ Save H6280 state

	ldmfd sp!,{r4-r11,lr}
	bx lr
;@----------------------------------------------------------------------------
cpuReset:					;@ Called by loadcart/resetGame
	.type cpuReset STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}

	ldr r0,=CYCLE_PSL			;@ 455
	str r0,scanlineCycles

//	bl h6280Hacks
	bl h6280Reset

	ldmfd sp!,{lr}
	bx lr
;@----------------------------------------------------------------------------
	.end
#endif // __arm__
