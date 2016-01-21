#ifndef __SLEX_H
#define __SLEX_H

#include "sinterp.h"

typedef enum tag_token_type {
	TK_NULL = 0,
	TK_PLUS,		TK_MINUS,		TK_MUL,			TK_DIV,
	TK_OPENPAR,		TK_CLOSEPAR,	TK_OPENSQ,		TK_CLOSESQ,
	TK_OPENCURL,	TK_CLOSECURL,	TK_STRING,		TK_NUMBER,
	TK_ARRAY,		TK_NAME
} lex_token_type;

typedef struct tag_token {
	lex_token_type	type;
	u8*				word;
	u32				line;
} lex_token;

typedef struct tag_lex_state {
	lex_token	tokens[1024];
	u32			tptr;
} lex_state;

lex_state*				spylex_newstate();
void					lex_tokenize(lex_state*, const s8*);
static inline const s8*	lex_stringFromType(lex_state*, lex_token_type);
static void				lex_dumpTokens(lex_state*);

#endif
