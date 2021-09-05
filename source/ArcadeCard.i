;@ ASM header for the PC-Engine ArcadeCard emulator
;@

	acptr			.req r12

							;@ arcadecard.s
	.struct 0					// changes section so make sure it's set before real code.
acBase:			.space 4
acOffset:		.space 4
acIncrement:	.space 4
acControl:		.space 4

acPortSize:

;@----------------------------------------------------------------------------

