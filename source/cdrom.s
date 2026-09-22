//
//  cdrom.s
//  NitroGrafx
//
//  Created by Fredrik Ahlström on 2004-04-23.
//  Copyright © 2004-2026 Fredrik Ahlström. All rights reserved.
//
#ifdef __arm__

#include "cdrom.i"
#include "ARMH6280/H6280mac.h"
#include "Equates.h"

	.global bramAccess
	.global currentPos
	.global currentTrack
	.global sectorPtr
	.global cddaVolume
	.global cdAudioPlaying
	.global cdSeekTime
	.global isoBase
	.global cdInserted
	.global cdFileSize
	.global TGCD_D_Header
	.global TGCD_M_Header
	.global cdRomToc

	.global cdInit
	.global cdReset
	.global CDROM_R
	.global CDROM_W
	.global updateCDROM
	.global renderADPCM

#define CMD_TEST_UNIT_READY			0x00	;@ Test unit ready command
#define CMD_REQUEST_SENSE			0x03	;@ Request sense command
#define CMD_READ6					0x08	;@ Read command
#define CMD_START_PLAY_CD			0xD8	;@ Start Play CD
#define CMD_END_PLAY_CD				0xD9	;@ End Play CD
#define CMD_PAUSE_CD				0xDA	;@ Pause CD
#define CMD_SUB_Q					0xDD	;@ Read sub channel Q
#define CMD_GET_INFO				0xDE	;@ Get info
#define CMD_ABORT					0xFF	;@ Abort

	// SCSI STATUS
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

	// Int flags
