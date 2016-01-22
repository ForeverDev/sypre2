#include <stdio.h>
#include <stdlib.h>
#include "sinterp.h"
#include "slex.h"

int main(int argc, char** argv) {

	if (argc <= 2) {
		// todo print usage
		return 1;
	}

	if (argv[1][0] == 'c') {
		FILE* input;
		char* src;
		unsigned long long file_size;

        input = fopen(argv[2], "r");
        if (input == NULL) {
            printf("SPYRE: attempt to run non-existant bytecode file '%s'\n", argv[2]);
            return 1;
        }
        fseek(input, 0, SEEK_END);
        file_size = (unsigned long long)ftell(input);
        rewind(input);
        src = malloc(file_size);
        fread(src, sizeof(char), file_size, input);
        src[file_size] = '\0';
        fclose(input);

		lex_state* L = spylex_newstate();
		lex_tokenize(L, src);

	}

	return 0;
}
