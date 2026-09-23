using Gee;

// Deprecated: the "old" special-line syntax, >>word [arg]. Kept working
// exactly as before for compatibility; see frag_push_line() below for its
// replacement. New scripts should use that instead; see --help.
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

	case "select":
		win.opts.index = int.parse(arg);
		break;

	default:
		return false;
	}

	return true;
}

// The new special-line syntax:
//
//   [text] :: key=value key2=value2 ...
//
// `text' (optional) becomes the item's name. What follows an unescaped
// `::' is a flat, whitespace-separated list of key=value pairs running
// to the end of the line (no nesting, no commas); a bare key or "a
// quoted one", and a bare word or a quoted string as its value -- quote
// a value only when it needs to contain whitespace or start with a
// quote character itself; single or double quotes both work. A literal
// `::' inside `text' is written `\::'. Keys matching an Item field
// (name, exec, icon, icon-size, comment, selected, terminal, confirm)
// set that field, overriding `text' if `name' is also given. A `cmd'
// key is a directive instead of an item; see frag_dispatch_cmd() for
// the recognized values. Any other key, or any parse error after `::',
// is treated as "this wasn't this syntax after all" and falls back to a
// plain-text item, the same as an unmatched line always has.
//
// Unlike a >>-style or bracket-style marker, "::" is never special to
// any POSIX shell (dash or bash) in any position, quoted or not, so
// these lines never need shell quoting just to survive being echoed.

const string[] FRAG_ITEM_KEYS = {
	"name", "exec", "icon", "icon-size", "comment", "selected",
	"terminal", "confirm"
};
const string[] FRAG_CMD_KEYS = { "cmd", "dirs", "path" };

bool frag_key_known(string key) {
	foreach (var k in FRAG_ITEM_KEYS) if (k == key) return true;
	foreach (var k in FRAG_CMD_KEYS)  if (k == key) return true;
	// cmd=set's own keys, e.g. "title" in `:: cmd=set title="New Title"';
	// LIVE_SETTABLE (opts.vala) is the one place that list is defined
	foreach (var k in LIVE_SETTABLE)  if (k == key) return true;
	return false;
}

// First unescaped "::" in `line', or -1 if none. "\::" doesn't count, so
// that literal "::" can appear in `text'.
int frag_find_split(string line) {
	int i = 0;
	while (true) {
		int idx = line.index_of("::", i);
		if (idx < 0) return -1;
		if (idx > 0 && line[idx - 1] == '\\') {
			i = idx + 2;
			continue;
		}
		return idx;
	}
}

string frag_unescape(string text) {
	return text.replace("\\::", "::");
}

// `frag[i]' is the opening quote (' or "); on success, returns the
// unescaped content and leaves `i' just past the closing quote. Null on
// an unterminated string.
string? frag_parse_quoted(string frag, ref int i) {
	int len = frag.length;
	char q = frag[i];
	i++; // opening quote
	var sb = new StringBuilder();
	while (i < len && frag[i] != q) {
		if (frag[i] == '\\' && i + 1 < len && (frag[i + 1] == q || frag[i + 1] == '\\')) {
			i++;
		}
		sb.append_c(frag[i]);
		i++;
	}
	if (i >= len) return null; // unterminated
	i++; // closing quote
	return sb.str;
}

// Reads a bare (unquoted) token: everything up to the next whitespace or
// end of string, leaving `i' right after it.
string frag_read_bare(string frag, ref int i) {
	int start = i;
	int len = frag.length;
	while (i < len && !frag[i].isspace()) i++;
	return frag[start:i];
}

