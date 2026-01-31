//
//  pcepsg.h
//  NitroGrafx
//
//  Created by Fredrik Ahlström on 2003-01-01.
//  Copyright © 2003-2026 Fredrik Ahlström. All rights reserved.
//
#ifndef PCEPSG_HEADER
#define PCEPSG_HEADER

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
	u8 psgChannel;			// Channel select
	u8 globalBalance;		//
	u8 noiseCtrl4;			// Noise control ch4
	u8 noiseCtrl5;			// Noise control ch5
	u8 lfoFreq;				// LFO frequency
	u8 lfoCtrl;				// LFO control
	u8 ch3Change;			//
	u8 padding[1];

	u8 ch0Control;
	u8 ch1Control;
	u8 ch2Control;
	u8 ch3Control;
	u8 ch4Control;
	u8 ch5Control;
	u8 ch6Control;			// Dummy
	u8 ch7Control;			// Dummy

	u8 ch0Balance;
	u8 ch1Balance;
	u8 ch2Balance;
	u8 ch3Balance;
	u8 ch4Balance;
	u8 ch5Balance;
	u8 ch6Balance;			// Dummy
	u8 ch7Balance;			// Dummy

	u8 ch0WaveIndx;
	u8 ch1WaveIndx;
	u8 ch2WaveIndx;
	u8 ch3WaveIndx;
	u8 ch4WaveIndx;
	u8 ch5WaveIndx;
	u8 ch6WaveIndx;			// Dummy
	u8 ch7WaveIndx;			// Dummy

	u16 ch0Freq;
	u16 ch1Freq;
	u16 ch2Freq;
	u16 ch3Freq;
	u16 ch4Freq;
	u16 ch5Freq;
	u16 ch6Freq;			// Dummy
	u16 ch7Freq;			// Dummy

	u32 pcm0CurrentAddr;	// Current addr
	u32 pcm1CurrentAddr;	// Current addr
	u32 pcm2CurrentAddr;	// Current addr
	u32 pcm3CurrentAddr;	// Current addr
	u32 pcm4CurrentAddr;	// Current addr
	u32 pcm5CurrentAddr;	// Current addr
	u32 noise4CurrentAddr;	// Current addr
	u32 noise5CurrentAddr;	// Current addr

	u8 ch0Waveform[32];
	u8 ch1Waveform[32];
	u8 ch2Waveform[32];
	u8 ch3Waveform[32];
	u8 ch4Waveform[32];
	u8 ch5Waveform[32];
	u8 ch6Waveform[32];		// Dummy
	u8 ch7Waveform[32];		// Dummy
} PCEPSGCore;

/**
 * Saves the state of the chip to the destination.
 * @param  *destination: Where to save the state.
 * @param  *chip: The PCEPSGCore to save.
 * @return The size of the state.
 */
int pcePSGSaveState(void *destination, const PCEPSGCore *chip);

/**
 * Loads the state of the chip from the source.
 * @param  *chip: The PCEPSGCore to load a state into.
 * @param  *source: Where to load the state from.
 * @return The size of the state.
 */
int pcePSGLoadState(PCEPSGCore *chip, const void *source);

/**
 * Gets the state size of a K1GE/K2GE.
 * @return The size of the state.
 */
int pcePSGGetStateSize(void);


#ifdef __cplusplus
} // extern "C"
#endif

#endif // PCEPSG_HEADER
