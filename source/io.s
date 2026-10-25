//
//  io.s
//  NitroGrafx
//
//  Created by Fredrik Ahlström on 2003-01-01.
//  Copyright © 2003-2026 Fredrik Ahlström. All rights reserved.
//
#ifdef __arm__

#include "ARMH6280/H6280.i"
#include "Equates.h"
#include "Shared/EmuMenu.i"

#define PCE_KEY_I		(1<<0)
#define PCE_KEY_II		(1<<1)
#define PCE_KEY_SELECT	(1<<2)
#define PCE_KEY_RUN		(1<<3)
#define PCE_KEY_UP		(1<<4)
#define PCE_KEY_RIGHT	(1<<5)
#define PCE_KEY_DOWN	(1<<6)
#define PCE_KEY_LEFT	(1<<7)
#define PCE_KEY_III		(1<<8)
#define PCE_KEY_IV		(1<<9)
#define PCE_KEY_V		(1<<10)
#define PCE_KEY_VI		(1<<11)

	.global joyCfg
	.global EMUinput
	.global button3

	.global ioReset
	.global IO_R
	.global IO_W
	.global refreshEMUjoypads
	.global convertInput
	.global setJoyMapping

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

	ldr r12,=gHwFlags
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
	ldr r1,=gRegion
	ldrb r1,[r1]
	tst r1,#USCOUNTRY
	biceq r0,r0,#0x40			;@ US/Japan
	strb r0,joyExtra

	ldmfd sp!,{lr}
	bx lr
;@----------------------------------------------------------------------------
setJoyMapping:
	.type setJoyMapping STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r11}
	ldr r2,joyCfg
	mov r0,r2,lsr#25
	and r0,r0,#3
	mov r1,#KEY_L|KEY_R
	cmp r0,#2
	movpl r1,#KEY_L|KEY_SELECT
	str r1,menuOpener
	mov r1,#KEY_L
	movpl r1,#0
	str r1,scrlUpKey
	mov r1,#KEY_R
	movpl r1,#0
	str r1,scrlDownKey

	adr r1,keyMap3Button
	add r1,r1,r0,lsl#3+2
	ldmia r1,{r4-r11}
	cmp r0,#2
	bpl setKeyMap

	ldrb r1,button3
	cmp r1,#1
	orreq r6,r6,r8
	orrhi r7,r7,r8
	mov r8,#0

	tst r2,#0x400				;@ Swap I/II?
	movne r1,r4
	movne r4,r5
	movne r5,r1

setKeyMap:
	adr r0,PCE_MAP_I
	stmia r0,{r4-r11}

	ldmfd sp!,{r4-r11}
	bx lr
;@----------------------------------------------------------------------------
convertInput:			;@ Convert from device keys to target r0=input/output
	.type convertInput STT_FUNC
;@----------------------------------------------------------------------------
	mvn r1,r0
	ldr r2,menuOpener
	tst r1,r2					;@ Keys to open menu
	orreq r0,r0,#ACT_OPEN_MENU
	ldr r2,scrlUpKey
	tst r1,r2
	orreq r0,r0,#ACT_SCRL_UP
	ldr r2,scrlDownKey
	tst r1,r2
	orreq r0,r0,#ACT_SCRL_DOWN
	bx lr
