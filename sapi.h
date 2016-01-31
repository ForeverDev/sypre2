#ifndef __SAPI_H
#define __SAPI_H

#include "sinterp.h"

#define memadr(i) (SIZE_STACK + (i) + 1)

typedef enum spyL_datatypes {
	TYPE_NULL	= 0x00,
	TYPE_REAL	= 0x01,
	TYPE_STR	= 0x02,
	TYPE_PTR	= 0x03
} spyL_datatypes;

void	spyL_pushcfunction(spy_state*, void (*)(spy_state*, u64, u64), s8*);

void	spyL_push(spy_state*, f64);

f64		spyL_toreal(spy_state*);
void	spyL_tostring(spy_state*, s8*);


#endif
