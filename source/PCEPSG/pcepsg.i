;@ ASM header for the PC-Engine PSG emulator
;@

	psgptr			.req r12

							;@ pcepsg.s
	.struct 0					// Changes section so make sure it's set before real code.
psgChannel:		.byte 0			;@ Channel select
globalBalance:	.byte 0			;@
noiseCtrl4:		.byte 0			;@ Noise control ch4
noiseCtrl5:		.byte 0			;@ Noise control ch5
lfoFreq:		.byte 0			;@ LFO frequency
lfoCtrl:		.byte 0			;@ LFO control
ch3Change:		.byte 0
				.space 1

ch0Control:		.byte 0
ch1Control:		.byte 0
ch2Control:		.byte 0
ch3Control:		.byte 0
ch4Control:		.byte 0
ch5Control:		.byte 0
ch6Control:		.byte 0			;@ Dummy
ch7Control:		.byte 0			;@ Dummy

ch0Balance:		.byte 0
ch1Balance:		.byte 0
ch2Balance:		.byte 0
ch3Balance:		.byte 0
ch4Balance:		.byte 0
ch5Balance:		.byte 0
ch6Balance:		.byte 0			;@ Dummy
ch7Balance:		.byte 0			;@ Dummy

ch0WaveIndx:	.byte 0
ch1WaveIndx:	.byte 0
ch2WaveIndx:	.byte 0
ch3WaveIndx:	.byte 0
ch4WaveIndx:	.byte 0
ch5WaveIndx:	.byte 0
ch6WaveIndx:	.byte 0			;@ Dummy
ch7WaveIndx:	.byte 0			;@ Dummy

ch0Freq:		.long 0
ch1Freq:		.long 0
ch2Freq:		.long 0
ch3Freq:		.long 0
ch4Freq:		.long 0
ch5Freq:		.long 0
ch6Freq:		.long 0			;@ Dummy
ch7Freq:		.long 0			;@ Dummy

pcm0CurrentAddr:	.long 0		;@ Current addr
pcm1CurrentAddr:	.long 0		;@ Current addr
pcm2CurrentAddr:	.long 0		;@ Current addr
pcm3CurrentAddr:	.long 0		;@ Current addr
pcm4CurrentAddr:	.long 0		;@ Current addr
pcm5CurrentAddr:	.long 0		;@ Current addr
noise4CurrentAddr:	.long 0		;@ Current addr
noise5CurrentAddr:	.long 0		;@ Current addr

ch0Waveform:		.space 32
ch1Waveform:		.space 32
ch2Waveform:		.space 32
ch3Waveform:		.space 32
ch4Waveform:		.space 32
ch5Waveform:		.space 32
ch6Waveform:		.space 32	;@ Dummy
ch7Waveform:		.space 32	;@ Dummy

pcePsgSize:

;@----------------------------------------------------------------------------

