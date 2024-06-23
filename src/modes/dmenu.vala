bool parse_push_cmd_line(GMenuWin win, string line) {
	if (!line.has_prefix(">>")) {
		return false;
	}

	string cmd;
	string arg;

	int cmd_end = line.index_of(" ");
	if (cmd_end > 0) {
		cmd = line[2:cmd_end].strip();
		arg = line[cmd_end + 1:].strip();
	} else {
		cmd = line[2:].strip();
		arg = null;
	}

	switch (cmd) {
	case "json":
	case "j": // arg is a json string
		load_json_str(win, arg);
		break;

	case "json-file":
	case "jfile":
		if (arg == null) return false;
		load_json_file(win, arg);
		break;

	case "power": // no arg
		load_power(win);
		break;

	case "desktops": // arg is null or a colons separated string of dirs
		dotdesktop_push_from_dirs(win, arg);
		break;

	default:
		return false;
	}

	return true;
}

int run_dmenu(GMenuWin win) {
	/*win.opts.dims    = "25%x50%";
	win.opts.index   = 0;
	win.opts.noic    = true;
	win.opts.maxcols = 1;
	win.opts.maxlbl  = 1000;
	win.opts.horiz   = true;*/

	win.build();

	string line = "";
	while (!stdin.eof() &&
		   (line = stdin.read_line()) != null &&
		   line != "END") {
		if (!parse_push_cmd_line(win, line)) {
			win.push(new Item(line), true);
		}
	}

	return 0;
}
