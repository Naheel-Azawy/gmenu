string? dotdesktop_str_parse(string line) {
	string[] sp = line.split("=");
	if (sp.length < 2) {
		return null;
	}
	return string.joinv("=", sp[1:]).strip();
}

bool dotdesktop_bool_parse(string line) {
	return dotdesktop_str_parse(line).down() == "true";
}

Item? dotdesktop_parse(string desktop_file) {
	var ret = new Item();

	var file = File.new_for_path(desktop_file);
	if (!file.query_exists()) {
		GLib.stderr.printf("File '%s' doesn't exist.\n", file.get_path());
		return null;
	}
	ret.desktop_file = file.get_path();

	try {
		bool is_readable = false;
		var dis = new DataInputStream(file.read());
		string line;
		while ((line = dis.read_line(null)) != null) {
			if (line.has_prefix("[")) {
				is_readable = line.strip() == "[Desktop Entry]";
				continue;
			}

			if (is_readable) {
				if (line.has_prefix("NoDisplay=")) {
					if (dotdesktop_bool_parse(line)) {
						return null;
					}
				}

				if (line.has_prefix("OnlyShowIn=")) {
					if (dotdesktop_str_parse(line).length > 0) {
						return null;
					}
				}

				if (line.has_prefix("Name=")) {
					ret.name = dotdesktop_str_parse(line);
				}

				if (line.has_prefix("Icon=")) {
					ret.icon = dotdesktop_str_parse(line);
				}

				if (line.has_prefix("Comment=")) {
					ret.comment = dotdesktop_str_parse(line);
				}

				if (line.has_prefix("Terminal=")) {
					ret.terminal = dotdesktop_bool_parse(line);
				}

				if (line.has_prefix("Exec=")) {
					ret.exec = dotdesktop_str_parse(line);
					if (ret.exec != null && ret.exec.contains("%")) {
						int exec_i = ret.exec.index_of("%");
						ret.exec = ret.exec.substring(0, exec_i).strip() +
							" " +
							ret.exec.substring(exec_i + 2, -1).strip();
					}
				}
			}
		}
		return ret;
	} catch (Error e) {
		GLib.stderr.printf("%s\n", e.message);
		return null;
	}
}

void dotdesktop_add_from_dir(ref GLib.List<Item> list,
							 ref Gee.HashMap<string, bool> skip,
							 string desktops_dir) {
	if (!FileUtils.test(desktops_dir, FileTest.IS_DIR)) {
		return;
	}
	try {
		var directory = File.new_for_path(desktops_dir);
		var enumerator = directory.enumerate_children(FileAttribute.STANDARD_NAME, 0);
		string path;
		Item i;
		FileInfo file_info;
		while ((file_info = enumerator.next_file()) != null) {
			if (file_info.get_name().has_suffix(".desktop")) {
				path = desktops_dir + "/" + file_info.get_name();
				i = dotdesktop_parse(path);
				if (i != null &&
					(!skip.has_key(i.name) || !skip[i.name])) {
					list.append(i);
					skip[i.name] = true; // avoid repeated desktops
				}
			}
		}
	} catch (Error e) {
		GLib.stderr.printf("Error: %s\n", e.message);
	}
}

GLib.List<Item> dotdesktop_from_dirs(string[] dirs, ref Gee.HashMap<string, bool> skip) {
	var list = new GLib.List<Item>();
	foreach (var d in dirs) {
		dotdesktop_add_from_dir(ref list, ref skip, d);
	}
	list.sort((a, b) => GLib.strcmp(a.name, b.name));
	return list;
}

string[] dotdesktop_default_dirs() {
	return new string[]{
		Environment.get_home_dir() + "/.local/share/applications",
		"/usr/local/share/applications",
		"/usr/share/applications"
	};
}

string dotdesktop_blacklist_path() {
	return Environment.get_home_dir() + "/.local/share/applications/blacklist";
}

void dotdesktop_blacklist_fill(ref Gee.HashMap<string, bool> skip) {
	var file = File.new_for_path(dotdesktop_blacklist_path());
	if (!file.query_exists()) {
		return;
	}

	try {
		var dis = new DataInputStream(file.read());
		string line;
		while ((line = dis.read_line(null)) != null) {
			line = line.strip();
			skip[line] = true;
		}
	} catch (Error e) {
		GLib.stderr.printf("%s\n", e.message);
	}
}

void dotdesktop_blacklist_add(string name) {
	FileStream fs = FileStream.open(dotdesktop_blacklist_path(), "a");
	fs.puts(name + "\n");
}

void dotdesktop_push_from_dirs(GMenuWin win, string? dirs_str=null) {
	string[] dirs;
	if (dirs_str == null) {
		dirs = dotdesktop_default_dirs();
	} else {
		dirs = dirs_str.split(":");
		for (int i = 0; i < dirs.length; ++i) {
			dirs[i] = clean_path(dirs[i]);
		}
	}

	var skip = new Gee.HashMap<string, bool>();
	dotdesktop_blacklist_fill(ref skip);
	GLib.List<Item> list = dotdesktop_from_dirs(dirs, ref skip);
	foreach (Item i in list) {
		win.push(i);
	}
}
