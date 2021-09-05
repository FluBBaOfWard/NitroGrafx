/* cue2toc.h - declarations for conversion routines
 * Copyright (C) 2004 Matthias Czapla <dermatsch@gmx.de>
 *
 * This file is part of cue2toc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
 */
#ifndef CUE2TOC_H
#define CUE2TOC_H

/* Maximum length of the FILEname */
#define FILENAMELEN 255
/* Number of characters allowed per CD-Text entry (w/o termin. Null) */
#define CDTEXTLEN 80

/* Index can be 0 to 99, but 0 and 1 are pre-gap and track start
   respectively, so 98 are left */
#define NUM_OF_INDEXES 2

enum session_type {
	CD_DA = 1,	/* Only audio tracks */
	CD_ROM,		/* Mode1 [and audio] */
	CD_ROM_XA,	/* Mode2 form1 or mode2 form2 [and audio] */
	INVALID		/* Invalid mixture of track modes */
};

enum track_mode {	/* Corresponding TRACK types in CUE format: */
	AUDIO = 1,	/* AUDIO (2352)	*/
	MODE1,		/* MODE1/2048	*/
	MODE1_RAW,	/* MODE1/2352	*/
	MODE2,		/* MODE2/2336	*/
	MODE2_RAW	/* MODE2/2352 	*/
};

struct trackspec {
	enum track_mode mode;
	long start;				/* Track start in file (in frames) */
	long LBA;				/* LBA position on disc */
};

struct cuesheet {
	int trackcount;
	char file[FILENAMELEN + 1];
	struct trackspec tracklist[99];
};

struct cuesheet *read_cue(const char*);

#endif /* CUE2TOC_H */
