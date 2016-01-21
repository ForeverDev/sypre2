#include <stdio.h>
#include "sinterp.h"
#include "slex.h"

int main(int argc, char** argv) {

	lex_state* L = spylex_newstate();
	lex_tokenize(L, "'Hello' 'Swag'");

	return 0;
}
