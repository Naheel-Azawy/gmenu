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

int system(string cmd) {
    try {
		Process.spawn_command_line_async(cmd);
		return 0;
    } catch (SpawnError e) {
        return -1;
    }
}

string? uninstall_cmd_of(string file) {
	// TODO: consider apt, dnf, etc...
	if (!exists("pacman")) return null;

	string o;
	string e;
	int status;
	try {
		Process.spawn_command_line_sync("pacman -Qo " + Posix.realpath(file),
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

	return "sudo pacman -R " + owner;
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
					   string.joinv(", ", terminals));
	return null;
}

int run_on_terminal(string cmd) {
	var trm = get_terminal();
	if (trm == null) {
		return -1;
	}
	return system(trm + " -e " + cmd);
}

string? get_editor() {
	string editor = Environment.get_variable("EDITOR");
	if (editor != null) return editor;

	foreach (var e in editors) {
		editor = which(e);
		if (editor != null) {
			return editor;
		}
	}

	GLib.stderr.printf("Set $EDITOR or install one of %s\n",
					   string.joinv(", ", terminals));
	return null;
}

int edit(string f) {
	var editor = get_editor();
	if (editor == null) {
		return -1;
	}
	// TODO: consider gui editors, escape '
	return run_on_terminal(editor + " '" + f + "'");
}

int locate_file(string f) {
	if (!exists("xdg-open")) return -1;
	string dir = GLib.Path.get_dirname(f);
	return system("xdg-open '" + dir + "'");
}
