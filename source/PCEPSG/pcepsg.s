#ifdef __arm__
#include "pcepsg.i"

#define PSGDIVIDE 20*4
#define PSGADDITION 0x00004000*PSGDIVIDE
#define PSGNOISEFEED 0x8600C001
//#define PSGNOISEFEED 0xC0184001
//#define PSGNOISEFEED 0x00090001

	.global PCEPSGReset
	.global PCEPSGMixer
	.global PCEPSGWrite

	.syntax unified
	.arm

	.section .itcm
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
;@----------------------------------------------------------------------------
pcmMix:
//IIIIIVCCCCCCCCCCCC10FFFFFFFFFFFF
//I=sampleindex, V=overflow, C=counter, F=frequency
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
PCEPSGReset:				;@ psgptr=r12=pointer to struct
;@----------------------------------------------------------------------------
	mov r1,#0
	mov r0,#(pcePsgSize/4)-1	;@ Don't clear freqptr
rLoop:
	subs r0,r0,#1
	strpl r1,[psgptr,r0,lsl#2]
	bhi rLoop

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

	ldrb r1,[psgptr,#ch0Balance]
	ldrb r0,[psgptr,#ch0Control]
	bl getVolumeDS				;@ Volume in r1/r2, uses r0,r3&r4.
	strb r1,[r10],#vol0_R-vol0_L
	strb r2,[r10],#vol1_L-vol0_R

	ldrb r1,[psgptr,#ch1Balance]
	ldrb r0,[psgptr,#ch1Control]
	bl getVolumeDS				;@ Volume in r1/r2, uses r0,r3&r4.
	strb r1,[r10],#vol1_R-vol1_L
	strb r2,[r10],#vol2_L-vol1_R

	ldrb r1,[psgptr,#ch2Balance]
	ldrb r0,[psgptr,#ch2Control]
	bl getVolumeDS				;@ Volume in r1/r2, uses r0,r3&r4.
	strb r1,[r10],#vol2_R-vol2_L
	strb r2,[r10],#vol3_L-vol2_R

	ldrb r1,[psgptr,#ch3Balance]
	ldrb r0,[psgptr,#ch3Control]
	bl getVolumeDS				;@ Volume in r1/r2, uses r0,r3&r4.
	strb r1,[r10],#vol3_R-vol3_L
	strb r2,[r10],#vol4_L-vol3_R

	ldrb r1,[psgptr,#ch4Balance]
	ldrb r0,[psgptr,#ch4Control]
	bl getVolumeDS				;@ Volume in r1/r2, uses r0,r3&r4.
	strb r1,[r10],#vol4_R-vol4_L
	strb r2,[r10],#vol5_L-vol4_R

	ldrb r1,[psgptr,#ch5Balance]
	ldrb r0,[psgptr,#ch5Control]
	bl getVolumeDS				;@ Volume in r1/r2, uses r0,r3&r4.
	strb r1,[r10],#vol5_R-vol5_L
	strb r2,[r10]

	add r0,psgptr,#ch0Freq		;@ Original freq
	ldmia r0,{r3-r8}
;@--------------------------
	ldrh r1,[psgptr,#pcm0CurrentAddr]
	and r1,r1,#0xF000
	orr r1,r1,r3
	strh r1,[psgptr,#pcm0CurrentAddr]
;@--------------------------
	ldrh r1,[psgptr,#pcm1CurrentAddr]
	and r1,r1,#0xF000
	orr r1,r1,r4
	strh r1,[psgptr,#pcm1CurrentAddr]
;@--------------------------
	ldrh r1,[psgptr,#pcm2CurrentAddr]
	and r1,r1,#0xF000
	orr r1,r1,r5
	strh r1,[psgptr,#pcm2CurrentAddr]
;@--------------------------
	ldrh r1,[psgptr,#pcm3CurrentAddr]
	and r1,r1,#0xF000
	orr r1,r1,r6
	strh r1,[psgptr,#pcm3CurrentAddr]
;@--------------------------
	ldrb r9,[psgptr,#noiseCtrl4]
	ands r0,r9,#0x80
	ldrb r1,[psgptr,#noise4CurrentAddr]
	and r1,r1,#0x01
	orr r1,r1,r0
	strb r1,[psgptr,#noise4CurrentAddr]
	and r0,r9,#0x1F
	rsb r0,r0,#0x1F

	ldrh r1,[psgptr,#pcm4CurrentAddr]
	and r1,r1,#0xF000
	orreq r1,r1,r7
	orrne r1,r1,r0,lsl#7
	strh r1,[psgptr,#pcm4CurrentAddr]
;@--------------------------
	ldrb r9,[psgptr,#noiseCtrl5]
	ands r0,r9,#0x80
	ldrb r1,[psgptr,#noise5CurrentAddr]
	and r1,r1,#0x01
	orr r1,r1,r0
	strb r1,[psgptr,#noise5CurrentAddr]
	and r0,r9,#0x1F
	rsb r0,r0,#0x1F

	ldrh r1,[psgptr,#pcm5CurrentAddr]
	and r1,r1,#0xF000
	orreq r1,r1,r8
	orrne r1,r1,r0,lsl#7
	strh r1,[psgptr,#pcm5CurrentAddr]
;@--------------------------

	add r0,psgptr,#pcm0CurrentAddr
	ldmia r0,{r3-r10}

	add psgptr,psgptr,#ch0Waveform	;@ r12 = PCE wavebuffer
	ldmfd sp,{r11,lr}			;@ r11=len, lr=dest buffer
;@	mov r11,r11					;@ no$gba break
	b pcmMix
pcmMixReturn:
;@	mov r11,r11					;@ no$gba break
	sub psgptr,psgptr,#ch0Waveform	;@ Get correct psgptr
	add r0,psgptr,#pcm0CurrentAddr	;@ Counters
	stmia r0,{r3-r10}

	ldmfd sp!,{r0,r1,r4-r11,pc}
;@----------------------------------------------------------------------------
getVolumeDS:
	and r2,r0,#0xc0
	cmp r2,#0x80				;@ Should channel be played?

	and r0,r0,#0x1f				;@ Channel master
;@	mov r3,#103					;@ Maybe boost?
	mov r3,#126					;@ Boost.
	movne r3,#0
	mul r0,r3,r0
	ldrb r3,[psgptr,#globalBalance]

	and r2,r1,#0xf				;@ Channel right
	and r4,r3,#0xf				;@ Main right
	mul r2,r4,r2
	mul r2,r0,r2

	mov r1,r1,lsr#4				;@ Channel left
	mov r3,r3,lsr#4				;@ Main left
	mul r4,r3,r1
	mul r1,r0,r4

	mov r1,r1,lsr#12			;@ 0 <= r1 <= 0xAF
	mov r2,r2,lsr#12			;@ 0 <= r2 <= 0xAF
	bx lr
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
	strb r0,[r2,r1,lsl#2]
	bx lr
;@----------------------------------------------------------------------------
_0803W:						;@ Frequency byte 1
;@----------------------------------------------------------------------------
	and r0,r0,#0xF
	orr r0,r0,#0x20
	ldrb r1,[psgptr,#psgChannel]
	add r2,psgptr,#ch0Freq+1
	strb r0,[r2,r1,lsl#2]
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
