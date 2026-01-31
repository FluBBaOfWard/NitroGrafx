//
//  Cart.s
//  NitroGrafx
//
//  Created by Fredrik Ahlström on 2003-01-01.
//  Copyright © 2003-2026 Fredrik Ahlström. All rights reserved.
//
#ifdef __arm__

#include "Equates.h"
#include "ARMH6280/H6280mac.h"
#include "PCEPSG/pcepsg.i"		// For savestates

//#define EMBEDDED_ROM

	.global gHwFlags
	.global romStart
	.global gCartFlags
	.global gHackFlags
	.global gMachine
	.global gMachineSet
//	.global gConfig
	.global gConfigSet
	.global gRegion
	.global gBramChanged
	.global gDipSwitch0
	.global gDipSwitch1
	.global gDipSwitch2
	.global romMask
	.global MEMMAPTBL_

	.global pceRAM
	.global sgxRAM
	.global pceSRAM
	.global CD_PCM_RAM
	.global ACC_RAM
	.global ROM_Space
	.global biosSpace
	.global g_BIOSBASE
	.global g_ROM_Size

	.global machineInit
	.global loadCart
	.global ejectCart
	.global enableSuperCDRAM

	.syntax unified
	.arm

	.section .rodata
	.align 2

#ifdef EMBEDDED_ROM
rawRom:
//	.incbin "roms/15-in-1 Mega Collection (J).pce"
//	.incbin "roms/1943 Kai (J).pce"
//	.incbin "roms/Aero Blasters (J).pce"
//	.incbin "roms/After Burner II (J).pce"
//	.incbin "roms/Aoi (Blue) Blink (J).pce"
//	.incbin "roms/Atomic Robokid Special (J).pce"
//	.incbin "roms/Ballistix (J).pce"
//	.incbin "roms/Battle Royale (U).pce"
//	.incbin "roms/Bomberman (U).pce"
//	.incbin "roms/Bonk's Adventure (USA).pce"
//	.incbin "roms/Bomberman '94 (J).pce"
//	.incbin "roms/Bullfight Ring no Haja (J).pce"
//	.incbin "roms/Burning Angels (J).pce"
//	.incbin "roms/CD-ROM System V1.00 (J).pce"
//	.incbin "roms/Cadash (U).pce"
//	.incbin "roms/Chase HQ (J).pce"
//	.incbin "roms/Champions Forever Boxing (U).pce"
//	.incbin "roms/Chikudenya Toubee (J).pce"
//	.incbin "roms/Coryoon - Child of Dragon (Japan).pce"
//	.incbin "roms/Davis Cup Tennis (U).pce"
//	.incbin "roms/Devil Crash (J).pce"
//	.incbin "roms/Dragon's Curse (U).pce"
//	.incbin "roms/Final Blaster (J).pce"
//	.incbin "roms/Final Soldier (J).pce"
//	.incbin "roms/Gaia no Monshou (J).pce"
//	.incbin "roms/Gradius (J).pce"
//	.incbin "roms/Games Express CD Card 1993 (J).pce"
//	.incbin "roms/Kyuukyoku Tiger (J).pce"
//	.incbin "roms/Legend of Hero Tonma (U).pce"
//	.incbin "roms/Magical Chase (U) [!].pce"
//	.incbin "roms/Makai Hakkenden Shada (J).pce"
//	.incbin "roms/Mr. Heli no Dai Bouken (J).pce"
//	.incbin "roms/New Adventure Island (U).pce"
//	.incbin "roms/New Zealand Story, The (J).pce"
//	.incbin "roms/Ninja Spirit (U).pce"
//	.incbin "roms/Ninja Warriors, The (J).pce"
//	.incbin "roms/Outrun (J).pce"
//	.incbin "roms/Order of the Griffon (U).pce"
//	.incbin "roms/Populous (J).pce"
//	.incbin "roms/R-Type Complete (U).pce"
//	.incbin "roms/Salamander (J).pce"
//	.incbin "roms/SideArms - Hyper Dyne - Magea Chip Version (U).pce"
//	.incbin "roms/Street Fighter II Champion Edition (J).pce"
//	.incbin "roms/Strip Fighter II (Japan).pce"
//	.incbin "roms/Super CD-ROM2 System V3.01 (U).pce"
//	.incbin "roms/Turrican (U).pce"
//	.incbin "roms/Takeda Shingen (J).pce"
//	.incbin "roms/TV Sports Basketball (U).pce"
//	.incbin "roms/Valkyrie no Densetsu (J).pce"
//	.incbin "roms/Wonder Momo (J).pce"
//	.incbin "roms/Youkai Douchuuki (J).pce"
rawRomEnd:
#endif
isoFile:
//	.incbin "bloCs.iso"
//	.incbin "rayxanber3.iso"
//	.incbin "valis2.iso"
//	.incbin "valis 4.iso"

	.align 2
