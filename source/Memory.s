//
//  Memory.s
//  NitroGrafx
//
//  Created by Fredrik Ahlström on 2003-01-01.
//  Copyright © 2003-2026 Fredrik Ahlström. All rights reserved.
//
#ifdef __arm__

#include "ARMH6280/H6280mac.h"

	.global emptyRead
	.global emptyWrite
	.global emptyIOW
	.global romWrite
	.global ram_R
	.global ram_W
	.global xram_W
	.global sram_R
	.global sram_W
	.global mem_R
	.global memcpy_
	.global membic_

	.global mem_W8
	.global mem_R8
	.global mem_R8IIX
	.global mem_R8IIY
	.global mem_R8ZPI
	.global mem_R8AIY
	.global mem_R8AIX
	.global h6280MemWriteTbl
	.global h6280MemReadTbl

	.syntax unified
	.arm

	.section .text
	.align 2
;@----------------------------------------------------------------------------
emptyRead:					;@ Read bad (IO) address, error.
;@----------------------------------------------------------------------------
	mov r11,r11					;@ No$GBA breakpoint
	mov r0,#0xFF				;@ PCE
	bx lr
;@----------------------------------------------------------------------------
emptyWrite:					;@ Write bad address (error)
emptyIOW:
;@----------------------------------------------------------------------------
	mov r11,r11					;@ No$GBA debug
	mov r0,#0xBA
	bx lr
