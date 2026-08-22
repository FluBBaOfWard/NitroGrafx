#ifndef PCENGINE_HEADER
#define PCENGINE_HEADER

#ifdef __cplusplus
extern "C" {
#endif

/// This runs all save state functions for each chip.
int pcePackState(void *statePtr);

/// This runs all load state functions for each chip.
void pceUnpackState(const void *statePtr);

/// Gets the total state size in bytes.
int pceGetStateSize(void);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // !PCENGINE_HEADER
