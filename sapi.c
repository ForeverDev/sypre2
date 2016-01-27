#include <string.h>
#include "sapi.h"

void spyL_pushcfunction(spy_state* S, void (*f)(spy_state*, u64 nargs), s8* identifier) {
	spy_cfunc func;
	strcpy(func.identifier, identifier);
	func.f = f;
	S->cfuncs[S->cfp++] = func;
}

void spyL_push(spy_state* S, f64 val) {
	S->mem[--S->sp] = val;
}

f64 spyL_pop(spy_state* S) {
	return S->mem[S->sp++];
}
