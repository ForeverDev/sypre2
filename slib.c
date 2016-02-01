#include <stdio.h>
#include <math.h>
#include "sapi.h"
#include "slib.h"

// IO LIBRARY
static void spy_io_print(spy_state* S, u64 nargs, u64 flags) {
	for (u64 i = 0; i < nargs; i++) {
		u8 type = (u8)(flags & 0x03);
		flags >>= 2;
		if (type == TYPE_REAL) {
			f64 n = spyL_toreal(S);
			if ((u64)n == n) {
				printf("%lld", (u64)n);
			} else {
				printf("%F", n);
			}
		} else if (type == TYPE_STR) {
			s8 buf[2048];
			spyL_tostring(S, buf);
			printf("%s", buf);
		} else if (type == TYPE_PTR) {
			printf("0x%08llx", (u64)spyL_toreal(S));
		}
		if (i != nargs - 1) {
			printf("\t");
		}
	}
	spyL_push(S, 0);
}

static void spy_io_println(spy_state* S, u64 nargs, u64 flags) {
	spy_io_print(S, nargs, flags);
	printf("\n");
}

static void spy_mem_free(spy_state* S, u64 nargs, u64 flags) {
	spy_free(S, (u64)spyL_toreal(S));
	spyL_push(S, 0);
}

// MATH LIBRARY
static void spy_math_max(spy_state* S, u64 nargs, u64 flags) {
	if (nargs == 0) {
		spyL_push(S, 0);
		return;
	}
	f64 max = spyL_toreal(S);
	for (u64 i = 1; i < nargs; i++) {
		f64 val = spyL_toreal(S);
		max = val > max ? val : max;
	}
	spyL_push(S, max);
}

static void spy_math_min(spy_state* S, u64 nargs, u64 flags) {
	if (nargs == 0) {
		spyL_push(S, 0);
		return;
	}
	f64 min = spyL_toreal(S);
	for (u64 i = 1; i < nargs; i++) {
		f64 val = spyL_toreal(S);
		min = val < min ? val : min;
	}
	spyL_push(S, min);
}

static void spy_math_sin(spy_state* S, u64 nargs, u64 flags) {
	spyL_push(S, sin(spyL_toreal(S)));
}

static void spy_math_cos(spy_state* S, u64 nargs, u64 flags) {
	spyL_push(S, cos(spyL_toreal(S)));
}

static void spy_math_tan(spy_state* S, u64 nargs, u64 flags) {
	spyL_push(S, tan(spyL_toreal(S)));
}

static void spy_math_sqrt(spy_state* S, u64 nargs, u64 flags) {
	spyL_push(S, sqrt(spyL_toreal(S)));
}

static void spy_math_map(spy_state* S, u64 nargs, u64 flags) {
	f64 n = spyL_toreal(S);
	f64 a = spyL_toreal(S);
	f64 b = spyL_toreal(S);
	f64 c = spyL_toreal(S);
	f64 d = spyL_toreal(S);
	spyL_push(S, (n - a)/(b - a) * (d - c) + c);
}

static void spy_math_plot(spy_state* S, u64 nargs, u64 flags) {
	f64 n = spyL_toreal(S);
	f64 lower = spyL_toreal(S);
	f64 upper = spyL_toreal(S);
	if (n < lower) {
		n = lower;
	} else if (n > upper) {
		n = upper;
	}
	spyL_push(S, n);
}

void spy_loadlibs(spy_state* S) {
	spyL_pushcfunction(S, spy_io_print, "print");
	spyL_pushcfunction(S, spy_io_println, "println");

	spyL_pushcfunction(S, spy_mem_free, "free");

	spyL_pushcfunction(S, spy_math_max, "max");
	spyL_pushcfunction(S, spy_math_min, "min");
	spyL_pushcfunction(S, spy_math_sin, "sin");
	spyL_pushcfunction(S, spy_math_cos, "cos");
	spyL_pushcfunction(S, spy_math_tan, "tan");
	spyL_pushcfunction(S, spy_math_sqrt, "sqrt");
	spyL_pushcfunction(S, spy_math_map, "map");
	spyL_pushcfunction(S, spy_math_plot, "plot");
}
