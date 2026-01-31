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

//#define sample_rate  32768
//#define sample_rate  55930
#define sample_rate  44100
#define buffer_size  512

extern PCEPSGCore PSG_0;

void soundInit(void);
void soundSetFrequency(void);
void setMuteSoundGUI(void);
mm_word VblSound2(mm_word length, mm_addr dest, mm_stream_formats format);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // SOUND_HEADER
