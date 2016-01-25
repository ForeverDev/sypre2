#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include "sinterp.c"

int main(int argc, char** argv) {

	if (argc <= 2) {
		// todo print usage
		return 1;
	}

	if (argv[1][0] == 'c') {
		FILE* output;
        char* filename;
        const char* bytecode;
        lua_State* L;

        L = luaL_newstate();
        luaL_openlibs(L);
        if (luaL_dofile(L, "spyre.lua")) {
            printf("\nSPYRE ERROR: could not run compiler (spyre.lua)\n\n");
            return 1;
        }
        // push entry point
        lua_getglobal(L, "main");
        // push file to be compiled
        lua_pushstring(L, argv[2]);
        // call entry point
        if (lua_pcall(L, 1, 1, 0)) {
            printf("\nSPYRE ERROR: compiler lua error:\n");
            printf("\t%s\n\n", lua_tostring(L, -1));
        }

        bytecode = lua_tostring(L, -1);
        lua_pop(L, -1);
        filename = malloc(sizeof(argv[3]));
        strcpy(filename, argv[3]);
        output = fopen(filename, "w");
        if (output == NULL) {
            printf("SPYRE: could not compile file '%s'\n", filename);
            return 1;
        }
        fputs(bytecode, output);
        fclose(output);
        free(filename);
    } else if (argv[1][0] == 'r') {
        FILE* input;
        char* bytecode;
        unsigned long long file_size;
        spy_state* S;

        input = fopen(argv[2], "r");
        if (input == NULL) {
            printf("SPYRE: attempt to run non-existant bytecode file '%s'\n", argv[2]);
            return 1;
        }
        fseek(input, 0, SEEK_END);
        file_size = (unsigned long long)ftell(input);
        rewind(input);
        bytecode = malloc(file_size);
        fread(bytecode, sizeof(char), file_size, input);
        bytecode[file_size] = '\0';
        fclose(input);

        if (!strncmp(argv[1], "du", 2)) {
            printf("\nSPYRE: bytecode dump:\n%s\n\n", bytecode);
            return 1;
        }

        S = spy_newstate();
        spy_runFromString(S, bytecode);
        spy_dumpMemory(S);

        free(bytecode);
        free(S);
    }

    return 0;
}
