#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sinterp.h"

spy_state* spy_newstate() {
	spy_state* S = malloc(sizeof(spy_state));
	S->ip = 0;
	S->sp = SIZE_STACK; // stack grows downwards
	S->fp = 0;
	memset(S->mem, 0, sizeof(S->mem));
	memset(S->marks, 0, sizeof(S->marks));
	spy_mark mark_null;
	mark_null.isnull = 1;
	for (u64 i = 0; i < SIZE_MEM; i++) {
		S->marks[i] = mark_null;
	}
	return S;
}

u64 spy_malloc(spy_state* S, u64 size) {
	u64 memptr = SIZE_STACK + 1;
	u64 cursize = 0;
	for (u64 i = SIZE_STACK + 1; i < SIZE_MEM; i++) {
		if (S->marks[i].isnull) {
			cursize++;
		} else {
			memptr = i;
			cursize = 0;
		}
		if (cursize == size) {
			return memptr;
		}
	}
	// out of mem
	// TODO realloc space for MEMSIZE * 2
	spy_runtimeError(S, "out of mem");
	return 0;
}

void spy_runtimeError(spy_state* S, const char* message) {
	printf("SPYRE RUNTIME ERROR: %s\n", message);
	exit(1);
}

void spy_dumpMemory(spy_state* S) {
	printf("MEMORY DUMP:\n");
	for (u64 i = S->sp; i < SIZE_MEM; i++) {
		if (i <= SIZE_STACK || !S->marks[i].isnull) {
			printf("0x%08llx: %F\n", i, S->mem[i]);
		}
	}
}

void spy_run(spy_state* S, const u64* code) {
	while (1) {
		if (S->sp <= 0) {
			spy_runtimeError(S, "stack overflow");
		}
		const u8 opcode = (u8)code[S->ip++];
		switch (opcode) {
			case 0x00:
				return;
			case 0x01: 
				S->mem[--S->sp] = code[S->ip++];	
				break;
			case 0x02: {
				u64 slen = code[S->ip++];
				u64 memlc = spy_malloc(S, slen);
				u64 ptr = memlc;
				u8 c;
				while ((c = (u8)code[S->ip++]) != 0x00) {
					S->marks[memlc].isnull = 0;
					S->mem[ptr++] = (f64)c;	
				}
				S->mem[--S->sp] = memlc;
				break;
			}
			case 0x03:
				break;
			case 0x04:
				S->sp++;
				break;	
			case 0x05:
				S->mem[--S->sp] = S->mem[S->sp++] + S->mem[S->sp++];
				break;
			case 0x06:
				S->mem[--S->sp] = S->mem[S->sp++] - S->mem[S->sp++];
				break;
			case 0x07:
				S->mem[--S->sp] = S->mem[S->sp++] * S->mem[S->sp++];
				break;
			case 0x08:
				S->mem[--S->sp] = S->mem[S->sp++] / S->mem[S->sp++];
				break;
			case 0x09:
				S->mem[--S->sp] = S->mem[S->sp++] && S->mem[S->sp++];
				break;
			case 0x0a:
				S->mem[--S->sp] = S->mem[S->sp++] || S->mem[S->sp++];
				break;
			case 0x0b:
				S->mem[--S->sp] = !S->mem[S->sp++];
				break;
		}
	}
}
