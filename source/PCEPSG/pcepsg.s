//
//  pcepsg.s
//  NitroGrafx PC-Engine PSG emulator
//
//  Created by Fredrik Ahlström on 2003-01-01.
//  Copyright © 2003-2026 Fredrik Ahlström. All rights reserved.
//
#ifdef __arm__

#include "pcepsg.i"

#define PSGDIVIDE 80
#define PSGADDITION 0x00004000*PSGDIVIDE
#define PSGNOISEFEED 0x8600C01F
//#define PSGNOISEFEED 0xC018401F
//#define PSGNOISEFEED 0x0009001F

	.global PCEPSGInit
	.global PCEPSGReset
	.global pcePSGSaveState
	.global pcePSGLoadState
	.global pcePSGGetStateSize
	.global PCEPSGMixer
	.global PCEPSGWrite

	.syntax unified
	.arm

#ifdef NDS
	.section .itcm, "ax", %progbits		;@ For the NDS ARM9
#elif GBA
	.section .iwram, "ax", %progbits	;@ For the GBA
#endif
	.align 2
;@----------------------------------------------------------------------------
;@ r0  = Length
;@ r1  = Destination
;@ r2  = Mixer register
;@ r3  = Current sample
;@ r4  = Channel 0 pos+freq
;@ r5  = Channel 1 pos+freq
;@ r6  = Channel 2 pos+freq
;@ r7  = Channel 3 pos+freq
;@ r8  = Channel 4 pos+freq
;@ r9  = Channel 5 pos+freq
;@ r10 = Ch4 noise reg
;@ r11 = Ch5 noise reg
;@ r12 = PCE samplebuffers
;@ lr  = Current volume
;@ Waveforms should not be signed!!!
;@----------------------------------------------------------------------------
// IIIIIVCCCCCCCCCCCC10FFFFFFFFFFFF
// I=sampleindex, V=overflow, C=counter, F=frequency
;@----------------------------------------------------------------------------
PCEPSGMixer:				;@ r0=len, r1=dest, r12=psgptr
;@----------------------------------------------------------------------------
	stmfd sp!,{r0,r1,r3-r11,lr}
	ldrb r8,[psgptr,#amplitudeChg]
	cmp r8,#0
	blne updateAmplitudes
	ldmia psgptr!,{r4-r11}		;@ r12 = PCE wavebuffer
pcmMixLoop:
	add r4,r4,#PSGADDITION
	orrs r3,r12,r4,lsr#27
	mov lr,r4,lsl#18
	subcs r4,r4,lr,asr#4
vol0_L:
	mov r2,#0x00				;@ Volume left
vol0_R:
	orrs lr,r2,#0xFF0000		;@ Volume right
	ldrsbne r3,[r3,#0x00]		;@ Channel 0
	mulne r2,lr,r3
;@----------------------------
	add r5,r5,#PSGADDITION
	orrs r3,r12,r5,lsr#27
	mov lr,r5,lsl#18
	subcs r5,r5,lr,asr#4
vol1_L:
	mov lr,#0x00				;@ Volume left
vol1_R:
	orrs lr,lr,#0xFF0000		;@ Volume right
	ldrsbne r3,[r3,#0x20]		;@ Channel 1
	mlane r2,lr,r3,r2
;@----------------------------
	add r6,r6,#PSGADDITION
	orrs r3,r12,r6,lsr#27
	mov lr,r6,lsl#18
	subcs r6,r6,lr,asr#4
vol2_L:
	mov lr,#0x00				;@ Volume left
vol2_R:
	orrs lr,lr,#0xFF0000		;@ Volume right
	ldrsbne r3,[r3,#0x40]		;@ Channel 2
	mlane r2,lr,r3,r2
;@----------------------------
	add r7,r7,#PSGADDITION
	orrs r3,r12,r7,lsr#27
	mov lr,r7,lsl#18
	subcs r7,r7,lr,asr#4
vol3_L:
	mov lr,#0x00				;@ Volume left
vol3_R:
	orrs lr,lr,#0xFF0000		;@ Volume right
	ldrsbne r3,[r3,#0x60]		;@ Channel 3
	mlane r2,lr,r3,r2
;@----------------------------
	add r8,r8,#PSGADDITION
	orrs r3,r12,r8,lsr#27
	mov lr,r8,lsl#18
	subcs r8,r8,lr,asr#4

	movcs lr,r10,lsr#14
	addscs r10,r10,lr,lsl#14
	ldrcs lr,=PSGNOISEFEED
	eorcs r10,r10,lr
	tst r10,#0x80				;@ Noise 4 enabled?
	ldrsbeq r3,[r3,#0x80]		;@ Channel 4
	andne r3,r10,#0x0000001F
vol4_L:
	mov lr,#0x00				;@ Volume left
vol4_R:
	orrs lr,lr,#0xFF0000		;@ Volume right
	mlane r2,lr,r3,r2
;@----------------------------
	adds r9,r9,#PSGADDITION
	orrs r3,r12,r9,lsr#27
	mov lr,r9,lsl#18
	subcs r9,r9,lr,asr#4

	movcs lr,r11,lsr#14
	addscs r11,r11,lr,lsl#14
	ldrcs lr,=PSGNOISEFEED
	eorcs r11,r11,lr
	tst r11,#0x80				;@ Noise 5 enabled?
	ldrsbeq r3,[r3,#0xA0]		;@ Channel 5
	andne r3,r11,#0x0000001F
vol5_L:
	mov lr,#0x00				;@ Volume left
vol5_R:
	orrs lr,lr,#0xFF0000		;@ Volume right
	mlane r2,lr,r3,r2
;@----------------------------

	subs r0,r0,#1
	strpl r2,[r1],#4
	bgt pcmMixLoop				;@ 91 cycles according to No$gba

	stmdb psgptr!,{r4-r11}		;@ Write back counters
	ldmfd sp!,{r0,r1,r3-r11,pc}
;@----------------------------------------------------------------------------

	.section .text
	.align 2

;@----------------------------------------------------------------------------
PCEPSGInit:					;@ r0=psgptr
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r5,lr}
	ldr r4,=attenuation
	mov r0,r4
	mov r1,#0
	mov r2,#96*4
	bl memset

//	ldr r1,=0xB53BEF57			;@ 0.70794578 (-1.5dB)
	ldr r1,=0xE189374B			;@ Not -1.5dB
	mov r2,#0xB000				;@ (0x8000/6/31)<<8
	mov r5,#91					;@ 31+30+30
attenuationLoop:
	mov r3,r2,lsr#8
	str r3,[r4,r5,lsl#2]
	umull r3,r2,r1,r2
	subs r5,r5,#1
	cmp r5,#60
	bne attenuationLoop

	ldmfd sp!,{r4-r5,lr}
	bx lr
;@----------------------------------------------------------------------------
PCEPSGReset:				;@ psgptr=r12=pointer to struct
;@----------------------------------------------------------------------------
	mov r1,#0
	mov r0,#pcePsgSize/4
rLoop:
	subs r0,r0,#1
	strpl r1,[psgptr,r0,lsl#2]
	bhi rLoop

	mov r0,#0x00002000
	str r0,[psgptr,#pcm0CurrentAddr]
	str r0,[psgptr,#pcm1CurrentAddr]
	str r0,[psgptr,#pcm2CurrentAddr]
	str r0,[psgptr,#pcm3CurrentAddr]
	str r0,[psgptr,#pcm4CurrentAddr]
	str r0,[psgptr,#pcm5CurrentAddr]
	mov r0,#0x8000001F
	str r0,[psgptr,#noise4CurrentAddr]
	str r0,[psgptr,#noise5CurrentAddr]
	bx lr
;@----------------------------------------------------------------------------
pcePSGSaveState:		;@ In r0=destination, r1=psgptr. Out r0=state size.
	.type   pcePSGSaveState STT_FUNC
;@----------------------------------------------------------------------------
	mov r2,#pcePsgSize
	stmfd sp!,{r2,lr}
	bl memcpy
	ldmfd sp!,{r0,lr}
	bx lr
;@----------------------------------------------------------------------------
pcePSGLoadState:			;@ In r0=psgptr, r1=source. Out r0=state size.
	.type   pcePSGLoadState STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	mov r2,#pcePsgSize
	bl memcpy
	ldmfd sp!,{lr}
;@----------------------------------------------------------------------------
pcePSGGetStateSize:			;@ Out r0=state size.
	.type   pcePSGGetStateSize STT_FUNC
;@----------------------------------------------------------------------------
	mov r0,#pcePsgSize
	bx lr
;@----------------------------------------------------------------------------
updateAmplitudes:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}

	ldr r7,=vol0_L
	ldrb r4,[psgptr,#globalBalance]
	adr r5,attenuation
	mov r4,r4,ror#4

	ldrb r2,[psgptr,#ch0Control]
	ldrb r3,[psgptr,#ch0Balance]
	bl getVolumeDS				;@ Volume in r2/r3, uses r2-r7.
	strb r2,[r7,#vol0_L-vol0_L]
	strb r3,[r7,#vol0_R-vol0_L]

	ldrb r2,[psgptr,#ch1Control]
	ldrb r3,[psgptr,#ch1Balance]
	bl getVolumeDS				;@ Volume in r2/r3, uses r2-r7.
	strb r2,[r7,#vol1_L-vol0_L]
	strb r3,[r7,#vol1_R-vol0_L]

	ldrb r2,[psgptr,#ch2Control]
	ldrb r3,[psgptr,#ch2Balance]
	bl getVolumeDS				;@ Volume in r2/r3, uses r2-r7.
	strb r2,[r7,#vol2_L-vol0_L]
	strb r3,[r7,#vol2_R-vol0_L]

	ldrb r2,[psgptr,#ch3Control]
	ldrb r3,[psgptr,#ch3Balance]
	bl getVolumeDS				;@ Volume in r2/r3, uses r2-r7.
	strb r2,[r7,#vol3_L-vol0_L]
	strb r3,[r7,#vol3_R-vol0_L]

	ldrb r2,[psgptr,#ch4Control]
	ldrb r3,[psgptr,#ch4Balance]
	bl getVolumeDS				;@ Volume in r2/r3, uses r2-r7.
	strb r2,[r7,#vol4_L-vol0_L]
	strb r3,[r7,#vol4_R-vol0_L]

	ldrb r2,[psgptr,#ch5Control]
	ldrb r3,[psgptr,#ch5Balance]
	bl getVolumeDS				;@ Volume in r2/r3, uses r2-r7.
	strb r2,[r7,#vol5_L-vol0_L]
	strb r3,[r7,#vol5_R-vol0_L]

	mov r8,#0
	strb r8,[psgptr,#amplitudeChg]
	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
getVolumeDS:				;@ r0=chCtrl,r1=chBalance,r2=globalBalance
;@----------------------------------------------------------------------------
#ifdef SAMPLE_PLAYING
	tst r2,#0x80				;@ Should channel be played?
	moveq r2,#0
#else
	and r6,r2,#0xC0
	cmp r6,#0x80				;@ Should channel be played?
	movne r2,#0
#endif

	and r2,r2,#0x1F				;@ Channel master

	mov r3,r3,ror#4
	add r6,r2,r3,lsr#28-1		;@ Channel right
	add r6,r6,r4,lsr#28-1		;@ Global right

	add r2,r2,r3,lsl#1			;@ Channel left
	add r2,r2,r4,lsl#1			;@ Global left
	and r2,r2,#0x7F

	ldr r2,[r5,r2,lsl#2]
	ldr r3,[r5,r6,lsl#2]
	bx lr
;@----------------------------------------------------------------------------
attenuation:
	.space 96*4
;@----------------------------------------------------------------------------
PCEPSGWrite:				;@ r0=data, r1=address, r12=psgptr
;@----------------------------------------------------------------------------
	and r1,r1,#0xf
	ldr pc,[pc,r1,lsl#2]
;@----------------------------------------------------------------------------
	.long 0
PSGWriteTable:
	.long _0800W
	.long _0801W
	.long _0802W
	.long _0803W
	.long _0804W
	.long _0805W
	.long _0806W
	.long _0807W
	.long _0808W
	.long _0809W
	.long emptyWrite
	.long emptyWrite
	.long emptyWrite
	.long emptyWrite
	.long emptyWrite
	.long emptyWrite
;@----------------------------------------------------------------------------
_0800W:
;@----------------------------------------------------------------------------
	and r0,r0,#0x7
	strb r0,[psgptr,#psgChannel]
	bx lr
;@----------------------------------------------------------------------------
_0801W:						;@ Main Volume
;@----------------------------------------------------------------------------
	strb r0,[psgptr,#globalBalance]
	mov r1,#0x3F
	strb r1,[psgptr,#amplitudeChg]
	bx lr
;@----------------------------------------------------------------------------
_0802W:						;@ Frequency byte 0
;@----------------------------------------------------------------------------
	ldrb r1,[psgptr,#psgChannel]
	add r2,psgptr,r1,lsl#2
	strb r0,[r2,#ch0Freq]
	strb r0,[r2,#pcm0CurrentAddr]
	bx lr
;@----------------------------------------------------------------------------
_0803W:						;@ Frequency byte 1
;@----------------------------------------------------------------------------
	and r0,r0,#0xF
	ldrb r1,[psgptr,#psgChannel]
	add r2,psgptr,r1,lsl#2
	strb r0,[r2,#ch0Freq+1]
	ldrb r1,[r2,#pcm0CurrentAddr+1]
	bic r1,r1,#0xF
	orr r1,r1,r0
	strb r1,[r2,#pcm0CurrentAddr+1]
	bx lr
;@----------------------------------------------------------------------------
_0804W:						;@ Channel Enable, DDA & Volume
;@----------------------------------------------------------------------------
	ldrb r1,[psgptr,#psgChannel]
	add r2,psgptr,r1,lsl#2
	strb r0,[r2,#ch0Control]
	tst r0,#0x40				;@ Lock index?
	mov r0,#1
	mov r0,r0,lsl r1
	ldrb r1,[psgptr,#amplitudeChg]
	orr r1,r1,r0
	strb r1,[psgptr,#amplitudeChg]
	ldr r0,[r2,#pcm0CurrentAddr]
	bic r0,r0,#0x3000
	orreq r0,r0,#0x2000			;@ Normal index update
	orrne r0,r0,#0x0050			;@ No index update, make sure freq is not to high.
	bicne r0,#0xF8000000		;@ Clear channel X index
	str r0,[r2,#pcm0CurrentAddr]
	bx lr
;@----------------------------------------------------------------------------
_0805W:						;@ Channel Balance
;@----------------------------------------------------------------------------
	ldrb r1,[psgptr,#psgChannel]
	add r2,psgptr,r1,lsl#2
	strb r0,[r2,#ch0Balance]
	bx lr
;@----------------------------------------------------------------------------
_0806W:						;@ Waveform Data
;@----------------------------------------------------------------------------
	ldrb r1,[psgptr,#psgChannel]
	add r2,psgptr,r1,lsl#2
	ldrb r2,[r2,#ch0Control]
	tst r2,#0x40				;@ Lock index?
	mov r2,#pcm0CurrentAddr+3
	add r2,r2,r1,lsl#2
	add r1,psgptr,r1,lsl#5
	ldrb r2,[psgptr,r2]!		;@ Get channel X index
	add r1,r1,r2,lsr#3
	and r0,r0,#0x1f
	sub r0,r0,#0x10
	strb r0,[r1,#ch0Waveform]
	addeq r2,r2,#0x08
	strb r2,[psgptr]			;@ Write back channel X index
	bx lr
;@----------------------------------------------------------------------------
_0807W:						;@ Noise enable and frequency
;@----------------------------------------------------------------------------
	ldrb r1,[psgptr,#psgChannel]
	cmp r1,#5
	beq noise5W
	cmp r1,#4
	bxne lr
;@----------------------------------------------------------------------------
noise4W:
;@----------------------------------------------------------------------------
	strb r0,[psgptr,#noiseCtrl4]

	ldrb r1,[psgptr,#noise4CurrentAddr]
	ands r2,r0,#0x80
	bic r1,r1,#0x80
	orr r1,r1,r2
	strb r1,[psgptr,#noise4CurrentAddr]
	rsb r0,r0,#0x1F

	ldr r2,[psgptr,#pcm4CurrentAddr]
	ldreq r1,[psgptr,#ch4Freq]
	mov r2,r2,lsr#12
	orreq r2,r2,r1,lsl#20
	orrne r2,r2,r0,lsl#27
	mov r2,r2,ror#20
	str r2,[psgptr,#pcm4CurrentAddr]

	bx lr
;@----------------------------------------------------------------------------
noise5W:
;@----------------------------------------------------------------------------
	strb r0,[psgptr,#noiseCtrl5]

	ldrb r1,[psgptr,#noise5CurrentAddr]
	ands r2,r0,#0x80
	bic r1,r1,#0x80
	orr r1,r1,r2
	strb r1,[psgptr,#noise5CurrentAddr]
	rsb r0,r0,#0x1F

	ldr r2,[psgptr,#pcm5CurrentAddr]
	ldreq r1,[psgptr,#ch5Freq]
	mov r2,r2,lsr#12
	orreq r2,r2,r1,lsl#20
	orrne r2,r2,r0,lsl#27
	mov r2,r2,ror#20
	str r2,[psgptr,#pcm5CurrentAddr]

	bx lr
;@----------------------------------------------------------------------------
_0808W:						;@ LFO frequency
;@----------------------------------------------------------------------------
	strb r0,[psgptr,#lfoFreq]
	bx lr
;@----------------------------------------------------------------------------
_0809W:						;@ LFO trigger and control
;@----------------------------------------------------------------------------
	strb r0,[psgptr,#lfoCtrl]
	bx lr
;@----------------------------------------------------------------------------

#endif // #ifdef __arm__
