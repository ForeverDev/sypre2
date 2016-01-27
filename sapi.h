#ifndef __SAPI_H
#define __SAPI_H

#include "sinterp.h"

void	spyL_pushcfunction(spy_state*, void (*)(spy_state*, u64 nargs), s8*);

void	spyL_push(spy_state*, f64);
f64		spyL_pop(spy_state*);

#endif
