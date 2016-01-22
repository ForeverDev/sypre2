#ifndef __SLEX_H
#define __SLEX_H

#include "sinterp.h"

typedef enum lex_token_type {
	// OPERATORS / NON-KEYWORDS
	TK_NULL = 0,
	TK_PLUS,		TK_MINUS,		TK_MUL,			TK_DIV,
	TK_OPENPAR,		TK_CLOSEPAR,	TK_OPENSQ,		TK_CLOSESQ,
	TK_OPENCURL,	TK_CLOSECURL,	TK_SEMICOLON,	TK_COLON,
	TK_ASSIGN,		TK_REASSIGN,	TK_EQUAL,
	
	TK_STRING,		TK_NUMBER,		TK_ARRAY,		TK_NAME,
	// KEYWORDS
	TK_IF,			TK_ELSE,		TK_ELIF,		TK_WHILE,
	TK_FOR,			TK_FUNC,		TK_DO,			TK_RETURN,
	TK_ID,

	TK_EOF
} lex_token_type;

typedef struct lex_token {
	lex_token_type	type;
	s8*				word;
	u32				line;
} lex_token;

typedef struct lex_state {
	lex_token	tokens[1024];
	u32			tptr;
} lex_state;

lex_state*				spylex_newstate();
void					lex_tokenize(lex_state*, const s8*);
static inline const s8*	lex_stringFromType(lex_state*, lex_token_type);
static void				lex_dumpTokens(lex_state*);
static void				lex_identifyKeyword(lex_state*, lex_token*);

#endif
