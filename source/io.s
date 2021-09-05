#ifdef __arm__

#include "ARMH6280/H6280.i"
#include "Equates.h"

	.global ioReset
	.global IO_R
	.global IO_W
	.global refreshEMUjoypads

	.global ioState
	.global joyCfg
	.global EMUinput

	.syntax unified
	.arm

	.section .text
	.align 2
;@----------------------------------------------------------------------------
ioReset:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}

	ldr r1,=joySelect
	mov r0,#0
	strb r0,[r1],#1
	strb r0,[r1]
	strb r0,joy6ButtonSw

	str r0,ioState

	ldr r12,=g_hwFlags
	ldrb r12,[r12]

	tst r12,#AC_CARD
	ldreq r1,=emptyRead
	ldreq r2,=emptyWrite
	ldrne r1,=ARCADE_R
	ldrne r2,=ARCADE_W
	str r1,arcadeReadPtr
	str r2,arcadeWritePtr

	tst r12,#CD_DEVICE
	ldreq r1,=emptyRead
	ldreq r2,=emptyWrite
	ldrne r1,=CDROM_R
	ldrne r2,=CDROM_W
	str r1,cdromReadPtr
	str r2,cdromWritePtr

	mov r0,#0xFF
	bicne r0,r0,#0x80			;@ CD-ROM
	ldr r1,=g_region
	ldrb r1,[r1]
	tst r1,#USCOUNTRY
	biceq r0,r0,#0x40			;@ US/Japan
	strb r0,joyExtra

	ldmfd sp!,{lr}
	bx lr
