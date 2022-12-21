int main (string[] args) {
	Gtk.init(ref args);
	var win = new GMenuWin();

	string mode = win.opts.args_parse(args);

	int ret;
	switch (mode) {
	case "yesno": ret = run_yesno(win); break;
	case "power": ret = run_power(win); break;
	case "apps":  ret = run_apps(win);  break;
	case "dmenu": ret = run_dmenu(win); break;
	default:      ret = 1;              break;
	}

	if (ret == 0) {
		win.show();
		Gtk.main();
	}

    return ret;
}
