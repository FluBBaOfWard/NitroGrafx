//
//  cdrom.s
//  NitroGrafx
//
//  Created by Fredrik Ahlström on 2003-01-01.
//  Copyright © 2003-2026 Fredrik Ahlström. All rights reserved.
//
#ifdef __arm__

#include "ARMH6280/H6280.i"
#include "Equates.h"

	.global cdInit
	.global cdReset
	.global CDROM_R
	.global CDROM_W
	.global updateCDROM
	.global bramAccess
	.global currentPos
	.global currentTrack
	.global currentSeek
	.global sectorPtr
	.global cdAudioPlaying
	.global cdSeekTime
	.global isoBase
	.global cdInserted
	.global cdFileSize
	.global TGCD_D_Header
	.global TGCD_M_Header
	.global CDROM_TOC

#define SCSISTATUS_OK				0x00
#define SCSISTATUS_CHECKCONDITION	0x02
#define SCSISTATUS_CONDITIONMET		0x04
#define NECSTATUS_TIMEOUT			0x06
#define SCSISTATUS_BUSY				0x08
#define SCSISTATUS_INTERMEDIATE		0x10

	// SCSI RESPONSE CODE
#define SCSIRESPONSE_CURRENTERRORS_FIXED	0x70
#define SCSIRESPONSE_DEFERREDERRORS_FIXED	0x71
#define SCSIRESPONSE_CURRENTERRORS_DESC		0x72
#define SCSIRESPONSE_DEFERREDERRORS_DESC	0x73

	// SCSI SENSE KEY
#define SCSISENSE_NOSENSE			0x00
#define SCSISENSE_RECOVEREDERROR	0x01
#define SCSISENSE_NOTREADY			0x02
#define SCSISENSE_MEDIUMERROR		0x03
#define SCSISENSE_HARDWAREERROR		0x04
#define SCSISENSE_ILLEGALREQUEST	0x05
#define SCSISENSE_UNITATTENTION		0x06
#define SCSISENSE_DATAPROTECT		0x07
#define SCSISENSE_FIRMWAREERROR		0x09
#define SCSISENSE_ABORTEDCOMMAND	0x0B
#define SCSISENSE_EQUAL				0x0C
#define SCSISENSE_VOLUMEOVERFLOW	0x0D
#define SCSISENSE_MISCOMPARE		0x0E

	// "SCSI" SENSE CODE
#define NECCODE_OK					0x00
#define NECCODE_UNKNOWN04			0x04		// NotReadyFlag?
#define NECCODE_NODISC				0x0B
#define NECCODE_COVEROPEN			0x0D
#define NECCODE_UNKNOWN11			0x11
#define NECCODE_UNKNOWN15			0x15
#define NECCODE_UNKNOWN16			0x16
#define NECCODE_UNKNOWN1C			0x1C
#define NECCODE_UNKNOWN1D			0x1D
#define NECCODE_UNKNOWN20			0x20
#define NECCODE_UNKNOWN21			0x21
#define NECCODE_UNKNOWN22			0x22
#define NECCODE_UNKNOWN25			0x25
#define NECCODE_UNKNOWN2A			0x2A
#define NECCODE_UNKNOWN2C			0x2C

	.syntax unified
	.arm
	.section .text
	.align 2

// One CD frame/sector contains 2048bytes of data in MODE_1, 2352 bytes in AUDIO.
// A 1x speed CD drive reads 75 CD frames/sectors per second.
;@----------------------------------------------------------------------------
cdInit:
	.type   cdInit STT_FUNC
;@----------------------------------------------------------------------------
	mov r0,#0
	strb r0,cdInserted
	bx lr
;@----------------------------------------------------------------------------
cdReset:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}

	ldr r0,=cdromState
	mov r1,#0
	mov r2,#(cdromStateEnd-cdromState)/4
	bl memset_					;@ Clear CD-ROM regs
