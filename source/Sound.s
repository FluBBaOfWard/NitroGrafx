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

	.global soundInit
	.global soundReset
	.global soundSetFrequency
	.global VblSound2
	.global PSG_0_R
	.global PSG_0_W
	.global setMuteSoundGUI
	.global setMuteSoundGame


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
	mov r0,#0
	str r0,silenceWave
	str r0,sectorCountDown

	ldr psgptr,=PSG_0
	b PCEPSGReset				;@ Sound
;@----------------------------------------------------------------------------
soundSetFrequency:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	ldr r1,=3579545				;@ NTSC freq
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
setMuteSoundGame:			;@ For System E ?
;@----------------------------------------------------------------------------
	strb r0,muteSoundGame
	bx lr
;@----------------------------------------------------------------------------
VblSound2:					;@ r0=length, r1=pointer
	.type VblSound2 STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r0,r1,r4-r8,lr}

	ldr r2,muteSound
	cmp r2,#0
	bne silenceMix

//	mov r0,r0,lsl#2
//	ldr r1,=MixSpace
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
	ldmfd sp!,{r0,r1,r4-r8,lr}
	bx lr

	ldmfd sp,{r0,r1}
//	ldr r2,=MixSpace
mixLoop00:
	ldrsh r12,[r2],#2
	ldrsh r4,[r2],#2
	ldrsh r3,[r2],#2
	ldrsh r5,[r2],#2
	add r12,r12,r3
	add r4,r4,r5
	ldrsh r3,[r2],#2
	ldrsh r5,[r2],#2
	add r12,r12,r3
	add r4,r4,r5
	ldrsh r3,[r2],#2
	ldrsh r5,[r2],#2
	add r12,r12,r3
	add r4,r4,r5

	mov r4,r4,asr#2
	mov r12,r12,lsl#16-2
	mov r4,r4,lsl#16
	orr r12,r4,r12,lsr#16
	str r12,[r1],#4
	subs r0,r0,#1
	bhi mixLoop00

	str r12,silenceWave

	ldmfd sp!,{r0,r1,r4-r8,lr}
	bx lr

silenceMix:
	ldr r2,silenceWave
silenceLoop:
	subs r0,r0,#1
	strpl r2,[r1],#4
	bhi silenceLoop

	ldmfd sp!,{r0,r1,r4-r8,lr}
	bx lr

;@----------------------------------------------------------------------------
mixCDData:
;@----------------------------------------------------------------------------
	ldmfd sp,{r0,r1}

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

//	ldr r1,=MixSpace
	ldr r6,=cdBuffer
	ldr r8,=cdReadPtr
	ldr r7,[r8]
mixLoop01:
	ldr r2,[r1]
	mov r4,r7,lsl#18			;@ 16kB
	ldr r3,[r6,r4,lsr#18]
	add r7,r7,#4

	and r4,r2,r3
	eor r2,r2,r3
	mov r2,r2,ror#16
	mov r2,r2,asr#1
	mov r2,r2,ror#15
	add r2,r4,r2,asr#1

	str r2,[r1],#4
	subs r0,r0,#1
	bhi mixLoop01

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
sectorCountDown:
	.space 4
silenceWave:
	.space 4

muteSound:
muteSoundGUI:
	.byte 0
muteSoundGame:
	.byte 0
	.space 2

;@----------------------------------------------------------------------------
//	.section .bss
//MixSpace:
//	.space 0x10000
;@----------------------------------------------------------------------------
#ifdef NDS
	.section .sbss				;@ This is DTCM on NDS with devkitARM
#elif GBA
	.section .bss				;@ This is IWRAM on GBA with devkitARM
#else
	.section .bss
#endif
	.align 2
PSG_0:
	.space pcePsgSize
;@----------------------------------------------------------------------------
	.end
#endif // #ifdef __arm__
