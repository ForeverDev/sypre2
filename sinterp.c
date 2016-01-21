#include "sinterp.h"

spy_state* spy_newstate() {
	spy_state* S = malloc(sizeof(spy_state));
	S->ip = 0;
	S->sp = SIZE_STACK; // stack grows downwards
	S->fp = 0;
	memset(S->mem, 0, sizeof(S->mem));
	memset(S->marks, 0, sizeof(S->marks));
}

u64 spy_malloc(spy_state* S, u64 size) {
	u64 memptr = 0;
	u64 cursize = 0;
	while (u64 i = 0; i < SIZE_MEM; i++) {
		if (!S->marks[i]) {
			cursize++;
		} else {
			memptr = i;
			cursize = 0;
		}
		if (cursize == size) {
			return memptr;
		}
	}
	// out of memory
	spy_runtimeError(S, "out of memory");
	return 0;
}

void spy_runtimeError(spy_state* S, const u8* message) {
	printf("SPYRE RUNTIME ERROR: %s\n", message);
	exit(1);
}

void spy_run(spy_state* S, u64* code) {
	while (1) {
		if (S->sp <= 0) {
			spy_runtimeError(S, "stack overflow");
		}
		const u64 opcode = code[S->ip++];
		switch (opcode) {
			case 0x00:
				return;
			case 0x01:
				spy_data d;
				d.type = TYPE_INT;
				d.ival = code[S->ip++];
				S->memory[--S->sp] = d;
				break;
			case 0x02:
				break;
			case 0x03:
				break;
			case 0x04:
				break;	
		}
	}
}
