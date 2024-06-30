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

	// used to avoid selection in initial hover
	public int cursor_x = -1;
	public int cursor_y = -1;

	public int ret = 0;
	private Mutex mx = Mutex();

	public void build() {
		if (this.opts.sync) {
			this.build_real();
			return;
		}
		GLib.Idle.add(() => {
			mx.lock();
			this.build_real();
			mx.unlock();
			return false;
		});
	}

	private void build_real() {
		this.set_keep_above(true);
		this.gravity = Gdk.Gravity.CENTER;
        this.set_position(Gtk.WindowPosition.CENTER);

		if (this.opts.prompt != null) {
			this.title = this.opts.prompt;
		} else {
			this.title = "Menu";
		}

		this.destroy.connect(main_end);
		this.key_press_event.connect(this.on_key);
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
		if (!this.opts.solid) {
			var visual = screen.get_rgba_visual();
			if (visual != null && screen.is_composited())
				this.set_visual(visual);
			this.set_app_paintable(true);
		}

		// layout
		var main_container = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        var outer_box      = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		this.items_cont    = new ItemsContainer(this);

		main_container.set_property("name", "maincontainer");

		if (this.opts.prompt != null) {
			var p = new Label(this.opts.prompt);
			p.set_property("name", "prompt");
			p.set_halign(Gtk.Align.START);
			outer_box.pack_start(p, false, false, 0);
		}

		if (!this.opts.nosearch) {
			this.search_entry = new Gtk.SearchEntry();
			this.search_entry.set_property("name", "searchbox");
			this.search_entry.set_sensitive(true);
			this.search_entry.changed.connect(this.on_search_change);
			this.search_entry.focus_in_event.connect(this.on_search_focus_in);
			outer_box.pack_start(this.search_entry, false, false, 0);
		}

		outer_box.pack_start(this.items_cont.box(), true, true, 0);

		main_container.pack_start(outer_box, true, true, 0);
		this.add(main_container);

		// initial cursor position
		this.cursor_pos(out this.cursor_x, out this.cursor_y);

		// dims geometry
		Gdk.Rectangle geo = this.geometry();

		// auto opts
		this.opts.auto_set(geo.width);

		// dims
		if (this.opts.dims == null) {
			if (geo.width >= geo.height) {
				this.opts.dims = "40%x80%";
			} else {
				this.opts.dims = "55%x50%";
			}
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

		this.show_win();
	}

	public void cursor_pos(out int x, out int y) {
		Gdk.Display display = this.get_screen().get_display();
		Seat        seat    = display.get_default_seat();
		Device?     mouse   = seat.get_pointer();
		if (mouse != null) {
			Gdk.Window wing = display.get_default_group();
			wing.get_device_position(mouse, out x, out y, null);
		} else {
			x = y = -1;
		}
	}

	private Gdk.Rectangle geometry() {
		Gdk.Rectangle geo = {0};
		// Gdk.Window  active  = screen.get_active_window();
		// Gdk.Monitor monitor = display.get_monitor_at_window(active);
		// Since the above is deprecated and no alternatives were found,
		// we work around by getting the monitor at the current position
		// of the cursor's device
		Gdk.Screen  screen  = this.get_screen();
		Gdk.Display display = screen.get_display();
		int x, y;
		this.cursor_pos(out x, out y);
		if (x != -1 && y != -1) {
			Gdk.Monitor monitor = display.get_monitor_at_point(x, y);
			geo = monitor.get_geometry();
		}
		if (geo.width == 0 || geo.height == 0) {
			geo.width  = 1920;
			geo.height = 1080;
		}
		return geo;
	}

	private void on_search_change(Gtk.Editable self) {
		if (this.items_cont != null) {
			this.items_cont.unselect();
			this.items_cont.update();
		}
	}

	private bool on_search_focus_in(Gtk.Widget self, Gdk.EventFocus ev) {
		this.items_cont.unselect();
		return false;
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

	private bool on_key(Gtk.Widget self, Gdk.EventKey ev) {
		if (this.search_entry != null           &&
			!this.search_entry.has_focus        &&
			ev.str != null && ev.str.length > 0 &&
			search_char_allowed(ev.str[0])) {
			this.search_entry.text += ev.str;
			this.search_entry.grab_focus();
			this.search_entry.set_position(-1);
			return true;

		} else if (this.search_entry != null         &&
				   !this.search_entry.has_focus      &&
				   this.search_entry.text.length > 0 &&
				   ev.keyval == Gdk.Key.BackSpace) {
			this.search_entry.text = this.search_entry.text[:-1];
			this.search_entry.grab_focus();
			this.search_entry.set_position(-1);
			return true;

		} else if (this.search_entry != null &&
				   ev.keyval == Gdk.Key.Return) {
			var txt = this.search_entry.text;
			if (txt.has_prefix("$")) {
				system(txt[1:]);
				main_end();
			} else {
				Item i = this.items_cont.selected_item();
				if (i != null) {
					this.items_cont.launch(i);
				} else if (txt != null && txt.length > 0) {
					this.items_cont.launch_first();
					main_end();
				}
			}
			return true;

		} else if (ev.keyval == Gdk.Key.Escape) {
			if (this.search_entry != null &&
				this.search_entry.text.length > 0) {
				this.search_entry.text = "";
			} else {
				main_end();
			}
			return true;

		} else if (ev.keyval == Gdk.Key.Right ||
				   ev.keyval == Gdk.Key.Left  ||
				   ev.keyval == Gdk.Key.Up    ||
				   ev.keyval == Gdk.Key.Down) {
			Item i = this.items_cont.selected_item();
			if (i == null) {
				if (ev.keyval == Gdk.Key.Right ||
					ev.keyval == Gdk.Key.Down) {
					this.items_cont.select_first();
				} else if (ev.keyval == Gdk.Key.Left  ||
						   ev.keyval == Gdk.Key.Up) {
					this.items_cont.select_last();
				}
				return true;
			}
			return false;
		}

		return false;
	}

	private bool on_focus_out(Gtk.Widget self, Gdk.EventFocus ev) {
		if (!this.opts.stay)
			main_end();
		return false;
	}

	public void loading_update() {
		if (this.search_entry == null) {
			return;
		}
		string txt;
		if (this.items.length == 0) {
			txt = "Loading...";
		} else {
			txt = "Loading " +
				this.items.length.to_string() +
				" items...";
		}
		this.search_entry.set_placeholder_text(txt);
	}

	public void loading_end() {
		GLib.Idle.add(() => {
			mx.lock();
			if (this.search_entry != null) {
				this.search_entry.set_placeholder_text(null);
			}
			mx.unlock();
			return false;
		}, GLib.Priority.LOW);
	}

	private void push_real(Item item) {
		item.i = this.items.length;
		this.items += item;
		this.items_cont.push(item);

		// set initial index
		if (this.items.length - 1 == this.opts.index) {
			this.items_cont.select_n(this.opts.index);
		}

		this.show_all();
	}

	public void push(Item item, bool loading=false) {
		if (this.opts.sync) {
			this.push_real(item);
			return;
		}
		GLib.Idle.add(() => {
			mx.lock();
			this.push_real(item);
			if (loading) {
				this.loading_update();
			}
			mx.unlock();
			// because main loop would get stuck otherwise
			while (Gtk.events_pending() && !main_ended) {
				Gtk.main_iteration();
			}
			return false;
		});
	}

	private void show_win() {
		this.resizable = false;
		this.show_all();
		this.resizable = true; // to stay floating in a tiling wm
		if (this.opts.full) {
			this.fullscreen();
		}
	}
}
