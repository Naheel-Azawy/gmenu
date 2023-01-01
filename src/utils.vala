using Gee;

const string NAME = "gmenu";

const string[] terminals = {
	"gtrm",
	"st",
	"foot",
	"kitty",
	"gnome-terminal",
	"xterm"
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

string? get_terminal() {
	string trm = Environment.get_variable("TERMINAL");
	if (trm != null) return trm;

	foreach (var t in terminals) {
		trm = which(t);
		if (trm != null) {
			return trm;
		}
	}

	return null;
}
