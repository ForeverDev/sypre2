#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

int main(int argc, char** argv) {

	if (argc <= 2) {
		// todo print usage
		return 1;
	}

	if (argv[1][0] == 'c') {
		FILE* input;
		char* src;
		unsigned long long file_size;
        lua_State* L;

        // read source contents
        input = fopen(argv[2], "r");
        if (input == NULL) {
            printf("\nSPYRE ERROR: attempt to compile non-existant file '%s'\n\n", argv[2]);
            return 1;
        }
        fseek(input, 0, SEEK_END);
        file_size = (unsigned long long)ftell(input);
        rewind(input);
        src = malloc(file_size);
        fread(src, sizeof(char), file_size, input);
        src[file_size] = '\0';
        fclose(input);

        // hand to lua compiler
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
	}

    return 0;
}
