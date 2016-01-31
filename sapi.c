#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include "sapi.h"

void spyL_pushcfunction(spy_state* S, void (*f)(spy_state*, u64, u64), s8* identifier) {
	spy_cfunc func;
	strcpy(func.identifier, identifier);
	func.f = f;
	S->cfuncs[S->cfp++] = func;
}

void spyL_push(spy_state* S, f64 val) {
	S->mem[--S->sp] = val;
}

f64 spyL_toreal(spy_state* S) {
	return S->mem[S->sp++];
}

void spyL_tostring(spy_state* S, s8* buf) {
	u64 ptr = memadr(S->mem[S->sp++]); 
	u64 i = 0;
	while (S->mem[ptr] != 0) {
		buf[i++] = S->mem[ptr++];
	}
	buf[i] = '\0';
}
