int load_power(GMenuWin win) {
	if (!exists("systemctl")) {
		stderr.printf("Error: systemctl does not exist\n");
		return 1;
	}

	win.push(new Item("Sleep",     "systemctl suspend",   "power-sleep",     "", false, false));
	win.push(new Item("Shutdown",  "systemctl poweroff",  "power-shutdown",  "", false, true));
	win.push(new Item("Restart",   "systemctl reboot",    "power-restart",   "", false, true));
	win.push(new Item("Hibernate", "systemctl hibernate", "power-hibernate", "", false, true));

	if (!exists("ndg")) {
		return 0;
	}

	win.push(new Item("Logout", "ndg wm end",     "power-logout", "", false, true));
	win.push(new Item("Lock",   "ndg lockscreen", "power-lock",   "", false, false));

	return 0;
}
