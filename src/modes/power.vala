int run_power(GMenuWin win) {
	// TODO: you need better units
	if (win.opts.isize == 64) {
		win.opts.dims = "8.5ix3.7i";
	} else {
		win.opts.dims = "11ix4i";
	}
	win.opts.index   = 0;
	win.opts.maxcols = 3;
	win.opts.horiz   = true;

	win.build();
	load_power(win);
	return 0;
}
