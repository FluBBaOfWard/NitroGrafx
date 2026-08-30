/* timecode.h - timecode parsing routine
 * Calculates frames/sectors from timecode string.
 */
#ifndef TIMECODE_H
#define TIMECODE_H

/* Calculates number of frames/sectors from a timecode string ("MM:SS:FF").
 * Tries to be lenient, skips leading whitespace, ignoring any trailing
 * non-timecode junk. Recognizes simple values like "0" (interpreted as
 * "00:00:00"), "1:2" ("00:01:02") etc.
 * Returns -1 on error (argument NULL or some value out of range) */
long tc2fr(const char *);

#endif // !TIMECODE_H
