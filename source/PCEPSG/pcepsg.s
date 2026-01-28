//
//  pcepsg.s
//  NitroGrafx PC-Engine PSG emulator
//
//  Created by Fredrik Ahlström on 2003-01-01.
//  Copyright © 2003-2026 Fredrik Ahlström. All rights reserved.
//
#ifdef __arm__

#include "pcepsg.i"

#define PSGDIVIDE 20*4
#define PSGADDITION 0x00004000*PSGDIVIDE
#define PSGNOISEFEED 0x8600C001
//#define PSGNOISEFEED 0xC0184001
//#define PSGNOISEFEED 0x00090001

	.global PCEPSGInit
	.global PCEPSGReset
	.global PCEPSGMixer
	.global PCEPSGWrite

	.syntax unified
	.arm

	.section .itcm, "ax", %progbits
	.align 2
;@----------------------------------------------------------------------------
;@ r0 = sample reg.
;@ r1 = volume.
;@ r2 = mixer reg.
;@ r3 -> r8 = pos+freq.
;@ r9,r10 = noise regs.
;@ r11 = length.
;@ r12 = PCE samplebuffers.
;@ r14 = mixerbuffer1.
;@ Waveforms should not be signed!!!
;@----------------------------------------------------------------------------
pcmMix:
// IIIIIVCCCCCCCCCCCC10FFFFFFFFFFFF
// I=sampleindex, V=overflow, C=counter, F=frequency
;@----------------------------------------------------------------------------
pcmMixLoop:
	add r3,r3,#PSGADDITION
	movs r0,r3,lsr#27
	mov r1,r3,lsl#18
	subcs r3,r3,r1,asr#4
vol0_L:
	mov r2,#0x00				;@ Volume left
vol0_R:
	orrs r1,r2,#0xFF0000		;@ Volume right
	ldrsbne r0,[r12,r0]			;@ Channel 0
	mulne r2,r1,r0

	add r4,r4,#PSGADDITION
	movs r0,r4,lsr#27
	add r0,r0,#0x20
	mov r1,r4,lsl#18
	subcs r4,r4,r1,asr#4
vol1_L:
	mov r1,#0x00				;@ Volume left
vol1_R:
	orrs r1,r1,#0xFF0000		;@ Volume right
	ldrsbne r0,[r12,r0]			;@ Channel 1
	mlane r2,r1,r0,r2


	add r5,r5,#PSGADDITION
	movs r0,r5,lsr#27
	add r0,r0,#0x40
	mov r1,r5,lsl#18
	subcs r5,r5,r1,asr#4
vol2_L:
	mov r1,#0x00				;@ Volume left
vol2_R:
	orrs r1,r1,#0xFF0000		;@ Volume right
	ldrsbne r0,[r12,r0]			;@ Channel 2
	mlane r2,r1,r0,r2


	add r6,r6,#PSGADDITION
	movs r0,r6,lsr#27
	add r0,r0,#0x60
	mov r1,r6,lsl#18
	subcs r6,r6,r1,asr#4
vol3_L:
	mov r1,#0x00				;@ Volume left
vol3_R:
	orrs r1,r1,#0xFF0000		;@ Volume right
	ldrsbne r0,[r12,r0]			;@ Channel 3
	mlane r2,r1,r0,r2


	add r7,r7,#PSGADDITION
	movs r0,r7,lsr#27
	add r0,r0,#0x80
	mov r1,r7,lsl#18
	subcs r7,r7,r1,asr#4

	movcs r1,r9,lsr#14
	addscs r9,r9,r1,lsl#14
	ldrcs r1,=PSGNOISEFEED
	eorcs r9,r9,r1
	tst r9,#0x80				;@ Noise 4 enabled?
	ldrsbeq r0,[r12,r0]			;@ Channel 4
	andsne r0,r9,#0x00000001
	movne r0,#0x1F

vol4_L:
	mov r1,#0x00				;@ Volume left
vol4_R:
	orrs r1,r1,#0xFF0000		;@ Volume right
	mlane r2,r1,r0,r2


	adds r8,r8,#PSGADDITION
	movs r0,r8,lsr#27
	add r0,r0,#0xA0
	mov r1,r8,lsl#18
	subcs r8,r8,r1,asr#4

	movcs r1,r10,lsr#14
	addscs r10,r10,r1,lsl#14
	ldrcs r1,=PSGNOISEFEED
	eorcs r10,r10,r1
	tst r10,#0x80				;@ Noise 5 enabled?
	ldrsbeq r0,[r12,r0]			;@ Channel 5
	andsne r0,r10,#0x00000001
	movne r0,#0x1F

