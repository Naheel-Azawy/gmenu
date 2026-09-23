// Settings sourced from the environment (GMENU_-prefixed), not the
// command line. Each var, its one-line description, and its default are
// defined exactly once, here; Opts's constructor and args_parse()'s
// --help text (see env_vars_help() below) both read from this table
// instead of repeating the name/description/default themselves.
// GMENU_EDITOR's default is "": it has no real fallback string, since
// unset means "defer to $EDITOR, then autodetection" (see utils.vala's
// get_editor()) rather than a fixed command.
struct EnvVar {
	public string name;
	public string def;
	public string desc;
}

const EnvVar[] ENV_VARS = {
	{ "GMENU_PKG_QUERY_CMD",       "pacman -Qo",          "command to find which package owns a file" },
	{ "GMENU_PKG_UNINSTALL_CMD",   "sudo pacman -R",      "command to remove a package (its name is appended)" },
	{ "GMENU_EDITOR",              "",                    "preferred editor, overriding $EDITOR and autodetection" },
	{ "GMENU_POWER_SLEEP_CMD",     "systemctl suspend",   "command the power menu's Sleep action runs" },
	{ "GMENU_POWER_SHUTDOWN_CMD",  "systemctl poweroff",  "command the power menu's Shutdown action runs" },
	{ "GMENU_POWER_RESTART_CMD",   "systemctl reboot",    "command the power menu's Restart action runs" },
	{ "GMENU_POWER_HIBERNATE_CMD", "systemctl hibernate", "command the power menu's Hibernate action runs" },
	{ "GMENU_POWER_LOGOUT_CMD",    "ndg wm end",          "command the power menu's Logout action runs" },
	{ "GMENU_POWER_LOCK_CMD",      "ndg lockscreen",      "command the power menu's Lock action runs" },
};

// The value of `name', from the environment if set, else ENV_VARS' own
// default for it.
private string env_or_default(string name) {
	foreach (var v in ENV_VARS) {
		if (v.name == name) return Environment.get_variable(name) ?? v.def;
	}
	assert_not_reached();
}

// Renders ENV_VARS as an "Environment:" --help section.
private string env_vars_help() {
	int width = 0;
	foreach (var v in ENV_VARS) {
		if (v.name.length > width) width = v.name.length;
	}
	var sb = new StringBuilder("Environment:\n");
	foreach (var v in ENV_VARS) {
		sb.append("  %-*s  %s (default: %s)\n".printf(
			width, v.name, v.desc, v.def == "" ? "none" : v.def));
	}
	return sb.str[:-1];
}

// Which CLI flags (by their `entries()' long_name) can also be changed
// mid-session from stdin via `:: cmd=set key=value'; see Opts.set_live()
// and GMenuWin.set_live_opt(). A deliberately curated subset, not "every
// flag": e.g. solid (a window's GdkVisual can't be swapped once it's
// realized), nosearch (would mean creating a widget that was never
// built), sync/floating/mode/list (decided once, before or at window
// creation, with no live equivalent) are all left out on purpose.
// dmenu.vala's frag_key_known() also reads this, so a name only ever
// needs to be added here once.
const string[] LIVE_SETTABLE = {
	"title", "dims", "css", "maxcols", "index",
	"isize", "maxlbl", "center", "horiz",
	"stay", "notooltip", "full",
};

