build:
	v main.v
windows:
	v -os windows main.v -o ghpkg.exe
linux:
	v -os linux main.v -o ghpkg
clean:
	rm -rf *.bin *.exe
install_prod: prod
	sudo mv ./ghpkg /usr/local/bin/ghpkg
install: linux
	sudo mv ./ghpkg /usr/local/bin/ghpkg
prod:
	v -os linux -prod main.v -o ghpkg