;@----------------------------------------------------------------------------
romWrite:					;@ Write ROM address (SF2 needs this)
;@----------------------------------------------------------------------------
	mov r11,r11					;@ No$GBA debugg
	mov r0,#0xB0
	add r2,h6280ptr,#h6280MapperState
	ldrb r0,[r2,addy,lsr#13]

	ldr r1,=romMask				;@ rommask=romsize-1
	ldr r1,[r1]
	cmp r1,#0x80
	ldr r1,=0x1ffc
	ldr r2,=0x1ff0
	and r1,r1,addy
	cmppl r1,r2
	andeq r1,addy,#3
	ldreq r2,=SF2Mapper
	streq r1,[r2]

	bx lr
;@----------------------------------------------------------------------------

#ifdef NDS
	.section .itcm, "ax", %progbits		;@ For the NDS ARM9
#elif GBA
	.section .iwram, "ax", %progbits	;@ For the GBA
#endif
	.align 2
;@----------------------------------------------------------------------------
mem_W8:						;@ Mem write ($0000-$FFFF)
;@----------------------------------------------------------------------------
	and r1,addy,#0xE000
	ldr pc,[pc,r1,lsr#11]		;@ in: addy,r0=val(bits 8-31=?)
	nop							;@ out: r0,r1,r2,addy=?
h6280MemWriteTbl:
	.long IO_W,ram_W,romWrite,romWrite,romWrite,romWrite,romWrite,romWrite		;@ $0000-FFFF

;@----------------------------------------------------------------------------
mem_R8IIX:					;@ Mem read ($0000-$FFFF)
;@----------------------------------------------------------------------------
	doIIX
	adr r0,h6280MemReadTbl
	and r1,addy,#0xE000
	ldr pc,[r0,r1,lsr#11]		;@ in: addy,r0=val(bits 8-31=?)
;@----------------------------------------------------------------------------
mem_R8IIY:					;@ Mem read ($0000-$FFFF)
;@----------------------------------------------------------------------------
	doIIY
	adr r0,h6280MemReadTbl
	and r1,addy,#0xE000
	ldr pc,[r0,r1,lsr#11]		;@ in: addy,r0=val(bits 8-31=?)
;@----------------------------------------------------------------------------
mem_R8ZPI:					;@ Mem read ($0000-$FFFF)
;@----------------------------------------------------------------------------
	doZPI
	adr r0,h6280MemReadTbl
	and r1,addy,#0xE000
	ldr pc,[r0,r1,lsr#11]		;@ in: addy,r0=val(bits 8-31=?)
;@----------------------------------------------------------------------------
mem_R8AIY:					;@ Mem read ($0000-$FFFF)
;@----------------------------------------------------------------------------
	doAIY
	adr r0,h6280MemReadTbl
	and r1,addy,#0xE000
	ldr pc,[r0,r1,lsr#11]		;@ in: addy,r0=val(bits 8-31=?)
;@----------------------------------------------------------------------------
mem_R8AIX:					;@ Mem read ($0000-$FFFF)
;@----------------------------------------------------------------------------
	doAIX
	adr r0,h6280MemReadTbl
	and r1,addy,#0xE000
	ldr pc,[r0,r1,lsr#11]		;@ in: addy,r0=val(bits 8-31=?)
;@----------------------------------------------------------------------------
mem_R8:						;@ Mem read ($0000-$FFFF)
;@----------------------------------------------------------------------------
	and r1,addy,#0xE000
	ldr pc,[pc,r1,lsr#11]		;@ in: addy,r0=val(bits 8-31=?)
	nop							;@ out: r0,r1,r2,addy=?
h6280MemReadTbl:
	.long IO_R,ram_R,mem_R,mem_R,mem_R,mem_R,mem_R,mem_R		;@ $0000-FFFF

;@----------------------------------------------------------------------------
ram_R:						;@ Ram read ($2000-$3FFF)
;@----------------------------------------------------------------------------
	bic r1,addy,#0xfe000
	ldrb r0,[h6280zpage,r1]
	bx lr
;@----------------------------------------------------------------------------
ram_W:						;@ Ram write ($2000-$3FFF)
;@----------------------------------------------------------------------------
	bic r1,addy,#0xfe000
	strb r0,[h6280zpage,r1]
	bx lr
;@----------------------------------------------------------------------------
sram_R:						;@ sram read
;@----------------------------------------------------------------------------
	bic r1,addy,#0xfe000
	ldr r0,=EMU_SRAM
	ldrb r0,[r0,r1]
	ldr r1,=bramAccess
	ldrb r1,[r1]
	cmp r1,#0
	moveq r0,#0xff
	bx lr
;@----------------------------------------------------------------------------
sram_W:						;@ sram write
;@----------------------------------------------------------------------------
	ldr r1,=bramAccess
	ldrb r1,[r1]
	cmp r1,#0

	bicne r2,addy,#0xfe000
	ldrne r1,=EMU_SRAM
	strbne r0,[r1,r2]
	ldrne r1,=gBramChanged
	movne r2,#1
	strbne r2,[r1]
	bx lr

;@----------------------------------------------------------------------------
xram_W:						;@ Memory write
;@----------------------------------------------------------------------------
	add r2,h6280ptr,#h6280RomMap
	ldr r1,[r2,r1,lsr#11]		;@ r1=addy & 0xe000
	strb r0,[r1,addy]
	bx lr
;@----------------------------------------------------------------------------
mem_R:						;@ Memory read
;@----------------------------------------------------------------------------
	add r2,h6280ptr,#h6280RomMap
	ldr r1,[r2,r1,lsr#11]		;@ r1=addy & 0xe000
	ldrb r0,[r1,addy]
	bx lr
;@----------------------------------------------------------------------------
memcpy_:					;@ r0=dest r1=src r2=word count
;@	exit with r0 & r1 unchanged, r2=0, r3 trashed
;@----------------------------------------------------------------------------
	subs r2,r2,#1
	ldrpl r3,[r1,r2,lsl#2]
	strpl r3,[r0,r2,lsl#2]
	bhi memcpy_
	bx lr
;@----------------------------------------------------------------------------
membic_:					;@ r0=dest r1=data r2=word count
;@	exit with r0 & r1 unchanged, r2=0, r3 trashed
;@----------------------------------------------------------------------------
	subs r2,r2,#1
	ldrpl r3,[r0,r2,lsl#2]
	bicpl r3,r3,r1
	strpl r3,[r0,r2,lsl#2]
	bhi membic_
	bx lr
;@----------------------------------------------------------------------------
	.end
#endif // #ifdef __arm__
