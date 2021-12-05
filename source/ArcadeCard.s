#ifdef __arm__

#include "ARMH6280/H6280.i"
#include "ArcadeCard.i"

	.global arcadeReset
	.global ARCADE_R
	.global ARCADE_W
	.global AC00_R
	.global AC10_R
	.global AC20_R
	.global AC30_R
	.global AC00_W
	.global AC10_W
	.global AC20_W
	.global AC30_W
	.global ac_port0


	.syntax unified
	.arm

	.section .text
	.align 2
;@----------------------------------------------------------------------------
arcadeReset:
;@----------------------------------------------------------------------------
	ldr r0,=acPort0
	mov r1,#0
	mov r2,#acPortSize+2
	b memset_

;@	Fix Page $40-$43
;@----------------------------------------------------------------------------
ARCADE_R:					;@ 0x1A00-0x1A3F
;@----------------------------------------------------------------------------
;@	mov r11,r11					;@ No$GBA debugg
	tst addy,#0x05C0
	and r0,addy,#0x0F
	ldreq pc,[pc,r0,lsl#2]
	b AC_Read2
;@---------------------------------------
	.long ACx0_R				;@ Memory Read
	.long ACx0_R				;@ Memory Read
	.long AC02_R				;@ Base Address 0-7
	.long AC03_R				;@ Base Address 8-15
	.long AC04_R				;@ Base Address 16-23
	.long AC05_R				;@ Offset Address 0-7
	.long AC06_R				;@ Offset Address 8-15
	.long AC07_R				;@ Address increment 0-7
	.long AC08_R				;@ Address increment 8-15
	.long AC09_R				;@ Control
	.long AC0A_R				;@ Trigger, returns 0
	.long emptyRead				;@
	.long emptyRead				;@
	.long emptyRead				;@
	.long emptyRead				;@
	.long emptyRead				;@
;@----------------------------------------------------------------------------
AC_Read2:					;@ 0x1AE0-0x1AFF
;@----------------------------------------------------------------------------
	and r0,addy,#0x0FE0
	cmp r0,#0x0AE0
	and r0,addy,#0x1F
	ldreq pc,[pc,r0,lsl#2]
	b emptyRead
;@---------------------------------------
	.long ACE0_R				;@ Shift Register 0
	.long ACE1_R				;@ Shift Register 1
	.long ACE2_R				;@ Shift Register 2
	.long ACE3_R				;@ Shift Register 3
	.long ACE4_R				;@ Shift Amount
	.long ACE5_R				;@ Rotate Amount
	.long emptyRead				;@
	.long emptyRead				;@
	.long emptyRead				;@
	.long emptyRead				;@
	.long emptyRead				;@
	.long emptyRead				;@
	.long emptyRead				;@
	.long emptyRead				;@
	.long emptyRead				;@
	.long emptyRead				;@
	.long emptyRead				;@
	.long emptyRead				;@
	.long emptyRead				;@
	.long emptyRead				;@
	.long emptyRead				;@
	.long emptyRead				;@
	.long emptyRead				;@
	.long emptyRead				;@
	.long emptyRead				;@
	.long emptyRead				;@
	.long emptyRead				;@
	.long emptyRead				;@ 
	.long ACFC_R				;@ Unknown 
	.long ACFD_R				;@ Unknown
	.long ACFE_R				;@ Version?
	.long ACFF_R				;@ Arcade Card Check

;@----------------------------------------------------------------------------
ARCADE_W:					;@ 0x1A00-0x1A3F
;@----------------------------------------------------------------------------
;@	mov r11,r11					;@ No$GBA debugg
	tst addy,#0x05C0
	and r1,addy,#0x0F
	ldreq pc,[pc,r1,lsl#2]
	b AC_Write2
;@---------------------------
ac_write_tbl:
	.long ACx0_W				;@ Memory Write
	.long ACx0_W				;@ Memory Write
	.long AC02_W				;@ Base Address 0-7
	.long AC03_W				;@ Base Address 8-15
	.long AC04_W				;@ Base Address 16-23
	.long AC05_W				;@ Offset Address 0-7
	.long AC06_W				;@ Offset Address 8-15
	.long AC07_W				;@ Address increment 0-7
	.long AC08_W				;@ Address increment 8-15
	.long AC09_W				;@ Control
	.long AC0A_W				;@ Offset addition
	.long emptyWrite			;@
	.long emptyWrite			;@
	.long emptyWrite			;@
	.long emptyWrite			;@
	.long emptyWrite			;@

;@----------------------------------------------------------------------------
AC_Write2:					;@ 0x1AE0-0x1AE5
;@----------------------------------------------------------------------------
	and r2,addy,#0x0FF0
	cmp r2,#0x0AE0
	ldreq pc,[pc,r1,lsl#2]
	b emptyWrite
;@---------------------------------------
	.long ACE0_W				;@ Shift Register 0
	.long ACE1_W				;@ Shift Register 1
	.long ACE2_W				;@ Shift Register 2
	.long ACE3_W				;@ Shift Register 3
	.long ACE4_W				;@ Shift Amount
	.long ACE5_W				;@ Rotate Amount
	.long emptyWrite			;@
	.long emptyWrite			;@
	.long emptyWrite			;@
	.long emptyWrite			;@
	.long emptyWrite			;@
	.long emptyWrite			;@
	.long emptyWrite			;@
	.long emptyWrite			;@
	.long emptyWrite			;@
	.long emptyWrite			;@

;@----------------------------------------------------------------------------
AC00_R:
;@----------------------------------------------------------------------------
	ldr acptr,=acPort0
	ldrb r1,[acptr,#acControl]	;@ Control
	and r1,r1,#0x1F
	ldr pc,[pc,r1,lsl#2]
	b emptyRead
;@---------------------------------------
acCtrlTblR:
	.long ac00_xr				;@ Default AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_0x03r			;@ AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_0x11r			;@ AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_0x13r			;@ AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_xr				;@ Default AC data read
	.long ac00_xr				;@ Default AC data read

;@----------------------------------------------------------------------------
AC10_R:
;@----------------------------------------------------------------------------
	ldr acptr,=acPort1
	ldrb r1,[acptr,#acControl]	;@ Control
	and r1,r1,#0x1F
	adr r2,acCtrlTblR
	ldr pc,[r2,r1,lsl#2]
;@----------------------------------------------------------------------------
AC20_R:
;@----------------------------------------------------------------------------
	ldr acptr,=acPort2
	ldrb r1,[acptr,#acControl]	;@ Control
	and r1,r1,#0x1F
	adr r2,acCtrlTblR
	ldr pc,[r2,r1,lsl#2]
;@----------------------------------------------------------------------------
AC30_R:
;@----------------------------------------------------------------------------
	ldr acptr,=acPort3
	ldrb r1,[acptr,#acControl]	;@ Control
	and r1,r1,#0x1F
	adr r2,acCtrlTblR
	ldr pc,[r2,r1,lsl#2]
;@----------------------------------------------------------------------------
ACx0_R:
;@----------------------------------------------------------------------------
	and r2,addy,#0x30
	ldr acptr,=acPort0
	add acptr,acptr,r2
	ldrb r1,[acptr,#acControl]	;@ Control
	and r1,r1,#0x1F
	adr r2,acCtrlTblR
	ldr pc,[r2,r1,lsl#2]
ac00_xr:
	ldr r2,[acptr,#acBase]		;@ addy=base
	ands r0,r1,#0x02			;@ Should we use offset?
	ldrne r0,[acptr,#acOffset]	;@ Offset
	tst r1,#0x08				;@ Is Offset signed or not?
	addeq r2,r2,r0,lsr#8
	addne r2,r2,r0,asr#8
	ldr r0,=ACC_RAM
	bic r2,r2,#0xE0000000
	ldrb r0,[r0,r2,lsr#8]

	tst r1,#0x01				;@ Should we increment?
	bxeq lr

	ldr r2,[acptr,#acIncrement]	;@ Increment

	tst r1,#0x04				;@ Is increment signed or not?
	moveq r2,r2,lsr#8
	movne r2,r2,asr#8

	tst r1,#0x10				;@ Should we increment base or offset?
	ldrne r1,[acptr,#acBase]!
	ldreq r1,[acptr,#acOffset]!
	addne r1,r1,r2
	addeq r1,r1,r2,lsl#8
	str r1,[acptr]
	bx lr
;@----------------------------------------------------------------------------
ac00_0x03r:
;@----------------------------------------------------------------------------
	ldmfd acptr,{r0-r2}			;@ Base, Offset & Increment
	add r2,r1,r2				;@ Offset + Increment to r2
	str r2,[acptr,#acOffset]
	ldr r2,=ACC_RAM
	add r1,r0,r1,lsr#8			;@ Use base + offset
	bic r1,r1,#0xE0000000
	ldrb r0,[r2,r1,lsr#8]
	bx lr
;@----------------------------------------------------------------------------
ac00_0x11r:
;@----------------------------------------------------------------------------
	ldr r0,[acptr,#acBase]		;@ Base
	ldr r1,[acptr,#acIncrement]	;@ Increment
	add r2,r0,r1,lsr#8
	str r2,[acptr,#acBase]
	ldr r2,=ACC_RAM
	bic r1,r0,#0xE0000000
	ldrb r0,[r2,r1,lsr#8]
	bx lr
;@----------------------------------------------------------------------------
ac00_0x13r:
;@----------------------------------------------------------------------------
	ldmfd acptr,{r0-r2}			;@ Base, Offset & Increment
	add r2,r0,r2,lsr#8			;@ Base + Increment to r2
	str r2,[acptr,#acBase]
	ldr r2,=ACC_RAM
	add r1,r0,r1,lsr#8			;@ Use base + offset
	bic r1,r1,#0xE0000000
	ldrb r0,[r2,r1,lsr#8]
	bx lr

;@----------------------------------------------------------------------------
AC02_R:						;@ Base Address
;@----------------------------------------------------------------------------
	ldr r1,=acPort0+acBase+1
	and r2,addy,#0x30
	ldrb r0,[r1,r2]
	bx lr
;@----------------------------------------------------------------------------
AC03_R:						;@ Base Address
;@----------------------------------------------------------------------------
	ldr r1,=acPort0+acBase+2
	and r2,addy,#0x30
	ldrb r0,[r1,r2]
	bx lr
;@----------------------------------------------------------------------------
AC04_R:						;@ Base Address
;@----------------------------------------------------------------------------
	ldr r1,=acPort0+acBase+3
	and r2,addy,#0x30
	ldrb r0,[r1,r2]
	bx lr
;@----------------------------------------------------------------------------
AC05_R:						;@ Offset Address
;@----------------------------------------------------------------------------
	ldr r1,=acPort0+acOffset+2
	and r2,addy,#0x30
	ldrb r0,[r1,r2]
	bx lr
;@----------------------------------------------------------------------------
AC06_R:						;@ Offset Address
;@----------------------------------------------------------------------------
	ldr r1,=acPort0+acOffset+3
	and r2,addy,#0x30
	ldrb r0,[r1,r2]
	bx lr
;@----------------------------------------------------------------------------
AC07_R:						;@ Address Increment
;@----------------------------------------------------------------------------
	ldr r1,=acPort0+acIncrement+2
	and r2,addy,#0x30
	ldrb r0,[r1,r2]
	bx lr
;@----------------------------------------------------------------------------
AC08_R:						;@ Address Increment
;@----------------------------------------------------------------------------
	ldr r1,=acPort0+acIncrement+3
	and r2,addy,#0x30
	ldrb r0,[r1,r2]
	bx lr
;@----------------------------------------------------------------------------
AC09_R:						;@ Control
;@----------------------------------------------------------------------------
	ldr r1,=acPort0+acControl
	and r2,addy,#0x30
	ldrb r0,[r1,r2]
	bx lr
;@----------------------------------------------------------------------------
AC0A_R:						;@ Offset Trigger (allways return 0 on read)
;@----------------------------------------------------------------------------
	mov r0,#0
	bx lr


;@----------------------------------------------------------------------------
ACE0_R:						;@ Shift register 0
;@----------------------------------------------------------------------------
	ldrb r0,acShiftReg
	bx lr
;@----------------------------------------------------------------------------
ACE1_R:						;@ Shift register 1
;@----------------------------------------------------------------------------
	ldrb r0,acShiftReg+1
	bx lr
;@----------------------------------------------------------------------------
ACE2_R:						;@ Shift register 2
;@----------------------------------------------------------------------------
	ldrb r0,acShiftReg+2
	bx lr
;@----------------------------------------------------------------------------
ACE3_R:						;@ Shift register 3
;@----------------------------------------------------------------------------
	ldrb r0,acShiftReg+3
	bx lr
;@----------------------------------------------------------------------------
ACE4_R:						;@ Shift amount
;@----------------------------------------------------------------------------
	ldrb r0,acShiftBits
	bx lr

;@----------------------------------------------------------------------------
ACE5_R:						;@ Rotate amount
;@----------------------------------------------------------------------------
	ldrb r0,acRotateBits
	bx lr
;@----------------------------------------------------------------------------
ACFC_R:						;@ Unknown, returns 0x00 on my ACC for SCD2
;@----------------------------------------------------------------------------
	mov r0,#0x00
	bx lr
;@----------------------------------------------------------------------------
ACFD_R:						;@ Unknown, returns 0x00 on my ACC for SCD2
;@----------------------------------------------------------------------------
	mov r0,#0x00
	bx lr
;@----------------------------------------------------------------------------
ACFE_R:						;@ Unknown, returns 0x10 on my ACC for SCD2
;@----------------------------------------------------------------------------
	mov r0,#0x10
	bx lr
;@----------------------------------------------------------------------------
ACFF_R:						;@ Arcade Card check
;@----------------------------------------------------------------------------
	mov r0,#0x51
	bx lr



;@----------------------------------------------------------------------------
AC00_W:
;@----------------------------------------------------------------------------
	adr acptr,acPort0
	ldrb r1,[acptr,#acControl]	;@ Control
	and r1,r1,#0x1F
	ldr pc,[pc,r1,lsl#2]
	b emptyWrite
;@---------------------------------------
acCtrlTblW:
	.long ac00_xw				;@ Default AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_0x03w			;@ AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_0x11w			;@ AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_0x13w			;@ AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_xw				;@ Default AC data write
	.long ac00_xw				;@ Default AC data write

;@----------------------------------------------------------------------------
AC10_W:
;@----------------------------------------------------------------------------
	adr acptr,acPort1
	ldrb r1,[acptr,#acControl]	;@ Control
	and r1,r1,#0x1F
	adr r2,acCtrlTblW
	ldr pc,[r2,r1,lsl#2]
;@----------------------------------------------------------------------------
AC20_W:
;@----------------------------------------------------------------------------
	adr acptr,acPort2
	ldrb r1,[acptr,#acControl]	;@ Control
	and r1,r1,#0x1F
	adr r2,acCtrlTblW
	ldr pc,[r2,r1,lsl#2]
;@----------------------------------------------------------------------------
AC30_W:
;@----------------------------------------------------------------------------
	adr acptr,acPort3
	ldrb r1,[acptr,#acControl]	;@ Control
	and r1,r1,#0x1F
	adr r2,acCtrlTblW
	ldr pc,[r2,r1,lsl#2]
;@----------------------------------------------------------------------------
ACx0_W:
;@----------------------------------------------------------------------------
	and r2,addy,#0x30
	adr acptr,acPort0
	add acptr,acptr,r2
	ldrb r1,[acptr,#acControl]	;@ Control
	and r1,r1,#0x1F
	adr r2,acCtrlTblW
	ldr pc,[r2,r1,lsl#2]
ac00_xw:
	and r0,r0,#0xFF
	ldr r2,[acptr,#acBase]		;@ Base
	orr r0,r0,r1,lsl#24
	ands r1,r1,#0x02			;@ Should we use offset?
	ldrne r1,[acptr,#acOffset]	;@ Offset
	tst r0,#0x08000000			;@ Is Offset signed or not?
	addeq r2,r2,r1,lsr#8
	addne r2,r2,r1,asr#8
	bic r2,r2,#0xE0000000
	ldr r1,=ACC_RAM
	strb r0,[r1,r2,lsr#8]

	tst r0,#0x01000000			;@ Should we Increment?
	bxeq lr

	ldr r1,[acptr,#acIncrement]	;@ Increment

	tst r0,#0x04000000			;@ Is Increment signed or not?
	moveq r1,r1,lsr#8
	movne r1,r1,asr#8
	tst r0,#0x10000000			;@ Should we increment base or offset?
	ldrne r2,[acptr,#acBase]!
	ldreq r2,[acptr,#acOffset]!
	addne r2,r2,r1
	addeq r2,r2,r1,lsl#8
	str r2,[acptr]
	bx lr
;@----------------------------------------------------------------------------
ac00_0x03w:
;@----------------------------------------------------------------------------
	ldr r1,[acptr,#acOffset]
	ldr r2,[acptr,#acIncrement]
	add r2,r1,r2				;@ Offset + Increment to r2
	str r2,[acptr,#acOffset]
	ldr r2,[acptr,#acBase]
	add r2,r2,r1,lsr#8			;@ Use base + offset
	ldr r1,=ACC_RAM
	bic r2,r2,#0xE0000000
	strb r0,[r1,r2,lsr#8]
	bx lr
;@----------------------------------------------------------------------------
ac00_0x11w:
;@----------------------------------------------------------------------------
	ldr r2,[acptr,#acBase]
	ldr r1,[acptr,#acIncrement]	;@ Increment
	add r1,r2,r1,lsr#8
	str r1,[acptr,#acBase]
	ldr r1,=ACC_RAM
	bic r2,r2,#0xE0000000
	strb r0,[r1,r2,lsr#8]
	bx lr
;@----------------------------------------------------------------------------
ac00_0x13w:
;@----------------------------------------------------------------------------
	ldr r2,[acptr,#acBase]
	ldr r1,[acptr,#acIncrement]
	add r1,r2,r1,lsr#8			;@ Base + Increment to r1
	str r1,[acptr,#acBase]
	ldr r1,[acptr,#acOffset]
	add r2,r2,r1,lsr#8			;@ Use base + offset
	ldr r1,=ACC_RAM
	bic r2,r2,#0xE0000000
	strb r0,[r1,r2,lsr#8]
	bx lr
;@----------------------------------------------------------------------------
AC02_W:						;@ Base Address
;@----------------------------------------------------------------------------
	ldr r1,=acPort0+acBase+1
	and r2,addy,#0x30
	strb r0,[r1,r2]
	bx lr
;@----------------------------------------------------------------------------
AC03_W:						;@ Base Address
;@----------------------------------------------------------------------------
	ldr r1,=acPort0+acBase+2
	and r2,addy,#0x30
	strb r0,[r1,r2]
	bx lr
;@----------------------------------------------------------------------------
AC04_W:						;@ Base Address
;@----------------------------------------------------------------------------
	ldr r1,=acPort0+acBase+3
	and r2,addy,#0x30
	strb r0,[r1,r2]
	bx lr

;@----------------------------------------------------------------------------
AC05_W:						;@ Offset Address
;@----------------------------------------------------------------------------
	adr r1,acPort0
	and r2,addy,#0x30
	add r1,r1,r2
	strb r0,[r1,#acOffset+2]	;@ Offset+2

	ldrb r0,[r1,#acControl]		;@ Control
	and r2,r0,#0x60
	cmp r2,#0x20				;@ Offset trigger 5
	beq addOffsetToBase
	bx lr
;@----------------------------------------------------------------------------
AC06_W:						;@ Offset Address
;@----------------------------------------------------------------------------
	adr r1,acPort0
	and r2,addy,#0x30
	add r1,r1,r2
	strb r0,[r1,#acOffset+3]	;@ Offset+3

	ldrb r0,[r1,#acControl]		;@ Control
	and r2,r0,#0x60
	cmp r2,#0x40				;@ Offset trigger 6
	beq addOffsetToBase
	bx lr

;@----------------------------------------------------------------------------
AC07_W:						;@ Address Increment
;@----------------------------------------------------------------------------
	ldr r1,=acPort0+acIncrement+2
	and r2,addy,#0x30
	strb r0,[r1,r2]
	bx lr
;@----------------------------------------------------------------------------
AC08_W:						;@ Address Increment
;@----------------------------------------------------------------------------
	ldr r1,=acPort0+acIncrement+3
	and r2,addy,#0x30
	strb r0,[r1,r2]
	bx lr

;@----------------------------------------------------------------------------
AC09_W:						;@ Control
;@----------------------------------------------------------------------------
	adr r1,acPort0+acControl
	and r2,addy,#0x30
	strb r0,[r1,r2]
	bx lr
;@----------------------------------------------------------------------------
AC0A_W:						;@ Address Addition
;@----------------------------------------------------------------------------
	adr r1,acPort0
	and r2,addy,#0x30
	add r1,r1,r2
	ldrb r0,[r1,#acControl]		;@ Control
	and r2,r0,#0x60
	cmp r2,#0x60
	bxne lr

addOffsetToBase:
	tst r0,#0x08				;@ Treat as signed?
	ldr r0,[r1]					;@ Base
	ldr r2,[r1,#acOffset]		;@ Offset
	addeq r0,r0,r2,lsr#8
	addne r0,r0,r2,asr#8
	str r0,[r1]					;@ Base
	bx lr

;@----------------------------------------------------------------------------
ACE0_W:						;@ Shift register 0
;@----------------------------------------------------------------------------
	strb r0,acShiftReg
	bx lr
;@----------------------------------------------------------------------------
ACE1_W:						;@ Shift register 1
;@----------------------------------------------------------------------------
	strb r0,acShiftReg+1
	bx lr
;@----------------------------------------------------------------------------
ACE2_W:						;@ Shift register 2
;@----------------------------------------------------------------------------
	strb r0,acShiftReg+2
	bx lr
;@----------------------------------------------------------------------------
ACE3_W:						;@ Shift register 3
;@----------------------------------------------------------------------------
	strb r0,acShiftReg+3
	bx lr
;@----------------------------------------------------------------------------
ACE4_W:						;@ Shift amount
;@----------------------------------------------------------------------------
	and r0,r0,#0xF
	strb r0,acShiftBits
	ldr r1,acShiftReg
	tst r0,#8
	rsbne r0,r0,#16
	movne r1,r1,lsr r0
	moveq r1,r1,lsl r0
	str r1,acShiftReg
	bx lr
;@----------------------------------------------------------------------------
ACE5_W:						;@ Rotate amount
;@----------------------------------------------------------------------------
	and r0,r0,#0xF
	strb r0,acRotateBits
	ldr r1,acShiftReg
	tst r0,#8
	rsbeq r0,r0,#32
	rsbne r0,r0,#16
	mov r1,r1,ror r0
	str r1,acShiftReg
	bx lr

;@----------------------------------------------------------------------------
acPort0: .space acPortSize
acPort1: .space acPortSize
acPort2: .space acPortSize
acPort3: .space acPortSize

acShiftReg:
	.long 0						;@ Shift register
acShiftBits:
	.byte 0						;@ Shift amount
acRotateBits:
	.byte 0						;@ Rotate amount

	.byte 0,0

;@----------------------------------------------------------------------------
	.end
#endif // #ifdef __arm__
