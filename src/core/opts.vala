class Opts {
	public string mode     = "dmenu";
	public string title    = null;
	public string prompt   = null;
	public string dims     = null; // auto
	public string css      = null;
	public int    index    = -1; // none
	public int    isize    = -1; // auto
	public int    maxcols  = 7;
	public int    maxlbl   = -1; // auto
	public bool   horiz    = false;
	public bool   center   = false;
	public bool   notooltip = false;
	public bool   nosearch = false;
	public bool   stay     = false;
	public bool   solid    = false;
	public bool   full     = false;
	public bool   sync     = false;

	// -l/--list is detected by a pre-scan in args_parse() before real
	// parsing starts (see there); this field only exists so GOption still
	// recognizes and consumes the flag -- its value here is otherwise unused
	private bool list = false;

	// -nb/-nf/-sb/-sf became long options (GOption has no "-nb"-style short
	// option, i.e. more than one letter after a single dash); their values
	// are folded into `css' once parsing is done
	private string nb_color = null;
	private string nf_color = null;
	private string sb_color = null;
	private string sf_color = null;

	// bare, non-option words: the command (apps/power/yesno) and, for
	// dmenu's `-l N' compatibility, a trailing item count that we accept
	// and ignore
	[CCode (array_length = false, array_null_terminated = true)]
	private string[]? remaining = null;

	public void auto_set(int screen_width) {
		if (screen_width >= 1920) {
			if (this.isize == -1)
				this.isize = 64;
			if (this.maxlbl == -1)
				this.maxlbl = 15;
		} else {
			if (this.isize == -1)
				this.isize = 48;
			if (this.maxlbl == -1)
				this.maxlbl = 10;
		}
	}

	public string? args_parse(string[] args) {
		this.mode = "dmenu";

		// --list/-l is a shorthand that presets several fields below; it
		// must be detected and applied *before* the real parse so that an
		// explicit flag (e.g. -d) always overrides it, in either order on
		// the command line -- matching what a preset is supposed to mean
		foreach (unowned string tok in args) {
			if (tok == "-l" || tok == "--list") {
				this.dims    = "30%x50%";
				this.index   = 0;
				this.isize   = 0;
				this.horiz   = true;
				this.maxcols = 1;
				this.maxlbl  = 1000;
				break;
			}
		}

		var ctx = new GLib.OptionContext("<CMD>");
		// GOption's own help binds --help and -? (confirmed against this
		// GLib: -h is left free), so it coexists with our -h (--horiz) and
		// there is no need to handle --help by hand any more
		ctx.set_summary(
			"Commands:\n" +
			"  apps    show desktop files from default directories\n" +
			"  power   system power options\n" +
			"  yesno   yes/no prompt\n" +
			"  (NONE)  dmenu-like behavior");
		ctx.set_description(
			"Input:\n" +
			"  stdin can be any of the following when the command is (NONE)\n" +
			"  >>j, >>json STR           insert json string\n" +
			"  >>jfile, >>json-file STR  insert json file\n" +
			"  >>power                   insert power options\n" +
			"  >>desktops <STR>          insert desktop files at optional directory\n" +
			"\n" +
			"Dims:\n" +
			"              pixels by default\n" +
			"  `%':        percent of the current screen geometry\n" +
			"  `i':        percent of the icon size\n" +
			"  `min(...)': minimum of two values\n" +
			"  `max(...)': maximum of two values\n" +
			"  Example:    `-d 'min(800, 90%)*max(80%, 600)'`");

		GLib.OptionEntry[] entries = {
			{ "title",     0,   OptionFlags.NONE, OptionArg.STRING,      ref this.title,     "title of the menu", "STR" },
			{ "prompt",    'p', OptionFlags.NONE, OptionArg.STRING,      ref this.prompt,    "prompt of the menu", "STR" },
			{ "dims",      'd', OptionFlags.NONE, OptionArg.STRING,      ref this.dims,      "dimensions of the window", "DIM" },
			{ "css",       's', OptionFlags.NONE, OptionArg.STRING,      ref this.css,       "CSS file or string", "STR" },
			{ "nb",        0,   OptionFlags.NONE, OptionArg.STRING,      ref this.nb_color,  "normal item background color", "STR" },
			{ "nf",        0,   OptionFlags.NONE, OptionArg.STRING,      ref this.nf_color,  "normal item foreground color", "STR" },
			{ "sb",        0,   OptionFlags.NONE, OptionArg.STRING,      ref this.sb_color,  "selected item background color", "STR" },
			{ "sf",        0,   OptionFlags.NONE, OptionArg.STRING,      ref this.sf_color,  "selected item foreground color", "STR" },
			{ "index",     'n', OptionFlags.NONE, OptionArg.INT,         ref this.index,     "index of initially selected item", "INT" },
			{ "isize",     'i', OptionFlags.NONE, OptionArg.INT,         ref this.isize,     "icon size (0 to disable icons)", "INT" },
			{ "maxcols",   'c', OptionFlags.NONE, OptionArg.INT,         ref this.maxcols,   "maximum number of columns", "INT" },
			{ "maxlbl",    0,   OptionFlags.NONE, OptionArg.INT,         ref this.maxlbl,    "maximum length of characters in item's names", "INT" },
			{ "horiz",     'h', OptionFlags.NONE,    OptionArg.NONE,     ref this.horiz,     "layout items horizontally", null },
			{ "no-horiz",  0,   OptionFlags.REVERSE, OptionArg.NONE,     ref this.horiz,     "layout items vertically (undoes --horiz)", null },
			{ "center",    0,   OptionFlags.NONE,    OptionArg.NONE,     ref this.center,    "center text", null },
			{ "no-center", 0,   OptionFlags.REVERSE, OptionArg.NONE,     ref this.center,    "don't center text (undoes --center)", null },
			{ "list",      'l', OptionFlags.NONE,    OptionArg.NONE,     ref this.list,      "-d '30%x50%' -n 0 -i 0 -h -c 1 --maxlbl 1000", null },
			{ "notooltip", 0,   OptionFlags.NONE,    OptionArg.NONE,     ref this.notooltip, "no tooltip", null },
			{ "tooltip",   0,   OptionFlags.REVERSE, OptionArg.NONE,     ref this.notooltip, "show tooltip (undoes --notooltip)", null },
			{ "nosearch",  0,   OptionFlags.NONE,    OptionArg.NONE,     ref this.nosearch,  "no search bar", null },
			{ "search",    0,   OptionFlags.REVERSE, OptionArg.NONE,     ref this.nosearch,  "show search bar (undoes --nosearch)", null },
			{ "stay",      0,   OptionFlags.NONE,    OptionArg.NONE,     ref this.stay,      "prevent quitting when out of focus", null },
			{ "no-stay",   0,   OptionFlags.REVERSE, OptionArg.NONE,     ref this.stay,      "quit when out of focus (undoes --stay)", null },
			{ "solid",     0,   OptionFlags.NONE,    OptionArg.NONE,     ref this.solid,     "disable transparency", null },
			{ "no-solid",  0,   OptionFlags.REVERSE, OptionArg.NONE,     ref this.solid,     "enable transparency (undoes --solid)", null },
			{ "full",      0,   OptionFlags.NONE,    OptionArg.NONE,     ref this.full,      "fullscreen window", null },
			{ "no-full",   0,   OptionFlags.REVERSE, OptionArg.NONE,     ref this.full,      "windowed, not fullscreen (undoes --full)", null },
			{ "sync",      0,   OptionFlags.NONE,    OptionArg.NONE,     ref this.sync,      "wait for all input before showing", null },
			{ "no-sync",   0,   OptionFlags.REVERSE, OptionArg.NONE,     ref this.sync,      "don't wait for all input (undoes --sync)", null },
			// collects the bare command (apps/power/yesno) plus, for
			// dmenu's `-l N' compatibility, any trailing number
			{ GLib.OPTION_REMAINING, 0, OptionFlags.NONE, OptionArg.STRING_ARRAY, ref this.remaining, null, null },
			{ null }
		};
		ctx.add_main_entries(entries, null);

		// Legacy single-dash spellings of these four flags predate GOption
		// (which only allows a single character after one dash); rewritten
		// to their long form here, silently, so old callers keep working
		string[] argv_pre = new string[args.length];
		for (int i = 0; i < args.length; ++i) {
			switch (args[i]) {
			case "-nb": argv_pre[i] = "--nb"; break;
			case "-nf": argv_pre[i] = "--nf"; break;
			case "-sb": argv_pre[i] = "--sb"; break;
			case "-sf": argv_pre[i] = "--sf"; break;
			default:    argv_pre[i] = args[i];  break;
			}
		}

		unowned string[] argv = argv_pre;
		try {
			ctx.parse(ref argv);
		} catch (GLib.OptionError e) {
			// --help/-? is handled by GOption itself and exits before this
			// point is reached; this branch is for actual usage errors
			stderr.printf("%s\n", e.message);
			print("%s", ctx.get_help(true, null));
			return null;
		}

		foreach (unowned string tok in this.remaining ?? new string[]{}) {
			if (tok == "yesno" || tok == "power" || tok == "apps") {
				this.mode = tok;
			} else if (int.try_parse(tok)) {
				// dmenu's `-l N': N is accepted for compatibility, ignored
				continue;
			} else {
				stderr.printf("Unknown argument: %s\n", tok);
				print("%s", ctx.get_help(true, null));
				return null;
			}
		}

		if (this.nb_color != null) {
			if (this.css == null) this.css = "";
			this.css += "flowboxchild {" +
				"background-color: " + this.nb_color + ";" +
				"}";
		}
		if (this.nf_color != null) {
			if (this.css == null) this.css = "";
			this.css += "flowboxchild {" +
				"color: " + this.nf_color + ";" +
				"}";
		}
		if (this.sb_color != null) {
			if (this.css == null) this.css = "";
			this.css += "flowboxchild:selected {" +
				"background-color: " + this.sb_color + ";" +
				"}";
		}
		if (this.sf_color != null) {
			if (this.css == null) this.css = "";
			this.css += "flowboxchild:selected {" +
				"color: " + this.sf_color + ";" +
				"}";
		}

		return this.mode;
	}
}
