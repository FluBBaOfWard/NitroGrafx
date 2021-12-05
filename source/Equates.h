
//-----------------------------------------------------------machine
#define HW_AUTO			0
#define HW_PCENGINE		1
#define HW_CDROM		2
#define HW_SCDROM		3
#define HW_SCD_ACDUO	4
#define HW_SGRAFIX		5
#define HW_CD_SCD		6
#define HW_CD_ACPRO		7
#define HW_TURBOGRAFX	7
#define HW_SGX_ACPRO	8
//-----------------------------------------------------------region
#define REGION_US		0
#define REGION_JAPAN	1
//-----------------------------------------------------------hwFlags
#define USCOUNTRY		0x01	// 0=JAP 1=US
#define CD_DEVICE		0x02	// 1=CDROM unit
#define SCD_DEVICE		0x04	// 1=Super CD unit
#define SCD_CARD		0x08	// 1=Super CD card
#define AC_CARD			0x10	// 1=Arcade card
#define SGX_DEVICE		0x40	// 1=Super Grafx unit


#define SCALED_1_1		0		// Display types
#define SCALED_FIT		1
#define SCALED_ASPECT	2
