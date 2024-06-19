PREFIX    = /usr/local
BINPREFIX = $(DESTDIR)$(PREFIX)/bin
ICONSDIR  = $(DESTDIR)$(PREFIX)/share/icons/hicolor/scalable/actions

SRC = $(shell find ./src -name '*.vala') \
	./build/style.vala

FLAGS =            \
	-X -w          \
	--pkg posix    \
	--pkg gtk+-3.0 \
	--pkg gee-0.8  \
	--pkg json-glib-1.0

all: ./build/gmenu

./build/style.vala: ./src/style.css
	mkdir -p ./build
	printf 'const string CSS = """\n'  > ./build/style.vala
	cat ./src/style.css               >> ./build/style.vala
	printf '""";\n'                   >> ./build/style.vala

./build/gmenu: $(SRC)
	valac $(FLAGS) $(SRC) -o ./build/gmenu

C: $(SRC)
	valac $(FLAGS) $(SRC) -C

install:
	mkdir -p $(BINPREFIX) $(ICONSDIR)
	cp -f ./build/gmenu $(BINPREFIX)/
	cp -f ./icons/*.svg $(ICONSDIR)/

uninstall:
	rm -f $(BINPREFIX)/gmenu

clean:
	find ./src -name '*.c' -exec rm '{}' \;
	rm -rf ./build

.PHONY: install uninstall clean C
