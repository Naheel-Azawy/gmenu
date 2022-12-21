int run_apps(GMenuWin win) {
	win.build();
	dotdesktop_push_from_dirs(win);
	load_power(win);
	return 0;
}
