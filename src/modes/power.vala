int run_power(GMenuWin win) {
	if (win.opts.title == null) {
		win.opts.title = "Power";
	}
	win.opts.dims    = "11ix4i";
	win.opts.isize   = 48;
	win.opts.index   = 0;
	win.opts.maxcols = 3;
	win.opts.horiz   = true;

	win.build();
	load_power(win);
	return 0;
}
