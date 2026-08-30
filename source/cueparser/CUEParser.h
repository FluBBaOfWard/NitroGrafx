/*
 * Simple CUE sheet parser suitable for embedded systems.
 *
 * Copyright (c) 2023 Rabbit Hole Computing
 * Additional fixes Copyright (c) 2026 Fredrik Ahlström
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the “Software”), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */

#ifndef CUEPARSER_H
#define CUEPARSER_H

/* Maximum length of the FILEname */
#define FILENAMELEN 256
/* Number of tracks allowed per CD */
#define MAX_TRACKS 99

typedef enum {
	FILE_TYPE_BINARY = 0,
	FILE_TYPE_MOTOROLA,
	FILE_TYPE_MP3,
	FILE_TYPE_WAVE,
	FILE_TYPE_AIFF,
} CueFileType;

typedef enum {	// Corresponding TRACK types in CUE format: */
	TRK_MODE_AUDIO = 0,	// AUDIO (2352)
	TRK_MODE_CDG,
	TRK_MODE_MODE1_2048,
	TRK_MODE_MODE1_2352,
	TRK_MODE_MODE2_2048,
	TRK_MODE_MODE2_2324,
	TRK_MODE_MODE2_2336,
	TRK_MODE_MODE2_2352,
	TRK_MODE_CDI_2336,
	TRK_MODE_CDI_2352,
} TrackMode;

typedef struct
{
	// Source file name and file type, and offset to start of track data in bytes.
	char filename[FILENAMELEN];
	int fileIndex;
	CueFileType fileMode;
	uint32_t fileOffset; // corresponds to dataStart below

	// Track number and mode in CD format
	int trackNumber;
	TrackMode trackMode;

	// Sector length for this track in bytes, assuming BINARY or MOTOROLA file modes.
	uint32_t sectorLength;

	// The CD frames of PREGAP time at the start of this track, or 0 if none are present.
	// These frames of silence are not stored in the underlying data file.
	uint32_t unstoredPregapLength;

	// The CD frames of PREGAP time at the start of this track,
	// which are present both on CD and in data file.
	uint32_t storedPregapLength;

	// The cumulative lba offset of unstored data
	uint32_t cumulativeOffset;

	// LBA start position of this file
	uint32_t fileStart;

	// LBA start position of the data area (INDEX 01) of this track (in CD frames)
	uint32_t dataStart;

	// LBA for the beginning of the track, which will be INDEX 00 if that is present.
	// If there is unstored PREGAP, it's added between trackStart and dataStart.
	// Otherwise this will be INDEX 01 matching dataStart above.
	uint32_t trackStart;
} CUETrackInfo;

typedef struct {
	TrackMode mode;
	long start;				// Track start in file (in frames)
	long LBA;				// LBA position on disc
} TrackSpec;

typedef struct {
	int trackCount;
	char file[FILENAMELEN];
	TrackSpec tracks[MAX_TRACKS];
} CueSheet;

/**
 * Parses the cue-file string and returns a pointer to the cue-sheet.
 * The cuesheet should be freed after use.
 * @param  *cuefile: the cue file as a string.
 * @return The CueSheet or null.
 */
CueSheet *readCue(const char *cuefile);

#endif // !CUEPARSER_H
