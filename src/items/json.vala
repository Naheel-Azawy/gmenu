void load_json_str(GMenuWin win, string j) {
	win.push(new Item.from_json_str(j));
}

void load_json_file(GMenuWin win, string json_file) {
	try {
		var parser = new Json.Parser();
		parser.load_from_file(json_file);
		var elems = parser.get_root().get_array();
		Item item;
		foreach (var node in elems.get_elements()) {
			item = new Item.from_json(node);
			win.push(item);
		}
	} catch (Error e) {
		stderr.printf("Failed opening JSON file '%s'\n", json_file);
	}
}