;@----------------------------------------------------------------------------
refreshEMUjoypads:			;@ Call every frame
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r11}
	ldr r0,EMUinput
		ldr r1,=frameTotal
		ldr r1,[r1]
		movs r1,r1,lsr#2		;@ C=frame&2 (autofire alternates every other frame)
	mov r1,r0
		ldr r2,joyCfg
		andcs r1,r1,r2
		tstcs r1,r1,lsr#9		;@ R?
		andcs r1,r1,r2,lsr#16
	and r1,r1,#0xF
	and r4,r0,#0xf00
	orr r1,r1,r4
	and r0,r0,#0xf0
	adr r3,rlud2urdl
	ldrb r0,[r3,r0,lsr#4]		;@ UpRightDownLeft

	adr r3,PCE_MAP_I
	ldmia r3,{r4-r11}
	tst r1,r4
	orrne r0,r0,#PCE_KEY_I
	tst r1,r5
	orrne r0,r0,#PCE_KEY_II
	tst r1,r6
	orrne r0,r0,#PCE_KEY_SELECT
	tst r1,r7
	orrne r0,r0,#PCE_KEY_RUN
	tst r1,r8
	orrne r0,r0,#PCE_KEY_III
	tst r1,r9
	orrne r0,r0,#PCE_KEY_IV
	tst r1,r10
	orrne r0,r0,#PCE_KEY_V
	tst r1,r11
	orrne r0,r0,#PCE_KEY_VI

	orr r0,r0,#0xFF000

	mov r1,#0xFF000
	str r1,joy0State
	str r1,joy1State
	str r1,joy2State
	str r1,joy3State
	str r1,joy4State
	and r2,r2,#0x70000000		;@ Which player?
	adr r1,joy0State
	str r0,[r1,r2,lsr#26]
	ldmfd sp!,{r4-r11}
	bx lr

;@----------------------------------------------------------------------------
menuOpener:		.long KEY_L|KEY_R
scrlUpKey:		.long KEY_L
scrlDownKey:	.long KEY_R
joyCfg: .long 0x00ff01ff	;@ byte0=auto mask, byte1=(saves R), byte2=R auto mask
							;@ bit 31=multitap, 30-28=P1-P5, 27-25=3b/6b, 24=disable select+run
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
abss221sr:		.byte 0x00,0x02,0x01,0x03, 0x04,0x06,0x05,0x07, 0x08,0x0a,0x09,0x0b, 0x0c,0x0e,0x0d,0x0f
rlud2urdl:		.byte 0x00,0x20,0x80,0xa0, 0x10,0x30,0x90,0xb0, 0x40,0x60,0xc0,0xe0, 0x50,0x70,0xd0,0xf0

PCE_MAP_I:		.long KEY_A
PCE_MAP_II:		.long KEY_B
PCE_MAP_SELECT:	.long KEY_SELECT
PCE_MAP_RUN:	.long KEY_START
PCE_MAP_III:	.long KEY_R
PCE_MAP_IV:		.long KEY_L
PCE_MAP_V:		.long KEY_Y
PCE_MAP_VI:		.long KEY_X

EMUinput:
	.long 0						;@ EMUjoypad (this is what Emu sees)

button3:	.byte 0
	.byte 0,0,0

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
	strb r0,[h6280ptr,#h6280IoBuffer]
	and r0,r0,#3
	ldrb r1,joyPortWrite
	strb r0,joyPortWrite

	ldr r2,joyCfg
	tst r2,#0x80000000
	bne joypadMultiTapW

	ldr r1,joy0State

	and r2,r2,#0x06000000
	cmp r2,#0x04000000
	bpl joypad6ButtonsW
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
	and r2,r2,#0x06000000
	cmp r2,#0x04000000
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
JOYP_R:						;@ 0x1000-0x13ff
;@----------------------------------------------------------------------------
	ldrb r0,joySerial
	ldrb r1,joyExtra
	eor r0,r0,r1
	strb r0,[h6280ptr,#h6280IoBuffer]
	bx lr
;@----------------------------------------------------------------------------
EMPTY_IO_R:					;@ 0x0800-0x0BFF
;@----------------------------------------------------------------------------
	ldrb r0,[h6280ptr,#h6280IoBuffer]
	bx lr
;@----------------------------------------------------------------------------
keyMap3Button:
	.long KEY_A				;@ I
	.long KEY_B				;@ II
	.long KEY_SELECT		;@ Select
	.long KEY_START			;@ Run
	.long KEY_Y				;@ III
	.long 0
	.long 0
	.long 0

keyMap3ButtonAlt:
	.long KEY_B				;@ I
	.long KEY_Y				;@ II
	.long KEY_SELECT		;@ Select
	.long KEY_START			;@ Run
	.long KEY_X				;@ III
	.long 0
	.long 0
	.long 0

keyMap6Button:
	.long KEY_A				;@ I
	.long KEY_B				;@ II
	.long KEY_SELECT		;@ Select
	.long KEY_START			;@ Run
	.long KEY_R				;@ III
	.long KEY_L				;@ IV
	.long KEY_Y				;@ V
	.long KEY_X				;@ VI

keyMap6ButtonAlt:
	.long KEY_R				;@ I
	.long KEY_A				;@ II
	.long KEY_SELECT		;@ Select
	.long KEY_START			;@ Run
	.long KEY_B				;@ III
	.long KEY_Y				;@ IV
	.long KEY_X				;@ V
	.long KEY_L				;@ VI
;@----------------------------------------------------------------------------
	.end
#endif // __arm__
