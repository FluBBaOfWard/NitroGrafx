/* cue2toc.c - conversion routines
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <unistd.h>
#include <errno.h>
#include <stdarg.h>
#include "cue2toc.h"
#include "timecode.h"

#define TCBUFLEN 9	/* Buffer length for timecode strings (HH:MM:SS) */
#define MAXCMDLEN 10	/* Longest command (currently SONGWRITER) */

/*
 * Input is divied into tokens that are separated by whitespace, horizantal
 * tabulator, line feed and carriage return. Tokens can be either commands
 * from a fixed set or strings. If a string is to contain any of the token
 * delimiting characters it must be enclosed in double quotes.
 */

static const char token_delimiter[] = { ' ', '\t', '\n', '\r' };

/* Return true if c is one of token_delimiter */
static int
isdelim(int c)
{
	int i;
	int n = sizeof(token_delimiter);

	for (i = 0; i < n; i++)
		if (c == token_delimiter[i])
			return 1;
	return 0;
}

/* Used as return type for get_command and index into cmds */
enum command { REM, CATALOG, CDTEXTFILE,
	FILECMD, PERFORMER, SONGWRITER, TITLE, TRACK, FLAGS, DCP,
	FOURCH, PRE, SCMS, ISRC, PREGAP, INDEX, POSTGAP, BINARY,
	MOTOROLA, AIFF, WAVE, MP3, UNKNOWN, END };

/* Except the last two these are the valid CUE commands */
char cmds[][MAXCMDLEN + 1] = { "REM", "CATALOG", "CDTEXTFILE",
	"FILE", "PERFORMER", "SONGWRITER", "TITLE", "TRACK", "FLAGS", "DCP",
	"4CH", "PRE", "SCMS", "ISRC", "PREGAP", "INDEX", "POSTGAP", "BINARY",
	"MOTOROLA", "AIFF", "WAVE", "MP3", "UNKNOWN", "END" };

/* These are for error messages */
static const char *fname = "stdin";
static long line;		/* current line number */
static long tokenstart;		/* line where last token started */
static long currenttrack;

/* Fatal error while processing input file */
static void
err_cue(const char *s)
{
//	err_quit("%s:%ld: %s", fname, tokenstart, s);
}

/* EOF while expecting more */
static void
err_earlyend()
{
//	err_quit("%s:%ld: Premature end of file", fname, line);
}

/* Get next command from file */
static enum command
get_command(FILE *f)
{
	int c;
	char buf[MAXCMDLEN + 1];
	int i = 0;

	/* eat whitespace */
	do {
		c = getc(f);
		if (c == '\n')
			line++;
	} while (isdelim(c));

	if (c == EOF) {
		return END;
	}
	tokenstart = line;

	/* get command, transform to upper case */
	do {
		buf[i++] = toupper(c);
		c = getc(f);
	} while (!isdelim(c) && c!= EOF && i < MAXCMDLEN);

	if (!isdelim(c)) return UNKNOWN; /* command longer than MAXCMDLEN */
	if (c == EOF) return END;
	if (c == '\n') line++;

	buf[i] = '\0';

	if (strcmp(buf, cmds[REM]) == 0) return REM;
	else if (strcmp(buf, cmds[CATALOG]) == 0) return CATALOG;
	else if (strcmp(buf, cmds[CDTEXTFILE]) == 0) return CDTEXTFILE;
	else if (strcmp(buf, cmds[FILECMD]) == 0) return FILECMD;
	else if (strcmp(buf, cmds[PERFORMER]) == 0) return PERFORMER;
	else if (strcmp(buf, cmds[SONGWRITER]) == 0) return SONGWRITER;
	else if (strcmp(buf, cmds[TITLE]) == 0) return TITLE;
	else if (strcmp(buf, cmds[TRACK]) == 0) return TRACK;
	else if (strcmp(buf, cmds[FLAGS]) == 0) return FLAGS;
	else if (strcmp(buf, cmds[DCP]) == 0) return DCP;
	else if (strcmp(buf, cmds[FOURCH]) == 0) return FOURCH;
	else if (strcmp(buf, cmds[PRE]) == 0) return PRE;
	else if (strcmp(buf, cmds[SCMS]) == 0) return SCMS;
	else if (strcmp(buf, cmds[ISRC]) == 0) return ISRC;
	else if (strcmp(buf, cmds[PREGAP]) == 0) return PREGAP;
	else if (strcmp(buf, cmds[INDEX]) == 0) return INDEX;
	else if (strcmp(buf, cmds[POSTGAP]) == 0) return POSTGAP;
	else if (strcmp(buf, cmds[BINARY]) == 0) return BINARY;
	else if (strcmp(buf, cmds[MOTOROLA]) == 0) return MOTOROLA;
	else if (strcmp(buf, cmds[AIFF]) == 0) return AIFF;
	else if (strcmp(buf, cmds[WAVE]) == 0) return WAVE;
	else if (strcmp(buf, cmds[MP3]) == 0) return MP3;
	else return UNKNOWN;
}