//	bl copyTCD
	ldmfd sp!,{lr}

	ldr r0,=cdIsBinCue
	ldr r0,[r0]
	cmp r0,#0
	beq createTCD

	ldr r12,=CDROM_TOC
	str r12,tgcdBase
	ldrb r0,[r12,#0x0C]			;@ Number of tracks
	add r12,r12,r0,lsl#3		;@ (Track number x 8)
	ldr r0,[r12,#0x0C]			;@ Offset for this track
	ldrb r2,[r12,#0x08]			;@ Mode for this track
	ldr r1,cdFileSize
	sub r0,r1,r0				;@ Calculate size of track in bytes
	cmp r2,#4					;@ Sector size for track
	ldrne r1,=0x1BDD2B			;@ 0x100000000/2352
	umullne r2,r0,r1,r0
	moveq r0,r0,lsr#11

	ldrb r1,[r12,#0x09]			;@ Track LBA
	ldrb r2,[r12,#0x0A]
	orr r1,r2,r1,lsl#8
	ldrb r2,[r12,#0x0B]
	orr r1,r2,r1,lsl#8
	add r0,r1,r0

	mov r1,r0,lsl#2				;@ 2 extra bits for the cd frame vs gba frame.
	str r1,sectorEnd
	ldr r2,tgcdBase
	strb r0,[r2,#0x0F]
	mov r0,r0,lsr#8
	strb r0,[r2,#0x0E]
	mov r0,r0,lsr#8
	strb r0,[r2,#0x0D]

	bx lr
;@----------------------------------------------------------------------------
copyTCD:
;@----------------------------------------------------------------------------
	ldr r1,=TGCD_T_Header
	ldr r2,=CDROM_TOC
	str r2,tgcdBase
	mov r12,#0x100
cTocLoop:
	ldr r0,[r1],#4
	str r0,[r2],#4
	subs r12,r12,#1
	bhi cTocLoop

	bx lr
;@----------------------------------------------------------------------------
createTCD:
;@----------------------------------------------------------------------------
	stmfd sp!,{r3-r6,lr}

	ldr r1,=TGCD_D_Header
	ldr r2,=CDROM_TOC
	str r2,tgcdBase
	ldr r5,cdFileSize
	ldr r0,[r1],#4
	str r0,[r2],#4
	ldr r0,[r1],#8
	str r0,[r2],#8
	ldr r0,[r1],#4
	str r0,[r2],#4

	mov r6,#0
	and r3,r0,#0xFF				;@ Last Track/number of tracks
tocLoop:
	ldrb r0,[r1],#1				;@ Data/music track?
	strb r0,[r2],#1
	cmp r0,#4
	moveq r6,#1

	ldrb r0,[r1],#1				;@ LBA H
	ldrb r4,[r1],#1				;@ LBA M
	orr r0,r4,r0,lsl#8
	ldrb r4,[r1],#1				;@ LBA L
	orr r0,r4,r0,lsl#8
	cmp r6,#2
	addpl r0,r0,r5,lsr#11
	mov r4,r0,lsr#16
	strb r4,[r2],#1
	mov r4,r0,lsr#8
	strb r4,[r2],#1
	strb r0,[r2],#1
	ldr r0,[r1],#4				;@ File offset
	str r0,[r2],#4

	cmp r6,#1
	moveq r6,#2
	subs r3,r3,#1
	bhi tocLoop

	add r0,r0,r5,lsr#11
	mov r1,r0,lsl#2				;@ 2 extra bits for the cd frame vs gba frame.
	str r1,sectorEnd
	ldr r2,tgcdBase
	strb r0,[r2,#0x0F]
	mov r0,r0,lsr#8
	strb r0,[r2,#0x0E]
	mov r0,r0,lsr#8
	strb r0,[r2,#0x0D]

	ldmfd sp!,{r3-r6,lr}
	bx lr
;@----------------------------------------------------------------------------
updateCDROM:				;@ Called every frame
;@----------------------------------------------------------------------------
	stmfd sp!,{r0,r3,lr}
	ldrb r0,cdAudioPlaying
	cmp r0,#0
	beq noCDAudio

	ldr r0,cdSeekTime
	subs r0,r0,#1
	strpl r0,cdSeekTime
	cmp r0,#4
	bpl noCDAudio
	blx CD_FillBuffer
	mov r0,#0
	str r0,ampPtr
	ldrb r0,cdIrqReq
	orr r0,r0,#0x10				;@ Set Sub Q-Channel ready.
	strb r0,cdIrqReq

	ldr r0,sectorPtr			;@ This is now updated in sound.s
//	add r0,r0,#5
//	str r0,sectorPtr
	mov r1,r0,lsl#11-2
	str r1,currentPos
	ldr r1,sectorEnd
	cmp r0,r1
	bmi noCDAudio

;@	mov r11,r11					;@ No$GBA Debugg
	ldrb r1,cdAudioPlaying
	cmp r1,#0x02
	ldrbeq r0,cdIrqReq
	orreq r0,r0,#0x20			;@ CD Audio finnished playing
	strbeq r0,cdIrqReq
	ldrb r0,cdAudioRepeat
	strb r0,cdAudioPlaying
	cmp r0,#0
	blne CD_DoRepeat
noCDAudio:
	ldr r0,currentPos
	mov r0,r0,lsr#11
	bl LBA2Track
	str r0,currentTrack

	ldrb r0,adDma
	tst r0,#0x03
	movne r0,#0xA00				;@ 2048*(75/60). CD frames/TV frames.
	blne AdpcmDMA
	ldmfd sp!,{r0,r3,lr}

	ldr r0,adPlayTime
	cmp r0,#0
	ble CD_Check_IRQ
	ldrb r1,adpcmRate
	add r1,r1,#0x01
	ldrb r2,cdIrqReq
	subs r0,r0,r1,lsl#7			;@ 5 should be pretty ok.
	str r0,adPlayTime
	orrcc r2,r2,#0x08			;@ ADPCM finnished playing.
	biccc r2,r2,#0x04
	ldr r1,adHalfTime
	cmp r0,r1
	movcc r1,#0
	strcc r1,adHalfTime
	orrcc r2,r2,#0x04			;@ ADPCM play half-finnished.
	biccc r2,r2,#0x08
	strb r2,cdIrqReq

;@----------------------------------------------------------------------------
CD_Check_IRQ:					;@ Don't use r0 as it may be used as return data.
;@----------------------------------------------------------------------------
	ldrb r2,cdIrqMask
	ldrb r1,cdIrqReq
	and r2,r2,r1
	tst r2,#0x7C

	ldrb r1,[h6280ptr,#h6280IrqPending]
	bic r1,r1,#BRKIRQ_F				;@ Clear CD IRQ
	orrne r1,r1,#BRKIRQ_F			;@ Set CD IRQ if appropriate
	strb r1,[h6280ptr,#h6280IrqPending]

	bx lr
;@----------------------------------------------------------------------------
AdpcmDMA:					;@ r0=length to transfer now.
;@----------------------------------------------------------------------------
	stmfd sp!,{r3-r5,lr}

	mov r5,r0
	ldrb r0,adpcmStatus
	orr r0,r0,#0x04				;@ Busy with last write.
	strb r0,adpcmStatus
	mov r0,#0x04				;@ ADPCM DMA busy writing.
	strb r0,adpcmDmaOn
	ldr r3,adWrPtr				;@ ADPCM write pointer
	ldr r4,=CD_PCM_RAM			;@ ADPCM-RAM base
dmaLoop:
	ldrb r0,scsiSignal
	cmp r0,#0xC8				;@ Data out?
	bne adpcmEnd
	bl SCSI_SendData
	strb r0,[r4,r3,lsr#16]
	add r3,r3,#0x10000
	subs r5,r5,#1
	bhi dmaLoop
	str r3,adWrPtr
	ldmfd sp!,{r3-r5,lr}
	bx lr
adpcmEnd:
	str r3,adWrPtr
	mov r0,#0x00				;@ ADPCM DMA _not_ busy writing.
	strb r0,adpcmDmaOn
	ldrb r0,adDma
	bic r0,r0,#1
	strb r0,adDma
	ldmfd sp!,{r3-r5,lr}
	bx lr
	.pool
;@----------------------------------------------------------------------------
CDROM_R:					;@ 0x1800-0x180f
;@----------------------------------------------------------------------------
//	stmfd sp!,{r0-r2,lr}
//	and r2,addy,#0x0F
//	mov r1,#7
//	mul r2,r1,r2
//	adr r1,RD_txt
//	add r1,r1,r2
//	bl debugOutput_asm
//	ldmfd sp!,{r0-r2,lr}
	tst addy,#0x07F0
	andeq r1,addy,#0x0F
	ldreq pc,[pc,r1,lsl#2]
	b moreCD_R					;@ Anything else than 0x1800-0x180f
;@---------------------------
cdReadTbl:
	.long CD00_R				;@ CDC status
	.long CD01_R				;@ CDC command / status / data
	.long CD02_R				;@ ADPCM / CD control
	.long CD03_R				;@ BRAM lock / CD status
	.long CD04_R				;@ CD reset
	.long CD05_R				;@ Convert PCM data / PCM data
	.long CD06_R				;@ PCM data
	.long CD07_R				;@ BRAM unlock / CD status
	.long CD08_R				;@ ADPCM address (LSB) / CD data
	.long CD09_R				;@ ADPCM address (MSB)
	.long CD0A_R				;@ ADPCM RAM data port
	.long CD0B_R				;@ ADPCM DMA control
	.long CD0C_R				;@ ADPCM status
	.long CD0D_R				;@ ADPCM address control
	.long CD0E_R				;@ ADPCM playback rate
	.long CD0F_R				;@ ADPCM and CD audio fade timer
;@----------------------------------------------------------------------------
moreCD_R:					;@ 0x18CX
;@----------------------------------------------------------------------------
	mov r11,r11					;@ No$GBA Debugg
	and r0,addy,#0x03F8
	cmp r0,#0xC0
	bne emptyRead

	ldr r0,=gHwFlags
	ldrb r0,[r0]
	tst r0,#SCD_DEVICE+SCD_CARD
	bxeq lr

	tst r0,#USCOUNTRY
	adreq r1,SCD_J
	adrne r1,SCD_U
	tst r0,#SCD_CARD
	adreq r1,SCD_HW
	and r0,addy,#0x07
	ldrb r0,[r1,r0]
	bx lr
;@----------------------------------------------------------------------------
;@ 0x18C0 = Enable SCD RAM.
;@ 0x18C3/0x18C7 = Number of 64kB blocks
;@----------------------------------------------------------------------------
SCD_HW:							;@ Super CDROM unit
		.byte 0x00,0xAA,0x55,0x03,0xFF,0xFF,0xFF,0xFF
SCD_J:							;@ Super CDROM card (J)
		.byte 0xFF,0xFF,0xFF,0xFF,0x00,0xAA,0x55,0x03
SCD_U:							;@ Super CDROM card (U)
		.byte 0xFF,0xFF,0xFF,0xFF,0x00,0x55,0xAA,0x03

;@----------------------------------------------------------------------------
CDROM_W:					;@ 0x1800-0x180f
;@----------------------------------------------------------------------------
	tst addy,#0x07F0
	andeq r1,addy,#0x0F
	ldreq pc,[pc,r1,lsl#2]
	b moreCD_W					;@ Anything else than 0x1800-0x180f
;@---------------------------
cdWriteTbl:
	.long CD00_W				;@ CDC status
	.long CD01_W				;@ CDC command / status / data
	.long CD02_W				;@ ADPCM / CD control
	.long CD03_W				;@ BRAM lock / CD status
	.long CD04_W				;@ CD reset
	.long CD05_W				;@ Convert PCM data / PCM data
	.long CD06_W				;@ PCM data
	.long CD07_W				;@ BRAM unlock / CD status
	.long CD08_W				;@ ADPCM address (LSB) / CD data
	.long CD09_W				;@ ADPCM address (MSB)
	.long CD0A_W				;@ ADPCM RAM data port
	.long CD0B_W				;@ ADPCM DMA control
	.long CD0C_W				;@ ADPCM status
	.long CD0D_W				;@ ADPCM address control
	.long CD0E_W				;@ ADPCM playback rate
	.long CD0F_W				;@ ADPCM and CD audio fade timer
;@----------------------------------------------------------------------------
moreCD_W:					;@ 0x18C0
;@ 0x18C0 = enable SCD RAM.
;@----------------------------------------------------------------------------
	mov r11,r11					;@ No$GBA Debugg
	bic r1,addy,#0xF800
	cmp r1,#0xC0
	bne emptyWrite
	ldr r1,=gHwFlags
	ldrb r1,[r1]
	tst r1,#SCD_DEVICE
	beq emptyWrite
	mov r11,r11					;@ No$GBA Debugg
	cmp r0,#0xAA				;@ Enable Super CD-Rom? Bios writes 0xAA and then 0x55.
	cmp r0,#0x55				;@ Enable Super CD-Rom?
	bxne lr
	b enableSuperCDRAM

;@----------------------------------------------------------------------------
CD00_R:						;@ SCSI BUS SIGNALS
;@----------------------------------------------------------------------------
	ldrb r0,scsiSignal
	ldrb r1,cdIrqMask
	and r1,r1,#0x80
	bic r0,r0,r1,lsr#1
	bx lr
;@----------------------------------------------------------------------------
CD01_R:						;@ SCSI BUS DATA
;@----------------------------------------------------------------------------
	ldrb r0,scsiData
	bx lr
;@----------------------------------------------------------------------------
CD02_R:						;@ IRQ mask & SCSI ACK
;@----------------------------------------------------------------------------
	ldrb r0,cdIrqMask
	bx lr
;@----------------------------------------------------------------------------
CD03_R:						;@ IRQ request
;@----------------------------------------------------------------------------
;@	mov r11,r11					;@ No$GBA Debugg
	mov r0,#0
	strb r0,bramAccess			;@ BRAM is locked if 0x1803 is read
	ldrb r0,cdIrqReq
//	bic r1,r0,#0x60
	eor r1,r0,#0x02				;@ L/R bit should be toggled.
	strb r1,cdIrqReq
	bx lr
//	b CD_Check_IRQ
;@----------------------------------------------------------------------------
CD04_R:						;@ SCSI sub I/O
;@----------------------------------------------------------------------------
	ldrb r0,scsiReset
	bx lr
;@----------------------------------------------------------------------------
CD05_R:						;@ CD sound low(?) byte
;@----------------------------------------------------------------------------
;@	mov r11,r11					;@ No$GBA Debugg
	ldrb r0,cdIrqReq
	tst r0,#0x02				;@ L/R bit
	ldrbeq r0,amplitude
	ldrbne r0,amplitude+2
	bx lr
;@----------------------------------------------------------------------------
CD06_R:						;@ CD sound high(?) byte
;@----------------------------------------------------------------------------
;@	mov r11,r11					;@ No$GBA Debugg
	ldrb r0,cdIrqReq
	tst r0,#0x02				;@ L/R bit
	ldrbeq r0,amplitude+1
	ldrbne r0,amplitude+3
	bx lr
;@----------------------------------------------------------------------------
CD07_R:						;@ Read Sub Q-Channel, clear
;@----------------------------------------------------------------------------
;@	mov r11,r11					;@ No$GBA Debugg
	ldrb r0,cdIrqReq
	bic r0,r0,#0x10				;@ Clear Sub Q-Channel ready.
	strb r0,cdIrqReq

	mov r0,#0
	bx lr
;@----------------------------------------------------------------------------
CD08_R:
;@----------------------------------------------------------------------------
	ldrb r0,scsiSignal
	cmp r0,#0xC8				;@ Data out?
	beq SCSI_SendData
//	bne NoRead08
noRead08:
//	adr r0,RD_txt + 0x08*8
//	vbadebugg
	mov r0,#0
	bx lr
;@----------------------------------------------------------------------------
CD09_R:
;@----------------------------------------------------------------------------
;@	mov r11,r11					;@ No$GBA Debugg
	mov r0,#0
	bx lr
;@----------------------------------------------------------------------------
CD0A_R:						;@ ADPCM data read
;@----------------------------------------------------------------------------
;@	adr r0,RD_txt + 0x0A*8
;@	vbadebugg

	ldrb r0,adpcmStatus
	orr r0,r0,#0x80				;@ Busy with last read.
	strb r0,adpcmStatus

	ldr r0,adRdPtr
	add r1,r0,#0x10000
	str r1,adRdPtr
	ldr r1,=CD_PCM_RAM
	ldrb r1,[r1,r0,lsr#16]
	ldrb r0,adLatch
	strb r1,adLatch

	bx lr
;@----------------------------------------------------------------------------
CD0B_R:
;@----------------------------------------------------------------------------
;@	mov r11,r11					;@ No$GBA Debugg
	ldrb r0,adDma
	bx lr
;@----------------------------------------------------------------------------
CD0C_R:						;@ ADPCM Status
;@----------------------------------------------------------------------------
;@	mov r11,r11					;@ No$GBA Debugg
	ldrb r1,adpcmDmaOn
	cmp r1,#0
	ldrb r0,adpcmStatus
	bic r1,r0,#0x80
	biceq r1,r1,#0x04
	strb r1,adpcmStatus
	ldr r1,adPlayTime
	cmp r1,#0
	orrle r0,#0x01
	orrgt r0,#0x08				;@ 8 or 0
	bx lr
;@----------------------------------------------------------------------------
CD0D_R:
;@----------------------------------------------------------------------------
;@	mov r11,r11					;@ No$GBA Debugg
	ldrb r0,adAdrCtrl
	bx lr
;@----------------------------------------------------------------------------
CD0E_R:
;@----------------------------------------------------------------------------
	ldrb r0,adpcmRate
	bx lr
;@----------------------------------------------------------------------------
CD0F_R:
;@----------------------------------------------------------------------------
;@	mov r11,r11					;@ No$GBA Debugg
	ldrb r0,cdAudioFade
	and r0,r0,#0x8F
	bx lr


;@----------------------------------------------------------------------------
;@----------------------------------------------------------------------------
CD00_W:						;@ SCSI BUS SIGNALS
;@----------------------------------------------------------------------------
	cmp r0,#0x60
	moveq r1,#0
	strbeq r1,scsiSignal
	ldrb r1,scsiSignal
	cmp r1,#0
	cmpeq r0,#0x81				;@ BSY+SEL
	moveq r1,#0xD0				;@ Command Out
	strbeq r1,scsiSignal
	moveq r1,#0
	strbeq r1,scsiPtr
	bx lr
;@----------------------------------------------------------------------------
CD01_W:						;@ SCSI BUS DATA
;@----------------------------------------------------------------------------
	ldrb r1,scsiSignal
	tst r1,#0x08
	strbeq r0,scsiData
	bx lr
/*
WR_txt:
	.string "W$1800"
	.string "W$1801"
	.string "W$1802"
	.string "W$1803"
	.string "W$1804"
	.string "W$1805"
	.string "W$1806"
	.string "W$1807"
	.string "W$1808"
	.string "W$1809"
	.string "W$180A"
	.string "W$180B"
	.string "W$180C"
	.string "W$180D"
	.string "W$180E"
	.string "W$180F"
RD_txt:
	.string "R$1800"
	.string "R$1801"
	.string "R$1802"
	.string "R$1803"
	.string "R$1804"
	.string "R$1805"
	.string "R$1806"
	.string "R$1807"
	.string "R$1808"
	.string "R$1809"
	.string "R$180A"
	.string "R$180B"
	.string "R$180C"
	.string "R$180D"
	.string "R$180E"
	.string "R$180F"
*/
;@----------------------------------------------------------------------------
CD02_W:						;@ IRQ2 Mask & SCSI ACK
;@----------------------------------------------------------------------------
	ldrb r1,cdIrqMask
	strb r0,cdIrqMask
	eor r1,r1,r0
	and r1,r1,r0

	stmfd sp!,{r1,lr}
	bl CD_Check_IRQ
	ldmfd sp!,{r1,lr}

	tst r1,#0x80				;@ CD-Ack?
	bxeq lr						;@ No.

	ldrb r1,scsiSignal
	cmp r1,#0xD0
	beq getCommand
	cmp r1,#0xC8
	beq SCSI_SendData
	cmp r1,#0xD8
	beq sendStatus
	cmp r1,#0xF8
	beq sendMessage
	bx lr						;@ Zero or unknown.

getCommand:
	adrl r1,scsiCmd
	ldrb r2,scsiPtr
	ldrb r0,scsiData
	strb r0,[r1,r2]
	add r2,r2,#1
	ldrb r1,[r1]				;@ Get command
	cmp r1,#0x20
	mov r0,#10					;@ Most commands are 10 bytes long
	movmi r0,#6					;@ Except the 3 first which are 6.
	cmp r2,r0
	moveq r2,#0
	strb r2,scsiPtr
	bxne lr						;@ Exit

	stmfd sp!,{r0-r1,lr}
	bl printSCSICommand
	ldmfd sp!,{r0-r1,lr}

	mov r0,#0xC8				;@ SCSI data
	strb r0,scsiSignal
	cmp r1,#0x00				;@ Test Unit Ready
	beq CMD_TestUnitReady
	cmp r1,#0x03				;@ Request Sense
	beq CMD_RequestSense
	cmp r1,#0x08				;@ Read 6
	beq CMD_Read6
	cmp r1,#0xD8				;@ Play CD, set start time, play & search
	beq CMD_PlayCD
	cmp r1,#0xD9				;@ Play CD, set end time
	beq CMD_PlayCD2
	cmp r1,#0xDA				;@ Paus CD
	beq CMD_PausCD
	cmp r1,#0xDD				;@ Read SubChannel?
	beq CMD_SubQ
	cmp r1,#0xDE				;@ Get Info
	beq CMD_GetInfo
	b CMD_Unknown

sendStatus:
	mov r0,#0x00
	strb r0,scsiData
	mov r0,#0xF8
	strb r0,scsiSignal
	bx lr
sendMessage:
	ldrb r0,cdIrqReq
	bic r0,r0,#0x20				;@ Clear CD Read finnished.
	strb r0,cdIrqReq
	mov r0,#0x00
	strb r0,scsiData
	strb r0,scsiSignal
	bx lr
;@----------------------------------------------------------------------------
CD03_W:						;@ Read Only
;@----------------------------------------------------------------------------
;@	mov r11,r11					;@ No$GBA Debugg
	bx lr
;@----------------------------------------------------------------------------
CD04_W:						;@ SCSI reset?
;@----------------------------------------------------------------------------
	strb r0,scsiReset
	tst r0,#2
	bxeq lr
	mov r1,#0
	strb r1,scsiSignal
	strb r1,scsiData
	strb r1,cdAudioPlaying
	strb r1,cdIrqReq
	bx lr
;@----------------------------------------------------------------------------
CD05_W:						;@ start CD sound fetching
;@----------------------------------------------------------------------------
	ldrb r0,cdAudioPlaying
	cmp r0,#0
	ldr r1,=cdReadPtr
	ldr r1,[r1]
	ldr r2,ampPtr
	add r1,r1,r2,lsl#2
	add r2,r2,#1
	str r2,ampPtr
	ldr r2,=cdBuffer
	mov r1,r1,lsl#18			;@ 16kB
	ldrne r0,[r2,r1,lsr#18]
	str r0,amplitude
	bx lr
;@----------------------------------------------------------------------------
CD06_W:						;@ PCM Audio high, R/O.
;@----------------------------------------------------------------------------
;@	mov r11,r11					;@ No$GBA Debugg
	bx lr
;@----------------------------------------------------------------------------
CD07_W:						;@ BACK UP RAM Enable
;@----------------------------------------------------------------------------
	ands r0,r0,#0x80			;@ Unlock BRAM if bit 7 is set when writing to 0x1807
	movne r0,#1
	strbne r0,bramAccess
	bx lr
;@----------------------------------------------------------------------------
CD08_W:						;@ ADPCM read-/write-adr/len low
;@----------------------------------------------------------------------------
	strb r0,adPtr+2
	bx lr
;@----------------------------------------------------------------------------
CD09_W:						;@ ADPCM read-/write-adr/len high
;@----------------------------------------------------------------------------
	strb r0,adPtr+3
	bx lr
;@----------------------------------------------------------------------------
CD0A_W:						;@ ADPCM-RAM write
;@----------------------------------------------------------------------------
	ldr r1,adWrPtr
	ldr r2,=CD_PCM_RAM
	strb r0,[r2,r1,lsr#16]
	add r1,r1,#0x10000
	str r1,adWrPtr
	ldrb r0,adpcmStatus
	orr r0,r0,#0x04				;@ Busy with last write.
	strb r0,adpcmStatus

	bx lr
;@----------------------------------------------------------------------------
CD0B_W:						;@ CD-ROM to ADPCM-RAM DMA
;@----------------------------------------------------------------------------
	strb r0,adDma
	ands r0,r0,#0x03
	bxeq lr

	stmfd sp!,{lr}
	mov r0,#0xA00				;@ 2048*(75/60). CD frames/TV frames.
	bl AdpcmDMA
	ldmfd sp!,{lr}

	adr r1,CDMA_txt
	b debugOutput_asm
CDMA_txt:
	.string "CD DMA"
	.align 4
;@----------------------------------------------------------------------------
CD0C_W:						;@ ADPCM status (Read Only)
;@----------------------------------------------------------------------------
;@	mov r11,r11					;@ No$GBA Debugg
	bx lr
;@----------------------------------------------------------------------------
CD0D_W:						;@ ADPCM adr control
;@----------------------------------------------------------------------------
	ldrb r1,adAdrCtrl
	strb r0,adAdrCtrl
	eor r1,r0,r1
	and r0,r0,r1				;@ r0=bits set this time
	bic r1,r1,r0				;@ r1=bits reset this time
	ldr r2,adPtr

	tst r1,#0x03
	strne r2,adWrPtr
	tst r1,#0x0C
	strne r2,adRdPtr
	tst r1,#0x10
	strne r2,adLen
	tst r0,#0x80
	movne r2,#0
	strne r2,adLen
	strne r2,adPtr
	strne r2,adWrPtr
	strne r2,adRdPtr
	tst r1,#0x60
	ldrb r1,cdIrqReq
	bicne r1,r1,#0x0C			;@ Clear ADPCM IRQ flags
	strb r1,cdIrqReq
	bne CD_Check_IRQ
	tst r0,#0x60				;@ Was r1
	bxeq lr
	ldrb r1,cdIrqReq
	bic r1,r1,#0x0C				;@ Clear ADPCM IRQ flags
	strb r1,cdIrqReq
	ldr r0,adLen
	movs r0,r0,lsr#16			;@ Just a made up number to count.
//	orreq r0,r0,#0x10000		;@ This should be changed depending on the shift
	add r0,r0,#1
	str r0,adPlayTime
	mov r0,r0,lsr#1
	str r0,adHalfTime
	adr r1,PS_txt
	b debugOutput_asm

PS_txt:
	.string "ADPCM Play"
	.align 4
;@----------------------------------------------------------------------------
CD0E_W:						;@ ADPCM playback rate
;@----------------------------------------------------------------------------
	and r0,r0,#0x0F
	strb r0,adpcmRate
	adr r1,PB_txt
	b debugOutput_asm
//	bx lr
PB_txt:
	.string "ADPCM Rate"
	.align 4
;@----------------------------------------------------------------------------
CD0F_W:						;@ CD Audio fade
;@----------------------------------------------------------------------------
	strb r0,cdAudioFade
	adr r1,AF_txt
	b debugOutput_asm
//	bx lr
AF_txt:
	.string "Audio Fade"
	.align 4

;@----------------------------------------------------------------------------
cdromState:
dmaOutPtr:	.long 0				;@ DMA data byte ptr
dataOutPtr:	.long 0				;@ SCSI data byte ptr
currentPos:	.long 0				;@ Current position on disc
currentTrack: .long 0			;@ Current track
currentSeek: .long 0			;@ Current image byte position
dataLen:	.long 0				;@ SCSI data length in bytes
sectorPtr:	.long 0				;@ Audio sector pointer, shift 2 right to get real value.
sectorEnd:	.long 0				;@ Audio end sector pointer, shift 2 right to get real value.
cddaStart:	.long 0				;@ Start position for cd audio (for repeat...).
cdSeekTime:	.long 0				;@ Seek time in frames (when setting sector).

adPtr:		.long 0				;@ ADPCM ptr	($1808-1809)
adLen:		.long 0				;@ ADPCM length
adWrPtr:	.long 0				;@ ADPCM write ptr
adRdPtr:	.long 0				;@ ADPCM read ptr
adPlayTime:	.long 0				;@ ADPCM play timer (for emulation)
adHalfTime:	.long 0				;@ ADPCM play timer (for emulation)
amplitude:	.long 0				;@ CD Audio amplitude
ampPtr:		.long 0				;@ CD Audio amplitude pointer

scsiSignal:		.byte 0			;@ bit7-3		($1800)
scsiData:		.byte 0			;@				($1801)
cdIrqMask:		.byte 0			;@ bit7=cd-ack?	($1802)
cdIrqReq:		.byte 0			;@				($1803)
scsiReset:		.byte 0			;@				($1804)
bramAccess:		.byte 0			;@				($1807)
adLatch:		.byte 0			;@ ADPCM read latch ($180A)
adDma:			.byte 0			;@ ADPCM DMA ctrl ($180B)
adAdrCtrl:		.byte 0			;@ ADPCM address control ($180D)
adpcmRate:		.byte 0			;@ ADPCM playback rate ($180E)
adpcmStatus:	.byte 0			;@ ADPCM busy status.
adpcmDmaOn:		.byte 0			;@ ADPCM -> CD DMA on?
cdAudioFade:	.byte 0			;@ CD Audio fade ($180F)
cdAudioPlaying:	.byte 0			;@ Is cd audio playing?
cdAudioRepeat:	.byte 0			;@ Should music repeat after completion?
scsiPtr:		.byte 0			;@ Which byte of the command

scsiCmd:		.space 10
scsiResponse:	.space 10
	.align 4
cdromStateEnd:

tgcdBase:
	.long 0
cdFileSize:
	.long 0
isoBase:
	.long 0
cdInserted:		.byte 0
coverOpen:		.byte 0
	.align 4
scsiCommandHex:	.space 32


;@----------------------------------------------------------------------------
printSCSICommand:
;@----------------------------------------------------------------------------
	stmfd sp!,{r3-r5,lr}
	adr r1,scsiCmd
	adr r2,scsiCommandHex

	mov r3,#10
hexLoop:
	ldrb r0,[r1],#1
	mov r4,r0,lsr#4
	cmp r4,#0x0A
	addmi r4,r4,#0x30
	addpl r4,r4,#0x37
	strb r4,[r2],#1
	and r4,r0,#0x0F
	cmp r4,#0x0A
	addmi r4,r4,#0x30
	addpl r4,r4,#0x37
	strb r4,[r2],#1
	mov r4,#0x20
	strb r4,[r2],#1
	subs r3,r3,#1
	bhi hexLoop

	ldmfd sp!,{r3-r5,lr}
	bx lr
;@----------------------------------------------------------------------------
LBA2RealOffset:			;@ in r0=real LBA, out r0=data file offset
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r5,lr}
	mov r4,r0					;@ Save LBA
	bl LBA2Track				;@ Figure out which track it tries to read from
	mov r5,r0					;@ Save track
	bl Track2LBA				;@ Get first sector of this track

	sub r4,r4,r0				;@ Convert LBA to sector offset from track start.
	mov r0,r5
	bl Track2Offset

	ldr r1,tgcdBase
	add r1,r1,r5,lsl#3			;@ (Track number x 8)
	ldrb r1,[r1,#8]				;@ Mode for this track
	cmp r1,#0
	cmpne r1,#8
	ldreq r1,=2352
	ldrne r1,=2048
	mla r0,r1,r4,r0

	ldmfd sp!,{r4-r5,lr}
	bx lr
;@----------------------------------------------------------------------------
LBA2AudioOffset:			;@ in r0=real LBA
;@----------------------------------------------------------------------------
	stmfd sp!,{r3,lr}
	bl LBA2RealOffset
	blx CD_SeekPos
	blx CD_ResetBuffer

	ldmfd sp!,{r3,lr}
	bx lr
;@----------------------------------------------------------------------------
LBA2DataOffset:				;@ in r0=real LBA
;@----------------------------------------------------------------------------
	stmfd sp!,{r3,lr}
	bl LBA2RealOffset
	blx CD_SeekPos
	ldmfd sp!,{r3,lr}
;@----------------------------------------------------------------------------
SCSI_SendData:
	ldrb r0,scsiCmd
	cmp r0,#0x08				;@ Read6
	bne SCSI_SendResponse

	ldr r0,dataLen
	subs r0,r0,#1
	str r0,dataLen
	bmi noMoreScsiData

	ldr r0,currentPos
	add r0,r0,#1
	str r0,currentPos

//	ldr r1,dataOutPtr
//	ldrb r2,[r1],#1
//	str r1,dataOutPtr
	stmfd sp!,{r3,lr}
	blx CD_ReadByte
	ldmfd sp!,{r3,lr}
	mov r2,r0

	ldrb r0,scsiData
	strb r2,scsiData
	bx lr

noMoreScsiData:
	ldrb r0,scsiData
	mov r1,#0					;@ Scsi data should be clear if we have sent all the data, or error code if error occured.
	strb r1,scsiData
	mov r1,#0xD8
	strb r1,scsiSignal
//	adrl r1,scsiCmd
//	ldrb r1,[r1]
//	cmp r1,#0x08
;@	cmpne r1,#0xD8
;@	cmpne r1,#0xD9
	ldrb r2,cdIrqReq
	orr r2,r2,#0x20				;@ CD Read finnished
	bic r2,r2,#0x40				;@ CD Ready finnished
	strb r2,cdIrqReq
	b CD_Check_IRQ
//	bx lr
;@----------------------------------------------------------------------------
SCSI_SendResponse:
;@----------------------------------------------------------------------------
	ldr r0,dataLen
	subs r0,r0,#1
	str r0,dataLen

	ldrpl r1,dataOutPtr
	ldrbpl r2,[r1],#1
	strpl r1,dataOutPtr
	ldrb r0,scsiData
	strb r2,scsiData
	bxpl lr
	mov r2,#0					;@ Scsidata should be clear if we have sent all the data
	strb r2,scsiData
	mov r1,#0xD8
	strb r1,scsiSignal
	bx lr
;@----------------------------------------------------------------------------
CMD_TestUnitReady:
	mov r0,#0xD8				;@ No data only status
	strb r0,scsiSignal

	ldrb r0,cdInserted
	cmp r0,#0
	movne r0,#SCSISTATUS_OK
	moveq r0,#SCSISTATUS_CHECKCONDITION
	strb r0,scsiData

	mov r12,r12
	b noTur
	.short 0x6464,0x0000
turTxt:
	.string "TestUnitReady"
	.align 4
noTur:
	adr r1,turTxt
	b debugOutput_asm
//	bx lr
;@----------------------------------------------------------------------------
CMD_RequestSense:
	mov r0,#0
	mov r2,#10
	str r2,dataLen
	adrl r1,scsiResponse
	str r1,dataOutPtr
rsLoop:
	subs r2,r2,#1
	strbne r0,[r1,r2]
	bne rsLoop

	stmfd sp!,{lr}
	ldrb r0,cdInserted
	cmp r0,#0
	mov r0,#0x00
	moveq r0,#SCSIRESPONSE_CURRENTERRORS_FIXED	;@ 0x70
	strb r0,[r1]								;@ Response Code.
	moveq r0,#SCSISENSE_RECOVEREDERROR			;@ 0x01
//	moveq r0,#SCSISENSE_NOTREADY				;@ 0x02
	strb r0,[r1,#2]								;@ Sense Key.
	moveq r0,#NECCODE_NODISC					;@ No disc in drive
//	moveq r0,#NECCODE_COVEROPEN					;@ Disc door open
//	moveq r0,#0x04
	strb r0,[r1,#9]								;@ Sense Code?
	bl SCSI_SendData
	ldmfd sp!,{lr}

	mov r12,r12
	b noSense
	.short 0x6464,0x0000
rsTxt:
	.string "RequestSense"
	.align 4
noSense:
	adr r1,rsTxt
	b debugOutput_asm
//	bx lr
;@----------------------------------------------------------------------------
CMD_Read6:
	stmfd sp!,{lr}

	mov r0,#0					;@ Audio isn't playing anymore
	strb r0,cdAudioPlaying
	adrl r2,scsiCmd
	ldrb r0,[r2,#4]				;@ Number of sectors
	movs r0,r0,lsl#11			;@ 0x800
	moveq r0,#0x80000
	str r0,dataLen

	mov r0,#60
	str r0,cdSeekTime			;@ This should probably be calculated from old pos to new pos.
	ldrb r0,[r2,#1]				;@ LBA1
	and r0,r0,#0x1F
	ldrb r1,[r2,#2]				;@ LBA2
	orr r0,r1,r0,lsl#8			;@
	ldrb r1,[r2,#3]				;@ LBA3
	orr r0,r1,r0,lsl#8
	mov r1,r0,lsl#11
	str r1,currentPos

	bl LBA2DataOffset			;@ r0 = real LBA, out data file offset

	ldrb r0,cdIrqReq
	orr r0,r0,#0x40				;@ CD ready to go?
	strb r0,cdIrqReq
	ldmfd sp!,{lr}

	adr r1,r6Txt
	b debugOutput_asm
//	bx lr
r6Txt:
	.string "Read6"
	.align 4
;@----------------------------------------------------------------------------
CMD_PlayCD:
	stmfd sp!,{r3-r5,lr}

	mov r0,#60
	str r0,cdSeekTime			;@ This should probably be calculated from old pos to new pos.
	mov r0,#0					;@ Audio must be stopped before we can seek.
	strb r0,cdAudioPlaying
	adrl r4,scsiCmd
	ldrb r2,[r4,#9]				;@ LBA, Track or MSF
	ands r2,r2,#0xC0
	beq  cdGetLBA
	cmp r2,#0x40				;@ MSF
	bne notMSF
	ldrb r0,[r4,#2]				;@ Min
	ldrb r1,[r4,#3]				;@ Sec
	orr r0,r1,r0,lsl#8
	ldrb r1,[r4,#4]				;@ Fra
	orr r0,r1,r0,lsl#8
	bl MSF2LBA
	b  writeSec
notMSF:
	cmp r2,#0x80				;@ Tracks
	bne notTrack
	ldrb r0,[r4,#2]				;@ Track
	bl Bcd2Hex
	bl Track2LBA
	b  writeSec
cdGetLBA:
	ldrb r0,[r4,#3]				;@ MSB
	and r0,r0,#0x1F
	ldrb r1,[r4,#4]				;@
	orr r0,r1,r0,lsl#8
	ldrb r1,[r4,#5]				;@ LSB
	orr r0,r1,r0,lsl#8
writeSec:
	str r0,cddaStart
	mov r1,r0,lsl#2				;@ 2 extra bits for the cd frame vs gba frame.
	str r1,sectorPtr
	bl LBA2AudioOffset			;@ r0 = real LBA, set audio file offset
	bl CD_FindEnd

notTrack:
	ldrb r0,[r4,#1]				;@ To play or not.
	strb r0,cdAudioPlaying
	cmp r0,#1					;@ Repeat after completion?
	cmpne r0,#4					;@ Repeat after completion?
	movne r0,#0
	strb r0,cdAudioRepeat
	mov r1,#0xD8				;@ No data only status
	strb r1,scsiSignal
	mov r1,#0
	strb r1,scsiData

	ldrb r1,cdIrqReq
	orr r1,r1,#0x20				;@ SCSICD_IRQ_DATA_TRANSFER_DONE
	strb r1,cdIrqReq

	adr r1,pcTxt
	bl debugOutput_asm
	ldmfd sp!,{r3-r5,lr}
	adr r1,scsiCommandHex
	b debugOutput_asm
//	bx lr
pcTxt:
	.string "PlayCD_D8"
	.align 4

;@----------------------------------------------------------------------------
CD_DoRepeat:
;@----------------------------------------------------------------------------
	ldr r0,cddaStart
	mov r1,r0,lsl#2				;@ 2 extra bits for the cd frame vs gba frame.
	str r1,sectorPtr
	b LBA2AudioOffset			;@ r0 = real LBA, set audio file offset
;@----------------------------------------------------------------------------
CD_FindEnd:
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r5,lr}
	ldr r0,cddaStart
	bl LBA2Track				;@ Get current track
	ldr r5,tgcdBase
	ldrb r4,[r5,#12]			;@ Last track
	add r5,r5,#8
findLoop:
	add r0,r0,#1
	ldrb r2,[r5,r0,lsl#3]
	cmp r2,#0					;@ Audio?
	bne foundDataTrack
	cmp r0,r4
	ble findLoop

foundDataTrack:
	bl Track2LBA
	ldr r1,=450
	sub r0,r0,r1				;@ 3 second pregap for a data track following an audio one.
	mov r0,r0,lsl#2				;@ 2 extra bits for the cd frame vs gba frame.
	str r0,sectorEnd

	ldmfd sp!,{r4-r5,lr}
	bx lr
;@----------------------------------------------------------------------------
CMD_PlayCD2:
	stmfd sp!,{r3-r5,lr}

	mov r0,#0					;@ Audio must be stopped before we can seek.
	strb r0,cdAudioPlaying
	adrl r4,scsiCmd
	ldrb r2,[r4,#9]				;@ LBA, Tracks or MSF
	ands r2,r2,#0xC0
	beq  cdGetLBA2
	cmp r2,#0x40				;@ MSF
	bne notMSF2
	ldrb r0,[r4,#2]				;@ Min
	ldrb r1,[r4,#3]				;@ Sec
	orr r0,r1,r0,lsl#8
	ldrb r1,[r4,#4]				;@ Fra
	orr r0,r1,r0,lsl#8
	bl MSF2LBA
	b  writeSec2
notMSF2:
	cmp r2,#0x80				;@ Tracks
	bne notTrack2
	ldrb r0,[r4,#2]				;@ Track
	bl Bcd2Hex
	bl Track2LBA
	b  writeSec2
cdGetLBA2:
	ldrb r0,[r4,#3]				;@ MSB
	and r0,r0,#0x1F
	ldrb r1,[r4,#4]				;@ 
	orr r0,r1,r0,lsl#8
	ldrb r1,[r4,#5]				;@ LSB
	orr r0,r1,r0,lsl#8
writeSec2:
	mov r0,r0,lsl#2				;@ 2 extra bits for the cd frame vs gba frame.
	str r0,sectorEnd

notTrack2:
	ldrb r0,[r4,#1]				;@ To play or not.
	strb r0,cdAudioPlaying
	cmp r0,#1					;@ Repeat after completion?
	cmpne r0,#4					;@ Repeat after completion?
	movne r0,#0
	strb r0,cdAudioRepeat
	mov r1,#0xD8				;@ No data only status
	strb r1,scsiSignal
	mov r1,#0
	strb r1,scsiData

	adr r1,pc2Txt
	bl debugOutput_asm
	ldmfd sp!,{r3-r5,lr}
	adrl r1,scsiCommandHex
	b debugOutput_asm
//	bx lr
pc2Txt:
	.string "PlayCD_D9"
	.align 4
;@----------------------------------------------------------------------------
CMD_PausCD:
	mov r0,#0xD8				;@ No data only status
	strb r0,scsiSignal
	mov r0,#0
	strb r0,scsiData
	strb r0,cdAudioPlaying
	adr r1,paTxt
	b debugOutput_asm
//	bx lr
paTxt:
	.string "PauseCD"
	.align 4
;@----------------------------------------------------------------------------
CMD_SubQ:
;@	mov r11,r11					;@ No$GBA Debugg
	stmfd sp!,{r3-r5,lr}
	adrl r5,scsiResponse
	ldrb r0,cdAudioPlaying
	cmp r0,#0
	movne r0,#0					;@ 0 if playing, 1 paused, 2 (search?) paused, 3 complete (stopped?).
	moveq r0,#0x03				;@ 3 if not playing.
//	ldr r1,cdSeekTime
//	cmp r1,#0
//	movne r0,#0x01
	strb r0,[r5]				;@ CTRL & ADR, BIOS want's this to be 0 before a Pause.
	mov r0,#0x00
	strb r0,[r5,#1]				;@ Preemphasis, digital copy, 2ch/4ch, music/data????

	ldr r0,sectorPtr
	mov r0,r0,lsr#2				;@ Throw away the lowest bits.
	bl LBA2Track				;@ r0 in & out
	mov r4,r0
	bl Hex2Bcd
	strb r0,[r5,#2]				;@ Track in BCD
	mov r1,#0x01
	strb r1,[r5,#3]				;@ Index (allways 1 for data track)

	mov r0,r4
	bl Track2LBA				;@ r0 in & out
	ldr r4,sectorPtr
	rsb r0,r0,r4,lsr#2			;@ Calculate sectors into this track.
	sub r0,r0,#150				;@ As this is only relative.
	bl LBA2MSF					;@ r0 in & out
	strb r0,[r5,#6]				;@ Track Frames
	mov r0,r0,lsr#8
	strb r0,[r5,#5]				;@ Track Seconds
	mov r0,r0,lsr#8
	strb r0,[r5,#4]				;@ Track Minutes

	ldr r0,sectorPtr
	mov r0,r0,lsr#2				;@ Throw away the lowest bits.
	bl LBA2MSF					;@ r0 in & out
	strb r0,[r5,#9]				;@ Absolute Frames
	mov r0,r0,lsr#8
	strb r0,[r5,#8]				;@ Absolute Seconds
	mov r0,r0,lsr#8
	strb r0,[r5,#7]				;@ Absolute Minutes

	str r5,dataOutPtr
	mov r0,#10
	str r0,dataLen
	bl SCSI_SendData

	ldmfd sp!,{r3-r5,lr}
//	adr r1,sqTxt
//	b debugOutput_asm
	bx lr
sqTxt:
	.string "SubQ"
	.align 4
;@----------------------------------------------------------------------------
CMD_GetInfo:
	mov r0,#0
	mov r2,#4
	str r2,dataLen
	adrl r1,scsiResponse
	str r1,dataOutPtr
giLoop:
	subs r2,r2,#1
	strbne r0,[r1,r2]
	bne giLoop

	adrl r2,scsiCmd
	ldrb r0,[r2,#1]
	cmp r0,#0
	beq firstLastTrack
	cmp r0,#1
	beq totalTime
	cmp r0,#2
	beq trackInfo
	adrl r1,giukTxt
giBack:
	stmfd sp!,{lr}
	bl debugOutput_asm
	ldmfd sp!,{lr}
	b SCSI_SendData
//	bx lr

;@--------------------------------
firstLastTrack:
	stmfd sp!,{r3-r4,lr}
	ldr r4,tgcdBase
	mov r0,#0x01				;@ First Track
	strb r0,scsiResponse
	ldrb r0,[r4,#12]			;@ Last Track
	bl Hex2Bcd
	strb r0,scsiResponse+1
//	adrl r1,GIFL_txt
	ldmfd sp!,{r3-r4,lr}
	b giBack
;@--------------------------------
totalTime:
	stmfd sp!,{r3,r4,lr}

	ldr r4,tgcdBase
	ldrb r0,[r4,#0x0D]			;@ Total len, LBA
	ldrb r2,[r4,#0x0E]
	orr r0,r2,r0,lsl#8
	ldrb r2,[r4,#0x0F]
	orr r0,r2,r0,lsl#8

	bl LBA2MSF

	strb r0,scsiResponse+2		;@ Frames
	mov r0,r0,lsr#8
	strb r0,scsiResponse+1		;@ Seconds (2=150 frames/sectors)
	mov r0,r0,lsr#8
	strb r0,scsiResponse		;@ Total minutes

	ldmfd sp!,{r3,r4,lr}
	adrl r1,gittTxt
	b giBack
;@--------------------------------
trackInfo:
	ldrb r0,[r2,#2]				;@ Track number
	adrl r1,gitiTxt
	and r2,r0,#0xf
	add r2,r2,#0x30
	strb r2,[r1,#19]
	mov r2,r0,lsr#4
	add r2,r2,#0x30
	strb r2,[r1,#18]

	stmfd sp!,{r3,lr}

	bl Bcd2Hex					;@ r0 in & out

	ldr r2,tgcdBase
	add r2,r2,r0,lsl#3			;@ (Track number x 8)
	ldrb r1,[r2,#8]				;@ Mode for this track
	cmp r1,#0					;@ Everything but 0 is...
	movne r1,#4					;@ Data track
	strb r1,scsiResponse+3

	bl Track2LBA				;@ r0 in & out
	bl LBA2MSF					;@ r0 in & out

	strb r0,scsiResponse+2		;@ Frames
	mov r0,r0,lsr#8
	strb r0,scsiResponse+1		;@ Seconds (2=150 frames/sectors)
	mov r0,r0,lsr#8
	strb r0,scsiResponse		;@ Track starting minutes

	ldmfd sp!,{r3,lr}
	adrl r1,gitiTxt
	b giBack

;@----------------------------------------------------------------------------
LBA2MSF:					;@ r0 input & output, uses r1-r3.
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r5,lr}

	add r0,r0,#150				;@ MSF is 150 more than LBA

	ldr r1,=4500				;@ Number of frames in a minute
	swi 0x090000				;@ Division r0/r1, r0=result, r1=remainder.
	mov r4,r1
	bl Hex2Bcd
	mov r5,r0					;@ Track starting minutes

	mov r0,r4
	mov r1,#75					;@ Number of frames in a second
	swi 0x090000				;@ Division r0/r1, r0=result, r1=remainder.
	mov r4,r1
	bl Hex2Bcd
	orr r5,r0,r5,lsl#8			;@ Seconds (2=150 frames/sectors)
	mov r0,r4
	bl Hex2Bcd
	orr r0,r0,r5,lsl#8			;@ Frames

	ldmfd sp!,{r4-r5,pc}
;@----------------------------------------------------------------------------
MSF2LBA:					;@ r0 input & output, uses r1-r3.
;@----------------------------------------------------------------------------
	stmfd sp!,{r4,lr}

	mov r4,r0					;@ Save MSF to r4
	mov r0,r0,lsr#16
	bl Bcd2Hex
	ldr r1,=4500				;@ Number of frames in a minute
	mul r3,r1,r0

	mov r0,r4,lsr#8
	and r0,r0,#0xFF
	bl Bcd2Hex
	mov r1,#75					;@ Number of frames in a second
	mla r3,r1,r0,r3

	and r0,r4,#0xFF
	bl Bcd2Hex
	add r0,r3,r0

	sub r0,r0,#150				;@ LBA is 150 less than MSF

	ldmfd sp!,{r4,pc}
;@----------------------------------------------------------------------------
LBA2Track:					;@ r0 input & output, uses r1-r3.
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r5,lr}

	mov r4,r0					;@ Save LBA to compare.
	ldr r1,tgcdBase
	ldrb r5,[r1,#12]			;@ How many tracks
trLoop:
	mov r0,r5
	bl Track2LBA				;@ r0 in & out
	cmp r4,r0
	submi r5,r5,#1
	bmi trLoop
	mov r0,r5

	ldmfd sp!,{r4-r5,pc}
;@----------------------------------------------------------------------------
Track2LBA:					;@ r0 input & output, uses r1-r2.
;@----------------------------------------------------------------------------
	ldr r2,tgcdBase
	ldrb r1,[r2,#12]			;@ Last track
	cmp r1,r0
	addmi r2,r2,#4
	addpl r2,r2,r0,lsl#3		;@ (Track number x 8)

	ldrb r0,[r2,#9]				;@ LBA for this track
	ldrb r1,[r2,#10]
	orr r0,r1,r0,lsl#8
	ldrb r1,[r2,#11]
	orr r0,r1,r0,lsl#8

	bx lr
;@----------------------------------------------------------------------------
Track2Offset:				;@ r0 input & output, uses r1. Gives the offset from the cd-image start.
;@----------------------------------------------------------------------------
	ldr r1,tgcdBase
	add r1,r1,r0,lsl#3			;@ (Track number x 8)
	ldr r0,[r1,#0x0C]			;@ Offset for this track
	bx lr
;@----------------------------------------------------------------------------
Hex2Bcd:					;@ r0 input & output, uses r1-r3.
;@----------------------------------------------------------------------------
	mov r1,#10
	swi 0x090000				;@ Division r0/r1, r0=result, r1=remainder.
	add r0,r1,r0,lsl#4			;@ (result x 16)+Remainder.
	bx lr
;@----------------------------------------------------------------------------
Bcd2Hex:					;@ r0 input & output, uses r1.
;@----------------------------------------------------------------------------
	mov r1,r0,lsr#4
	and r0,r0,#0xf
	add r1,r1,r1,lsl#2			;@ Multiply by 5
	add r0,r0,r1,lsl#1			;@ Multiply by 2 and add low
	bx lr
;@----------------------------------------------------------------------------
CMD_Unknown:
;@	mov r11,r11					;@ No$GBA Debugg
	adr r1,ukTxt
	stmfd sp!,{lr}
	bl debugOutput_asm
	ldmfd sp!,{lr}
	adrl r1,scsiCommandHex
	b debugOutput_asm
//	bx lr
;@----------------------------------------------------------------------------
giflTxt:
	.string "GetInfo FirstLast"
gittTxt:
	.string "GetInfo TotalTime"
gitiTxt:
	.string "GetInfo TrackInfo   "
giukTxt:
	.string "GetInfo "
ukTxt:
	.string "Unknown"
	.align 4

TGCD_D_Header:
	.incbin "new.tcd"
//	.incbin "express.tcd"
//	.incbin "Default.tcd"
//	.incbin "Sapphire.tcd"
TGCD_T_Header:
	.incbin "TestCD.tcd"
TGCD_M_Header:
	.incbin "MusicCD.tcd"

;@----------------------------------------------------------------------------
	.section .bss
	.align 4
;@----------------------------------------------------------------------------
CDROM_TOC:
	.space 8*128				;@ Max 99 tracks
;@----------------------------------------------------------------------------
	.end
#endif // #ifdef __arm__
