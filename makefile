spy:
	gcc main.c sapi.c slib.c -llua -lm -o spy
	sudo cp -R . /usr/local/share/spyre
	sudo mv spy /usr/local/bin
