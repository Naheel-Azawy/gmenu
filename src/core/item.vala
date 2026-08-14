using Gtk;
using Gdk;
using Pango;

class Item {
    public string name;
    public string exec;
    public string icon;
    public int    icon_sz;
    public string comment;
    public string selected;
    public bool   terminal;
    public bool   confirm;
	public string desktop_file  = null;
	public string uninstall_cmd = "";

	public  int          i    = 0;
	public  GMenuWin     win  = null;
	private Gtk.EventBox _box = null;
	private Gtk.Label    _lbl = null;
	private bool         _flowbox_hooked = false;

	public Item(string name="",
				string exec="",
				string icon="",
				string comment="",
				string selected="",
				bool   terminal=false,
				bool   confirm=false) {
		this.name     = name;
		this.exec     = exec;
		this.icon     = icon;
		this.icon_sz  = -1;
		this.comment  = comment;
		this.selected = selected;
		this.terminal = terminal;
		this.confirm  = confirm;
	}

	public Item.from_json(Json.Node node) {
		var elem = node.get_object();
		this.name     = elem.get_string_member_with_default("name",      "");
		this.exec     = elem.get_string_member_with_default("exec",      "");
		this.icon     = elem.get_string_member_with_default("icon",      "");
		this.icon_sz  = (int) elem.get_int_member_with_default("icon-size", 0);
		this.comment  = elem.get_string_member_with_default("comment",   "");
		this.selected = elem.get_string_member_with_default("selected",  "");
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
		builder.set_member_name("selected");
		builder.add_string_value(this.selected);
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
		this._lbl = new Label(this.name);
		var img = this.win.opts.isize <= 0 ? null : this.app_image(
			this.icon, this.icon_sz > 0 ? this.icon_sz : this.win.opts.isize);

		this._lbl.set_ellipsize(Pango.EllipsizeMode.END);
		this._lbl.set_max_width_chars(this.win.opts.maxlbl);

		if (this.win.opts.horiz) {
			this._lbl.set_halign(Gtk.Align.START);
			if (img != null) {
				box.pack_start(img, false, false, 0);
			}
			box.pack_start(this._lbl, true, true, 10);
		} else {
			this._lbl.set_halign(Gtk.Align.CENTER);
            // box.set_size_request(this.win.opts.isize * 2, this.win.opts.isize * 2);
            if (img != null) {
                box.pack_start(img, true, true, 5);
			}
            box.pack_start(this._lbl, true, true, 5);
		}
		if (this.win.opts.center) {
			this._lbl.set_halign(Gtk.Align.CENTER);
			this._lbl.set_justify(Gtk.Justification.CENTER);
		}

		this._box = new Gtk.EventBox();
		this._box.add(box);
		this._box.enter_notify_event.connect(this.on_hover);
		this._box.map.connect(this.hook_flowbox_selection);

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

	private void update_lbl_text(FlowBoxChild flowboxchild) {
		if (flowboxchild.is_selected() &&
			this.selected != null && this.selected.length > 0) {
			this._lbl.set_text(this.name + "\n" + this.selected);
		} else {
			this._lbl.set_text(this.name);
		}
	}

	private void hook_flowbox_selection() {
		if (this._flowbox_hooked) {
			return;
		}
		var flowboxchild = this._box.get_parent() as FlowBoxChild;
		if (flowboxchild == null) {
			return;
		}
		var flowbox = flowboxchild.get_parent() as FlowBox;
		if (flowbox == null) {
			return;
		}

		this._flowbox_hooked = true;
		flowbox.selected_children_changed.connect(() => {
			this.update_lbl_text(flowboxchild);
		});

		// set initial text in case the child is already selected
		this.update_lbl_text(flowboxchild);
	}

	private bool on_hover(Gtk.Widget self, Gdk.EventCrossing ev) {
		this.hook_flowbox_selection();

		if (this.win != null && this.win.items_cont != null) {
			if (this.win.cursor_x == -2 &&
				this.win.cursor_y == -2 &&
				this._box != null &&
				!this.win.opts.notooltip) {
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
		try {
			if (icon.has_prefix("/")) {
				var pixbuf = new Gdk.Pixbuf.from_file_at_size(
					icon, isize, isize);
				return new Gtk.Image.from_pixbuf(pixbuf);
			} else {
				if (icon.has_suffix(".svg") || icon.has_suffix(".png")) {
					icon = icon.split(".")[0];
				}
				var img = new Gtk.Image.from_icon_name(
					icon, Gtk.IconSize.MENU);
				img.set_pixel_size(isize);
				return img;
			}
		} catch (Error e) {
			return new Gtk.Image.from_icon_name(
				"application-x-executable", isize);
		}
	}
}
