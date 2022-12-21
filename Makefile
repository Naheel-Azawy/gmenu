PREFIX    = /usr/local
BINPREFIX = $(DESTDIR)$(PREFIX)/bin
ICONSDIR  = $(DESTDIR)$(PREFIX)/share/icons/hicolor/scalable/actions

SRC =                              \
	./build/style.vala             \
	./src/utils.vala               \
	./src/core/opts.vala           \
	./src/core/item.vala           \
	./src/core/item_container.vala \
	./src/core/main_window.vala    \
	./src/items/desktops.vala      \
	./src/items/json.vala          \
	./src/items/power.vala         \
	./src/modes/yesno.vala         \
	./src/modes/apps.vala          \
	./src/modes/power.vala         \
	./src/modes/dmenu.vala         \
	./src/main.vala

FLAGS =            \
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

install:
	mkdir -p $(BINPREFIX) $(ICONSDIR)
	cp -f ./build/gmenu $(BINPREFIX)/
	cp -f ./icons/*.svg $(ICONSDIR)/

uninstall:
	rm -f $(BINPREFIX)/gmenu

clean:
	rm -rf ./build

.PHONY: install uninstall clean
