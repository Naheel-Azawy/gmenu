using Gtk;

class ItemsContainer {
	private GMenuWin           win;
	private Gtk.FlowBox        flow;
	private Gtk.ScrolledWindow scroll;

	private Item first   = null;
	private int  margins = 10;

	// Destinations named by an item's `redirect' field (dmenu.vala's
	// frag_apply_item()) are opened once and kept open for the rest of
	// the session, keyed by the exact string given, rather than
	// reopened (and closed) every time an item is launched -- wasteful
	// for a file path, and outright wrong for a `redirect=<fd>' target,
	// since closing our own handle onto an already-open fd would close
	// that fd out from under whoever handed it to us. Plain fds, not
	// FileStreams, are cached: FileStream is a single-owner compact
	// type with no copy function, so Gee can't hold it as a value.
	private static Gee.HashMap<string, int> redirect_fds =
		new Gee.HashMap<string, int>();

	// --multi mode only: the child select_child() last moved keyboard
	// focus to, tracked so its `nav-cursor' CSS class (added below) can
	// be moved off it and onto the next one, rather than accumulating.
	// This is a second, independent thing from GTK's own :focus state:
	// relying on :focus's own CSS rendering directly was tried and
	// confirmed unreliable (its appearance turned out to depend on
	// GTK/theme specifics outside this project's control), so this
	// tracks and marks the "current" item explicitly instead.
	private Gtk.FlowBoxChild? nav_cursor = null;

	// GTK relayouts the whole flowbox -- every item already shown, not
	// just future ones -- the moment this is called; no rebuilding needed.
	public void set_maxcols(int n) {
		this.flow.set_max_children_per_line(n);
	}

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

        // Single mode (default): unchanged from before -- FlowBox's own
        // default is already SINGLE, and a single click both selects and
        // activates (launches). Multi mode: MULTIPLE selection handles
        // click/ctrl-click/shift-click/rubber-band selection natively;
        // activate-on-single-click off means a single click only selects,
        // a double click activates (see on_activate()).
        if (this.win.opts.multi) {
            this.flow.set_selection_mode(Gtk.SelectionMode.MULTIPLE);
            this.flow.set_activate_on_single_click(false);
        }

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

	// A flow box child is really shown only when it is both shown by the
	// application (`visible') and not filtered out by the flow box.
	// GtkFlowBox implements its filter with gtk_widget_set_child_visible(),
	// which leaves the `visible' property untouched. Hence, checking
	// `visible' alone reports true even for filtered out children.
	public static bool child_shown(Gtk.Widget? w) {
		return w != null && w.get_visible() && w.get_child_visible();
	}

