#include <stdio.h>
#include "sapi.h"
#include "sio.h"

static void spy_print(spy_state* S, u64 nargs) {
	for (u64 i = 0; i < nargs; i++) {
		printf("%F", spyL_pop(S));
		if (i != nargs - 1) {
			printf("\t");
		}
	}
	spyL_push(S, 0);
}

static void spy_println(spy_state* S, u64 nargs) {
	spy_print(S, nargs);
	printf("\n");
}

void spy_iolib_load(spy_state* S) {
	spyL_pushcfunction(S, spy_print, "print");
	spyL_pushcfunction(S, spy_println, "println");
}