#define INT_DAT_IN			0x40
#define INT_MSG_IN			0x20

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

	ldr r0,=44100
	str r0,adFreqToCD

	ldr r0,=cdIsBinCue
	ldr r0,[r0]
	cmp r0,#0
	beq createTCD

	ldr r12,=cdRomToc
	str r12,tgcdBase
	ldrb r0,[r12,#cdTOCTrackCount]	;@ Number of tracks
	add r12,r12,r0,lsl#3		;@ (Track number x 8)
	add r12,r12,#cdTOCSize-cdTrackSize
	ldr r0,[r12,#cdTrackstart]	;@ Offset for this track
	ldrb r2,[r12,#cdTrackMode]	;@ Mode for this track
	ldr r1,cdFileSize
	sub r0,r1,r0				;@ Calculate size of track in bytes
	cmp r2,#4					;@ Sector size for track
	ldrne r1,=0x1BDD2C			;@ 0x100000000/2352
	umullne r2,r0,r1,r0
	moveq r0,r0,lsr#11

	ldrb r1,[r12,#cdTrackLBA0]	;@ Track LBA
	ldrb r2,[r12,#cdTrackLBA1]
	orr r1,r2,r1,lsl#8
	ldrb r2,[r12,#cdTrackLBA2]
	orr r1,r2,r1,lsl#8
	add r0,r1,r0

	mov r1,r0,lsl#2				;@ 2 extra bits for the cd frame vs gba frame.
	str r1,sectorEnd
	ldr r2,tgcdBase
	strb r0,[r2,#cdTOCEndLBA2]
	mov r0,r0,lsr#8
	strb r0,[r2,#cdTOCEndLBA1]
	mov r0,r0,lsr#8
	strb r0,[r2,#cdTOCEndLBA0]

	bx lr
;@----------------------------------------------------------------------------
copyTCD:
;@----------------------------------------------------------------------------
	ldr r1,=TGCD_T_Header
	ldr r2,=cdRomToc
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
	ldr r2,=cdRomToc
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
	strb r0,[r2,#cdTOCEndLBA2]
	mov r0,r0,lsr#8
	strb r0,[r2,#cdTOCEndLBA1]
	mov r0,r0,lsr#8
	strb r0,[r2,#cdTOCEndLBA0]

	ldmfd sp!,{r3-r6,lr}
	bx lr
;@----------------------------------------------------------------------------
updateCDROM:				;@ Called every frame
;@----------------------------------------------------------------------------
	mov r0,#0
	strb r0,adpcmStatus

	ldr r0,cdSeekTime
	subs r0,r0,#1
	strpl r0,cdSeekTime
	bhi noCDUpd

	stmfd sp!,{r3,lr}
//	ldrb r0,scsiCmd
//	cmp r0,#CMD_READ6			;@ Read command
//	bne notReadCmd
	ldrb r0,scsiSignal
	tst r0,#0x80
	orrne r0,r0,#0x40			;@ Ready for more data.
	bl setSCSISignal
notReadCmd:

	ldrb r0,cdPlayMode
	cmp r0,#0
	beq noCDAudio
	strb r0,cdAudioPlaying

	blx CD_FillBuffer
	mov r0,#0
	str r0,ampPtr
	ldrb r0,cdIrqReq
	orr r0,r0,#0x10				;@ Set Sub Q-Channel ready.
	strb r0,cdIrqReq

	ldr r0,sectorPtr			;@ This is now updated in sound.s
	mov r1,r0,lsl#11-2
	str r1,currentPos
	ldr r1,sectorEnd
	cmp r0,r1
	bmi noCDAudio

;@	mov r11,r11					;@ No$GBA Debugg
	ldrb r1,cdAudioPlaying
	cmp r1,#0x02
	ldrbeq r0,cdIrqReq
	orreq r0,r0,#INT_MSG_IN		;@ CD Audio finnished playing
	strbeq r0,cdIrqReq
	ldrb r0,cdAudioRepeat
	strb r0,cdAudioPlaying
	cmp r0,#0
	blne CD_DoRepeat
noCDAudio:
	ldr r0,currentPos
	mov r0,r0,lsr#11
	bl LBA2Track
	bl Hex2Bcd
	strb r0,currentTrack

	ldrb r0,adDma
	tst r0,#0x03
	ldrne r0,dataLen
	cmpne r0,#0
	movne r0,#0xA00				;@ 2048*(75/60). CD frames/TV frames.
	blne AdpcmDMA
	ldmfd sp!,{r3,lr}
noCDUpd:
	ldrb r2,fadeCtrl
	tst r2,#0x8					;@ Enabled?
	beq noFade
	ldr r0,fadeVolume
	ldr r1,cddaFade
	subs r0,r0,r1
	movmi r0,#0
	str r0,fadeVolume
	mov r1,#0x10000
	tst r2,#0x2
	streq r0,cddaVolume
	strne r1,cddaVolume
	streq r1,adpcmVolume
	strne r0,adpcmVolume
noFade:
	b CD_Check_IRQ
;@----------------------------------------------------------------------------
setSCSISignal:				;@ r0=new signal.
;@----------------------------------------------------------------------------
	ldrb r1,scsiSignal
	cmp r0,r1
	bxeq lr

	strb r0,scsiSignal
	ldrb r1,cdIrqReq
	bic r2,r1,#INT_DAT_IN | INT_MSG_IN
	cmp r0,#0xC8
	orreq r2,r2,#INT_DAT_IN
	cmp r0,#0xD8
	cmpne r0,#0xF8
	orreq r2,r2,#INT_MSG_IN
	eors r1,r1,r2
	strbne r2,cdIrqReq
	ands r1,r1,r2
	bxeq lr
// Fall through
;@----------------------------------------------------------------------------
CD_Check_IRQ:				;@ Don´t use r0 as it may be used as return data.
;@----------------------------------------------------------------------------
	ldrb r2,cdIrqMask
	ldrb r1,cdIrqReq
	and r2,r2,r1
	tst r2,#0x7C

	ldrb r1,[h6280ptr,#h6280IrqPending]
	bic r2,r1,#BRKIRQ_F				;@ Clear CD IRQ
	orrne r2,r1,#BRKIRQ_F			;@ Set CD IRQ if appropriate
	eors r1,r1,r2
	strbne r2,[h6280ptr,#h6280IrqPending]
	ands r1,r1,r2
//	h6280BailOut
	orrne cycles,cycles,#0xC0000000

	bx lr
;@----------------------------------------------------------------------------
renderADPCM:				;@ in r0 = len, r1 = dest.
;@----------------------------------------------------------------------------
	ldrb r2,adAdrCtrl
	tst r2,#0x20				;@ Are we playing?
	bxeq lr
	tst r2,#0x80				;@ Reset?
	bxne lr

	stmfd sp!,{r4-r11,lr}
	mov r4,r0
	mov r5,r1
	ldr r6,adLen
	ldrb r7,adpcmRate
	ldrb r0,adpcmRateCount
	and r7,r7,#0x0F
	orr r7,r7,r0,lsl#28
	ldr r0,=adpcmAccumulator
	ldr r0,[r0]
	mov r0,r0,asr#1
	orr r0,r0,r0,lsr#16

	ldr r8,=CD_PCM_RAM
	ldr r9,adRdPtr
	ldr r10,adFreqToCD
	ldr r11,=32100<<16
	tst r7,#0xF0000000
	bne noFetch
adpcmLoop:
	ldrb r0,[r8,r9,lsr#16]
	tst r9,#0x8000				;@ Even or odd?
	moveq r0,r0,lsr#4
	add r9,r9,#0x8000
	orr r7,r7,r7,lsl#28
	bl adpcmConvert4Bit
noFetch:
	subs r4,r4,#1
	bcc adEnd
	ldr r2,[r5]
	add r2,r2,r0
	str r2,[r5],#4
	subs r10,r10,r11
	bcs noFetch
	add r10,r10,r10,lsl#16
	adds r7,r7,#0x10000000
	bcc noFetch

	subs r6,r6,#0x4000
	bne adpcmLoop
adEnd0:
	ldrb r0,adAdrCtrl
	tst r0,#0x40				;@ Stop playing?
	bicne r0,r0,#0x20			;@ Stop playing.
	strb r0,adAdrCtrl
adEnd:
	ldrb r1,cdIrqReq
	tst r6,#0x18000<<15
	bicne r1,r1,#0x04
	orreq r1,r1,#0x04			;@ ADPCM play half-finnished.
	cmp r6,#0
	orreq r1,r1,#0x08			;@ ADPCM finnished playing.
	strb r1,cdIrqReq

	str r6,adLen
	str r9,adRdPtr
	str r10,adFreqToCD
	mov r7,r7,lsr#28
	strb r7,adpcmRateCount
	ldmfd sp!,{r4-r11,pc}
;@----------------------------------------------------------------------------
AdpcmDMA:					;@ r0=length to transfer now.
;@----------------------------------------------------------------------------
	stmfd sp!,{r3-r6,lr}

	mov r5,r0
	mov r6,r0
	ldrb r0,adpcmStatus
	orr r0,r0,#0x04				;@ Busy with last write.
	strb r0,adpcmStatus
	mov r0,#0x04				;@ ADPCM DMA busy writing.
	strb r0,adpcmDmaOn
	ldr r3,adWrPtr				;@ ADPCM write pointer
	ldr r4,=CD_PCM_RAM			;@ ADPCM-RAM base
dmaLoop:
	ldrb r0,scsiSignal
	and r1,r0,#0xBF
	cmp r1,#0x88				;@ Data out?
	bne dmaEnd
	tst r0,#0x40				;@ REQ set?
	beq dmaSectorEnd
	bl SCSI_SendData
	strb r0,[r4,r3,lsr#16]
	add r3,r3,#0x10000
	subs r5,r5,#1
	bhi dmaLoop
	b dmaSkip
dmaEnd:
	mov r0,#0x00				;@ ADPCM DMA _not_ busy writing.
	strb r0,adpcmDmaOn
dmaSectorEnd:
	ldrb r0,adDma
	bic r0,r0,#1
	strb r0,adDma
dmaSkip:
	sub r6,r6,r5
	ldr r0,adLen
	ldrb r1,cdIrqReq
	cmp r0,#0
	orreq r1,r1,#0x08			;@ ADPCM finnished playing.
	adds r0,r0,r6,lsl#15
	orrhi r1,r1,#0x08			;@ C set & Z not set, ADPCM finnished playing.
	str r0,adLen
	sub r0,r0,#1<<15
	tst r0,#0x18000<<15
	bicne r1,r1,#0x04
	orreq r1,r1,#0x04			;@ ADPCM <32k left.
	strb r1,cdIrqReq
	str r3,adWrPtr
	ldmfd sp!,{r3-r6,pc}
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
;@	mov r11,r11					;@ No$GBA Debugg
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
	.pool
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
	.long CD0B_W				;@ ADPCM DMA
	.long CD0C_W				;@ ADPCM status
	.long CD0D_W				;@ ADPCM control
	.long CD0E_W				;@ ADPCM playback rate
	.long CD0F_W				;@ ADPCM and CD audio fade timer
;@----------------------------------------------------------------------------
moreCD_W:					;@ 0x18C0
;@ 0x18C0 = enable SCD RAM.
;@----------------------------------------------------------------------------
;@	mov r11,r11					;@ No$GBA Debugg
	bic r1,addy,#0xF800
	cmp r1,#0xC0
	bne emptyWrite
	ldr r1,=gHwFlags
	ldrb r1,[r1]
	tst r1,#SCD_DEVICE
	beq emptyWrite
;@	mov r11,r11					;@ No$GBA Debugg
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
	ldrb r0,scsiSignal
	tst r0,#0x08				;@ In/Out
	ldrbeq r0,scsiDataLatch
	ldrbne r0,scsiData
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
	eor r0,r0,#0x02				;@ L/R bit is inverted.
	bx lr
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
	ldrbne r0,cdSample
	ldrbeq r0,cdSample+2
	bx lr
;@----------------------------------------------------------------------------
CD06_R:						;@ CD sound high(?) byte
;@----------------------------------------------------------------------------
;@	mov r11,r11					;@ No$GBA Debugg
	ldrb r0,cdIrqReq
	tst r0,#0x02				;@ L/R bit
	ldrbne r0,cdSample+1
	ldrbeq r0,cdSample+3
	bx lr
;@----------------------------------------------------------------------------
CD07_R:						;@ Read Sub Channel, clear 
;@----------------------------------------------------------------------------
;@	mov r11,r11					;@ No$GBA Debugg
	ldrb r0,cdIrqReq
	bic r0,r0,#0x10				;@ Clear Sub Q-Channel ready.
	strb r0,cdIrqReq

	mov r0,#0
	bx lr
;@----------------------------------------------------------------------------
CD08_R:						;@ CD data
;@----------------------------------------------------------------------------
	ldrb r0,scsiSignal
	cmp r0,#0xC8				;@ Data out?
	beq SCSI_SendData
	tst r0,#0x08				;@ In/Out
	ldrbeq r0,scsiDataLatch
	ldrbne r0,scsiData
//	adr r0,RD_txt + 0x08*8
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
	ldrb r0,adpcmStatus
	orr r0,r0,#0x80				;@ Busy with last read.
	strb r0,adpcmStatus

	ldrb r1,adAdrCtrl
	tst r1,#0x10				;@ Latch length?
	ldreq r2,adLen
	ldrne r2,adPtr
	movne r2,r2,lsr#1
	ldrb r1,cdIrqReq
	bne rdLenLck
	subs r2,r2,#0x1<<15			;@ Sub 1 from length.
	strcs r2,adLen
	orrcc r1,r1,#0x08			;@ ADPCM finnished playing.
rdLenLck:
	tst r2,#0x18000<<15
	bicne r1,r1,#0x04
	orreq r1,r1,#0x04			;@ ADPCM <32k left.
	strb r1,cdIrqReq

	ldr r0,adRdPtr
	ldr r1,=CD_PCM_RAM
	add r2,r0,#0x10000
	str r2,adRdPtr
	ldrb r1,[r1,r0,lsr#16]
	ldrb r0,adLatch
	strb r1,adLatch

	bx lr
;@----------------------------------------------------------------------------
CD0B_R:						;@ ADPCM DMA
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
	ldrb r1,cdIrqReq
	tst r1,#0x08				;@ ADPCM finnished playing?
	orrne r0,#0x01
	ldrb r1,adAdrCtrl
	tst r1,#0x20				;@ Are we playing?
	orrne r0,#0x08
	bx lr
;@----------------------------------------------------------------------------
CD0D_R:						;@ ADPCM control
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
	ldrb r0,fadeCtrl
	bx lr


;@----------------------------------------------------------------------------
;@----------------------------------------------------------------------------
CD00_W:						;@ SCSI BUS SIGNALS
;@----------------------------------------------------------------------------
	ldrb r1,scsiDataLatch
	and r1,#0x80
	cmp r1,#0x80
	cmpeq r0,#0x81				;@ BSY+SEL
	moveq r1,#0
	strbeq r1,scsiPtr
	moveq r0,#0xD0				;@ Command Out
	beq setSCSISignal
	bx lr
;@----------------------------------------------------------------------------
CD01_W:						;@ SCSI BUS DATA
;@----------------------------------------------------------------------------
	strb r0,scsiDataLatch
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
	ldrb r0,scsiDataLatch
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

	cmp r1,#CMD_TEST_UNIT_READY
	beq cmdTestUnitReady
	cmp r1,#CMD_REQUEST_SENSE
	beq cmdRequestSense
	cmp r1,#CMD_READ6
	beq cmdRead6
	cmp r1,#CMD_START_PLAY_CD	;@ Set start time, play & search
	beq cmdStartPlayCD
	cmp r1,#CMD_END_PLAY_CD		;@ Set end time
	beq cmdEndPlayCD
	cmp r1,#CMD_PAUSE_CD		;@ Paus CD
	beq cmdPausCD
	cmp r1,#CMD_SUB_Q			;@ Read SubChannel Q
	beq cmdSubQ
	cmp r1,#CMD_GET_INFO		;@ Get Info
	beq cmdGetInfo
	cmp r1,#CMD_ABORT			;@ Abort
	beq cmdAbort
	b cmdUnknown

sendStatus:
	mov r0,#SCSISTATUS_OK
	strb r0,scsiData
	mov r0,#0xF8
	b setSCSISignal
sendMessage:
	mov r0,#0x00
	strb r0,scsiData
	b setSCSISignal
;@----------------------------------------------------------------------------
CD03_W:						;@ IRQ request, R/O
;@----------------------------------------------------------------------------
;@	mov r11,r11					;@ No$GBA Debugg
	bx lr
;@----------------------------------------------------------------------------
CD04_W:						;@ SCSI reset?
;@----------------------------------------------------------------------------
	strb r0,scsiReset
	tst r0,#2
	bxeq lr
	mov r0,#0
	strb r0,scsiData
	strb r0,cdAudioPlaying
	strb r0,cdPlayMode
	strb r0,cdIrqReq
	b setSCSISignal
;@----------------------------------------------------------------------------
CD05_W:						;@ Start CD sound fetching
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
	mov r1,r1,lsl#19			;@ 8kB
	ldrne r0,[r2,r1,lsr#19]
	str r0,cdSample
	ldrb r0,cdIrqReq
	eor r0,r0,#0x02				;@ L/R bit should be toggled.
	strb r0,cdIrqReq
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

	ldrb r1,adAdrCtrl
	tst r1,#0x10				;@ Latch length?
	ldreq r2,adLen
	ldrne r2,adPtr
	movne r2,r2,lsr#1
	addeq r0,r2,#0x1<<15		;@ Add 1 to length.
	streq r0,adLen
	ldrb r1,cdIrqReq
	bne wrLenLck
	cmp r2,#0
	orreq r1,r1,#0x08			;@ ADPCM finnished playing.
wrLenLck:
	tst r2,#0x18000<<15
	bicne r1,r1,#0x04
	orreq r1,r1,#0x04			;@ ADPCM <32k left.
	strb r1,cdIrqReq

	bx lr
;@----------------------------------------------------------------------------
CD0B_W:						;@ CD-ROM to ADPCM-RAM DMA
;@----------------------------------------------------------------------------
	ldr r1,dataLen
	cmp r1,#0
	biceq r0,r0,#1
	strb r0,adDma
	ands r0,r0,#0x03
	bxeq lr

	adr r1,CDMA_txt
	b debugOutput_asm
CDMA_txt:
	.string "CD DMA"
	.align 2
;@----------------------------------------------------------------------------
CD0C_W:						;@ ADPCM status (Read Only)
;@----------------------------------------------------------------------------
;@	mov r11,r11					;@ No$GBA Debugg
	bx lr
;@----------------------------------------------------------------------------
CD0D_W:						;@ ADPCM control
;@----------------------------------------------------------------------------
	ldrb r1,adAdrCtrl
	strb r0,adAdrCtrl
	eor r1,r1,r0
	and r12,r1,r0				;@ r12=bits set this time
	tst r12,#0x80
	bne adReset

	ldr r2,adPtr
	tst r0,r0,lsr#1
	tst r12,#0x2
	movne r1,r2
	subcc r1,r1,#0x10000
	strne r1,adWrPtr

	tst r0,r0,lsr#3
	tst r12,#0x8
	movne r1,r2
	subcc r1,r1,#0x10000
	strne r1,adRdPtr

	tst r0,#0x10
	movne r2,r2,lsr#1
	strne r2,adLen
	ldrbne r2,cdIrqReq
	bicne r2,r2,#0x08			;@ Clear ADPCM finnished flag
	strbne r2,cdIrqReq
	bne CD_Check_IRQ
	tst r12,#0x20				;@ Start playing?
	bxeq lr
	stmfd sp!,{lr}
	bl adpcmReset
	strb r0,adpcmRateCount
	ldmfd sp!,{lr}
	adr r1,PS_txt
	b debugOutput_asm

adReset:
	mov r0,#0
	str r0,adPtr
	str r0,adWrPtr
	str r0,adRdPtr
	str r0,adLen
	ldrb r0,cdIrqReq
	bic r0,r0,#0x0C				;@ Clear ADPCM IRQ flags
	strb r0,cdIrqReq
	bx lr

PS_txt:
	.string "ADPCM Play"
	.align 2
;@----------------------------------------------------------------------------
CD0E_W:						;@ ADPCM playback rate
;@----------------------------------------------------------------------------
	strb r0,adpcmRate
	adr r1,PB_txt
	b debugOutput_asm
//	bx lr
PB_txt:
	.string "ADPCM Rate"
	.align 2
;@----------------------------------------------------------------------------
CD0F_W:						;@ Audio fade out
;@----------------------------------------------------------------------------
	strb r0,fadeCtrl
	tst r0,#0x4
	ldrne r1,=0x10000/(60*2)	;@ ~2 seconds fade
	moveq r1,#0x10000/(60*8)	;@ ~8 seconds fade
	tst r0,#0x8					;@ Enabled?
	moveq r1,#0
	str r1,cddaFade
	moveq r1,#0x10000
	streq r1,fadeVolume
	streq r1,cddaVolume
	streq r1,adpcmVolume
	adr r1,AF_txt
	b debugOutput_asm
//	bx lr
AF_txt:
	.string "Audio Fade"
	.align 2

;@----------------------------------------------------------------------------
cdromState:
dmaOutPtr:	.long 0				;@ DMA data byte ptr
dataOutPtr:	.long 0				;@ SCSI data byte ptr
currentPos:	.long 0				;@ Current position on disc
dataLen:	.long 0				;@ SCSI data length in bytes
sectorPtr:	.long 0				;@ Audio sector pointer, shift 2 right to get real value.
sectorEnd:	.long 0				;@ Audio end sector pointer, shift 2 right to get real value.
cddaStart:	.long 0				;@ Start position for cd audio (for repeat...).
cdSeekTime:	.long 0				;@ Seek time in frames (when setting sector).

adPtr:		.long 0				;@ ADPCM ptr	($1808-1809)
adLen:		.long 0				;@ ADPCM length, in upper 17/18 bits
adWrPtr:	.long 0				;@ ADPCM write ptr in upper 16bits
adRdPtr:	.long 0				;@ ADPCM read ptr in upper 16bits
cddaFade:	.long 0				;@ Fade value
fadeVolume:	.long 0x10000		;@ Used by fade command.
cddaVolume:	.long 0x10000		;@ Used by fade command.
adpcmVolume:.long 0x10000		;@ Used by fade command.
cdSample:	.long 0				;@ CD Audio sample
ampPtr:		.long 0				;@ CD Audio sample pointer
adFreqToCD:	.long 44100			;@ Counter for converting 32kHz to 44.1kHz

scsiSignal:		.byte 0			;@ bit7-3		($1800)
scsiData:		.byte 0			;@ From CD		($1801/1808)
scsiDataLatch:	.byte 0			;@ From cpu
cdIrqMask:		.byte 0			;@ bit7=cd-ack?	($1802)
cdIrqReq:		.byte 0			;@				($1803)
scsiReset:		.byte 0			;@				($1804)
bramAccess:		.byte 0			;@				($1807)
adLatch:		.byte 0			;@ ADPCM read latch ($180A)
adDma:			.byte 0			;@ ADPCM DMA ctrl ($180B)
adAdrCtrl:		.byte 0			;@ ADPCM address control ($180D)
adpcmRate:		.byte 0			;@ ADPCM playback rate ($180E)
adpcmRateCount:	.byte 0			;@ ADPCM playback rate counter
adpcmStatus:	.byte 0			;@ ADPCM busy status.
adpcmDmaOn:		.byte 0			;@ ADPCM -> CD DMA on?
fadeCtrl:		.byte 0			;@ ADPCM/CD Audio fade ($180F)
cdPlayMode:		.byte 0			;@ Which audio play mode?
cdAudioPlaying:	.byte 0			;@ Is cd audio playing?
cdAudioRepeat:	.byte 0			;@ Should music repeat after completion?
scsiPtr:		.byte 0			;@ Which byte of the command
currentTrack:	.byte 0			;@ Current track in BCD

scsiCmd:		.space 10
scsiResponse:	.space 10
	.align 2
cdromStateEnd:

tgcdBase:
	.long 0
cdFileSize:
	.long 0
isoBase:
	.long 0
cdInserted:		.byte 0
coverOpen:		.byte 0
	.align 2
scsiCommandHex:	.space 32


;@----------------------------------------------------------------------------
printSCSICommand:
;@----------------------------------------------------------------------------
	mov r0,#10
	adr r1,scsiCmd
;@----------------------------------------------------------------------------
printHexValues:			;@ r0=count,max 10, r1=source.
;@----------------------------------------------------------------------------
	stmfd sp!,{r3,lr}
	adr r2,scsiCommandHex

hexLoop:
	ldrb r3,[r1],#1
	mov lr,r3,lsr#4
	cmp lr,#0x0A
	addmi lr,lr,#0x30
	addpl lr,lr,#0x37
	strb lr,[r2],#1
	and r3,r3,#0x0F
	cmp r3,#0x0A
	addmi r3,r3,#0x30
	addpl r3,r3,#0x37
	strb r3,[r2],#1
	mov r3,#0x20
	strb r3,[r2],#1
	subs r0,r0,#1
	bhi hexLoop

	ldmfd sp!,{r3,lr}
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
calcSeekTime:
;@----------------------------------------------------------------------------
	stmfd sp!,{r0,r4-r5,lr}
	ldr r1,sectorPtr
	subs r0,r0,r1,lsr#2			;@ Remove the extra bits
	rsbmi r0,r0,#0
	mov r0,r0,lsr#13			;@ 21-13=8, for a max of 255 frames for 4GB seek.
	add r0,r0,#7
	str r0,cdSeekTime
	ldmfd sp!,{r0,r4-r5,pc}
;@----------------------------------------------------------------------------
LBA2AudioOffset:			;@ in r0=real LBA
;@----------------------------------------------------------------------------
	stmfd sp!,{r3,lr}
	bl calcSeekTime
	mov r1,r0,lsl#2				;@ 2 extra bits for the cd frame vs gba frame.
	str r1,sectorPtr
	bl LBA2RealOffset
	blx CD_SeekPos
	blx CD_ResetBuffer
	ldmfd sp!,{r3,lr}
	bx lr
;@----------------------------------------------------------------------------
LBA2DataOffset:				;@ in r0=real LBA, called from READ6
;@----------------------------------------------------------------------------
	stmfd sp!,{r3,lr}
	bl calcSeekTime
	mov r1,r0,lsl#2				;@ 2 extra bits for the cd frame vs gba frame.
	str r1,sectorPtr
	mov r1,r0,lsl#11
	str r1,currentPos
	bl LBA2RealOffset
	blx CD_SeekPos
	ldmfd sp!,{r3,lr}
	b preLoadData
;@----------------------------------------------------------------------------
SCSI_SendData:
	ldrb r0,scsiCmd
	cmp r0,#CMD_READ6
	bne SCSI_SendResponse

	ldr r0,dataLen
	subs r0,r0,#1
	strpl r0,dataLen
	beq noMoreScsiData
preLoadData:
	ldr r0,currentPos			;@ Current byte pos on disc.
	add r0,r0,#1
	str r0,currentPos

	stmfd sp!,{r3,lr}
	blx CD_ReadByte
	ldmfd sp!,{r3,lr}
	mov r2,r0

	ldrb r0,scsiData
	strb r2,scsiData
	bx lr

noMoreScsiData:
	mov r0,#0x98
	stmfd sp!,{lr}
	bl setSCSISignal
	ldmfd sp!,{lr}
	ldrb r0,scsiData
	mov r1,#0					;@ Scsi data should be clear if we have sent all the data, or error code if error occured.
	strb r1,scsiData
	bx lr
;@----------------------------------------------------------------------------
SCSI_SendResponse:
;@----------------------------------------------------------------------------
	ldr r0,dataLen
	subs r0,r0,#1
	strpl r0,dataLen

	ldrpl r1,dataOutPtr
	ldrbpl r2,[r1],#1
	strpl r1,dataOutPtr
	ldrb r0,scsiData
	strb r2,scsiData
	bxpl lr
	mov r2,#0					;@ Scsidata should be clear if we have sent all the data
	strb r2,scsiData
	stmfd sp!,{r0,lr}
	mov r0,#0xD8
	bl setSCSISignal
	ldmfd sp!,{r0,pc}
;@----------------------------------------------------------------------------
cmdTestUnitReady:			;@ Command 0x00
;@----------------------------------------------------------------------------
	mov r0,#0xD8				;@ No data only status
	stmfd sp!,{lr}
	bl setSCSISignal
	ldmfd sp!,{pc}

	ldrb r0,cdInserted
	cmp r0,#0
	movne r0,#SCSISTATUS_OK
	moveq r0,#SCSISTATUS_CHECKCONDITION
	strb r0,scsiData

	adr r1,turTxt
	b debugOutput_asm
//	bx lr
turTxt:
	.string "TestUnitReady"
	.align 2
;@----------------------------------------------------------------------------
cmdRequestSense:			;@ Command 0x03
;@----------------------------------------------------------------------------
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
//	moveq r0,#NECCODE_UNKNOWN04
	strb r0,[r1,#9]								;@ Sense Code?
	bl SCSI_SendData
	mov r0,#0xC8				;@ SCSI data
	bl setSCSISignal
	ldmfd sp!,{lr}

	adr r1,rsTxt
	b debugOutput_asm
//	bx lr
rsTxt:
	.string "RequestSense"
	.align 2
;@----------------------------------------------------------------------------
cmdRead6:					;@ Command 0x08
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}

	mov r0,#0					;@ Audio isn't playing anymore
	strb r0,cdAudioPlaying
	strb r0,cdPlayMode
	adrl r2,scsiCmd
	ldrb r0,[r2,#4]				;@ Number of sectors
	movs r0,r0,lsl#11			;@ 0x800
	moveq r0,#0x80000
	str r0,dataLen

	ldrb r0,[r2,#1]				;@ LBA1
	and r0,r0,#0x1F
	ldrb r1,[r2,#2]				;@ LBA2
	orr r0,r1,r0,lsl#8			;@
	ldrb r1,[r2,#3]				;@ LBA3
	orr r0,r1,r0,lsl#8

	bl LBA2DataOffset			;@ r0 = real LBA, out data file offset

	ldrb r0,cdIrqReq
	orr r0,r0,#0x10				;@ SUBCH ready?
	strb r0,cdIrqReq

	mov r0,#0x88				;@ SCSI data
	bl setSCSISignal

	ldmfd sp!,{lr}

	adr r1,r6Txt
	b debugOutput_asm
//	bx lr
r6Txt:
	.string "Read6"
	.align 2
;@----------------------------------------------------------------------------
cmdStartPlayCD:				;@ Command 0xD8
;@----------------------------------------------------------------------------
	stmfd sp!,{r3-r5,lr}

	adrl r4,scsiCmd
	ldrb r2,[r4,#9]				;@ LBA, Track or MSF
	ands r2,r2,#0xC0
	beq  cdGetLBA
	cmp r2,#0x40				;@ MSF?
	bne notMSF
	ldrb r0,[r4,#2]				;@ Min
	ldrb r1,[r4,#3]				;@ Sec
	orr r0,r1,r0,lsl#8
	ldrb r1,[r4,#4]				;@ Fra
	orr r0,r1,r0,lsl#8
	bl MSF2LBA
	b  writeSec
notMSF:
	cmp r2,#0x80				;@ Tracks?
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
	bl LBA2AudioOffset			;@ r0 = real LBA, set audio file offset
	bl CD_FindSetEnd

notTrack:
	ldrb r0,[r4,#1]				;@ Play mode.
	ands r0,r0,#0x3F
	strbeq r0,cdAudioPlaying
	cmp r0,#4					;@ Don't change since previous?
	strbne r0,cdPlayMode
	ldrbeq r0,cdPlayMode
	cmp r0,#1					;@ Repeat after completion?
	movne r0,#0
	strb r0,cdAudioRepeat
	mov r1,#0
	strb r1,scsiData

	mov r0,#0x98				;@ No data only status
	bl setSCSISignal

	mov r1,#0x10000
	str r1,fadeVolume

	adr r1,pcTxt
	bl debugOutput_asm
	ldmfd sp!,{r3-r5,lr}
	adr r1,scsiCommandHex
	b debugOutput_asm
//	bx lr
pcTxt:
	.string "PlayCD_D8"
	.align 2

;@----------------------------------------------------------------------------
CD_DoRepeat:
;@----------------------------------------------------------------------------
	ldr r0,cddaStart
	b LBA2AudioOffset			;@ r0 = real LBA, set audio file offset
;@----------------------------------------------------------------------------
CD_FindSetEnd:
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r5,lr}
	ldr r0,cddaStart
	bl LBA2Track				;@ Get current track
	ldr r5,tgcdBase
	ldrb r4,[r5,#cdTOCTrackCount]	;@ Last track
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
cmdEndPlayCD:				;@ Command 0xD9
;@----------------------------------------------------------------------------
	stmfd sp!,{r3-r5,lr}

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
	ldrb r0,[r4,#1]				;@ Play mode.
	ands r0,r0,#0x3F
	strbeq r0,cdAudioPlaying
	cmp r0,#4					;@ Don't change since previous?
	strbne r0,cdPlayMode
	ldrbeq r0,cdPlayMode
	cmp r0,#1					;@ Repeat after completion?
	movne r0,#0
	strb r0,cdAudioRepeat
	mov r1,#0
	strb r1,scsiData
	mov r0,#0xD8				;@ No data only status
	bl setSCSISignal

	adr r1,pc2Txt
	bl debugOutput_asm
	ldmfd sp!,{r3-r5,lr}
	adrl r1,scsiCommandHex
	b debugOutput_asm
//	bx lr
pc2Txt:
	.string "PlayCD_D9"
	.align 2
;@----------------------------------------------------------------------------
cmdPausCD:					;@ Command 0xDA
;@----------------------------------------------------------------------------
	mov r0,#0xD8				;@ No data only status
	stmfd sp!,{lr}
	bl setSCSISignal
	ldmfd sp!,{lr}
	mov r0,#0
	strb r0,scsiData
	strb r0,cdAudioPlaying
	strb r0,cdPlayMode
	adr r1,paTxt
	b debugOutput_asm
//	bx lr
paTxt:
	.string "PauseCD"
	.align 2
;@----------------------------------------------------------------------------
cmdSubQ:					;@ Command 0xDD
;@----------------------------------------------------------------------------
;@	mov r11,r11					;@ No$GBA Debugg
	stmfd sp!,{r3-r5,lr}
	adrl r5,scsiResponse
	ldrb r0,cdAudioPlaying
	cmp r0,#0
	movne r0,#0					;@ 0 if playing, 1 paused, 2 (search?) paused, 3 complete (stopped?).
	moveq r0,#0x03				;@ 3 if stopped, 2 paused.
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

	mov r0,#0xC8				;@ SCSI data
	bl setSCSISignal
	mov r0,#10
	str r0,dataLen
	bl SCSI_SendData

	ldmfd sp!,{r3-r5,lr}
//	adr r1,sqTxt
//	b debugOutput_asm
	bx lr
sqTxt:
	.string "SubQ"
	.align 2
;@----------------------------------------------------------------------------
cmdGetInfo:				;@ Command 0xDE
;@----------------------------------------------------------------------------
	mov r0,#0
	mov r2,#4
	str r2,dataLen
	adrl r1,scsiResponse
	str r1,dataOutPtr
giLoop:
	subs r2,r2,#1
	strbne r0,[r1,r2]
	bne giLoop

	stmfd sp!,{lr}
	mov r0,#0xC8				;@ SCSI data
	bl setSCSISignal
	adr lr,giBack
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
	bl debugOutput_asm
	ldmfd sp!,{lr}
	b SCSI_SendData
//	bx lr

;@--------------------------------
firstLastTrack:
	stmfd sp!,{r3,lr}
	ldr r1,tgcdBase
	mov r0,#0x01				;@ First Track
	strb r0,scsiResponse
	ldrb r0,[r1,#cdTOCTrackCount]	;@ Last Track
	bl Hex2Bcd
	strb r0,scsiResponse+1
	adr r1,GIFL_txt
	ldmfd sp!,{r3,pc}
GIFL_txt:
	.string "GetInfo FL"
	.align 2
;@--------------------------------
totalTime:
	stmfd sp!,{r3,lr}

	ldr r1,tgcdBase
	ldrb r0,[r1,#cdTOCEndLBA0]	;@ Total len, LBA
	ldrb r2,[r1,#cdTOCEndLBA1]
	orr r0,r2,r0,lsl#8
	ldrb r2,[r1,#cdTOCEndLBA2]
	orr r0,r2,r0,lsl#8

	bl LBA2MSF

	strb r0,scsiResponse+2		;@ Frames
	mov r0,r0,lsr#8
	strb r0,scsiResponse+1		;@ Seconds (2=150 frames/sectors)
	mov r0,r0,lsr#8
	strb r0,scsiResponse		;@ Total minutes

	adrl r1,gittTxt
	ldmfd sp!,{r3,pc}
;@--------------------------------
trackInfo:
	stmfd sp!,{r3,lr}

	ldrb r0,[r2,#2]				;@ Track number
	adrl r1,gitiTxt
	and r2,r0,#0xf
	add r2,r2,#0x30
	strb r2,[r1,#19]
	mov r2,r0,lsr#4
	add r2,r2,#0x30
	strb r2,[r1,#18]

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

	adrl r1,gitiTxt
	ldmfd sp!,{r3,pc}

;@----------------------------------------------------------------------------
cmdAbort:					;@ Command 0xFF
;@----------------------------------------------------------------------------
	mov r0,#0x00				;@ No data
	stmfd sp!,{lr}
	bl setSCSISignal
	ldmfd sp!,{lr}
	b cmdUnknown
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
	ldrb r5,[r1,#cdTOCTrackCount]	;@ How many tracks
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
	ldrb r1,[r2,#cdTOCTrackCount]	;@ Last track
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
cmdUnknown:
;@----------------------------------------------------------------------------
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
	.align 2

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
	.align 2
;@----------------------------------------------------------------------------
cdRomToc:
	.space cdTOCSize		;@ TOC
	.space cdTrackSize*99	;@ Max 99 tracks
;@----------------------------------------------------------------------------
	.end
#endif // __arm__
