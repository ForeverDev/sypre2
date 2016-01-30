spy:
	gcc main.c sapi.c slib.c -llua -lm -o spy
	sudo mv spy /usr/local/bin