	// The shown child in the row above/below `from', at the closest x
	// position to it -- null if `from' is already in the top/bottom
	// shown row. Used for --multi mode's Up/Down (GMenuWin.on_key()):
	// opts.maxcols is only the configured *ceiling* on columns per row,
	// not necessarily how many actually fit -- FlowBox reflows to fewer
	// whenever the window is narrower than that many items need, so
	// jumping by a fixed opts.maxcols would land on the wrong item (or
	// the wrong row entirely) as soon as the real layout differs from
	// it. Reading each shown child's actual allocated position instead
	// always matches what's really on screen, including a ragged last
	// row with fewer items than a full one.
	public FlowBoxChild? row_neighbor(FlowBoxChild from, bool down) {
		Gtk.Allocation from_alloc;
		from.get_allocation(out from_alloc);

		int row_y = -1;
		foreach (unowned var w in this.flow.get_children()) {
			if (!child_shown(w)) continue;
			Gtk.Allocation a;
			w.get_allocation(out a);
			if (down ? (a.y > from_alloc.y) : (a.y < from_alloc.y)) {
				if (row_y == -1 ||
					(down ? a.y < row_y : a.y > row_y)) {
					row_y = a.y;
				}
			}
		}
		if (row_y == -1) {
			return null; // already in the top/bottom shown row
		}

		FlowBoxChild? best = null;
		int best_dx = int.MAX;
		foreach (unowned var w in this.flow.get_children()) {
			if (!child_shown(w)) continue;
			Gtk.Allocation a;
			w.get_allocation(out a);
			if (a.y != row_y) continue;
			int dx = (a.x - from_alloc.x).abs();
			if (dx < best_dx) {
				best_dx = dx;
				best = (FlowBoxChild) w;
			}
		}
		return best;
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

	// Swaps in `item's widget at the position currently held by whatever
	// item is at `idx', for GMenuWin.push_real()'s id-based replace.
	// Removing then inserting at the same index is a net-zero shift for
	// every other child: nothing else's position changes. If the old
	// widget was the selected one, the new one takes over that selection
	// -- GTK doesn't carry it across a remove/insert on its own, since
	// as far as it's concerned these are two unrelated widgets.
	public void replace_at(int idx, Item item) {
		item.win = this.win;
		var old_child = this.flow.get_child_at_index(idx);
		bool was_selected = old_child.is_selected();
		this.flow.remove(old_child);
		this.flow.insert(item.box(), idx);
		if (was_selected) {
			this.select_n(idx);
		}
	}

	// Removes the widget at `idx' from the flowbox, for cmd=delete
	// (GMenuWin.delete_by_id()). GTK reindexes every following child
	// down by one on its own; the caller is responsible for keeping
	// win.items (and every Item.i) in that same shifted order, since
	// child2item() relies on the two staying in lockstep.
	public void remove_at(int idx) {
		var child = this.flow.get_child_at_index(idx);
		if (child == null) return;
		if (child == this.nav_cursor) {
			this.nav_cursor = null; // would otherwise dangle
		}
		this.flow.remove(child);
	}

	// cmd=delete-all (GMenuWin.delete_all()).
	public void remove_all() {
		foreach (unowned var w in this.flow.get_children()) {
			this.flow.remove(w);
		}
		this.nav_cursor = null;
		this.update();
	}

	// The "current position" for navigation and scroll-to-selection
	// purposes. In single mode this is the same thing as the (one)
	// actual GTK selection. In multi mode it can't be: navigating must
	// not itself select (see select_child() below), so there is no
	// dependable single GTK-selected child to read back -- the
	// keyboard-focused child is used instead, which select_child() (and
	// a click) always sets regardless of mode.
	public FlowBoxChild? selected_child() {
		if (this.win.opts.multi) {
			return this.win.get_focus() as FlowBoxChild;
		}
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

	// Grabs keyboard focus, and, in single mode, also selects -- a single
	// call covers both, since single mode's "current item" and "selected
	// item" are the same thing. In multi mode, actual selection is
	// click/ctrl-click/shift-click/rubber-band (native to MULTIPLE mode)
	// or space (see GMenuWin.on_key()); this only moves the focus cursor.
	// Confirmed empirically: flow.select_child() *adds* to the selection
	// rather than replacing it in MULTIPLE mode, so calling it here during
	// arrow-key navigation would accumulate every item passed over.
	// Deliberately does not touch the nav-cursor marker (see
	// mark_nav_cursor() below) -- this is called from places, like
	// --index's initial placement, that must not show it.
	public void select_child(FlowBoxChild child) {
		if (child != null) {
			child.grab_focus();
			if (!this.win.opts.multi) {
				this.flow.select_child(child);
			}
		}
	}

	// The nav-cursor marker (see the CSS in the constructor above) is
	// only ever shown because of an explicit call here, made only by
	// GMenuWin.on_key()'s keyboard navigation -- not on startup, not for
	// --index's initial placement, and not for a mouse click (which
	// instead calls hide_nav_cursor(), wired up in the constructor).
	public void mark_nav_cursor(FlowBoxChild? child) {
		if (!this.win.opts.multi || child == this.nav_cursor) return;
		if (this.nav_cursor != null) {
			this.nav_cursor.get_style_context().remove_class("nav-cursor");
		}
		if (child != null) {
			child.get_style_context().add_class("nav-cursor");
		}
		this.nav_cursor = child;
	}

	public void hide_nav_cursor() {
		this.mark_nav_cursor(null);
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
			if (child_shown(node.data)) {
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
			if (child_shown(node.data)) {
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

	// Only meaningful in single mode: clears the navigation highlight
	// when the search filter changes, since the highlighted item may no
	// longer be relevant. In multi mode this would be reached by the
	// same search-change/focus-in callers, but a no-op is correct there
	// -- real multi-selections must survive further searching, not be
	// cleared just because the user kept typing to find more items.
	public void unselect() {
		if (this.win.opts.multi) return;
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
					if (item.where == "toolbar") {
						this.launch_now(item);
					} else {
						// because `item' above reference if probably deleted
						Item i = this.selected_item();
						if (i != null) {
							this.launch_now(i);
						}
					}
				} else {
					main_end();
				}
			});
		}
	}

	// Writes `text' (an item's name, one per line -- the only thing
	// gmenu itself ever prints as output) to wherever `redirect'
	// names: null/empty/"stdout" (the default) or "stderr" go to the
	// standard streams as before; a bare integer is an already-open
	// file descriptor to write into directly; anything else is a file
	// path, opened (and kept open -- see redirect_fds above) in append
	// mode. Falls back to stdout, with a warning on stderr, if the
	// target can't be opened.
	private static void write_output(string text, string? redirect) {
		if (redirect == null || redirect == "" || redirect == "stdout") {
			print("%s\n", text);
			return;
		}
		if (redirect == "stderr") {
			stderr.printf("%s\n", text);
			return;
		}

		int fd;
		if (redirect_fds.has_key(redirect)) {
			fd = redirect_fds[redirect];
		} else {
			int given_fd;
			if (int.try_parse(redirect, out given_fd)) {
				fd = given_fd; // already open, inherited from whoever launched us
			} else {
				fd = Posix.open(redirect,
					Posix.O_WRONLY | Posix.O_CREAT | Posix.O_APPEND, 0644);
				if (fd < 0) {
					stderr.printf(
						"gmenu: failed to open redirect target '%s', falling back to stdout\n",
						redirect);
					print("%s\n", text);
					return;
				}
			}
			redirect_fds[redirect] = fd;
		}

		string line = text + "\n";
		Posix.write(fd, line, line.length);
	}

	public void launch_now(Item item) {
		if (this.win.onlaunch != null) {
			if (this.win.onlaunch(item)) {
				this.win.hide();
				return;
			}
		}

		if (item.feed != null && item.feed.length > 0) {
			// Feeds the value back through the same dispatch a real
			// stdin line goes through in run_dmenu() (old `>>' syntax,
			// then a `::' fragment -- cmd=... directives included --
			// falling back to a plain-text item if neither matches),
			// so `feed' can bake a whole submenu, or a cmd=... action,
			// right onto the item that triggers it, with no driving
			// script needed to notice the selection and push a
			// follow-up. Never prints, execs, or exits -- regardless of
			// --oneshot, since the point is for the session to keep
			// going. Also clears the search box: the fed-in item(s)
			// would otherwise risk being hidden by whatever query is
			// still typed from finding this one.
			if (!parse_push_cmd_line(this.win, item.feed) &&
				!frag_push_line(this.win, item.feed)) {
				this.win.push(new Item(item.feed), true);
			}
			if (this.win.search_entry != null) {
				this.win.search_entry.text = "";
			}
			return;
		}

		var cmd = item.exec;
		if (cmd != null && cmd.length > 0) {
			if (item.terminal) {
				run_on_terminal(cmd);
			} else {
				system(cmd);
			}
		} else {
			write_output(item.name, item.redirect);
		}

		// --nooneshot: stay open after printing/running the item instead
		// of exiting, so the caller can keep this session going; see
		// dmenu.vala's `:: cmd=exit' for how it ends explicitly then
		if (this.win.opts.oneshot) {
			main_end();
		}
	}

	public void launch_first() {
		if (this.first != null) {
			this.launch(this.first);
		}
	}

	// --multi mode: space toggles the focused child (GMenuWin.on_key()).
	public void toggle_child(FlowBoxChild child) {
		if (child.is_selected()) {
			this.flow.unselect_child(child);
		} else {
			this.flow.select_child(child);
		}
	}

	// --multi mode: ctrl-a (GMenuWin.on_key()). Toggles between selecting
	// and unselecting every *currently visible* item -- child_shown()
	// respects the search filter, so a filtered-out item is left alone
	// either way. Not exposed by FlowBox itself (only the per-child
	// select_child()/unselect_child() are), so done with a plain loop.
	public void toggle_select_all() {
		int total = 0, selected = 0;
		foreach (unowned var w in this.flow.get_children()) {
			if (!child_shown(w)) continue;
			total++;
			if (((FlowBoxChild) w).is_selected()) selected++;
		}
		bool all_selected = total > 0 && selected == total;
		foreach (unowned var w in this.flow.get_children()) {
			if (!child_shown(w)) continue;
			var child = (FlowBoxChild) w;
			if (all_selected) {
				this.flow.unselect_child(child);
			} else {
				this.flow.select_child(child);
			}
		}
	}

	// --multi mode: enter or the Done button (GMenuWin.on_key(),
	// build_real()). Prints each selected item's name, one per line, in
	// display order (get_selected_children()'s own order), then exits.
	// If nothing was ever explicitly selected (no click, no space) but
	// the keyboard nav-cursor is currently showing, that one item is
	// used instead of printing nothing -- matches how single mode's
	// Enter acts on wherever you've navigated to, even without some
	// separate, explicit "selecting" step.
	public void finish_multi() {
		var selected = this.flow.get_selected_children();
		if (selected.length() == 0 && this.nav_cursor != null) {
			var item = this.child2item(this.nav_cursor);
			write_output(item.name, item.redirect);
		} else {
			foreach (unowned var child in selected) {
				var item = this.child2item(child);
				write_output(item.name, item.redirect);
			}
		}

		if (this.win.opts.oneshot) {
			main_end();
		} else {
			// --nooneshot: printed, but staying open -- clear the
			// just-printed selection so the next Enter/Done starts a
			// fresh round instead of reprinting the same items
			this.flow.unselect_all();
			this.hide_nav_cursor();
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
