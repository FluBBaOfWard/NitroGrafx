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
	.global soundRender
	.global soundSetMuteGUI
	.global soundUpdate
	.global PSG_0_R
	.global PSG_0_W

#define SHIFTVAL (20)
#define SOUND_BUFFER_SIZE (1<<(32-SHIFTVAL))

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
soundSetMuteGUI:
	.type   soundSetMuteGUI STT_FUNC
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
soundRender:				;@ r0=length, r1=pointer
	.type soundRender STT_FUNC
;@----------------------------------------------------------------------------
	ldr r2,muteSound
	cmp r2,#0
	bne silenceMix
#ifdef SAMPLE_PLAYING
	stmfd sp!,{r0,r1,r4,r5,lr}
	ldr r4,pcmReadPtr
	add r5,r4,r0
	str r5,pcmReadPtr

;@------------------------------
soundCopyBuff:				;@ r0=length, r1=destination
	ldr r2,=WAVBUFFER			;@ Source
	mov r4,r4,lsl#SHIFTVAL
sndCopyLoop:
	subs r0,r0,#1
	ldrpl r3,[r2,r4,lsr#SHIFTVAL-2]
	addpl r4,r4,#1<<SHIFTVAL
	strpl r3,[r1],#4
	bhi sndCopyLoop
;@------------------------------

	ldr r2,sndWritePtr
	ldr r0,pcmWritePtr
	sub r2,r2,r0,lsl#SHIFTVAL
	add r0,r0,r2,lsr#SHIFTVAL
	str r0,pcmWritePtr
	sub r0,r5,r0
	add r0,r0,#SOUND_BUFFER_SIZE/2
	ldr r2,neededExtra
	rsb r2,r2,r2,lsl#3			;@ mul 7
	add r0,r2,r0
	mov r0,r0,asr#3
	str r0,neededExtra
//	bic r0,r0,#1		// 7
	mov r0,r0,asr#3
	ldr r1,=44100*256/60/262
	adds r0,r0,r1
	movmi r0,#10
	str r0,samplesCnt
//	blne debugIOUnmappedR

	ldmfd sp!,{r0,r1,r4,r5,lr}
	stmfd sp!,{r0,r1,lr}
	bl renderADPCM
	ldmfd sp!,{r0,r1,lr}
	ldr r2,=cdSeekTime
	ldr r2,[r2]
	cmp r2,#0
	bne seeking
	ldr r2,=cdAudioPlaying
	ldrb r2,[r2]
	cmp r2,#0
	bne mixCDData2
seeking:
	add r1,r1,r0,lsl#2
	ldr r2,[r1,#-4]
	str r2,silenceWave
	bx lr
#else
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
	add r1,r1,r0,lsl#2
	ldr r2,[r1,#-4]
	str r2,silenceWave
	ldmfd sp!,{r0,r1,lr}
	bx lr
#endif // SAMPLE_PLAYING

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
mixCDData2:
	stmfd sp!,{r0,r1,r4-r7}

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

	ldr r5,=cdBuffer
	ldr r7,=cdReadPtr
	ldr r6,[r7]
mixLoop01:
	ldr r2,[r1]
	mov r4,r6,lsl#18			;@ 16kB
	ldr r3,[r5,r4,lsr#18]
	add r6,r6,#4

	and r4,r2,r3
	eor r2,r2,r3
	mov r2,r2,ror#16
	mov r2,r2,asr#1
	mov r2,r2,ror#15
	add r2,r4,r2,asr#1

	str r2,[r1],#4
	subs r0,r0,#1
	bhi mixLoop01

	str r6,[r7]					;@ cd_readptr
	str r2,silenceWave

	ldmfd sp!,{r0,r1,r4-r7}
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
	stmfd sp!,{r3,r4,lr}
	ldr r1,=WAVBUFFER
	ldr r2,sndWritePtr
	ldr r0,samplesCnt
	mov r4,#0
	adds r3,r2,r0,lsl#SHIFTVAL-8	;@ Only use top 11 bits
	movcs r4,r3,lsr#SHIFTVAL
	subcs r3,r3,r4,lsl#SHIFTVAL
	str r3,sndWritePtr
	mov r2,r2,lsr#SHIFTVAL
	rsb r0,r2,r3,lsr#SHIFTVAL
	and r0,#7
	add r1,r1,r2,lsl#2

	ldr psgptr,=PSG_0
	bl PCEPSGMixer
	cmp r4,#0
	ldmfdeq sp!,{r3,r4,pc}

	ldr r1,=WAVBUFFER
	ldr r3,sndWritePtr
	add r3,r3,r4,lsl#SHIFTVAL
	str r3,sndWritePtr
	mov r0,r4
	bl PCEPSGMixer
	ldmfd sp!,{r3,r4,pc}

;@----------------------------------------------------------------------------
sndWritePtr:	.long 0
pcmWritePtr:	.long 0
pcmReadPtr:		.long 0
neededExtra:	.long 0
samplesCnt:		.long 0

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
#endif // __arm__
