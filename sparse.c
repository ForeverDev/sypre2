#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sparse.h"

parse_state* spyparse_newstate() {
	parse_state* P = malloc(sizeof(parse_state));
	P->root = parse_newnode(P, N_ROOT);
	P->lexptr = 0;
	// tokens assigned later in generateTree
	return P;
}

static parse_node* parse_newnode(parse_state* P, parse_node_type type) {
	parse_node* node = malloc(sizeof(parse_node));
	node->type = type;
	node->block = NULL;
	node->line = 0;
	return node;
}

static parse_node** parse_expressionUntil(parse_state* P, parse_node_type close) {
	parse_node** expression;
	u32 at = P->lexptr;
	u32 explen = 0;
	while (parse_state->tokens[at++].type != close) {
		explen++;
	}
	expression = malloc(sizeof(parse_node*) * explen);
	for (u32 i = P->lexptr; i < at; i++) {
		
	}
	return expression;
}

void parse_generateTree(parse_state* P, lex_state* L) {
	u32 tkcount = 0;
	while (L->tokens[tkcount].type != TK_EOF) {
		P->tokens[tkcount] = L->tokens[tkcount];
		tkcount++;
	}
	for (u32 i = 0; i < tkcount; i++) {
			
	}
}
