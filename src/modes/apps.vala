int run_apps(GMenuWin win) {
	if (win.opts.title == null) {
		win.opts.title = "Apps";
	}
	win.build();
	dotdesktop_push_from_dirs(win);
	load_power(win);
	return 0;
}