/* Skip leading token delimiters then read at most n chars from f into s.
 * Put terminating Null at the end of s. This implies that s must be
 * really n + 1. Return number of characters written to s. The only case to
 * return zero is on EOF before any character was read.
 * Exit the program indicating failure if string is longer than n. */
static size_t
get_string(FILE *f, char *s, size_t n)
{
	int c;
	size_t i = 0;

	/* Eat whitespace */
	do {
		c = getc(f);
		if (c == '\n')
			line++;
	} while (isdelim(c));

	if (c == EOF) {
		return 0;
	}
	tokenstart = line;

	if (c == '\"') {
		c = getc(f);
		if (c == '\n') line++;
		while (c != '\"' && c != EOF && i < n) {
			s[i++] = c;
			c = getc(f);
			if (c == '\n') line++;
		}
		if (i == n && c != '\"' && c != EOF)
			err_cue("String too long");
	} else {
		while (!isdelim(c) && c != EOF && i < n) {
			s[i++] = c;
			c = getc(f);
		}
		if (i == n && !isdelim(c) && c != EOF)
			err_cue("String too long");
	}
	if (i == 0) err_cue("Empty string");
	if (c == '\n') line++;
	s[i] = '\0';

	return i;
}

/* Return track mode */
static enum track_mode
get_track_mode(FILE *f)
{
	char buf[] = "MODE1/2048";
	char *pbuf = buf;

	if (get_string(f, buf, sizeof(buf) - 1) < 1)
		err_cue("Illegal track mode");

	/* T ransform to upper case */
	while (*pbuf) {
		*pbuf = toupper(*pbuf);
		pbuf++;
	}

	if (strcmp(buf, "AUDIO") == 0) return AUDIO;
	else if (strcmp(buf, "MODE1/2048") == 0) return MODE1;
	else if (strcmp(buf, "MODE1/2352") == 0) return MODE1_RAW;
	else if (strcmp(buf, "MODE2/2336") == 0) return MODE2;
	else if (strcmp(buf, "MODE2/2352") == 0) return MODE2_RAW;
	else err_cue("Unsupported track mode");

	return 0;
}

/* Allocate, initialize and return new track */
static struct trackspec*
new_track(struct trackspec *track)
{
	track->start = track->LBA = -1;

	return track;
}

