//
//  io.h
//  NitroGrafx
//
//  Created by Fredrik Ahlström on 2003-01-01.
//  Copyright © 2003-2026 Fredrik Ahlström. All rights reserved.
//
#ifndef IO_HEADER
#define IO_HEADER

#ifdef __cplusplus
extern "C" {
#endif

extern u32 joyCfg;
extern u32 EMUinput;
extern u8 button3;

/**
 * Convert device input keys to target keys.
 * @param input NDS/GBA keys
 * @return The converted input.
 */
int convertInput(int input);

/**
 * Set joy mapping.
 * @param type default or alternate
 */
void setJoyMapping(void);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // !IO_HEADER
