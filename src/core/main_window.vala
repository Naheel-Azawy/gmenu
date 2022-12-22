using Gtk;
using Gdk;
using GLib;
using Pango;

// return true to stop delegating
delegate bool OnLaunch(Item item);

class GMenuWin : Gtk.Window {
	public Opts opts = new Opts();

	public OnLaunch        onlaunch     = null;
	public Item[]          items        = null;
	public ItemsContainer  items_cont   = null;
	public Gtk.SearchEntry search_entry = null;

	public void build() {
		this.set_keep_above(true);
		this.gravity = Gdk.Gravity.CENTER;
        this.set_position(Gtk.WindowPosition.CENTER);

		if (this.opts.prompt != null) {
			this.title = this.opts.prompt;
		} else {
			this.title = "Menu";
		}

		this.destroy.connect(Gtk.main_quit);
		this.key_release_event.connect(this.on_key_release);
		this.focus_out_event.connect(this.on_focus_out);

		// load css
		string css_sum = CSS;
		if (this.opts.css != null && this.opts.css.length > 0) {
			var f = File.new_for_path(this.opts.css);
			if (f.query_exists()) {
				try {
					string css_file_out;
					FileUtils.get_contents(this.opts.css, out css_file_out);
					css_sum += "\n" + css_file_out;
				} catch (GLib.FileError ignored) {
				}
			} else {
				css_sum += "\n" + this.opts.css;
			}
		}
		var screen = this.get_screen();
		var provider = new Gtk.CssProvider();
		try {
			provider.load_from_data(css_sum, css_sum.length);
			Gtk.StyleContext.add_provider_for_screen(
				screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
		} catch (Error e) {
			stderr.printf("Failed loading CSS\n");
		}

		// transparent window
		var visual = screen.get_rgba_visual();
		if (visual != null && screen.is_composited())
			this.set_visual(visual);
		this.set_app_paintable(true);

		// layout
		var main_container = new Box(Gtk.Orientation.VERTICAL, 0);
        var outer_box      = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		this.items_cont    = new ItemsContainer(this);

		main_container.set_property("name", "maincontainer");

		if (!this.opts.nosearch) {
			this.search_entry = new Gtk.SearchEntry();
			this.search_entry.set_property("name", "searchbox");
			this.search_entry.set_sensitive(true);
			this.search_entry.changed.connect(this.on_search_change);
			outer_box.pack_start(this.search_entry, false, false, 0);
		}

		if (this.opts.prompt != null) {
			var p = new Label(this.opts.prompt);
			p.set_property("name", "prompt");
			outer_box.pack_start(p, false, false, 0);
		}
		outer_box.pack_start(this.items_cont.box(), true, true, 0);

		main_container.pack_start(outer_box, true, true, 0);
		this.add(main_container);

		// dims geometry FIXME: depricated code
		var active = screen.get_active_window();
		int display_num;
		if (active != null) {
			display_num = screen.get_monitor_at_window(active);
		} else {
			display_num = 0;
		}
		Gdk.Rectangle geo;
		screen.get_monitor_geometry(display_num, out geo);

		// auto opts
		this.opts.auto_set(geo.width);

		// dims
		if (this.opts.dims != null) {
			if (geo.width == 0 || geo.height == 0) {
				geo.width  = 1920;
				geo.height = 1080;
			}

			string[] d = this.opts.dims.split("x");
			int[] geo_arr = {geo.width, geo.height};
			int[] res_dim = {0, 0};
			for (int i = 0; i < 2; ++i) {
				if (d[i].has_suffix("%")) {
					res_dim[i] = (int) (float.parse(d[i][:-1]) * geo_arr[i] / 100);
				} else if (d[i].has_suffix("i")) {
					res_dim[i] = (int) (float.parse(d[i][:-1]) * this.opts.isize);
				} else {
					res_dim[i] = int.parse(d[i]);
				}
			}
			this.set_default_size(res_dim[0], res_dim[1]);
		}
	}

	private void on_search_change(Gtk.Editable self) {
		if (this.items_cont != null) {
			this.items_cont.update();
		}
	}

	private static bool search_char_allowed(char target) {
		string ok = "qwertyuiopasdfghjklzxcvbnm1234567890 $";
		for (int i = 0; i < ok.length; ++i) {
			if (target == ok[i]) {
				return true;
			}
		}
		return false;
	}

	private bool on_key_release(Gtk.Widget self, Gdk.EventKey ev) {
		if (ev.type != Gdk.EventType.KEY_RELEASE) {
			return true;
		}

		if (this.search_entry != null           &&
			!this.search_entry.has_focus        &&
			ev.str != null && ev.str.length > 0 &&
			search_char_allowed(ev.str[0])) {
			this.search_entry.text += ev.str;
			this.search_entry.set_position(-1);

		} else if (this.search_entry != null         &&
				   !this.search_entry.has_focus      &&
				   this.search_entry.text.length > 0 &&
				   ev.keyval == Gdk.Key.BackSpace) {
			this.search_entry.text = this.search_entry.text[:-1];
			this.search_entry.set_position(-1);

		} else if (this.search_entry != null &&
				   ev.keyval == Gdk.Key.Return) {
			var txt = this.search_entry.text;
			if (txt.has_prefix("$")) {
				system(txt[1:]);
				Gtk.main_quit();
			} else if (txt != null && txt.length > 0) {
				this.items_cont.launch_first();
				Gtk.main_quit();
			}

		} else if (ev.keyval == Gdk.Key.Escape) {
			if (this.search_entry != null &&
				this.search_entry.text.length > 0) {
				this.search_entry.text = "";
			} else {
				Gtk.main_quit();
			}
		}

		return true;
	}

	private bool on_focus_out(Gtk.Widget self, Gdk.EventFocus ev) {
		if (!this.opts.stay)
			Gtk.main_quit();
		return false;
	}

	public void push(Item item) {
		this.items += item;
		this.items_cont.push(item);

		// set initial index
		if (this.items.length - 1 == this.opts.index) {
			this.items_cont.select_n(this.opts.index);
		}
	}

	public new void show() {
		this.resizable = false;
		this.show_all();
		this.resizable = true; // to stay floating in a tiling wm
	}
}