/* Read the cuefile and return a pointer to the cuesheet */
struct cuesheet*
read_cue(const char *cuefile)
{
	FILE *f;
	enum command cmd;
	struct cuesheet *cs = NULL;
	struct trackspec *track = NULL;
	size_t n;
	int c;
	int pregap_data_from_file = 0;	/* boolean */
	long pregap = -1;				/* Pre-gap in frames */
	long postgap = -1;				/* Post-gap in frames */
	long totalgap = 0;
//	enum command filetype = UNKNOWN;
	char timecode_buffer[TCBUFLEN];
	char devnull[FILENAMELEN + 1];	/* just for eating CDTEXTFILE arg */

	if (NULL == (f = fopen(cuefile, "r"))) {
		//err_sys("Could not open file \"%s\" for reading", cuefile);
		return NULL;
	}
	if (cuefile) {
		fname = cuefile;
	}
	if ((cs = (struct cuesheet*) malloc(sizeof(struct cuesheet))) == NULL) {
		err_cue("Memory allocation error in read_cue()");
	}
	cs->file[0] = '\0';
	line = 1;
	currenttrack=0;

	/* Global section */
	while ((cmd = get_command(f)) != TRACK) {
		switch (cmd) {
		case UNKNOWN:
			err_cue("Unknown command");
			break;
		case END:
			err_earlyend();
			break;
		case REM:
			c = getc(f);
			while (c != '\n' && c != EOF)
				c = getc(f);
			break;
		case CDTEXTFILE:
			get_string(f, devnull, FILENAMELEN);
			break;
		case CATALOG:
			get_string(f, devnull, 13);
			break;
		case TITLE:
			get_string(f, devnull, CDTEXTLEN);
			break;
		case PERFORMER:
			get_string(f, devnull, CDTEXTLEN);
			break;
		case SONGWRITER:
			get_string(f, devnull, CDTEXTLEN);
			break;
		case FILECMD:
			if (get_string(f, cs->file, FILENAMELEN) < 1) {
				err_earlyend();
			}
			switch (cmd = get_command(f)) {
				case BINARY:
//					filetype = BINARY;
					break;
				case MOTOROLA:
				case AIFF:
				case MP3:
				case WAVE:
//					filetype = WAVE;
					break;
				default:
					err_cue("Unsupported file type");
			}
			break;
		default:
			err_cue("Command not allowed in global section");
			break;
		}

	}

	/* leaving global section, entering track specifications */
	if (cs->file[0] == '\0') {
		err_cue("TRACK without previous FILE");
	}
	while (cmd != END) {
		switch(cmd) {
		case UNKNOWN:
			err_cue("Unknown command");
			break;
		case REM:
			c = getc(f);
			while (c != '\n' && c != EOF)
				c = getc(f);
			break;
		case TRACK:
			track = new_track(&cs->tracklist[currenttrack++]);
			pregap_data_from_file = 0;
			pregap = -1;				/* Pre-gap in frames */
			postgap = -1;				/* Post-gap in frames */

			/* the CUE format is "TRACK nn MODE" but we are not
			   interested in the track number */
			while (isdelim(c = getc(f)))
				if (c == '\n') line++;
			while (!isdelim(c = getc(f))) ;
			if (c == '\n') line++;

			track->mode = get_track_mode(f);

			break;
		case TITLE:
			get_string(f, devnull, CDTEXTLEN);
			break;
		case PERFORMER:
			get_string(f, devnull, CDTEXTLEN);
			break;
		case SONGWRITER:
			get_string(f, devnull, CDTEXTLEN);
			break;
		case ISRC:
			get_string(f, devnull, 12);
			break;
		case FLAGS:
			/* Get the flags */
			cmd = get_command(f);
			while (cmd == DCP || cmd == FOURCH || cmd == PRE || cmd == SCMS) {
				cmd = get_command(f);
			}
			/* Current non-FLAG command is already in cmd, so
			   avoid get_command() call below */
			continue; break;
		case PREGAP:
			if (pregap != -1)
				err_cue("PREGAP allowed only once per track");
			if (get_string(f, timecode_buffer, TCBUFLEN - 1) < 1)
				err_earlyend();
			pregap = tc2fr(timecode_buffer);
			if (pregap == -1)
				err_cue("Timecode out of range");
			pregap_data_from_file = 0;
			break;
		case POSTGAP:
			if (postgap != -1)
				err_cue("POSTGAP allowed only once per track");
			if (get_string(f, timecode_buffer, TCBUFLEN - 1) < 1)
				err_earlyend();
			postgap = tc2fr(timecode_buffer);
			if (postgap == -1)
				err_cue("Timecode out of range");
			break;
		case INDEX:
			if (get_string(f, timecode_buffer, 2) < 1)
				err_earlyend();
			n = atoi(timecode_buffer);
			if (n < 0 || n > 99)
				err_cue("Index out of range");
			if (get_string(f, timecode_buffer, TCBUFLEN - 1) < 1)
				err_cue("Missing timecode");

			/* Index 0 is _not_ track pregap and Index 1 is start
			   of track. Index 2 to 99 are the true subindexes
			   and only allowed if the preceding one was there
			   before */
			switch (n) {
			case 0:
				if (track->start != -1)
					err_cue("Indexes must be sequential");
//				if (pregap != -1)
//					err_cue("PREGAP allowed only once per track");
				/* This is only a temporary value until index 01 is read */
//				pregap = tc2fr(timecode_buffer);
//				if (pregap == -1)
//					err_cue("Timecode out of range");
//				pregap_data_from_file = 1;
				break;
			case 1:
				if (track->start != -1)
					err_cue("Each index allowed only once per track");
				track->start = tc2fr(timecode_buffer);
				if (track->start == -1)
					err_cue("Timecode out of range");
				/* Fix the pregap value */
				if (pregap_data_from_file)
					pregap = track->start - pregap;
				if (pregap != -1)
					totalgap += pregap;
				track->LBA = track->start + totalgap;
				break;
			default:	/* the other 97 indexes */
				break;
			}
			break;
		case FILECMD:
			if (get_string(f, cs->file, FILENAMELEN) < 1)
				err_earlyend();

			switch (cmd = get_command(f)) {
				case BINARY:
//					filetype = BINARY;
					break;
				case MOTOROLA:
				case AIFF:
				case MP3:
				case WAVE:
//					filetype = WAVE;
					break;
				default:
					err_cue("Unsupported file type");
			}
			break;
		default:
			err_cue("Command not allowed in track spec");
			break;
		}
		
		cmd = get_command(f);
	}
	cs->trackcount = currenttrack;
	fclose(f);

	return cs;
}
