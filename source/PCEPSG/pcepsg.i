;@ ASM header for the PC-Engine PSG emulator
;@

	psgptr			.req r12

							;@ pcepsg.s
	.struct 0					// changes section so make sure it's set before real code.
psgchannel:		.space 1		;@ Channel select
globalbalance:	.space 1		;@
noisectrl4:		.space 1		;@ Noise control ch4
noisectrl5:		.space 1		;@ Noise control ch5
lfofreq:		.space 1		;@ LFO frequency
lfoctrl:		.space 1		;@ LFO control
ch3change:		.space 1
				.space 1

ch0control:		.space 1
ch1control:		.space 1
ch2control:		.space 1
ch3control:		.space 1
ch4control:		.space 1
ch5control:		.space 1
ch6control:		.space 1		;@ Dummy
ch7control:		.space 1		;@ Dummy

ch0balance:		.space 1
ch1balance:		.space 1
ch2balance:		.space 1
ch3balance:		.space 1
ch4balance:		.space 1
ch5balance:		.space 1
ch6balance:		.space 1		;@ Dummy
ch7balance:		.space 1		;@ Dummy

ch0waveindx:	.space 1
ch1waveindx:	.space 1
ch2waveindx:	.space 1
ch3waveindx:	.space 1
ch4waveindx:	.space 1
ch5waveindx:	.space 1
ch6waveindx:	.space 1		;@ Dummy
ch7waveindx:	.space 1		;@ Dummy

ch0freq:		.space 4
ch1freq:		.space 4
ch2freq:		.space 4
ch3freq:		.space 4
ch4freq:		.space 4
ch5freq:		.space 4
ch6freq:		.space 4		;@ Dummy
ch7freq:		.space 4		;@ Dummy

pcm0currentaddr:	.space 4	;@ Current addr
pcm1currentaddr:	.space 4	;@ Current addr
pcm2currentaddr:	.space 4	;@ Current addr
pcm3currentaddr:	.space 4	;@ Current addr
pcm4currentaddr:	.space 4	;@ Current addr
pcm5currentaddr:	.space 4	;@ Current addr
noise4currentaddr:	.space 4	;@ Current addr
noise5currentaddr:	.space 4	;@ Current addr

ch0waveform:		.space 32
ch1waveform:		.space 32
ch2waveform:		.space 32
ch3waveform:		.space 32
ch4waveform:		.space 32
ch5waveform:		.space 32
ch6waveform:		.space 32	;@ Dummy
ch7waveform:		.space 32	;@ Dummy

pcePsgSize:

;@----------------------------------------------------------------------------