;@----------------------------------------------------------------------------
machineInit: 				;@ Called from C
	.type   machineInit STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}

	bl gfxInit
//	bl ioInit
	bl soundInit
	bl cdInit;

	ldmfd sp!,{lr}
	bx lr

	.section .ewram, "ax", %progbits
	.align 2
;@----------------------------------------------------------------------------
loadCart: 		;@ called from C:
	.type   loadCart STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r11,lr}

	ldr h6280ptr,=h6280OpTable

#ifdef EMBEDDED_ROM
	stmfd sp!,{r0-r4,lr}
	ldr r0,=ROM_Space
	ldr r1,=rawRom
	mov r2,#rawRomEnd-rawRom
	str r2,g_ROM_Size
	bl bytecopy_
	ldmfd sp!,{r0-r4,lr}
#endif
	ldr r3,=isoFile
	ldr r1,=isoBase
	str r3,[r1]

	ldrb r0,gConfigSet
	strb r0,gConfig
	bl checkMachine

	ldr r3,=ROM_Space
								;@ r3=rombase til end of loadcart so DON'T FUCK IT UP
	str r3,romBase				;@ Set rom base

	ldr r1,g_ROM_Size
	mov r1,r1,lsr#13			;@ Size in 8k blocks
	mov r2,#1
bigMask:
	mov r2,r2,lsl#1
	cmp r2,r1
	bmi bigMask
	sub r2,r2,#1
	str r2,romMask				;@ romMask=romsize-1

	mov r0,#0
	ldr r4,=SF2Mapper			;@ reset SF2CE mapper.
	str r0,[r4]					;@ reset SF2CE mapper.
	ldr r4,=MEMMAPTBL_
	ldr r5,=RDMEMTBL_
	ldr r6,=WRMEMTBL_
	ldr r7,=mem_R
	ldr r8,=romWrite
	cmp r1,#0x30				;@ Wierd rom banking?
	bne normalBank

