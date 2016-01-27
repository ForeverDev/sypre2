spy:
	gcc main.c sapi.c sio.c -llua -lm -o spy
	sudo mv spy /usr/local/bin
