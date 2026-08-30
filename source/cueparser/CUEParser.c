/*
 * Simple CUE sheet parser suitable for embedded systems.
 *
 * Copyright (c) 2023 Rabbit Hole Computing
 * Conversion from C++ to C and additions Copyright (c) 2026 Fredrik Ahlström
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

// Refer to e.g. https://www.gnu.org/software/ccd2cue/manual/html_node/CUE-sheet-format.html#CUE-sheet-format
//
// Example of a CUE file:
// FILE "foo bar.bin" BINARY
//   TRACK 01 MODE1/2048
//     INDEX 01 00:00:00
//   TRACK 02 AUDIO
//     PREGAP 00:02:00
//     INDEX 01 02:47:20
//   TRACK 03 AUDIO
//     INDEX 00 07:55:58
//     INDEX 01 07:55:65

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <errno.h>
#include <nds.h>

#include "CUEParser.h"

const char *mParsePos;
CUETrackInfo mTrackInfo;

static bool startLine();
static void nextLine();
static const char *skipSpace(const char *p);
static const char *readQuoted(const char *src, char *dest, int destSize);
static uint32_t parseTime(const char *src);
static CueFileType parseFileMode(const char *src);
static TrackMode parseTrackMode(const char *src);
static uint32_t getSectorLength(CueFileType filemode, TrackMode trackmode);
static void removeDotSlash(char *filename, size_t length);

void startParser(const char *cueSheet) {
	mParsePos = cueSheet;
	memset(&mTrackInfo, 0, sizeof(mTrackInfo));
}

const CUETrackInfo *nextTrack(uint32_t prevFileSize) {
	// Previous track info is needed to track file offset
	mTrackInfo.cumulativeOffset += mTrackInfo.unstoredPregapLength;

	bool gotTrack = false;
	bool gotData = false;
	bool gotPause = false; // true if a period of silence (INDEX 00) was encountered for a track
	while(!(gotTrack && gotData) && startLine()) {
		if (strncasecmp(mParsePos, "FILE ", 5) == 0) {
			if (mTrackInfo.fileIndex > 0) {
				// Take into account the length of last track in previous file.
				uint32_t lastTrackBlocks = (prevFileSize - mTrackInfo.fileOffset) / mTrackInfo.sectorLength;
				mTrackInfo.fileStart = mTrackInfo.dataStart + lastTrackBlocks;
			}

			const char *p = readQuoted(mParsePos + 5, mTrackInfo.filename, sizeof(mTrackInfo.filename));
			removeDotSlash(mTrackInfo.filename, sizeof(mTrackInfo.filename));
			mTrackInfo.fileMode = parseFileMode(skipSpace(p));
			mTrackInfo.fileOffset = 0;
			mTrackInfo.fileIndex++;
			mTrackInfo.trackMode = TRK_MODE_AUDIO;
		}
		else if (strncasecmp(mParsePos, "TRACK ", 6) == 0) {
			const char *trackNum = skipSpace(mParsePos + 6);
			char *endPtr;
			mTrackInfo.trackNumber = strtoul(trackNum, &endPtr, 10);
			mTrackInfo.trackMode = parseTrackMode(skipSpace(endPtr));
			mTrackInfo.sectorLength = getSectorLength(mTrackInfo.fileMode, mTrackInfo.trackMode);
			mTrackInfo.unstoredPregapLength = 0;
			mTrackInfo.storedPregapLength = 0;
			mTrackInfo.dataStart = 0;
			mTrackInfo.trackStart = 0;
			gotTrack = true;
			gotData = false;
			gotPause = false;
		}
		else if (strncasecmp(mParsePos, "PREGAP ", 7) == 0) {
			// Unstored pregap, which offsets the data start on CD but does not
			// affect the offset in data file.
			const char *timeStr = skipSpace(mParsePos + 7);
			mTrackInfo.unstoredPregapLength = parseTime(timeStr);
		}
		else if (strncasecmp(mParsePos, "INDEX ", 6) == 0) {
			const char *indexStr = skipSpace(mParsePos + 6);
			char *endPtr;
			int index = strtoul(indexStr, &endPtr, 10);

			const char *timeStr = skipSpace(endPtr);
			uint32_t time = parseTime(timeStr);

			if (index == 0) {
				// Stored pregap that is present both on CD and in data file
				mTrackInfo.trackStart = mTrackInfo.fileStart + time + mTrackInfo.cumulativeOffset;
				gotPause = true;
			}
			else if (index == 1) {
				// Data content of the track
				mTrackInfo.dataStart = mTrackInfo.fileStart + time + mTrackInfo.cumulativeOffset;
				gotData = true;
			}
		}

		nextLine();
	}

	if (gotData && !gotPause) {
		mTrackInfo.trackStart = mTrackInfo.dataStart;
		mTrackInfo.dataStart += mTrackInfo.unstoredPregapLength;
	}

	if (gotTrack && gotData) {
		// File offsets are always calculated by the sector length of the current track,
		// even in .cue files that mix different sector formats. This can result in some
		// padding needed in the file between a 2048 byte data track and 2352 byte audio
		// track.
		mTrackInfo.fileOffset = (mTrackInfo.trackStart - mTrackInfo.cumulativeOffset - mTrackInfo.fileStart)
									* mTrackInfo.sectorLength;

		if (gotPause) {
			// Advance file position by any stored pregap
			mTrackInfo.storedPregapLength = mTrackInfo.dataStart - mTrackInfo.trackStart;
			mTrackInfo.fileOffset += mTrackInfo.storedPregapLength * mTrackInfo.sectorLength;
			mTrackInfo.trackStart += mTrackInfo.unstoredPregapLength;
			mTrackInfo.dataStart += mTrackInfo.unstoredPregapLength;
		}
		else {
			uint32_t adjustment = mTrackInfo.dataStart - (mTrackInfo.trackStart + mTrackInfo.unstoredPregapLength);
			mTrackInfo.fileOffset += adjustment * mTrackInfo.sectorLength;
		}

		return &mTrackInfo;
	}
	else {
		return NULL;
	}
}

// Skip any whitespace at beginning of line.
// Returns false if at end of string.
bool startLine() {
	// Skip initial whitespace
	while (isspace(*mParsePos)) {
		mParsePos++;
	}
	return *mParsePos != '\0';
}

// Advance parser to next line
void nextLine() {
	// Find end of current line
	const char *p = mParsePos;
	while (*p != '\n' && *p != '\0') {
		p++;
	}
	// Skip any linefeeds
	while (*p == '\n' || *p == '\r') {
		p++;
	}

	mParsePos = p;
}

// Skip spaces in string, return pointer to first non-space character
const char *skipSpace(const char *p) {
	while (isspace(*p)) p++;
	return p;
}

// Read text starting with " and ending with next "
// Returns pointer to character after ending quote.
const char *readQuoted(const char *src, char *dest, int destSize) {
	// Search for starting quote
	while (*src != '"') {
		if (*src == '\0' || *src == '\n') {
			// Unexpected end of line / file
			dest[0] = '\0';
			return src;
		}
		src++;
	}
	src++;

	// Copy text until ending quote
	int len = 0;
	while (*src != '"' && *src != '\0' && *src != '\n') {
		if (len < destSize - 1) {
			dest[len++] = *src;
		}
		src++;
	}

	dest[len] = '\0';

	if (*src == '"') src++;
	return src;
}

// Parse time from MM:SS:FF format to frame number
uint32_t parseTime(const char *src) {
	char *endPtr;
	uint32_t minutes = strtoul(src, &endPtr, 10);
	if (*endPtr == ':') endPtr++;
	uint32_t seconds = strtoul(endPtr, &endPtr, 10);
	if (*endPtr == ':') endPtr++;
	uint32_t frames = strtoul(endPtr, &endPtr, 10);

	return frames + 75 * (seconds + 60 * minutes);
}

// Parse file type into enum
CueFileType parseFileMode(const char *src) {
	if (strncasecmp(src, "BIN", 3) == 0)
		return FILE_TYPE_BINARY;
	else if (strncasecmp(src, "MOTOROLA", 8) == 0)
		return FILE_TYPE_MOTOROLA;
	else if (strncasecmp(src, "MP3", 3) == 0)
		return FILE_TYPE_MP3;
	else if (strncasecmp(src, "WAV", 3) == 0)
		return FILE_TYPE_WAVE;
	else if (strncasecmp(src, "AIFF", 4) == 0)
		return FILE_TYPE_AIFF;
	else
		return FILE_TYPE_BINARY; // Default to binary mode
}

// Parse track mode into enum
TrackMode parseTrackMode(const char *src) {
	if (strncasecmp(src, "AUDIO", 5) == 0)
		return TRK_MODE_AUDIO;
	else if (strncasecmp(src, "CDG", 3) == 0)
		return TRK_MODE_CDG;
	else if (strncasecmp(src, "MODE1/2048", 10) == 0)
		return TRK_MODE_MODE1_2048;
	else if (strncasecmp(src, "MODE1/2352", 10) == 0)
		return TRK_MODE_MODE1_2352;
	else if (strncasecmp(src, "MODE2/2048", 10) == 0)
		return TRK_MODE_MODE2_2048;
	else if (strncasecmp(src, "MODE2/2324", 10) == 0)
		return TRK_MODE_MODE2_2324;
	else if (strncasecmp(src, "MODE2/2336", 10) == 0)
		return TRK_MODE_MODE2_2336;
	else if (strncasecmp(src, "MODE2/2352", 10) == 0)
		return TRK_MODE_MODE2_2352;
	else if (strncasecmp(src, "CDI/2336", 8) == 0)
		return TRK_MODE_CDI_2336;
	else if (strncasecmp(src, "CDI/2352", 8) == 0)
		return TRK_MODE_CDI_2352;
	else
		return TRK_MODE_MODE1_2048; // Default to data track
}

// Get sector length in file from track mode
uint32_t getSectorLength(CueFileType filemode, TrackMode trackmode) {
	if (filemode == FILE_TYPE_BINARY || filemode == FILE_TYPE_MOTOROLA) {
		switch (trackmode) {
			case TRK_MODE_AUDIO:        return 2352;
			case TRK_MODE_CDG:          return 2448;
			case TRK_MODE_MODE1_2048:   return 2048;
			case TRK_MODE_MODE1_2352:   return 2352;
			case TRK_MODE_MODE2_2048:   return 2048;
			case TRK_MODE_MODE2_2324:   return 2324;
			case TRK_MODE_MODE2_2336:   return 2336;
			case TRK_MODE_MODE2_2352:   return 2352;
			case TRK_MODE_CDI_2336:     return 2336;
			case TRK_MODE_CDI_2352:     return 2352;
			default:                    return 2048;
		}
	}
	else {
		return 0;
	}
}

// Remove './' or '.\' from the beginning of the filename as it is not recogized by the SDFat library
void removeDotSlash(char *filename, size_t length) {
	if (strncasecmp(filename, "./", 2) == 0 || strncasecmp(filename, ".\\", 2) == 0) {
		memmove(filename, filename + 2, length - 2);
	}
}


// Read the cuefile and return a pointer to the cuesheet
CueSheet *readCue(const char *cuefile) {
	FILE *f;
	CueSheet *cs = NULL;

	if (NULL == (f = fopen(cuefile, "r"))) {
		//err_sys("Could not open file \"%s\" for reading", cuefile);
		return NULL;
	}
	if ((cs = (CueSheet *)malloc(sizeof(CueSheet))) == NULL) {
		fclose(f);
		return NULL;
	}

	char *cueString = malloc(0x2000);
	fread(cueString, 1, 0x2000, f);
	fclose(f);

	startParser(cueString);
	const CUETrackInfo *trackInf;
	int i = 0;
	while ((trackInf = nextTrack(i)) != NULL) {
		if (i == 0) {
			strlcpy(cs->file, trackInf->filename, 256);
		}
		TrackSpec *ts = &cs->tracks[i];
		ts->mode = trackInf->trackMode;
		ts->start = trackInf->fileOffset;
		ts->LBA = trackInf->dataStart;
		i++;
	}
	cs->trackCount = i;

	free(cueString);

	return cs;
}
