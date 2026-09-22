
bool main_ended = false;

void main_end() {
	main_ended = true;
	Gtk.main_quit();
}

void run_mode(GMenuWin win) {
	switch (win.opts.mode) {
	case "yesno": win.ret = run_yesno(win); break;
	case "power": win.ret = run_power(win); break;
	case "apps":  win.ret = run_apps(win);  break;
	case "dmenu": win.ret = run_dmenu(win); break;
	default:      win.ret = 1;              break;
	}
	win.loading_end();
}

int main(string[] args) {
	Gtk.init(ref args);

	// Parsed here, before any window exists, and handed to `win' below --
	// not parsed via `win.opts.args_parse()' after `new GMenuWin()', as
	// before -- because Gdk.set_program_class() only affects windows
	// constructed after it runs. GTK captures the program class into a
	// Gtk.Window at *construction* time, not at realize/show time, so it
	// has no effect once any window -- even one still unshown -- already
	// exists, and `new GMenuWin()' constructs one immediately, since
	// GMenuWin extends Gtk.Window.
	var opts = new Opts();
	if (opts.args_parse(args) == null) {
		return -1;
	}

	if (!opts.floating) {
		// "floating" is gmenu's own choice; it isn't reflected in any
		// standard X property a tool like a compositor could match on by
		// itself. Give --nofloating windows a distinct WM_CLASS (stays at
		// GTK's default, "gmenu"/"Gmenu", when floating) so window rules
		// -- e.g. a picom rounded-corners-exclude rule -- can target one
		// and not the other. gdk_set_program_class() only changes the
		// class component (instance stays "gmenu"), and, unlike the
		// deprecated Gtk.Window.set_wmclass(), applies process-wide, so
		// it must run once, here, before any window (including a later
		// confirmation dialog) is created -- not per-window.
		Gdk.set_program_class("Gmenu-tiled");
	}

	var win = new GMenuWin();
	win.opts = opts;

	if (win.opts.sync) {
		run_mode(win);
		Gtk.main();
	} else {
		var thr = new Thread<void>("modes", () => run_mode(win));
		Gtk.main();
		thr.join();
	}
	return win.ret;
}