;@----------------------------------------------------------------------------
refreshEMUjoypads:			;@ Call every frame
;@----------------------------------------------------------------------------
;@	mov r11,r11

		ldr r4,=frameTotal
		ldr r4,[r4]
		movs r0,r4,lsr#2		;@ C=frame&2 (autofire alternates every other frame)
	ldr r1,EMUinput
	mov r4,r1
	and r0,r1,#0xf0
		ldr r2,joyCfg
		andcs r1,r1,r2
		tstcs r1,r1,lsr#9		;@ R?
		andcs r1,r1,r2,lsr#16
	adr addy,dulr2ldru
	ldrb r0,[addy,r0,lsr#4]		;@ downupleftright


	ands r3,r1,#3
	cmpne r3,#3
	tstne r2,#0x400				;@ Swap A/B?
	eorne r1,r1,#3

	ands r3,r4,#0xC00			;@ Swap X/Y.
	cmpne r3,#0xC00
	eorne r4,r4,#0xC00

	and r1,r1,#0x00F
	orr r0,r1,r0,lsl#4
	and r1,r4,#0xF00
	orr r0,r0,r1
	orr r0,r0,#0xFF000

//	tstne r4,#0x400				;@ X button.

;@	tst r2,#0x80000000
;@	bne multi

	mov r1,#0xFF000
	str r1,joy0State
	str r1,joy1State
	str r1,joy2State
	str r1,joy3State
	str r1,joy4State
	and r2,r2,#0x70000000		;@ Which player?
	adr r1,joy0State
	str r0,[r1,r2,lsr#26]
	bx lr


joyCfg: .long 0x00ff01ff	;@ byte0=auto mask, byte1=(saves R), byte2=R auto mask
							;@ bit 31=single/multi, 30-28=P1-P5, 27=2b/6b, 26=multitap, 25=multilink active, 24=reset signal received
playerCount:	.long 0		;@ Number of players in multilink.
joySerial:		.long 0
joy0State:		.long 0
joy1State:		.long 0
joy2State:		.long 0xFFFFF000
joy3State:		.long 0xFFFFF000
joy4State:		.long 0xFFFFF000
joyEmpty:		.long 0xFFFFFFFF
joySelect:		.byte 0
joyPortWrite:	.byte 0
joyExtra:		.byte 0
joy6ButtonSw:	.byte 0
ssba2rs12:		.byte 0x00,0x02,0x01,0x03, 0x04,0x06,0x05,0x07, 0x08,0x0a,0x09,0x0b, 0x0c,0x0e,0x0d,0x0f
dulr2ldru:		.byte 0x00,0x02,0x08,0x0a, 0x01,0x03,0x09,0x0b, 0x04,0x06,0x0c,0x0e, 0x05,0x07,0x0d,0x0f
EMUinput:
	.long 0						;@ EMUjoypad (this is what Emu sees)


;@----------------------------------------------------------------------------
IO_R:						;@ I/O read
;@----------------------------------------------------------------------------
	and r1,addy,#0x1e00
	ldr pc,[pc,r1,lsr#7]
;@---------------------------
	.long 0
;@ioReadTbl:
	.long VDC_R					;@ 0x0000-0x03FF
	.long VDC_R					;@ 0x0000-0x03FF
	.long VCE_R					;@ 0x0400-0x07FF
	.long VCE_R					;@ 0x0400-0x07FF
	.long EMPTY_IO_R			;@ 0x0800-0x0BFF
	.long EMPTY_IO_R			;@ 0x0800-0x0BFF
	.long timerRead				;@ 0x0C00-0x0FFF
	.long timerRead				;@ 0x0C00-0x0FFF
	.long JOYP_R				;@ 0x1000-0x13FF
	.long JOYP_R				;@ 0x1000-0x13FF
	.long irqRead				;@ 0x1400-0x17FF
	.long irqRead				;@ 0x1400-0x17FF
cdromReadPtr:
	.long CDROM_R				;@ 0x1800-0x19FF
arcadeReadPtr:
	.long ARCADE_R				;@ 0x1A00-0x1BFF
	.long emptyRead				;@ 0x1C00-0x1FFF
	.long emptyRead				;@ 0x1C00-0x1FFF

;@----------------------------------------------------------------------------
IO_W:						;@ I/O write
;@----------------------------------------------------------------------------
	and r1,addy,#0x1e00
	ldr pc,[pc,r1,lsr#7]
;@---------------------------
	.long 0
;@ioWriteTbl:
	.long VDC_W					;@ 0x0000-0x03FF
	.long VDC_W					;@ 0x0000-0x03FF
	.long VCE_W					;@ 0x0400-0x07FF
	.long VCE_W					;@ 0x0400-0x07FF
	.long PSG_0_W				;@ 0x0800-0x0BFF
	.long PSG_0_W				;@ 0x0800-0x0BFF
	.long timerWrite			;@ 0x0C00-0x0FFF
	.long timerWrite			;@ 0x0C00-0x0FFF
	.long JOYP_W				;@ 0x1000-0x13FF
	.long JOYP_W				;@ 0x1000-0x13FF
	.long irqWrite				;@ 0x1400-0x17FF
	.long irqWrite				;@ 0x1400-0x17FF
cdromWritePtr:
	.long CDROM_W				;@ 0x1800-0x19FF
arcadeWritePtr:
	.long ARCADE_W				;@ 0x1A00-0x1BFF
	.long emptyWrite			;@ 0x1C00-0x1FFF
	.long emptyWrite			;@ 0x1C00-0x1FFF

;@----------------------------------------------------------------------------
JOYP_W:						;@ 0x1000-0x13ff
;@----------------------------------------------------------------------------
	strb r0,[h6280optbl,#h6280IoBuffer]
	and r0,r0,#3
	ldrb r1,joyPortWrite
	strb r0,joyPortWrite

	ldr r2,joyCfg
	tst r2,#0x04000000
	bne joypadMultiTapW

	ldr r1,joy0State

	tst r2,#0x08000000
	bne joypad6ButtonsW
	b joypad2ButtonsW
;@----------------------------------------------------------------------------
joypadMultiTapW:
;@----------------------------------------------------------------------------
	ldrb r2,joySelect
	eor r1,r1,r0
	and r1,r1,r0
	cmp r1,#1					;@ Select next joypad if going from 0 to 1
	addeq r2,r2,#1
	cmp r0,#3					;@ Reset joySelect if going to 3.
	moveq r2,#0
	cmp r2,#5
	movpl r2,#5
	strb r2,joySelect

	ldr r1,=joy0State
	ldr r1,[r1,r2,lsl#2]

	ldr r2,joyCfg
	tst r2,#0x08000000
	bne joypad6ButtonsW
	and r0,r0,#1
;@----------------------------------------------------------------------------
joypad2ButtonsW:			;@ r0 = SEL & CLR, r1 = joybits
;@----------------------------------------------------------------------------
	tst r0,#2					;@ CLR high
	movne r1,#-1
	tst r0,#1					;@ SEL high
	movne r1,r1,lsr#4
	and r1,r1,#0x0F
	strb r1,joySerial
	bx lr
;@----------------------------------------------------------------------------
joypad6ButtonsW:			;@ r0 = SEL & CLR, r1 = joybits
;@----------------------------------------------------------------------------
	cmp r0,#3					;@ CLR high
	ldrb r2,joy6ButtonSw
	eoreq r2,#2
	tst r0,#1
	biceq r2,r2,#1
	orrne r2,r2,#1
	strb r2,joy6ButtonSw
	mov r2,r2,lsl#2
	mov r1,r1,lsr r2
	and r1,r1,#0x0F
	strb r1,joySerial
	bx lr
;@----------------------------------------------------------------------------
JOYP_R:						;@ $0x1000-0x13ff
;@----------------------------------------------------------------------------
	ldrb r0,joySerial
	ldrb r1,joyExtra
	eor r0,r0,r1
	strb r0,[h6280optbl,#h6280IoBuffer]
	bx lr


EMPTY_IO_R:
	ldrb r0,[h6280optbl,#h6280IoBuffer]
	bx lr
;@----------------------------------------------------------------------------
//PSG_W:
;@----------------------------------------------------------------------------
//	strb r0,[h6280optbl,#h6280_ioBuffer]
//	bx lr
;@----------------------------------------------------------------------------
ioState:
	.byte 0
	.byte 0
	.byte 0, 0
;@----------------------------------------------------------------------------
	.end
#endif // #ifdef __arm__
