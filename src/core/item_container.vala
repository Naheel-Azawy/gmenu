using Gtk;

class ItemsContainer {
	private GMenuWin           win;
	private Gtk.FlowBox        flow;
	private Gtk.ScrolledWindow scroll;

	private Item first        = null;
	public  int  hover_count  = 0; // changed below in Item
	private int  margins      = 10;

	public ItemsContainer(GMenuWin win) {
		this.win = win;
		this.flow = new Gtk.FlowBox();

		this.flow.set_margin_start(this.margins);
        this.flow.set_margin_end(this.margins);
        this.flow.set_max_children_per_line(this.win.opts.maxcols);
        this.flow.set_homogeneous(true);
        this.flow.set_orientation(Gtk.Orientation.HORIZONTAL);
        if (!this.win.opts.horiz) {
            this.flow.set_halign(Gtk.Align.CENTER);
		}
        this.flow.set_filter_func(this.filter_fun);
        this.flow.child_activated.connect(this.on_activate);

        var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        vbox.set_spacing(15);
        vbox.pack_start(this.flow, false, false, 0);

        this.scroll = new Gtk.ScrolledWindow(null, null);
        this.scroll.add(vbox);
	}

	public Gtk.ScrolledWindow box() {
		return this.scroll;
	}

	private string phrase() {
		if (this.win.search_entry != null) {
			return this.win.search_entry.text;
		} else {
			return "";
		}
	}

	private Item child2item(Gtk.FlowBoxChild child) {
		return this.win.items[child.get_index()];
	}

	private bool filter_fun(Gtk.FlowBoxChild child) {
		string p = this.phrase();
		Item item;
		bool ret;
		if (p.length <= 0) {
			item = null;
			ret = true;
		} else {
			item = this.child2item(child);
			ret = item.name.down().contains(p.down());
		}

		if (ret && this.first == null && item != null) {
			this.first = item;
		}
		return ret;
	}

	private void on_activate(Gtk.FlowBoxChild child) {
		var item = this.child2item(child);
		this.launch(item);
	}

	public void push(Item item) {
		item.win = this.win;
		this.flow.insert(item.box(), -1);
	}

	public void select_n(int n) {
		var child = this.flow.get_child_at_index(n);
		if (child != null) {
			child.grab_focus();
			this.flow.select_child(child);
		}
	}

	public void update() {
		this.first = null;
		this.flow.invalidate_filter();
	}

	public void launch(Item item) {
		if (!item.confirm) {
			this.launch_now(item);
		} else {
			this.win.hide();
			this.win.opts.stay = true;
			var yn_win = new GMenuWin();
			run_yesno(yn_win, item.name, yes => {
				if (yes) {
					// because `item' above reference if probably deleted
					List<unowned FlowBoxChild> c = this.win.items_cont
						.flow.get_selected_children();
					if (c.length() > 0) {
						Item i = this.child2item(c.data);
						this.launch_now(i);
					}
				} else {
					Gtk.main_quit();
				}
			});
			yn_win.show();
		}
	}

	public void launch_now(Item item) {
		if (this.win.onlaunch != null) {
			if (this.win.onlaunch(item)) {
				this.win.hide();
				return;
			}
		}

		var cmd = item.exec;
		if (cmd != null && cmd.length > 0) {
			if (item.terminal) {
				var trm = get_terminal();
				if (trm == null) {
					stderr.printf("Set $TERMINAL or install one of %s\n",
								  string.joinv(", ", terminals));
					print(">>> %s\n", item.exec);
				} else {
					cmd = trm + " -e " + cmd;
					system(cmd);
				}
			} else {
				system(cmd);
			}
		} else {
			print("%s\n", item.name);
		}
		Gtk.main_quit();
	}

	public void launch_first() {
		if (this.first != null) {
			this.launch(this.first);
		}
	}
}
