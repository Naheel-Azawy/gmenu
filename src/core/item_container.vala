using Gtk;

class ItemsContainer {
	private GMenuWin           win;
	private Gtk.FlowBox        flow;
	private Gtk.ScrolledWindow scroll;

	private Item first   = null;
	private int  margins = 10;

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
		string p = this.phrase().down();
		Item item;
		bool ret;
		if (p.length <= 0) {
			item = null;
			ret = true;
		} else {
			item = this.child2item(child);
			ret = item.name.down().contains(p) ||
				item.exec.down().contains(p);
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

	public FlowBoxChild? selected_child() {
		List<unowned FlowBoxChild> c = this.win.items_cont
			.flow.get_selected_children();
		if (c.length() > 0) {
			return c.data;
		}
		return null;
	}

	public Item? selected_item() {
		FlowBoxChild child = this.selected_child();
		if (child != null) {
			return this.child2item(child);
		}
		return null;
	}

	public void select_child(FlowBoxChild child) {
		if (child != null) {
			child.grab_focus();
			this.flow.select_child(child);
		}
	}

	public void select_n(int n) {
		this.select_child(this.flow.get_child_at_index(n));
	}

	public void select_item(Item i) {
		var child = i.box().get_parent() as FlowBoxChild;
		this.select_child(child);
	}

	public Gtk.FlowBoxChild get_child_at_index(int n) {
		return this.flow.get_child_at_index(n);
	}

	public Item? last_item() {
		// NOTE: be careful, this can be O(n)
		var children = this.flow.get_children();
		FlowBoxChild last_child = null;
		unowned List<weak Gtk.Widget>? node = children.last();
		while (node != null) {
			if (node.data.visible) {
				last_child = node.data as FlowBoxChild;
				break;
			}
			node = node.prev;
		}
		if (last_child == null) {
			return null;
		}
		return this.child2item(last_child);
	}

	public Item? first_item() {
		// NOTE: be careful, this can be O(n)
		var children = this.flow.get_children();
		FlowBoxChild first_child = null;
		unowned List<weak Gtk.Widget>? node = children.first();
		while (node != null) {
			if (node.data.visible) {
				first_child = node.data as FlowBoxChild;
				break;
			}
			node = node.next;
		}
		if (first_child == null) {
			return null;
		}
		return this.child2item(first_child);
	}

	public void select_last() {
		var last = this.last_item();
		if (last != null) {
			this.select_item(last);
		}
	}

	public void select_first() {
		var first = this.first_item();
		if (first != null) {
			this.select_item(first);
		}
	}

	public void unselect() {
		FlowBoxChild child = this.selected_child();
		if (child != null) {
			this.flow.unselect_child(child);
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
					Item i = this.selected_item();
					if (i != null) {
						this.launch_now(i);
					}
				} else {
					main_end();
				}
			});
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
				run_on_terminal(cmd);
			} else {
				system(cmd);
			}
		} else {
			print("%s\n", item.name);
		}
		main_end();
	}

	public void launch_first() {
		if (this.first != null) {
			this.launch(this.first);
		}
	}

	/* public void scroll_to(Gtk.Widget widget) {
		Gtk.Widget child = this.scroll.get_child();
		if (child == null)
			return;

		int x, y;
		widget.translate_coordinates(child, 0, 0, out x, out y);

		Gtk.Allocation allocation;
		widget.get_allocation(out allocation);

		Gtk.Adjustment vadj = this.scroll.get_vadjustment();

		double top = vadj.get_value();
		double bottom = top + vadj.get_page_size();

		if (y < top) {
			vadj.set_value(y);
		} else if (y + allocation.height > bottom) {
			vadj.set_value(y + allocation.height - vadj.get_page_size());
		}
	}*/

	public void smooth_scroll_to(Gtk.Widget widget) {
		Gtk.Widget child = this.scroll.get_child();
		if (child == null)
			return;

		int x, y;
		if (!widget.translate_coordinates(child, 0, 0, out x, out y))
			return;

		Gtk.Allocation allocation;
		widget.get_allocation(out allocation);

		Gtk.Adjustment vadj = this.scroll.get_vadjustment();

		double current = vadj.get_value();
		double target = current;

		double top = current;
		double bottom = current + vadj.get_page_size();

		if (y < top) {
			target = y;
		} else if (y + allocation.height > bottom) {
			target = y + allocation.height - vadj.get_page_size();
		}

		target = target.clamp(
			vadj.get_lower(),
			vadj.get_upper() - vadj.get_page_size()
			);

		if (Math.fabs(target - current) < 1.0)
			return;

		double start = current;
		int64 start_time = GLib.get_monotonic_time();

		Timeout.add(16, () => {
				double elapsed = (GLib.get_monotonic_time() - start_time) / 1000000.0;
				double t = elapsed / 0.3; // 300 ms
				if (t > 1.0) t = 1.0;

				// Ease-in-out
				t = t * t * (3.0 - 2.0 * t);

				vadj.set_value(start + (target - start) * t);

				return t < 1.0;
			});
	}
}
