//
//  cdrom.i
//  NitroGrafx PC-Engine CDROM emulator
//
//  Created by Fredrik Ahlström on 2026-09-02.
//  Copyright ©2026 Fredrik Ahlström. All rights reserved.
//
#if !__ASSEMBLER__
	#error This header file is only for use in assembly files!
#endif

							;@ cdrom.s
	.struct 0					// Changes section so make sure it's set before real code.
cdTOCMagic:		.space 8
cdTOCPadding0:	.space 4
cdTOCTrackCount:.byte 0
cdTOCPadding1:	.space 3
cdTOCTracks:
cdTOCSize:

	.struct 0
cdTrackMode:	.byte 0
cdTrackLBA0:	.byte 0
cdTrackLBA1:	.byte 0
cdTrackLBA2:	.byte 0
cdTrackstart:	.long 0
cdTrackSize:

;@----------------------------------------------------------------------------

