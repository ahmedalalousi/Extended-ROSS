#ifndef INC_tw_timing_h
#define INC_tw_timing_h

#ifdef __APPLE__
#include <sys/time.h>
#endif

#ifdef __linux__
#include <sys/time.h>
#endif

typedef struct timeval tw_wtime;

#endif
