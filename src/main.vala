
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
		new Thread<void>("modes", () => run_mode(win));
		Gtk.main();
	}

	// Not `return win.ret': if stdin is an endless producer (e.g. a
	// shell loop piping live updates forever via the id-based replace
	// feature -- see the README's counter example), the background
	// thread above can be permanently blocked in stdin.read_line() with
	// no further input coming once the window is closed. Confirmed by
	// direct measurement, isolated from GTK and from this thread's own
	// code entirely: a normal return (glibc's exit()) took over 3
	// seconds to actually tear the process down with such a thread still
	// blocked in a slow syscall, while Posix._exit() (straight to the
	// exit_group() syscall, no waiting on other threads) took under
	// 20ms. stdout is flushed first purely as a safety net -- _exit()
	// skips libc's normal stdio flush, and while GLib's print(), which
	// is what actually emits the selected item on stdout, was confirmed
	// safe across _exit() in isolated testing (unlike raw C printf(),
	// which was not), there's no reason to leave that to chance.
	stdout.flush();
	Posix._exit(win.ret);
	return win.ret; // unreachable; satisfies the compiler
}
