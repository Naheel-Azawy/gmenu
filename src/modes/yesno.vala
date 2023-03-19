delegate void OnYesNoAns(bool yes);

int run_yesno(GMenuWin win, string? q=null, OnYesNoAns? onans=null) {
	if (win.opts.prompt == null) {
		win.opts.prompt   = q == null ? "Are you sure?" : q + "?";
	}
	win.opts.dims     = "20%x1%";
	win.opts.index    = 0;
	win.opts.isize    = 0;
	win.opts.maxcols  = 2;
	win.opts.horiz    = true;
	win.opts.nosearch = true;
	win.opts.css      = "flowboxchild:selected {" +
		"background-color: rgba(255, 0, 0, 0.7);" +
		"color: black;" +
		"}";

	win.build();
	win.onlaunch = item => {
		bool yes = item.name == "Yes";
		if (onans != null) {
			onans(yes);
		} else {
			Process.exit(yes ? 0 : 1);
		}
		return true;
	};

	win.push(new Item("Yes"));
	win.push(new Item("No"));

	return 0;
}