vol5_L:
	mov r1,#0x00				;@ Volume left
vol5_R:
	orrs r1,r1,#0xFF0000		;@ Volume right
	mlane r2,r1,r0,r2


	subs r11,r11,#1
	strpl r2,[lr],#4
	bhi pcmMixLoop				;@ 91 cycles according to No$gba

	b pcmMixReturn
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
	mov r0,#0x80000000
	str r0,[psgptr,#noise4CurrentAddr]
	str r0,[psgptr,#noise5CurrentAddr]
	bx lr

;@----------------------------------------------------------------------------
PCEPSGMixer:				;@ r0=len, r1=dest, r12=psgptr
;@----------------------------------------------------------------------------
	stmfd sp!,{r0,r1,r4-r11,lr}
;@--------------------------
	ldr r10,=vol0_L

	ldrb r2,[psgptr,#globalBalance]
	adr r3,attenuation
	mov r2,r2,ror#4

	ldrb r0,[psgptr,#ch0Control]
	ldrb r1,[psgptr,#ch0Balance]
	bl getVolumeDS				;@ Volume in r0/r1, uses r0,r1 & r4.
	strb r0,[r10,#vol0_L-vol0_L]
	strb r1,[r10,#vol0_R-vol0_L]

	ldrb r0,[psgptr,#ch1Control]
	ldrb r1,[psgptr,#ch1Balance]
	bl getVolumeDS				;@ Volume in r0/r1, uses r0,r1 & r4.
	strb r0,[r10,#vol1_L-vol0_L]
	strb r1,[r10,#vol1_R-vol0_L]

	ldrb r0,[psgptr,#ch2Control]
	ldrb r1,[psgptr,#ch2Balance]
	bl getVolumeDS				;@ Volume in r0/r1, uses r0,r1 & r4.
	strb r0,[r10,#vol2_L-vol0_L]
	strb r1,[r10,#vol2_R-vol0_L]

	ldrb r0,[psgptr,#ch3Control]
	ldrb r1,[psgptr,#ch3Balance]
	bl getVolumeDS				;@ Volume in r0/r1, uses r0,r1 & r4.
	strb r0,[r10,#vol3_L-vol0_L]
	strb r1,[r10,#vol3_R-vol0_L]

	ldrb r0,[psgptr,#ch4Control]
	ldrb r1,[psgptr,#ch4Balance]
	bl getVolumeDS				;@ Volume in r0/r1, uses r0,r1 & r4.
	strb r0,[r10,#vol4_L-vol0_L]
	strb r1,[r10,#vol4_R-vol0_L]

	ldrb r0,[psgptr,#ch5Control]
	ldrb r1,[psgptr,#ch5Balance]
	bl getVolumeDS				;@ Volume in r0/r1, uses r0,r1 & r4.
	strb r0,[r10,#vol5_L-vol0_L]
	strb r1,[r10,#vol5_R-vol0_L]

	add r0,psgptr,#pcm0CurrentAddr
	ldmia r0,{r3-r10}
;@--------------------------
	ldrh r1,[psgptr,#ch0Freq]
	mov r3,r3,lsr#12
	orr r3,r1,r3,lsl#12
;@--------------------------
	ldrh r1,[psgptr,#ch1Freq]
	mov r4,r4,lsr#12
	orr r4,r1,r4,lsl#12
;@--------------------------
	ldrh r1,[psgptr,#ch2Freq]
	mov r5,r5,lsr#12
	orr r5,r1,r5,lsl#12
;@--------------------------
	ldrh r1,[psgptr,#ch3Freq]
	mov r6,r6,lsr#12
	orr r6,r1,r6,lsl#12
;@--------------------------
	ldrb r2,[psgptr,#noiseCtrl4]
	ands r0,r2,#0x80
	bic r9,r9,#0x80
	orr r9,r9,r0
	and r0,r2,#0x1F
	rsb r0,r0,#0x1F

	ldrh r1,[psgptr,#ch4Freq]
	mov r7,r7,lsr#12
	orreq r7,r1,r7,lsl#12
	orrne r7,r7,r0,ror#5
	movne r7,r7,ror#20
;@--------------------------
	ldrb r2,[psgptr,#noiseCtrl5]
	ands r0,r2,#0x80
	bic r10,r10,#0x80
	orr r10,r10,r0
	and r0,r2,#0x1F
	rsb r0,r0,#0x1F

	ldrh r1,[psgptr,#ch5Freq]
	mov r8,r8,lsr#12
	orreq r8,r1,r8,lsl#12
	orrne r8,r8,r0,ror#5
	movne r8,r8,ror#20
;@--------------------------

	add psgptr,psgptr,#ch0Waveform	;@ r12 = PCE wavebuffer
	ldmfd sp,{r11,lr}			;@ r11=len, lr=dest buffer
;@	mov r11,r11					;@ no$gba break
	b pcmMix
pcmMixReturn:
;@	mov r11,r11					;@ no$gba break
	sub psgptr,psgptr,#ch0Waveform	;@ Get correct psgptr
	add r0,psgptr,#pcm0CurrentAddr	;@ Counters
	stmia r0,{r3-r10}			;@ Write back counters

	ldmfd sp!,{r0,r1,r4-r11,pc}
;@----------------------------------------------------------------------------
getVolumeDS:				;@ r0=chCtrl,r1=chBalance,r2=globalBalance
;@----------------------------------------------------------------------------
	and r4,r0,#0xC0
	cmp r4,#0x80				;@ Should channel be played?

	movne r0,#0
	and r0,r0,#0x1F				;@ Channel master

	and r4,r1,#0xF				;@ Channel right
	add r4,r0,r4,lsl#1
	add r4,r4,r2,lsr#28-1		;@ Global right

	mov r1,r1,lsr#4				;@ Channel left
	add r0,r0,r1,lsl#1
	and r1,r2,#0xF				;@ Global left
	add r0,r0,r1,lsl#1

	ldr r0,[r3,r0,lsl#2]
	ldr r1,[r3,r4,lsl#2]
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
	bx lr
;@----------------------------------------------------------------------------
_0802W:						;@ Frequency byte 0
;@----------------------------------------------------------------------------
	ldrb r1,[psgptr,#psgChannel]
	add r2,psgptr,#ch0Freq
	strb r0,[r2,r1,lsl#1]
	bx lr
;@----------------------------------------------------------------------------
_0803W:						;@ Frequency byte 1
;@----------------------------------------------------------------------------
	and r0,r0,#0xF
	ldrb r1,[psgptr,#psgChannel]
	add r2,psgptr,#ch0Freq+1
	strb r0,[r2,r1,lsl#1]
	bx lr
;@----------------------------------------------------------------------------
_0804W:						;@ Channel Enable, DDA & Volume
;@----------------------------------------------------------------------------
	ldrb r1,[psgptr,#psgChannel]
	add r2,psgptr,r1
	strb r0,[r2,#ch0Control]
	tst r0,#0x40
	mov r0,#0
	strbne r0,[r2,#ch0WaveIndx]
	bx lr
;@----------------------------------------------------------------------------
_0805W:						;@ Channel Balance
;@----------------------------------------------------------------------------
	ldrb r1,[psgptr,#psgChannel]
	add r2,psgptr,#ch0Balance
	strb r0,[r2,r1]
	bx lr
;@----------------------------------------------------------------------------
_0806W:						;@ Waveform Data
;@----------------------------------------------------------------------------
	ldrb r1,[psgptr,#psgChannel]
	add r2,r1,#ch0WaveIndx
	add r1,psgptr,r1,lsl#5
	ldrb r2,[psgptr,r2]!		;@ Get channel X index
	add r1,r1,r2,lsr#3
	and r0,r0,#0x1f
	sub r0,r0,#0x10
	strb r0,[r1,#ch0Waveform]
	add r2,r2,#8
	strb r2,[psgptr]			;@ Write back channel X index
	bx lr
;@----------------------------------------------------------------------------
_0807W:						;@ Noise enable and frequency
;@----------------------------------------------------------------------------
	ldrb r1,[psgptr,#psgChannel]
	cmp r1,#4
	strbeq r0,[psgptr,#noiseCtrl4]
	cmp r1,#5
	strbeq r0,[psgptr,#noiseCtrl5]
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
