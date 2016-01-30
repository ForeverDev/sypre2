#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <unistd.h>
#include "sinterp.c"

#define MASK_COMPILE	0x01
#define MASK_RUN		0x02
#define MASK_DOBOTH		0x04
#define MASK_NOOPT		0x08
#define MASK_OUTPUT		0x10

static void run_file(const char* inputfn) {
	spy_state* S = spy_newstate();
	spy_executeBinaryFile(S, inputfn);
}

static void compile_file(const char* inputfn, const char* outputfn) {
	char cwd[1024];
	lua_State* L;

	getcwd(cwd, sizeof(cwd));

	L = luaL_newstate();
	luaL_openlibs(L);
	if (luaL_dofile(L, "/usr/local/share/spyre/spyre.lua")) {
		printf("\nSPYRE ERROR: could not run compiler (spyre.lua)\n\n");
		return;
	}
	// push entry point
	lua_getglobal(L, "main");
	// push file to be compiled
	lua_pushstring(L, inputfn);
	// push file name
	lua_pushstring(L, outputfn);
	// push cur dir
	lua_pushstring(L, cwd);
	// call entry point

	if (lua_pcall(L, 3, 0, 0)) {
		printf("\nSPYRE ERROR: compiler lua error:\n");
		printf("\t%s\n\n", lua_tostring(L, -1));
	}

}

static void do_file(const char* inputfn) {
	const char* temp = ".tmp_spyre_bytecode.spyb";
	compile_file(inputfn, temp);
	run_file(temp);
	remove(temp);
}

int main(int argc, char** argv) {

	unsigned int args = 0;
	unsigned int i = 1;
	char outputfn[128];
	char inputfn[128];
	char soloarg[128];

	memset(outputfn, 0, 128);
	memset(inputfn, 0, 128);
	memset(soloarg, 0, 128);

	for (; i < argc; i++) {
		if (!strncmp(argv[i], "-noopt", 6)) {
			args |= MASK_NOOPT;
		} else if (!strncmp(argv[i], "-c", 2)) {
			args |= MASK_COMPILE;
			memcpy(inputfn, argv[++i], 128);
		} else if (!strncmp(argv[i], "-r", 2)) {
			args |= MASK_RUN;
			memcpy(inputfn, argv[++i], 128);
		} else if (!strncmp(argv[i], "-o", 2)) {
			args |= MASK_OUTPUT;
			memcpy(outputfn, argv[++i], 128);
		} else {
			memcpy(soloarg, argv[i], 128);
		}
	}
	
	if (args & MASK_COMPILE) {
		compile_file(inputfn, (args & MASK_OUTPUT) ? outputfn : "a.spyb");
    } else if (args & MASK_RUN) {
		run_file(inputfn);
    } else {
		do_file(soloarg);
	}

    return 0;
}
