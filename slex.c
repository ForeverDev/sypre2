#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "slex.h"

lex_state* spylex_newstate() {
	lex_state* L = malloc(sizeof(lex_state));
	L->tptr = 0;
	memset(L->tokens, 0, sizeof(L->tokens));
	return L;
}

static inline const s8* lex_stringFromType(lex_state* L, lex_token_type type) {
	static const s8* names[] = {
		"TK_NULL", "TK_PLUS", "TK_MINUS", "TK_MUL", "TK_DIV",
		"TK_OPENPAR", "TK_CLOSEPAR", "TK_OPENSQ", "TK_CLOSESQ",
		"TK_OPENCURL", "TK_CLOSECURL", "TK_STRING", "TK_NUMBER",
		"TK_ARRAY"	
	};
	return names[type];
}

static void lex_dumpTokens(lex_state* L) {
	for (u32 i = 0; i < L->tptr; i++) {
		printf(	"0x%08x:\n\tTYPE: %s\n\tWORD: %s\n\tLINE: %d\n",
				i,
				lex_stringFromType(L, L->tokens[i].type),
				L->tokens[i].word,
				L->tokens[i].line
		);
	}
}

void lex_tokenize(lex_state* L, const s8* src) {
	u8 c;
	u32 srci = 0;
	u32 linecount = 0;
	lex_token t;
	while ((c = src[srci++]) != '\0') {
		t.type = TK_NULL;
		t.word = NULL;
		t.line = linecount;
		switch (c) {
			case '\n':
				linecount++;
				break;
			case ' ':
				break;
			case '(':
				t.type = TK_OPENPAR;
				break;
			case ')':
				t.type = TK_CLOSEPAR;
				break;
			case '[':
				t.type = TK_OPENSQ;
				break;
			case ']':
				t.type = TK_CLOSESQ;
				break;
			case '{':
				t.type = TK_OPENCURL;
				break;
			case '}':
				t.type = TK_CLOSECURL;
				break;
			case '\'':
			case '\"': {
				u32 slen = 0;
				while (src[srci + (slen++)] != c); 
				slen--;
				t.type = TK_STRING;
				t.word = malloc(sizeof(char) * slen);
				for (u32 i = 0; i <= slen; i++) {
					t.word[i] = src[srci++];
				}
				t.word[slen] = '\0';
				break;
			}
		}
		if (t.type != TK_NULL) {
			L->tokens[L->tptr++] = t;
		}
	}
	lex_dumpTokens(L);
}
