int run_power(GMenuWin win) {
	win.opts.dims    = "8.5ix3.7i";
	win.opts.index   = 0;
	win.opts.maxcols = 3;
	win.opts.horiz   = true;

	win.build();
	load_power(win);
	return 0;
}
