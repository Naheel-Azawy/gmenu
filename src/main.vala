
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
	var win = new GMenuWin();
	win.opts.args_parse(args);

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
