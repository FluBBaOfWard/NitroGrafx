//
//  Sound.h
//  NitroGrafx
//
//  Created by Fredrik Ahlström on 2003-01-01.
//  Copyright © 2003-2026 Fredrik Ahlström. All rights reserved.
//
#ifndef SOUND_HEADER
#define SOUND_HEADER

#ifdef __cplusplus
extern "C" {
#endif

#include <maxmod9.h>
#include "PCEPSG/pcepsg.h"

//#define sample_rate  47160
//#define buffer_size  1572
//#define sample_rate  31440
//#define buffer_size  1048
#define sample_rate  44100
#define buffer_size  1470

extern PCEPSGCore PSG_0;

void soundInit(void);
void soundSetMuteGUI(void);
mm_word soundRender(mm_word length, mm_addr dest, mm_stream_formats format);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // !SOUND_HEADER
