using Gee;
using Posix;

const string NAME = "gmenu";

const string[] terminals = {
	"gtrm",
	"st",
	"foot",
	"kitty",
	"gnome-terminal",
	"xterm"
};

const string[] editors = {
	"micro",
	"nano",
	"emacs",
	"nvim",
	"vim",
	"vi"
};

string[]                 which_paths = null;
HashMap<string, string?> which_cache = null;

string? which(string cmd) {
	if (which_paths == null) {
		var env_path = Environment.get_variable("PATH");
		if (env_path != null) {
			which_paths = env_path.split(":");
			which_cache = new HashMap<string, string?>();
		}
	}
	if (which_cache != null && which_cache.has_key(cmd)) {
		return which_cache[cmd];
	}
	string? ret = null;
	if (which_paths != null) {
		File f;
		foreach (var p in which_paths) {
			f = File.new_for_path(@"$p/$cmd");
			if (f.query_exists()) {
				ret = f.get_path();
				break;
			}
		}
	}
	which_cache[cmd] = ret;
	return ret;
}

bool exists(string cmd) {
	return which(cmd) != null;
}

string clean_path(string path) {
	if (path.has_prefix("~")) {
		return Environment.get_home_dir() + path[1:];
	}
	return path;
}

// Single-quotes `s' for safe embedding in a shell command line: wraps it in
// '...' and escapes any single quotes it contains as '\'' (close the
// quote, an escaped literal quote, reopen the quote), so content coming
// from a file path, a package name, or the like can't break out of the
// quoting it's embedded in.
string shell_quote(string s) {
	return "'" + s.replace("'", "'\\''") + "'";
}

int system(string cmd) {
    try {
		Process.spawn_command_line_async(cmd);
		return 0;
    } catch (SpawnError e) {
        return -1;
    }
}

string? uninstall_cmd_of(string file, string query_cmd, string uninstall_cmd) {
	// query_cmd/uninstall_cmd come from Opts (GMENU_PKG_QUERY_CMD /
	// GMENU_PKG_UNINSTALL_CMD, defaulting to pacman); the output parsing
	// below still assumes pacman's own "is owned by" wording -- see the
	// comment on those fields in opts.vala
	string[] query_argv = query_cmd.split(" ");
	if (query_argv.length == 0 || !exists(query_argv[0])) return null;

	string o;
	string e;
	int status;
	try {
		Process.spawn_command_line_sync(query_cmd + " " + shell_quote(Posix.realpath(file)),
										out o,
										out e,
										out status);
	} catch (SpawnError e) {
		return null;
	}

	if (status != 0) return null;
	string[] s;
	s = o.split(" is owned by ");
	if (s.length != 2) return null;
	s = s[1].split(" ");
	if (s.length != 2) return null;
	string owner = s[0];

	return uninstall_cmd + " " + owner;
}

string? get_terminal() {
	string trm = Environment.get_variable("TERMINAL");
	if (trm != null) return trm;

	foreach (var t in terminals) {
		trm = which(t);
		if (trm != null) {
			return trm;
		}
	}

	GLib.stderr.printf("Set $TERMINAL or install one of %s\n",
					   string.joinv(", ", (string[]) terminals));
	return null;
}

int run_on_terminal(string cmd) {
	var trm = get_terminal();
	if (trm == null) {
		return -1;
	}
	return system(trm + " -e " + cmd);
}

string? get_editor(string? preferred = null) {
	// `preferred' is Opts.editor (GMENU_EDITOR); it outranks $EDITOR and
	// autodetection, same relative priority $EDITOR already had over the
	// autodetected `editors' list
	if (preferred != null) return preferred;

	string editor = Environment.get_variable("EDITOR");
	if (editor != null) return editor;

	foreach (var e in editors) {
		editor = which(e);
		if (editor != null) {
			return editor;
		}
	}

	GLib.stderr.printf("Set $EDITOR or install one of %s\n",
					   string.joinv(", ", (string[]) terminals));
	return null;
}

int edit(string f, string? preferred_editor = null) {
	var editor = get_editor(preferred_editor);
	if (editor == null) {
		return -1;
	}
	return run_on_terminal(editor + " " + shell_quote(f));
}

int locate_file(string f) {
	if (!exists("xdg-open")) return -1;
	string dir = GLib.Path.get_dirname(f);
	return system("xdg-open " + shell_quote(dir));
}