private string live_settable_help() {
	return string.joinv(", ", LIVE_SETTABLE);
}

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
	public bool   floating = true; // --nofloating disables the resizable-toggle trick in main_window.vala's show_win()

	// Populated in the constructor below from ENV_VARS (defined above
	// class Opts) -- see there for names, descriptions and defaults.
	// valac 0.56 also crashes internally on a field initializer using
	// `??' (`vala_expression_insert_statement: assertion "block != NULL"
	// failed'), so these are set as ordinary statements, not inline.
	public string  pkg_query_cmd;
	public string  pkg_uninstall_cmd;
	public string? editor; // null: no override, see ENV_VARS' entry for it
	public string  power_sleep_cmd;
	public string  power_shutdown_cmd;
	public string  power_restart_cmd;
	public string  power_hibernate_cmd;
	public string  power_logout_cmd;
	public string  power_lock_cmd;

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

	// The single source of truth for every CLI flag: name, short letter,
	// type, and which field it writes. Its `ref' bindings point at this
	// Opts instance's own fields, so it's built once, here, rather than
	// as a `const' (impossible: a `const' can't reference `this' at
	// all) or rebuilt on every use. Reused both for real CLI parsing in
	// args_parse() and for live, stdin-driven changes in set_live()
	// below -- one definition instead of two.
	private GLib.OptionEntry[] _entries;

	public Opts() {
		this.pkg_query_cmd     = env_or_default("GMENU_PKG_QUERY_CMD");
		this.pkg_uninstall_cmd = env_or_default("GMENU_PKG_UNINSTALL_CMD");
		this.editor             = Environment.get_variable("GMENU_EDITOR");
		this.power_sleep_cmd     = env_or_default("GMENU_POWER_SLEEP_CMD");
		this.power_shutdown_cmd  = env_or_default("GMENU_POWER_SHUTDOWN_CMD");
		this.power_restart_cmd   = env_or_default("GMENU_POWER_RESTART_CMD");
		this.power_hibernate_cmd = env_or_default("GMENU_POWER_HIBERNATE_CMD");
		this.power_logout_cmd    = env_or_default("GMENU_POWER_LOGOUT_CMD");
		this.power_lock_cmd      = env_or_default("GMENU_POWER_LOCK_CMD");

		this._entries = {
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
			{ "nohoriz",   0,   OptionFlags.REVERSE, OptionArg.NONE,     ref this.horiz,     "layout items vertically (undoes --horiz)", null },
			{ "center",    0,   OptionFlags.NONE,    OptionArg.NONE,     ref this.center,    "center text", null },
			{ "nocenter",  0,   OptionFlags.REVERSE, OptionArg.NONE,     ref this.center,    "don't center text (undoes --center)", null },
			{ "list",      'l', OptionFlags.NONE,    OptionArg.NONE,     ref this.list,      "-d '30%x50%' -n 0 -i 0 -h -c 1 --maxlbl 1000", null },
			{ "notooltip", 0,   OptionFlags.NONE,    OptionArg.NONE,     ref this.notooltip, "no tooltip", null },
			{ "tooltip",   0,   OptionFlags.REVERSE, OptionArg.NONE,     ref this.notooltip, "show tooltip (undoes --notooltip)", null },
			{ "nosearch",  0,   OptionFlags.NONE,    OptionArg.NONE,     ref this.nosearch,  "no search bar", null },
			{ "search",    0,   OptionFlags.REVERSE, OptionArg.NONE,     ref this.nosearch,  "show search bar (undoes --nosearch)", null },
			{ "stay",      0,   OptionFlags.NONE,    OptionArg.NONE,     ref this.stay,      "prevent quitting when out of focus", null },
			{ "nostay",    0,   OptionFlags.REVERSE, OptionArg.NONE,     ref this.stay,      "quit when out of focus (undoes --stay)", null },
			{ "solid",     0,   OptionFlags.NONE,    OptionArg.NONE,     ref this.solid,     "disable transparency", null },
			{ "nosolid",   0,   OptionFlags.REVERSE, OptionArg.NONE,     ref this.solid,     "enable transparency (undoes --solid)", null },
			{ "full",      0,   OptionFlags.NONE,    OptionArg.NONE,     ref this.full,      "fullscreen window", null },
			{ "nofull",    0,   OptionFlags.REVERSE, OptionArg.NONE,     ref this.full,      "windowed, not fullscreen (undoes --full)", null },
			{ "floating",   0,  OptionFlags.NONE,    OptionArg.NONE,     ref this.floating,  "float the window in tiling window managers (default)", null },
			{ "nofloating", 0,  OptionFlags.REVERSE, OptionArg.NONE,     ref this.floating,  "tile normally in tiling window managers (undoes --floating; implies --stay)", null },
			{ "sync",      0,   OptionFlags.NONE,    OptionArg.NONE,     ref this.sync,      "wait for all input before showing", null },
			{ "nosync",    0,   OptionFlags.REVERSE, OptionArg.NONE,     ref this.sync,      "don't wait for all input (undoes --sync)", null },
			// collects the bare command (apps/power/yesno) plus, for
			// dmenu's `-l N' compatibility, any trailing number
			{ GLib.OPTION_REMAINING, 0, OptionFlags.NONE, OptionArg.STRING_ARRAY, ref this.remaining, null, null },
			{ null }
		};
	}

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

	// The "false"-setting flag name for each of LIVE_SETTABLE's boolean
	// (OptionArg.NONE) entries; the "true"-setting name is always the
	// key itself, since that is how every REVERSE pair in entries() was
	// built. Null for a key that isn't one of these five, or isn't
	// boolean at all.
	private static string? neg_flag_name(string key) {
		switch (key) {
		case "stay":      return "nostay";
		case "notooltip": return "tooltip";
		case "full":      return "nofull";
		case "center":    return "nocenter";
		case "horiz":     return "nohoriz";
		default:          return null;
		}
	}

	// Changes one field, by its entries() long_name, the same way a CLI
	// flag would -- reusing entries() itself for the actual parsing and
	// type coercion, rather than a second hand-written setter per field.
	// False if `key' isn't in LIVE_SETTABLE, or `value' doesn't parse.
	public bool set_live(string key, string value) {
		bool known = false;
		foreach (var k in LIVE_SETTABLE) if (k == key) known = true;
		if (!known) return false;

		OptionArg? kind = null;
		foreach (var e in this._entries) {
			if (e.long_name == key) { kind = e.arg; break; }
		}
		if (kind == null) return false;

		string[] argv_owned;
		if (kind == OptionArg.NONE) {
			// booleans take no "=value" in GOption's own grammar; drive
			// the existing flag/reverse-flag pair instead
			string flag;
			if (value == "true") {
				flag = key;
			} else if (value == "false") {
				var neg = neg_flag_name(key);
				if (neg == null) return false;
				flag = neg;
			} else {
				return false;
			}
			argv_owned = { "", "--" + flag };
		} else {
			argv_owned = { "", "--" + key + "=" + value };
		}

		var ctx = new GLib.OptionContext();
		ctx.set_help_enabled(false); // a stdin-driven "--help"/"-?" must never fire
		ctx.add_main_entries(this._entries, null);

		unowned string[] argv = argv_owned;
		try {
			ctx.parse(ref argv);
		} catch (GLib.OptionError e) {
			return false;
		}
		return true;
	}

	public string? args_parse(string[] args) {
		this.mode = "dmenu";

		// --list/-l and --nofloating are shorthands that preset other
		// fields below; they must be detected and applied *before* the
		// real parse so that an explicit flag (e.g. -d, or --nostay)
		// always overrides the preset, in either order on the command
		// line -- matching what a preset is supposed to mean. Checked
		// independently (not else-if), since both could be present at once.
		foreach (unowned string tok in args) {
			if (tok == "-l" || tok == "--list") {
				this.dims    = "30%x50%";
				this.index   = 0;
				this.isize   = 0;
				this.horiz   = true;
				this.maxcols = 1;
				this.maxlbl  = 1000;
			}
			if (tok == "--nofloating") {
				// a floating-less window is easy to lose focus to in a
				// tiling WM; default to not quitting when that happens
				this.stay = true;
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
			"\n" +
			"  [text] :: key=value key2=value2 ...\n" +
			"    `text' (optional) becomes the item's name; what follows an\n" +
			"    unescaped `::' is a flat, whitespace-separated key=value list\n" +
			"    running to the end of the line (a bare or \"quoted\" key, a\n" +
			"    bare or \"quoted\" value, no nesting; quote a value to allow\n" +
			"    whitespace in it). A literal `::' in `text' is written `\\::'.\n" +
			"    Keys matching an item field (name, exec, icon, icon-size,\n" +
			"    comment, selected, terminal, confirm) set that field; `cmd'\n" +
			"    is a directive instead of an item:\n" +
			"      :: cmd=power                    insert power options\n" +
			"      :: cmd=desktops dirs=<STR>      insert desktop files at optional directory\n" +
			"      :: cmd=json-file path=<STR>     insert items from a JSON file\n" +
			"      :: cmd=set key=value ...        change an option, mid-session\n" +
			"    Examples:\n" +
			"      Reboot :: exec=reboot confirm=true\n" +
			"      Firefox :: icon=firefox comment=\"Web browser\"\n" +
			"      :: cmd=set title=\"New Title\" maxcols=3\n" +
			"      :: cmd=set index=2\n" +
			"    cmd=set's keys are option names, not item fields:\n" +
			"    " + live_settable_help() + ".\n" +
			"\n" +
			"  Deprecated, still recognized: >>j, >>json STR (insert json\n" +
			"  string); >>jfile, >>json-file STR; >>power; >>desktops <STR>;\n" +
			"  >>select <INT>. Prefer the syntax above in new scripts.\n" +
			"\n" +
			"Dims:\n" +
			"              pixels by default\n" +
			"  `%':        percent of the current screen geometry\n" +
			"  `i':        percent of the icon size\n" +
			"  `min(...)': minimum of two values\n" +
			"  `max(...)': maximum of two values\n" +
			"  Example:    `-d 'min(800, 90%)*max(80%, 600)'`\n" +
			"\n" +
			env_vars_help());

		ctx.add_main_entries(this._entries, null);

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
