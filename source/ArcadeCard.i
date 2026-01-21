//
//  ArcadeCard.i
//  NitroGrafx PC-Engine ArcadeCard emulator
//
//  Created by Fredrik Ahlström on 2005-01-01.
//  Copyright © 2005-2026 Fredrik Ahlström. All rights reserved.
//
#if !__ASSEMBLER__
	#error This header file is only for use in assembly files!
#endif

	acptr			.req r12

							;@ arcadecard.s
	.struct 0					// changes section so make sure it's set before real code.
acBase:			.space 4
acOffset:		.space 4
acIncrement:	.space 4
acControl:		.space 4

acPortSize:

;@----------------------------------------------------------------------------

