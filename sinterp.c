#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sinterp.h"

spy_state* spy_newstate() {
	spy_state* S = malloc(sizeof(spy_state));
	S->ip = 0;
	S->sp = SIZE_STACK; // stack grows downwards
	S->fp = SIZE_STACK;
	memset(S->mem, 0, sizeof(S->mem));
	memset(S->marks, 0, sizeof(S->marks));
	for (u64 i = 0; i < SIZE_MEM; i++) {
		S->marks[i] = 0;
	}
	return S;
}

u64 spy_malloc(spy_state* S, u64 size) {
	u64 memptr = SIZE_STACK + 1;
	u64 cursize = 0;
	for (u64 i = SIZE_STACK + 1; i < SIZE_MEM; i++) {
		if (!S->marks[i]) {
			cursize++;
		} else {
			memptr = i;
			cursize = 0;
		}
		if (cursize == size) {
            for (u64 j = memptr; j <= memptr + size; j++) {
                S->marks[j] = 1;
            }
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
	printf("---STACK---\n");
	for (u64 i = S->sp; i < SIZE_MEM; i++) {
        if (i == SIZE_STACK) {
            printf("---STACK---\n\n---MEMORY---\n");
        } else if (i <= SIZE_STACK || S->marks[i]) {
			printf("0x%08llx: %F\n", i, S->mem[i]);
		}
	}
	printf("---MEMORY---\n\n");
	printf("---POINTERS---\n");
	printf("ip: 0x%04llx\n", S->ip);
	printf("sp: 0x%04llx\n", S->sp);
	printf("fp: 0x%04llx\n", S->fp);
	printf("---POINTERS---\n");
}

void spy_run(spy_state* S, const u64* code) {
	while (code[S->ip] != 0x00 || code[S->ip + 1] != 0x00 || code[S->ip + 2] != 0x00) {
		const char opcode = (u8)code[S->ip];
		S->ip++;
		if (opcode == 0x18) {
			S->labels[(u64)code[S->ip++]] = S->ip + 1;
		}
	}
	S->ip = 0;
	while (1) {
		if (S->sp <= 0) {
			spy_runtimeError(S, "stack overflow");
		}
		const u8 opcode = (u8)code[S->ip++];
		switch (opcode) {
            // NULL
			case 0x00:
				return;
            // PUSHNUM
			case 0x01:
				S->mem[--S->sp] = code[S->ip++];
				break;
            // PUSHSTR
			case 0x02: {
				u64 slen = code[S->ip++];
				u64 memlc = spy_malloc(S, slen);
				u64 ptr = memlc;
				u8 c;
				while ((c = (u8)code[S->ip++]) != 0x00) {
					S->mem[ptr++] = (f64)c;
				}
				S->mem[--S->sp] = memlc;
				break;
			}
            // PUSHPTR
			case 0x03:
				break;
            // POP
			case 0x04:
				S->sp++;
				break;
            // ADD
			case 0x05:
				S->mem[--S->sp] = S->mem[S->sp++] + S->mem[S->sp++];
				break;
            // SUB
			case 0x06: {
                f64 b = S->mem[S->sp++];
                S->mem[--S->sp] = S->mem[S->sp++] - b;
                break;
            }
            // MUL
			case 0x07:
				S->mem[--S->sp] = S->mem[S->sp++] * S->mem[S->sp++];
				break;
            // DIV
			case 0x08: {
                f64 b = S->mem[S->sp++];
                S->mem[--S->sp] = S->mem[S->sp++] / b;
                break;
            }
            // AND
			case 0x09:
				S->mem[--S->sp] = S->mem[S->sp++] && S->mem[S->sp++];
				break;
            // OR
			case 0x0a:
				S->mem[--S->sp] = S->mem[S->sp++] || S->mem[S->sp++];
				break;
            // NOT
			case 0x0b:
				S->mem[--S->sp] = !S->mem[S->sp++];
				break;
            // EQ
			case 0x0c:
				S->mem[--S->sp] = (f64)(S->mem[S->sp++] == S->mem[S->sp++]);
				break;
            // PUSHLOCAL
            case 0x0d:
                S->mem[--S->sp] = S->mem[S->fp - code[S->ip++]];
                break;
            // SETLOCAL
            case 0x0e: {
				f64 val = S->mem[S->sp++];
                S->mem[S->fp - (u64)S->mem[S->sp++]] = val;
                break;
			}
            // PUSHARG
            case 0x0f:
                S->mem[--S->sp] = S->mem[S->fp + 3 + code[S->ip++]];
                break;
            // CALL
            case 0x10: {
                u64 addr = code[S->ip++];
                S->mem[--S->sp] = (f64)code[S->ip++];
                S->mem[--S->sp] = (f64)S->fp;
                S->mem[--S->sp] = (f64)S->ip;
				S->fp = S->sp;
				S->ip = addr;
                break;
            }
            // RET
            case 0x11: {
                f64 retval = S->mem[S->sp++];
				S->sp = S->fp;
				S->ip = (u64)S->mem[S->sp++];
				S->fp = (u64)S->mem[S->sp++];
				S->sp += (u64)S->mem[S->sp++];
                S->mem[--S->sp] = retval;
				break;
            }
            // JMP
            case 0x12:
                S->ip = S->labels[(u64)code[S->ip++]];
                break;
            // JIT
            case 0x13:
                if (S->mem[S->sp++]) {
                    S->ip = S->labels[(u64)code[S->ip++]];
                } else {
					S->ip++;
				}
                break;
            // JIF
            case 0x14:
                if (!S->mem[S->sp++]) {
                    S->ip = S->labels[(u64)code[S->ip++]];
                } else {
					S->ip++;
				}
                break;
            // MALLOC
            case 0x15:
                S->mem[--S->sp] = spy_malloc(S, code[S->ip++]);
                break;
            // SET MEM
            case 0x16: {
                f64 val = S->mem[S->sp++];
                u64 addr = (u64)S->mem[S->sp++];
                S->mem[addr] = val;
                break;
            }
            // GET MEM
            case 0x17:
                S->mem[--S->sp] = S->mem[(u64)(S->mem[S->sp++])];
                break;
			// LABEL
			case 0x18:
				S->ip++;
				break;
			// GT
			case 0x19: {
				f64 val = S->mem[S->sp++];
				S->mem[--S->sp] = S->mem[S->sp++] > val;
			}
			// GE
			case 0x1a: {
				f64 val = S->mem[S->sp++];
				S->mem[--S->sp] = S->mem[S->sp++] >= val;
			}
			// LT
			case 0x1b: {
				f64 val = S->mem[S->sp++];
				S->mem[--S->sp] = S->mem[S->sp++] < val;
			}
			// LE
			case 0x1c: {
				f64 val = S->mem[S->sp++];
				S->mem[--S->sp] = S->mem[S->sp++] <= val;
			}

		}
	}
}

void spy_runFromString(spy_state* S, const s8* code) {
	u64 generated_code[65536];
	u64 index = 0, bufptr = 0, codeptr = 0;
	s8 buf[128];
	while (1) {
		if (code[index] == ' ' || code[index] == '\0') {
			char* hexa = malloc(bufptr);
			for (int i = 0; i < bufptr; i++) {
				hexa[i] = buf[i];
			}
			bufptr = 0;
			memset(buf, 0, sizeof(buf));
			generated_code[codeptr++] = (char)strtol(hexa, NULL, 16);
			free(hexa);
            if (code[index] == '\0') {
                break;
            }
		} else {
			buf[bufptr++] = code[index];
		}
		index++;
	}
	spy_run(S, generated_code);
}
