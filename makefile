build:
	v main.v
windows:
	v -os windows main.v -o main.exe
linux:
	v -os linux main.v -o ghpkg
clean:
	rm -rf *.bin *.exe
install:
	sudo mv ./main.bin /usr/local/bin/ghpkg
