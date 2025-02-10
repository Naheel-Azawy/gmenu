using Gtk;
using Gdk;
using Pango;

class Item {
    public string name;
    public string exec;
    public string icon;
    public string comment;
    public bool   terminal;
    public bool   confirm;
	public string desktop_file  = null;
	public string uninstall_cmd = "";

	public  int          i    = 0;
	public  GMenuWin     win  = null;
	private Gtk.EventBox _box = null;

	public Item(string name="",
				string exec="",
				string icon="",
				string comment="",
				bool   terminal=false,
				bool   confirm=false) {
		this.name     = name;
		this.exec     = exec;
		this.icon     = icon;
		this.comment  = comment;
		this.terminal = terminal;
		this.confirm  = confirm;
	}

	public Item.from_json(Json.Node node) {
		var elem = node.get_object();
		this.name     = elem.get_string_member_with_default("name",      "");
		this.exec     = elem.get_string_member_with_default("exec",      "");
		this.icon     = elem.get_string_member_with_default("icon",      "");
		this.comment  = elem.get_string_member_with_default("comment",   "");
		this.terminal = elem.get_boolean_member_with_default("terminal", false);
	}

	public Item.from_json_str(string json) {
		var parser = new Json.Parser();
		try {
			parser.load_from_data(json);
		} catch (Error e) {
			stderr.printf("Failed parsing JSON string\n");
		}
		this.from_json(parser.get_root());
	}

	/* This is left here in case needed later for debugging
	public string to_json() {
		Json.Builder builder = new Json.Builder();

		builder.begin_object();
		builder.set_member_name("name");
		builder.add_string_value(this.name);
		builder.set_member_name("exec");
		builder.add_string_value(this.exec);
		builder.set_member_name("icon");
		builder.add_string_value(this.icon);
		builder.set_member_name("comment");
		builder.add_string_value(this.comment);
		builder.set_member_name("terminal");
		builder.add_boolean_value(this.terminal);
		builder.end_object();

		Json.Generator generator = new Json.Generator();
		Json.Node root = builder.get_root();
		generator.set_root(root);
		return generator.to_data(null);
	} */

	public Gtk.EventBox box() {
		if (this._box != null) {
			return this._box;
		}

		var orien = this.win.opts.horiz ? Gtk.Orientation.HORIZONTAL:
			Gtk.Orientation.VERTICAL;

		var box = new Box(orien, 0);
		var lbl = new Label(this.name);
		var img = this.win.opts.isize <= 0 ? null : this.app_image(
			this.icon, this.win.opts.isize);

		lbl.set_ellipsize(Pango.EllipsizeMode.END);
		lbl.set_max_width_chars(this.win.opts.maxlbl);

		if (this.win.opts.horiz) {
			lbl.set_halign(Gtk.Align.START);
			if (img != null) {
				box.pack_start(img, false, false, 0);
			}
			box.pack_start(lbl, true, true, 10);
		} else {
			lbl.set_halign(Gtk.Align.CENTER);
            box.set_size_request(this.win.opts.isize * 2, this.win.opts.isize * 2);
            if (img != null) {
                box.pack_start(img, true, true, 5);
			}
            box.pack_start(lbl, true, true, 5);
		}

		this._box = new Gtk.EventBox();
		this._box.add(box);
		this._box.enter_notify_event.connect(this.on_hover);

		if (this.desktop_file != null) {
			this._box.button_press_event.connect (ev => {
				if (ev.type == EventType.BUTTON_PRESS && ev.button == 3) {
					this.on_right_click();
					return true;
				}
				return false;
			});
		}

		return this._box;
	}

	private void on_right_click() {
		bool old_stay = this.win.opts.stay;
		this.win.opts.stay = true;
		Gtk.Menu menu = new Gtk.Menu();
		menu.deactivate.connect(() => this.win.opts.stay = old_stay);
		menu.attach_to_widget(this._box, null);

		Gtk.MenuItem menu_item;

		menu_item = new Gtk.MenuItem.with_label("Desktop file location");
		menu_item.activate.connect(ev => locate_file(this.desktop_file));
		menu.add(menu_item);

		menu_item = new Gtk.MenuItem.with_label("Edit desktop file");
		menu_item.activate.connect(ev => edit(this.desktop_file));
		menu.add(menu_item);

		menu_item = new Gtk.MenuItem.with_label("Hide");
		menu_item.activate.connect(ev => dotdesktop_blacklist_add(this.name));
		menu.add(menu_item);

		if (this.uninstall_cmd == "") {
			this.uninstall_cmd = uninstall_cmd_of(this.desktop_file);
		}
		if (this.uninstall_cmd != null) {
			menu_item = new Gtk.MenuItem.with_label("Uninstall");
			menu_item.activate.connect(ev => this.pkg_uninstall());
			menu.add(menu_item);
		}

		menu.show_all();
		menu.popup_at_pointer(null);
	}

	private void pkg_uninstall() {
		this.win.hide();
		this.win.opts.stay = true;
		var yn_win = new GMenuWin();
		run_yesno(yn_win, "Uninstall " + this.name, yes => {
			if (yes) {
				run_on_terminal("sh -c '" +
								"echo " + this.uninstall_cmd + "; " +
								this.uninstall_cmd + "; " +
								"echo Press enter to close; read _'");
			}
			main_end();
		});
	}

	private string tooltip_text() {
		string res = this.name;
		if (this.comment != null && this.comment.length > 0) {
			res += ": " + this.comment;
		}
		if (this.exec != null && this.exec.length > 0) {
			res += " (" + this.exec.strip() + ")";
		}
		return res;
	}

	private bool on_hover(Gtk.Widget self, Gdk.EventCrossing ev) {
		if (this.win != null && this.win.items_cont != null) {
			if (this.win.cursor_x == -2 &&
				this.win.cursor_y == -2 &&
				this._box != null) {
				this._box.set_tooltip_text(this.tooltip_text());
			} else {
				int x, y;
				this.win.cursor_pos(out x, out y);
				if (x == this.win.cursor_x && y == this.win.cursor_y) {
					return true;
				}
				this.win.cursor_x = -2; // cursor moved
				this.win.cursor_y = -2;
			}
		}
		var flowboxchild = self.get_parent()         as FlowBoxChild;
		var flowbox      = flowboxchild.get_parent() as FlowBox;
		flowbox.select_child(flowboxchild);
		return true;
	}

	private Gtk.Image? app_image(string icon, int isize) {
		Gdk.Pixbuf pixbuf;
		var icon_theme = Gtk.IconTheme.get_default();
		try {
			if (icon.has_prefix("/")) {
				pixbuf = new Gdk.Pixbuf.from_file_at_size(icon, isize, isize);
			} else {
				if (icon.has_suffix(".svg") || icon.has_suffix(".png")) {
					icon = icon.split(".")[0];
				}
				pixbuf = icon_theme.load_icon(
					icon, isize, Gtk.IconLookupFlags.FORCE_SIZE);
			}
		} catch (Error e) {
			try {
				pixbuf = icon_theme.load_icon(
					"application-x-executable", isize, Gtk.IconLookupFlags.FORCE_SIZE);
			} catch (Error e) {
				return null;
			}
		}
		return new Gtk.Image.from_pixbuf(pixbuf);
	}
}
