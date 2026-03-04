//
//  Sound.s
//  NitroGrafx
//
//  Created by Fredrik Ahlström on 2003-01-01.
//  Copyright © 2003-2026 Fredrik Ahlström. All rights reserved.
//
#ifdef __arm__

#include "ARMH6280/H6280.i"
#include "PCEPSG/pcepsg.i"

	.extern pauseEmulation
	.extern powerIsOn

	.global PSG_0
	.global missingSamplesCnt

	.global soundInit
	.global soundReset
	.global VblSound2
	.global PSG_0_R
	.global PSG_0_W
	.global setMuteSoundGUI
	.global soundUpdate

#define SOUND_BUFFER_SIZE (0x1000)
#define SHIFTVAL (21)

	.syntax unified
	.arm

	.section .text
	.align 2
;@----------------------------------------------------------------------------
soundInit:
	.type soundInit STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	bl PCEPSGInit
	ldmfd sp!,{lr}
//	bx lr

;@----------------------------------------------------------------------------
soundReset:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	mov r0,#SOUND_BUFFER_SIZE/2
	str r0,pcmWritePtr
	mov r0,r0,lsl#SHIFTVAL		;@ Only keep 11 bits
	str r0,sndWritePtr
	mov r0,#0
	str r0,pcmReadPtr
	str r0,silenceWave
	str r0,sectorCountDown
	ldr psgptr,=PSG_0
	bl PCEPSGReset				;@ Sound
	mov r0,#SOUND_BUFFER_SIZE
	ldr r1,=WAVBUFFER
	bl silenceMix
	ldmfd sp!,{lr}
	bx lr

;@----------------------------------------------------------------------------
setMuteSoundGUI:
	.type   setMuteSoundGUI STT_FUNC
;@----------------------------------------------------------------------------
	ldr r1,=pauseEmulation		;@ Output silence when emulation paused.
	ldrb r0,[r1]
	ldr r1,=powerIsOn			;@ Output silence when power off.
	ldrb r1,[r1]
	cmp r1,#0
	orreq r0,r0,#0xFF
	strb r0,muteSoundGUI
	bx lr
;@----------------------------------------------------------------------------
VblSound2:					;@ r0=length, r1=pointer
	.type VblSound2 STT_FUNC
;@----------------------------------------------------------------------------
	ldr r2,muteSound
	cmp r2,#0
	bne silenceMix

	stmfd sp!,{r0,r1,lr}
	ldr psgptr,=PSG_0
	bl PCEPSGMixer

	ldr r2,=cdSeekTime
	ldr r2,[r2]
	cmp r2,#0
	bne seeking
	ldr r2,=cdAudioPlaying
	ldrb r2,[r2]
	cmp r2,#0
	bne mixCDData
seeking:
	sub r0,r0,#1
	ldr r2,[r1,r0,lsl#2]
	str r2,silenceWave
	ldmfd sp!,{r0,r1,lr}
	bx lr

;@----------------------------------------------------------------------------
soundCopyBuff:				;@ r0=length, r1=destination
;@----------------------------------------------------------------------------
	ldr r2,=WAVBUFFER			;@ Source
	mov r4,r4,lsl#SHIFTVAL
sndCopyLoop:
	subs r0,r0,#1
	ldrpl r3,[r2,r4,lsr#SHIFTVAL-2]
	add r4,r4,#1<<SHIFTVAL
	strpl r3,[r1],#4
	bhi sndCopyLoop
	bx lr
;@----------------------------------------------------------------------------
silenceMix:
;@----------------------------------------------------------------------------
	mov r3,r0
	ldr r2,silenceWave
silenceLoop:
	subs r3,r3,#1
	strpl r2,[r1],#4
	bhi silenceLoop

	bx lr

;@----------------------------------------------------------------------------
mixCDData:
;@----------------------------------------------------------------------------
	ldmfd sp!,{r0,r1,lr}
	stmfd sp!,{r0,r1,r4-r8,lr}

	ldr r3,=sectorPtr
	ldr r2,[r3]
	ldr r4,sectorCountDown
	subs r4,r4,r0
sectLoop:
	addmi r2,r2,#4
	addsmi r4,r4,#2352/4
	bmi sectLoop
	str r2,[r3]
	str r4,sectorCountDown

	ldr r6,=cdBuffer
	ldr r8,=cdReadPtr
	ldr r7,[r8]
	mov r7,r7,lsl#18			;@ 16kB
mixLoop01:
	ldr r2,[r1]
	ldr r3,[r6,r7,lsr#18]
	add r7,r7,#0x00100000		;@ 4

	and r4,r2,r3
	eor r2,r2,r3
	mov r2,r2,ror#16
	mov r2,r2,asr#1
	mov r2,r2,ror#15
	add r2,r4,r2,asr#1

	str r2,[r1],#4
	subs r0,r0,#1
	bhi mixLoop01

	mov r7,r7,lsr#18			;@ 16kB
	str r7,[r8]					;@ cd_readptr
	str r2,silenceWave

	ldmfd sp!,{r0,r1,r4-r8,lr}
	bx lr
;@----------------------------------------------------------------------------
fetchCDData:
;@----------------------------------------------------------------------------
	mov r0,r0,lsl#2
	blx CD_FetchAudio
	ldmfd sp!,{r0,r1,r4-r8,lr}
	bx lr
;@----------------------------------------------------------------------------
PSG_0_W:
;@----------------------------------------------------------------------------
	strb r0,[h6280ptr,#h6280IoBuffer]
	mov r1,addy
	ldr psgptr,=PSG_0
	b PCEPSGWrite
;@----------------------------------------------------------------------------
soundUpdate:				;@ r0 = samples to render
;@----------------------------------------------------------------------------
	ldr r1,=WAVBUFFER
	ldr r2,sndWritePtr
	mov r0,#2					;@ 31440Hz / (60Hz * 262 scanlines) = 2 samples
	add r1,r1,r2,lsr#SHIFTVAL-2
	add r2,r2,r0,lsl#SHIFTVAL	;@ Only use top 11 bits
	str r2,sndWritePtr
	ldr psgptr,=PSG_0
	b PCEPSGMixer

;@----------------------------------------------------------------------------
sndWritePtr:	.long 0
pcmWritePtr:	.long 0
pcmReadPtr:		.long 0
neededExtra:	.long 0
missingSamplesCnt:	.long 0

sectorCountDown:
	.long 0
silenceWave:
	.long 0

muteSound:
muteSoundGUI:
	.byte 0
muteSoundGame:
	.byte 0
	.space 2

;@----------------------------------------------------------------------------
#ifdef GBA
	.section .sbss				;@ This is EWRAM on GBA with devkitARM
#else
	.section .bss
#endif
	.align 2
WAVBUFFER:
	.space SOUND_BUFFER_SIZE*4
;@----------------------------------------------------------------------------
#ifdef NDS
	.section .sbss				;@ This is DTCM on NDS with devkitARM
#elif GBA
	.section .bss				;@ This is IWRAM on GBA with devkitARM
#else
	.section .bss
#endif
	.align 5
PSG_0:
	.space pcePsgSize
;@----------------------------------------------------------------------------
	.end
#endif // #ifdef __arm__
