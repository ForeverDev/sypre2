#ifndef __SPARSE_H
#define __SPARSE_H

#include "sinterp.h"
#include "slex.h"

typedef enum parse_node_type {
	N_NULL, N_ROOT,

	N_EXPRESSION,	N_VARDECL,	N_FUNCDECL,
	N_FUNCIMPL
} parse_node_type;

typedef struct parse_node {
	parse_node_type		type;
	u32					line;
	struct parse_node**	inners;
	struct parse_node**	block; 

} parse_node;

typedef struct parse_state {
	parse_node* root;
	lex_token	tokens[1024];
	u32			lexptr;
} parse_state;

parse_state*			spyparse_newstate();
static parse_node*		parse_newnode(parse_node_type);
static parse_node**		parse_expressionUntil(parse_state*, lex_token_type);
void					parse_generateTree(parse_state*, lex_state*);

#endif
