/* timecode.c - timecode parsing routine
 * Calculates frames/sectors from timecode string.
 */
#include <stdlib.h>
#include <string.h>

#define NUMOFNUMS	3
#define FRAMES_PER_SECOND (75)
#define SECONDS_PER_MINUTE (60)

long tc2fr(const char *tc)
{
	if (tc == NULL) {
		return -1;
	}

	int nums[NUMOFNUMS];

	const char *tmp = tc;
	int n = 0;
	for (n; n < NUMOFNUMS; n++) {
		nums[n] = atoi(tmp);
		tmp = strchr(tmp, ':');
		if (tmp == NULL) {
			break;
		}
		tmp++;
	}

	int minutes = 0;
	int seconds = 0;
	int frames = nums[n];

	if (--n >= 0) {
		seconds = nums[n];
	}
	if (--n >= 0) {
		minutes = nums[n];
	}

	if (seconds >= SECONDS_PER_MINUTE || frames >= FRAMES_PER_SECOND) {
		return -1;
	}
	return ((SECONDS_PER_MINUTE * minutes) + seconds) * FRAMES_PER_SECOND + frames;
}
