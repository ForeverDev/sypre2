#include <stdio.h>
#include <math.h>
#include "sapi.h"
#include "slib.h"

// IO LIBRARY
static void spy_io_print(spy_state* S, u64 nargs) {
	for (u64 i = 0; i < nargs; i++) {
		printf("%F", spyL_pop(S));
		if (i != nargs - 1) {
			printf("\t");
		}
	}
	spyL_push(S, 0);
}

static void spy_io_println(spy_state* S, u64 nargs) {
	spy_io_print(S, nargs);
	printf("\n");
}

// MATH LIBRARY
static void spy_math_max(spy_state* S, u64 nargs) {
	if (nargs == 0) {
		spyL_push(S, 0);
		return;
	}
	f64 max = spyL_pop(S);
	for (u64 i = 1; i < nargs; i++) {
		f64 val = spyL_pop(S);
		max = val > max ? val : max;
	}
	spyL_push(S, max);
}

static void spy_math_min(spy_state* S, u64 nargs) {
	if (nargs == 0) {
		spyL_push(S, 0);
		return;
	}
	f64 min = spyL_pop(S);
	for (u64 i = 1; i < nargs; i++) {
		f64 val = spyL_pop(S);
		min = val < min ? val : min;
	}
	spyL_push(S, min);
}

static void spy_math_sin(spy_state* S, u64 nargs) {
	spyL_push(S, sin(spyL_pop(S)));
}

static void spy_math_cos(spy_state* S, u64 nargs) {
	spyL_push(S, cos(spyL_pop(S)));
}

static void spy_math_tan(spy_state* S, u64 nargs) {
	spyL_push(S, tan(spyL_pop(S)));
}

static void spy_math_sqrt(spy_state* S, u64 nargs) {
	spyL_push(S, sqrt(spyL_pop(S)));
}

void spy_loadlibs(spy_state* S) {
	spyL_pushcfunction(S, spy_io_print, "print");
	spyL_pushcfunction(S, spy_io_println, "println");

	spyL_pushcfunction(S, spy_math_max, "max");
	spyL_pushcfunction(S, spy_math_min, "min");
	spyL_pushcfunction(S, spy_math_sin, "sin");
	spyL_pushcfunction(S, spy_math_cos, "cos");
	spyL_pushcfunction(S, spy_math_tan, "tan");
	spyL_pushcfunction(S, spy_math_sqrt, "sqrt");
}
