build:
	v main.v
windows:
	v -os windows main.v -o main.exe
linux:
	v -os linux main.v -o main.bin
macos:
	v -os macos main.v -o main.app
clean:
	rm -rf *.bin *.exe
install:
	sudo mv ./main.bin /usr/local/bin/ghpkg