// Parses a flat "key=value key2=value2 ..." list running to the end of
// `frag' (everything after the "::"). Every value comes back as its
// literal text (a caller wanting an int or a bool parses it from that);
// null on any syntax error.
Gee.HashMap<string, string>? frag_parse(string frag) {
	var result = new Gee.HashMap<string, string>();
	int i = 0;
	int len = frag.length;

	while (true) {
		while (i < len && frag[i].isspace()) i++;
		if (i >= len) return result; // clean end of line

		string key;
		if (frag[i] == '"' || frag[i] == '\'') {
			key = frag_parse_quoted(frag, ref i);
			if (key == null) return null;
		} else {
			int start = i;
			if (i < len && (frag[i].isalpha() || frag[i] == '_')) {
				i++;
				while (i < len && (frag[i].isalnum() || frag[i] == '_' || frag[i] == '-')) i++;
			}
			if (i == start) return null; // not a valid bare key
			key = frag[start:i];
		}

		if (i >= len || frag[i] != '=') return null;
		i++;
		if (i >= len) return null;

		string val;
		if (frag[i] == '"' || frag[i] == '\'') {
			val = frag_parse_quoted(frag, ref i);
			if (val == null) return null;
		} else {
			val = frag_read_bare(frag, ref i);
			if (val == "") return null;
		}

		// a pair must be followed by whitespace or end of line; catches
		// e.g. a quoted value with trailing garbage stuck right after it
		if (i < len && !frag[i].isspace()) return null;

		result[key] = val;
	}
}

void frag_apply_item(Item item, Gee.HashMap<string, string> f) {
	if (f.has_key("name"))      item.name     = f["name"];
	if (f.has_key("exec"))      item.exec     = f["exec"];
	if (f.has_key("icon"))      item.icon     = f["icon"];
	if (f.has_key("icon-size")) item.icon_sz  = int.parse(f["icon-size"]);
	if (f.has_key("comment"))   item.comment  = f["comment"];
	if (f.has_key("selected"))  item.selected = f["selected"];
	if (f.has_key("terminal"))  item.terminal = (f["terminal"] == "true");
	if (f.has_key("confirm"))   item.confirm  = (f["confirm"] == "true");
}

// `cmd' takes the place of >>power, >>desktops, >>select, >>json-file.
// (Old >>json/>>j has no equivalent here because it's no longer needed:
// a plain fragment already sets arbitrary item fields directly. Old
// >>select is now cmd=set index=N, alongside every other option.)
bool frag_dispatch_cmd(GMenuWin win, Gee.HashMap<string, string> f) {
	switch (f["cmd"]) {
	case "power":
		load_power(win);
		return true;

	case "desktops":
		dotdesktop_push_from_dirs(win, f.has_key("dirs") ? f["dirs"] : null);
		return true;

	case "json-file":
		if (!f.has_key("path")) return false;
		load_json_file(win, f["path"]);
		return true;

	case "set":
		// every other key on this line is an option to change, e.g.
		// `:: cmd=set title="New Title" maxcols=3'; frag_key_known()
		// has already checked each one is in LIVE_SETTABLE
		bool any = false;
		foreach (var key in f.keys) {
			if (key == "cmd") continue;
			any = true;
			if (!win.set_live_opt(key, f[key])) return false;
		}
		return any;

	default:
		return false;
	}
}

bool frag_push_line(GMenuWin win, string line) {
	int split = frag_find_split(line);
	if (split < 0) {
		// No unescaped "::": ordinarily let the caller's own plain-text
		// fallback push `line' unchanged. But if it contains an escaped
		// "\::", that still needs unescaping, which the caller's
		// fallback won't do -- handle it here instead.
		if (line.index_of("\\::") < 0) return false;
		win.push(new Item(frag_unescape(line).strip()), true);
		return true;
	}

	string text = frag_unescape(line[0:split]).strip();
	var fields = frag_parse(line[split + 2:]);
	if (fields == null) return false;

	foreach (var key in fields.keys) {
		if (!frag_key_known(key)) return false;
	}

	if (fields.has_key("cmd")) {
		return frag_dispatch_cmd(win, fields);
	}

	var item = new Item(text);
	frag_apply_item(item, fields);
	win.push(item, true);
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
		if (parse_push_cmd_line(win, line)) continue;
		if (frag_push_line(win, line))      continue;
		win.push(new Item(line), true);
	}

	return 0;
}