tbLoop0:
	and r1,r0,#0x70
	mov r9,r0					;@ 0x00, 0x10, 0x50
	cmp r1,#0x20
	cmpne r1,#0x40
	cmpne r1,#0x60
	subeq r9,r9,#0x10
	cmpne r1,#0x30
	cmpne r1,#0x70
	subeq r9,r9,#0x10

	and r1,r9,r2
	add r1,r3,r1,lsl#13
	str r1,[r4,r0,lsl#2]
	str r7,[r5,r0,lsl#2]
	str r8,[r6,r0,lsl#2]
	add r0,r0,#1
	cmp r0,#0x88
	bne tbLoop0
	b resBg

normalBank:
tbLoop1:
	and r1,r0,r2
	add r1,r3,r1,lsl#13
	str r1,[r4,r0,lsl#2]
	str r7,[r5,r0,lsl#2]
	str r8,[r6,r0,lsl#2]
	add r0,r0,#1
	cmp r0,#0x88
	bne tbLoop1
resBg:
	ldr r1,=DISABLEDMEM
	ldr r7,=emptyRead
	ldr r8,=emptyWrite
tbLoop2:
	str r1,[r4,r0,lsl#2]		;@ MemMap
	str r7,[r5,r0,lsl#2]
	str r8,[r6,r0,lsl#2]
	add r0,r0,#1
	cmp r0,#0x100
	bne tbLoop2

	ldrb r9,gHwFlags
	tst r9,#CD_DEVICE
	blne enableCDRAM
	tst r9,#SCD_CARD
	blne enableSuperCDRAM
	tst r9,#AC_CARD
	blne enableArcadeCard
;@	bl enablePopulousRam


	ldr r1,=pceSRAM
	ldr r7,=sram_R
	ldr r8,=sram_W
	mov r0,#0xF7				;@ SRAM
	str r1,[r4,r0,lsl#2]		;@ MemMap
	str r7,[r5,r0,lsl#2]		;@ RdMem
	str r8,[r6,r0,lsl#2]		;@ WrMem

	ldr r1,=pceRAM
	ldr r7,=ram_R
	ldr r8,=ram_W
memL3:
	add r0,r0,#1				;@ 0xF8-0xFB RAM
	str r1,[r4,r0,lsl#2]		;@ MemMap
	str r7,[r5,r0,lsl#2]		;@ RdMem
	str r8,[r6,r0,lsl#2]		;@ WrMem
	cmp r0,#0xFB
	bne memL3

	ldr r7,=IO_R
	ldr r8,=IO_W
	mov r0,#0xFF				;@ IO
	str r7,[r5,r0,lsl#2]		;@ RdMem
	str r8,[r6,r0,lsl#2]		;@ WrMem


	bl memReset
	bl gfxReset
	bl ioReset
	bl soundReset
	bl cdReset
	bl arcadeReset
	bl cpuReset
	ldmfd sp!,{r4-r11,lr}
	bx lr

;@----------------------------------------------------------------------------
checkMachine:
;@----------------------------------------------------------------------------
	stmfd sp!,{r2-r4}
	ldrb r0,gMachineSet
	cmp r0,#HW_AUTO
	bne setHWBits

	mov r0,#HW_CDROM
	ldr r1,g_ROM_Size
	cmp r1,#0x40000				;@ BIOS = 256kB
	cmpne r1,#0x8000			;@ GE BIOS = 32kB
	moveq r0,#HW_SCD_ACDUO

setHWBits:
	strb r0,gMachine
	adr r1,hwTable
	ldrb r0,[r1,r0]
	strb r0,gHwFlags

	ldmfd sp!,{r2-r4}
	bx lr
;@----------------------------------------------------------------------------
hwTable:
	.byte 0, 0, CD_DEVICE, CD_DEVICE+SCD_DEVICE, CD_DEVICE+SCD_DEVICE+AC_CARD
	.byte SGX_DEVICE, CD_DEVICE+SCD_CARD, CD_DEVICE+SCD_CARD+AC_CARD, SGX_DEVICE+CD_DEVICE+SCD_CARD+AC_CARD
	.align 2
;@----------------------------------------------------------------------------
enableCDRAM:
;@----------------------------------------------------------------------------
	stmfd sp!,{r2-r4}
	ldr r3,=MEMMAPTBL_
	ldr r4,=WRMEMTBL_

	ldr r1,=PCE_CD_RAM
	ldr r2,=xram_W
	mov r0,#0x80				;@ CD_RAM
cdMemLoop:
	str r1,[r3,r0,lsl#2]		;@ MemMap
	str r2,[r4,r0,lsl#2]		;@ WrMem
	add r1,r1,#0x2000
	add r0,r0,#1
	cmp r0,#0x88
	bne cdMemLoop

	ldmfd sp!,{r2-r4}
	bx lr
;@----------------------------------------------------------------------------
enableSuperCDRAM:
;@----------------------------------------------------------------------------
	stmfd sp!,{r2-r4}
	ldr r3,=MEMMAPTBL_
	ldr r4,=WRMEMTBL_

	ldr r1,=SCD_RAM
	ldr r2,=xram_W
	mov r0,#0x68				;@ Super-CD_RAM
scdMemLoop:
	str r1,[r3,r0,lsl#2]		;@ MemMap
	str r2,[r4,r0,lsl#2]		;@ WrMem
	add r1,r1,#0x2000
	add r0,r0,#1
	cmp r0,#0x80
	bne scdMemLoop

	ldmfd sp!,{r2-r4}
	bx lr
;@----------------------------------------------------------------------------
enableArcadeCard:			;@ 0x40-0x43 = port to extra RAM.
;@----------------------------------------------------------------------------
	mov r0,#0x40
	ldr r7,=AC00_R
	ldr r8,=AC00_W
	str r7,[r5,r0,lsl#2]		;@ RdMem
	str r8,[r6,r0,lsl#2]		;@ WrMem

	mov r0,#0x41
	ldr r7,=AC10_R
	ldr r8,=AC10_W
	str r7,[r5,r0,lsl#2]		;@ RdMem
	str r8,[r6,r0,lsl#2]		;@ WrMem

	mov r0,#0x42
	ldr r7,=AC20_R
	ldr r8,=AC20_W
	str r7,[r5,r0,lsl#2]		;@ RdMem
	str r8,[r6,r0,lsl#2]		;@ WrMem

	mov r0,#0x43
	ldr r7,=AC30_R
	ldr r8,=AC30_W
	str r7,[r5,r0,lsl#2]		;@ RdMem
	str r8,[r6,r0,lsl#2]		;@ WrMem

	bx lr
;@----------------------------------------------------------------------------
enablePopulousRam:			;@ 0x40-0x43 = port to extra RAM.
;@----------------------------------------------------------------------------
	stmfd sp!,{r2-r4}
	ldr r3,=MEMMAPTBL_
	ldr r4,=WRMEMTBL_

	ldr r1,=PCE_CD_RAM
	ldr r2,=xram_W
	mov r0,#0x40				;@ Populous RAM
popMemLoop:
	str r1,[r3,r0,lsl#2]		;@ MemMap
	str r2,[r4,r0,lsl#2]		;@ WrMem
	add r1,r1,#0x2000
	add r0,r0,#1
	cmp r0,#0x44
	bne popMemLoop

	ldmfd sp!,{r2-r4}
	bx lr

;@----------------------------------------------------------------------------
ejectCart:
	.type   ejectCart STT_FUNC
;@----------------------------------------------------------------------------
	bx lr
;@----------------------------------------------------------------------------
memReset:
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r9,r11,lr}

	bl checkPCEBRAM

	ldr r0,=DISABLEDMEM			;@ Reset disabled memory
	mov r1,#-1
	mov r2,#0x2000/4
	bl memset_

	ldrb r11,gMachineSet
	cmp r11,#HW_AUTO
	moveq r6,#0
	movne r6,#-1
	mov r2,#0
	mov r3,r2
	mov r7,r6
	stmfd sp!,{r2,r3,r6,r7}
	ldmfd sp!,{r4,r5,r8,r9}
	ldr r0,=pceRAM				;@ Clear PCE RAM.
	mov r1,#0x2000/64
wramLoop0:
	subs r1,r1,#1
	stmiapl r0!,{r2-r5}
	stmiapl r0!,{r2-r5}
	stmiapl r0!,{r6-r9}
	stmiapl r0!,{r6-r9}
	bhi wramLoop0

	ldmfd sp!,{r4-r9,r11,lr}
	bx lr

;@----------------------------------------------------------------------------
checkPCEBRAM:
;@----------------------------------------------------------------------------
	ldr r0,=pceSRAM
	ldr r1,[r0]
	ldr r2,=0x4d425548			;@ Init BRAM. "HUBM"
	cmp r1,r2
	bxeq lr

	str r2,[r0],#4				;@ Init BRAM. "HUBM",0x00,0xA0,0x10,0x80
	ldr r1,=0x8010A000			;@ 0x8010=first free address, 0xA000=last address.
	str r1,[r0],#4

	mov r1,#0					;@ Clear PCE BRAM
	mov r2,#0x2000/4
	sub r2,r2,#2
	b memset_

;@----------------------------------------------------------------------------

romBase:	.long 0
g_BIOSBASE:
	.long 0						;@ biosbase_sms, SMS
g_ROM_Size:
	.long 0
romMask:	.long 0

romInfo:						;@ keep emuflags/BGmirror together for savestate/loadstate
gHwFlags:
	.byte 0						;@ emuflags      (label this so UI.C can take a peek) see equates.h for bitfields
//scaling:
	.byte SCALED_FIT			;@ (display type)
	.byte 0,0					;@ (sprite follow val)
gCartFlags:
	.byte 0 					;@ cartflags
gMachine:
	.byte 0
gMachineSet:
	.byte 0
gConfig:
	.byte 0						;@ config, bit 7=BIOS on/off, bit 6=X as GG Start, bit 5=Select as Reset, bit 4=R as FastForward
gConfigSet:
	.byte 0x80
gRegion:
	.byte 0						;@ 0=USA, 1=Japan.
gBramChanged:
	.byte 0						;@ indicates if BRAM has been modified.
	.byte 0
gHackFlags:
	.long 0

#ifdef GBA
	.section .sbss				;@ This is EWRAM on GBA with devkitARM
#else
	.section .bss
#endif
	.align 8					;@ Align to 256 bytes for RAM
WRMEMTBL_:
	.space 256*4
RDMEMTBL_:
	.space 256*4
MEMMAPTBL_:
	.space 256*4

DISABLEDMEM:
	.space 0x2000
pceSRAM:
	.space 0x2000				;@ This is ususally just 2kB
	.size pceSRAM, 0x2000
pceRAM:
sgxRAM:
	.space 0x8000				;@ PC-Engine is 8kB, SuperGrafx is 32kB.
	.size pceRAM, 0x2000
	.size sgxRAM, 0x8000
ROM_Space:
biosSpace:
	.space 0x40000				;@ US/JP 256kB BIOS max
CD_PCM_RAM:
	.space 0x10000
SCD_RAM:
	.space 0x30000
PCE_CD_RAM:
	.space 0x10000
ACC_RAM:
	.space 0x200000
;@----------------------------------------------------------------------------
	.end
#endif // #ifdef __arm__
