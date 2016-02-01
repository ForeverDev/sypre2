spy:
	gcc main.c sapi.c slib.c -llua -ldl -lm -std=c11 -o spy
	sudo mv spy /usr/local/bin
