// True if `item' should be offered: either its command was overridden via
// `env_name' (in which case it's trusted as-is, whatever it needs), or it
// still runs the built-in default, which needs `binary' to be present.
private bool power_avail(string env_name, string binary) {
	return Environment.get_variable(env_name) != null || exists(binary);
}

int load_power(GMenuWin win) {
	var o = win.opts;

	if (power_avail("GMENU_POWER_SLEEP_CMD", "systemctl"))
		win.push(new Item("Sleep",     o.power_sleep_cmd,     "power-sleep",     "", "", false, false));
	if (power_avail("GMENU_POWER_SHUTDOWN_CMD", "systemctl"))
		win.push(new Item("Shutdown",  o.power_shutdown_cmd,  "power-shutdown",  "", "", false, true));
	if (power_avail("GMENU_POWER_RESTART_CMD", "systemctl"))
		win.push(new Item("Restart",   o.power_restart_cmd,   "power-restart",   "", "", false, true));
	if (power_avail("GMENU_POWER_HIBERNATE_CMD", "systemctl"))
		win.push(new Item("Hibernate", o.power_hibernate_cmd, "power-hibernate", "", "", false, true));

	if (power_avail("GMENU_POWER_LOGOUT_CMD", "ndg"))
		win.push(new Item("Logout", o.power_logout_cmd, "power-logout", "", "", false, true));
	if (power_avail("GMENU_POWER_LOCK_CMD", "ndg"))
		win.push(new Item("Lock",   o.power_lock_cmd,   "power-lock",   "", "", false, false));

	return 0;
}
