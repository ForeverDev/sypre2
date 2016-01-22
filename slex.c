#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "slex.h"

lex_state* spylex_newstate() {
	lex_state* L = malloc(sizeof(lex_state));
	L->tptr = 0;
	memset(L->tokens, 0, sizeof(L->tokens));
	return L;
}

// for debugging purposes
static inline const s8* lex_stringFromType(lex_state* L, lex_token_type type) {
	static const s8* names[] = {
		"TK_NULL", "TK_PLUS", "TK_MINUS", "TK_MUL", "TK_DIV",
		"TK_OPENPAR", "TK_CLOSEPAR", "TK_OPENSQ", "TK_CLOSESQ",
		"TK_OPENCURL", "TK_CLOSECURL", "TK_SEMICOLON", "TK_COLON",
		"TK_ASSIGN", "TK_REASSIGN", "TK_EQUAL",

		"TK_STRING", "TK_NUMBER", "TK_ARRAY", "TK_NAME",
		
		"TK_IF", "TK_ELSE", "TK_ELIF", "TK_WHILE", "TK_FOR",
		"TK_FUNC", "TK_DO", "TK_RETURN",
		
		"TK_ID",

		"TK_EOF"
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

static void lex_identifyKeyword(lex_state* L, lex_token* t) {
	if (!strcmp(t->word, "if")) {
		t->type = TK_IF;
	} else if (!strcmp(t->word, "else")) {
		t->type = TK_ELSE;
	} else if (!strcmp(t->word, "elseif")) {
		t->type = TK_ELIF;
	} else if (!strcmp(t->word, "while")) {
		t->type = TK_WHILE;
	} else if (!strcmp(t->word, "for")) {
		t->type = TK_FOR;
	} else if (!strcmp(t->word, "func")) {
		t->type = TK_FUNC;
	} else if (!strcmp(t->word, "do")) {
		t->type = TK_DO;
	} else if (!strcmp(t->word, "return")) {
		t->type = TK_RETURN;
	} else {
		t->type = TK_ID;
	}
}

#define peek(n) (src[srci + (n) - 1])

void lex_tokenize(lex_state* L, const s8* src) {
	u8 c;
	u32 srci = 0;
	u32 linecount = 1;
	lex_token t;
	while ((c = src[srci++]) != '\0') {
		t.type = TK_NULL;
		t.word = NULL;
		t.line = linecount;
		switch (c) {
			case '\0':
				t.type = TK_EOF;
				break;
			case '\n':
				linecount++;
				break;
			case ' ':
			case '\t':
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
			case '+':
				t.type = TK_PLUS;
				break;
			case '-':
				t.type = TK_MINUS;
				break;
			case '*':
				t.type = TK_MUL;
				break;
			case '/':
				t.type = TK_DIV;
				break;
			case ';':
				t.type = TK_SEMICOLON;
				break;
			case ':':
				if (peek(1) == '=') {
					t.type = TK_ASSIGN;
					srci++;
				} else {
					t.type = TK_COLON;
				}
				break;
			case '=':
				if (peek(1) == '=') {
					t.type = TK_EQUAL;
					srci++;
				} else {
					t.type = TK_REASSIGN;
				}
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
			// identifier or keyword or number
			default: {
				u32 idlen = 0;
				while (isalnum(src[srci + (idlen++)]));
				t.type = TK_NAME;
				t.word = malloc(sizeof(char) * idlen);
				t.word[0] = c;
				for (u32 i = 1; i < idlen; i++) {
					t.word[i] = src[srci++];
				}
				t.word[idlen] = '\0';
				lex_identifyKeyword(L, &t);
				break;
			}

		}
		if (t.type != TK_NULL) {
			L->tokens[L->tptr++] = t;
		}
	}
	t.type = TK_EOF;
	t.word = NULL;
	L->tokens[L->tptr++] = t;
	lex_dumpTokens(L);
}
