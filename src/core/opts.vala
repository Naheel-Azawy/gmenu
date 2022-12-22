class Opts {
	public string prompt   = null;
	public string dims     = "12ix80%";
	public string css      = null;
	public int    index    = -1;
	public int    isize    = 64;
	public int    maxcols  = 7;
	public int    maxlbl   = 15;
	public bool   horiz    = false;
	public bool   nosearch = false;
	public bool   stay     = false;

	public static void args_help(string[] args) {
		print("usage: %s <CMD> [OPTION]...\n", args[0]);
		print("\n");
		print("Commands:\n");
		print("  apps    show desktop files from default directories\n");
		print("  power   system power options\n");
		print("  yesno   yes/no prompt\n");
		print("  (NONE)  dmenu-like behavior\n");
		print("\n");
		print("Options:\n");
		print("  -p, --prompt STR   title and prompt of the menu\n");
		print("  -d, --dims STR     dimensions of the window (pixels by default, %: window percent, i: icon percent)\n");
		print("  -s, --css STR      CSS file or string\n");
		print("  -nb STR            normal item background color\n");
		print("  -nf STR            normal item foreground color\n");
		print("  -sb STR            selected item background color\n");
		print("  -sf STR            selected item foreground color\n");
		print("  -n, --index INT    index of initially selected item\n");
		print("  -i, --isize INT    icon size (0 to disable icons)\n");
		print("  -c, --maxcols INT  maximum number of columns\n");
		print("      --maxlbl INT   maximum length of characters in item's names\n");
		print("  -h, --horiz        layout items horizontally\n");
		print("  -l, --list         -d '30%%x50%%' -n 0 -i 0 -h -c 1 --maxlbl 1000\n");
		print("      --nosearch     no search bar\n");
		print("      --stay         prevent quitting when out of focus\n");
		print("      --help         show this help\n");
		print("\n");
		print("Input:\n");
		print("  stdin can be any of the following when the command is (NONE)\n");
		print("  >>j, >>json STR           insert json string\n");
		print("  >>jfile, >>json-file STR  insert json file\n");
		print("  >>power                   insert power options\n");
		print("  >>desktops <STR>          insert desktop files at optional directory\n");
	}

	public string? args_parse(string[] args) {
		string mode = "dmenu";
		for (int i = 1; i < args.length; ++i) {
			switch (args[i]) {
			case "yesno":
			case "power":
			case "apps":
				mode = args[i];
				break;

			case "--prompt":
			case "-p":
				this.prompt = args[++i];
				break;

			case "--dims":
			case "-d":
				this.dims = args[++i];
				break;

			case "--css":
			case "-s":
				this.css = args[++i];
				break;

			case "-nb":
				if (this.css == null) this.css = "";
				this.css += "flowboxchild {" +
					"background-color: " + args[++i] + ";" +
					"}";
				break;

			case "-nf":
				if (this.css == null) this.css = "";
				this.css += "flowboxchild {" +
					"color: " + args[++i] + ";" +
					"}";
				break;

			case "-sb":
				if (this.css == null) this.css = "";
				this.css += "flowboxchild:selected {" +
					"background-color: " + args[++i] + ";" +
					"}";
				break;

			case "-sf":
				if (this.css == null) this.css = "";
				this.css += "flowboxchild:selected {" +
					"color: " + args[++i] + ";" +
					"}";
				break;

			case "--index":
			case "-n":
				this.index = int.parse(args[++i]);
				break;

			case "--isize":
			case "-i":
				this.isize = int.parse(args[++i]);
				break;

			case "--maxcols":
			case "-c":
				this.maxcols = int.parse(args[++i]);
				break;

			case "--maxlbl":
				this.maxlbl = int.parse(args[++i]);
				break;

			case "--horiz":
			case "-h":
				this.horiz = true;
				break;

			case "--nosearch":
				this.nosearch = true;
				break;

			case "--stay":
				this.stay = true;
				break;

			case "--list":
			case "-l":
				this.dims    = "30%x50%";
				this.index   = 0;
				this.isize   = 0;
				this.horiz   = true;
				this.maxcols = 1;
				this.maxlbl  = 1000;
				break;

			default:
				Opts.args_help(args);
				return null;
			}
		}

		return mode;
	}
}
