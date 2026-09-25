#!/bin/sh
# Manual test script for gmenu's stdin syntax.
#
# Covers: every old (deprecated) >>word command, every new :: syntax
# case, escaping, quoting edge cases, the automatic-fallback cases, a
# mixed old+new feed to confirm compatibility, id-based replace/delete,
# where=toolbar items (including overflow, mnemonics, and icons), and
# --noparse.
#
# Each block opens its own gmenu window. Check the item(s) shown, then
# press Escape (or pick an item) to move on to the next block. Run the
# whole thing, or comment out sections you don't need.
#
# NOTE: "::" is never special to any POSIX shell (dash or bash), quoted
# or not, so unlike some other marker characters (brackets, redirection
# operators, ...) it never needs shell quoting just to survive being
# echoed -- no spacing rules to remember either, see the "no space
# around ::" case in section VI.
#
# Usage:
#   GMENU=/path/to/gmenu ./test-syntax.sh
# (defaults to "gmenu" on PATH)

GMENU="${GMENU:-gmenu}"

t() {
	title="$1"
	shift
	echo "=== $title ==="
	"$GMENU" --title "$title" "$@"
}

# --- test data for the json-file cases -------------------------------
# NOTE: I have not seen load_json_file()'s source in this project, only
# Item.from_json's field names; this file's shape (a JSON array of item
# objects) is my best guess at what it expects. Adjust if it errors.
cat > /tmp/gmenu-test-items.json <<'JSON'
[
  {"name": "File item 1", "exec": "true"},
  {"name": "File item 2", "exec": "true", "confirm": true}
]
JSON


# =======================================================================
# I. Old syntax (deprecated, must still work unchanged)
# =======================================================================

t "1. old: plain text" <<'EOF'
Plain text item
Another plain item
EOF

t "2. old: >>power" <<'EOF'
>>power
EOF

t "3. old: >>desktops (default dirs)" <<'EOF'
>>desktops
EOF

t "4. old: >>desktops <dir>" <<'EOF'
>>desktops /usr/share/applications
EOF

# NOTE: select (old or new) only takes effect if it appears *before*
# the item at that index is pushed -- selection is applied at the moment
# that item is added, not retroactively. So it goes in the middle here,
# not at the end.
t "5. old: >>select N (note position, before target item)" <<'EOF'
First
Second
>>select 2
Third
Fourth
EOF

t "6. old: >>json (full item spec)" <<'EOF'
>>json {"name": "Old JSON item", "exec": "true", "icon": "dialog-information"}
EOF

t "7. old: >>j (alias for >>json)" <<'EOF'
>>j {"name": "Old j alias", "exec": "true"}
EOF

t "8. old: >>json-file <path>" <<EOF
>>json-file /tmp/gmenu-test-items.json
EOF

t "9. old: >>jfile (alias for >>json-file)" <<EOF
>>jfile /tmp/gmenu-test-items.json
EOF


# =======================================================================
# II. New syntax: decorated items
# =======================================================================

t "10. new: exec + confirm" <<'EOF'
Reboot :: exec=reboot confirm=true
EOF

t "11. new: icon + comment" <<'EOF'
Firefox :: icon=firefox comment="Web browser"
EOF

t "12. new: terminal=true" <<'EOF'
Htop :: exec=htop terminal=true
EOF

t "13. new: name field overrides leading text" <<'EOF'
placeholder :: name="Overridden Name" exec=true
EOF

t "14. new: icon-size" <<'EOF'
Big Icon Item :: icon=firefox icon-size=96
EOF

t "15. new: selected (the sub-label shown while highlighted)" <<'EOF'
Hover or select me :: selected="shown only while highlighted"
EOF

t "16. new: bare (unquoted) true/false" <<'EOF'
Bare bools :: terminal=false confirm=true
EOF

t "17. new: quoted key (same effect as bare)" <<'EOF'
Quoted key test :: "exec"=true "confirm"=true
EOF

t "18. new: fragment only, no leading text, no name field" <<'EOF'
:: exec=true comment="name field intentionally omitted -- edge case"
EOF


# =======================================================================
# III. New syntax: cmd directives (power / desktops / json-file)
# =======================================================================

t "19. new: cmd power" <<'EOF'
:: cmd=power
EOF

t "20. new: cmd desktops, dirs as a bare colon-joined value (no quotes needed)" <<'EOF'
:: cmd=desktops dirs=/usr/share/applications:/usr/local/share/applications
EOF

t "21. new: cmd desktops, default dirs" <<'EOF'
:: cmd=desktops
EOF

t "22. new: cmd json-file" <<EOF
:: cmd=json-file path=/tmp/gmenu-test-items.json
EOF


# =======================================================================
# IV. New syntax: cmd=set (change an option mid-session)
#
# LIVE_SETTABLE (opts.vala): title, dims, css, maxcols, index, isize,
# maxlbl, center, horiz, stay, notooltip, full, maxtoolbar. Anything
# else -- e.g. solid, or a typo -- correctly falls back rather than
# silently no-op'ing.
# =======================================================================

t "23. cmd=set: string option (title)" <<'EOF'
Before the title change
:: cmd=set title="Live Title"
After the title change
EOF

t "24. cmd=set: int option (maxcols)" <<'EOF'
One
Two
Three
:: cmd=set maxcols=2
Four
EOF

# NOTE: cmd=set index=N has the same rule >>select always had: it only
# takes effect if it appears *before* the item at that index is pushed
# -- selection happens at the moment that item is added, not
# retroactively. So it goes in the middle here, not at the end.
t "25. cmd=set: index (replaces the old, removed cmd=select)" <<'EOF'
Alpha
Beta
:: cmd=set index=2
Gamma
Delta
EOF

t "26. cmd=set: bool option, true (stay)" <<'EOF'
:: cmd=set stay=true
EOF

t "27. cmd=set: bool option, false (stay)" <<'EOF'
:: cmd=set stay=false
EOF

# notooltip is the one LIVE_SETTABLE bool whose "true"/"false" values
# don't map onto a plain "no"-prefixed CLI flag name (--tooltip is the
# reverse of --notooltip, not --nonotooltip); this exercises that path
# specifically, not just the more common stay/full/center/horiz shape.
t "28. cmd=set: bool with an irregular flag pair (notooltip/tooltip)" <<'EOF'
:: cmd=set notooltip=true
:: cmd=set notooltip=false
EOF

t "29. cmd=set: several options in one line" <<'EOF'
:: cmd=set title="Multi" maxcols=4 stay=true
EOF

t "30. cmd=set fallback: option exists but isn't in LIVE_SETTABLE (solid)" <<'EOF'
:: cmd=set solid=true
EOF

t "31. cmd=set fallback: not a real option at all" <<'EOF'
:: cmd=set bogus=x
EOF

t "32. cmd=set fallback: malformed int value" <<'EOF'
:: cmd=set maxcols=notanumber
EOF

t "33. cmd=set fallback: malformed bool value" <<'EOF'
:: cmd=set full=maybe
EOF


# =======================================================================
# V. Escaping "::"
# =======================================================================

t "34. escape: literal :: in text, no fragment intended" <<'EOF'
C++ std\::vector notes
EOF

t "35. escape: multiple escaped :: in one line" <<'EOF'
Left \:: middle \:: right
EOF

t "36. escape: escaped :: in the text part, then a real fragment" <<'EOF'
Ratio \:: legacy shown as text :: exec=true confirm=true
EOF


# =======================================================================
# VI. Quoting edge cases
# =======================================================================

t "37. quoting: double-quoted value containing whitespace" <<'EOF'
Multi word :: comment="has several separate words in it"
EOF

t "38. quoting: single-quoted value, and an escaped embedded quote" <<'EOF'
Single quoted :: exec='echo hi' comment='it\'s a test'
EOF

t "39. quoting: no space around :: at all still parses" <<'EOF'
No space::icon=firefox
EOF


# =======================================================================
# VII. Automatic fallback (no escaping needed, malformed/unrecognized
#      just degrades to a plain-text item using the whole original line)
#      -- except case 42, kept here deliberately as a contrast: it used
#      to fall back too, until unquoted values learned to absorb
#      trailing bare words (see section X below).
# =======================================================================

t "40. fallback: bare key can't start with a digit" <<'EOF'
Bare digit key fails :: 4x=bad
EOF

t "41. fallback: accidental :: that doesn't parse as key=value at all" <<'EOF'
See the docs :: over here for details
EOF

t "42. new: trailing bare words that aren't 'key=' fold into the previous value, rather than falling back" <<'EOF'
Trailing junk :: exec=true extra stuff after
EOF

t "43. fallback: unterminated quote" <<'EOF'
Broken :: exec="unterminated
EOF

t "44. fallback: parses fine, but the key isn't recognized" <<'EOF'
Ready :: status=green
EOF

t "45. fallback: cmd=select was removed, index is now cmd=set index=N" <<'EOF'
:: cmd=select index=2
EOF


# =======================================================================
# VIII. Compatibility: old and new syntax mixed in one feed
# =======================================================================

t "46. mixed: old + new together" <<'EOF'
Plain item
>>power
Reboot :: exec=reboot confirm=true
:: cmd=desktops
EOF


# =======================================================================
# IX. id: a later item with a previously-seen id replaces that item in
#     its same position, instead of being added as a new one
# =======================================================================

t "47. id: basic replace in place (watch the 2nd item change, not grow the list)" <<'EOF'
First
Battery: charging :: id=battery
Third
Battery: 80% :: id=battery exec="notify-send battery"
EOF

t "48. id: old >>json also supports id (same replace-in-place)" <<'EOF'
>>json {"name": "Status: starting", "id": "status"}
Unrelated item
>>json {"name": "Status: ready", "id": "status"}
EOF

t "49. id: an empty id (id=\"\") is the same as no id -- always appends" <<'EOF'
One :: id=""
Two :: id=""
EOF


# =======================================================================
# X. An unquoted value can contain spaces without the producer having to
#    quote it, as long as no later word in it happens to look exactly
#    like "identifier=" -- a run of whitespace only ends the value if
#    what follows really does look like the start of another key=value
#    pair (case 42 above is the same mechanism, from the other side: an
#    unquoted trailing word that ISN'T "key=" folds into the value
#    rather than causing a fallback). A value that's genuinely ambiguous
#    against that still needs explicit "..." or '...' quoting, same as
#    ever -- most values, file paths included, don't contain "word=".
# =======================================================================

t "50. new: unquoted value with spaces, running to end of line" <<'EOF'
my photo.jpg :: icon=/home/user/pictures/my photo.jpg
EOF

t "51. new: unquoted value with spaces, followed by another key" <<'EOF'
my photo.jpg :: icon=/home/user/pictures/my photo.jpg comment=nice
EOF

t "52. new: unquoted value with spaces, followed by several more keys" <<'EOF'
my file :: icon=/home/user/my folder/a file.jpg comment=hi terminal=true
EOF

t "53. fallback still applies to genuinely malformed input: a trailing key with no value at all" <<'EOF'
Broken :: exec=true extra=
EOF


# =======================================================================
# XI. where=toolbar: a plain button next to the search box instead of a
#     normal, filtered, navigable item. Still just an item underneath --
#     id-based replace and delete work on one exactly like they do on a
#     content item.
# =======================================================================

t "54. where=toolbar: a button next to the search box, alongside a normal content item" <<'EOF'
Alpha
Refresh :: where=toolbar icon=view-refresh
Settings :: where=toolbar
EOF

t "55. where=toolbar: id-based replace works the same as content items (position kept)" <<'EOF'
Foo :: where=toolbar id=x
Bar :: where=toolbar id=y
Foo-updated :: where=toolbar id=x
EOF

t "56. where=toolbar: cmd=delete removes one by id, same as it would a content item" <<'EOF'
Foo :: where=toolbar id=x
Bar :: where=toolbar id=y
:: cmd=delete id=x
EOF


# =======================================================================
# XII. cmd=delete / cmd=delete-all: remove an item outright instead of
#      replacing it. Either way, an id that doesn't match anything is a
#      silent no-op, not an error (case 58 below).
# =======================================================================

t "57. cmd=delete: removes one content item by id" <<'EOF'
First
Battery: charging :: id=battery
Third
:: cmd=delete id=battery
EOF

t "58. cmd=delete: a non-matching id is a silent no-op, not an error" <<'EOF'
Alpha :: id=a
:: cmd=delete id=does-not-exist
Still here
EOF

t "59. cmd=delete-all: clears everything, content and toolbar items alike" <<'EOF'
Alpha
Bravo
One :: where=toolbar
:: cmd=delete-all
Fresh start
EOF


# =======================================================================
# XIII. Toolbar overflow, mnemonics, and icons. --maxtoolbar defaults to
#       3; beyond that many where=toolbar items, the rest collect behind
#       an icon-only "More" button (hold Alt to see each visible item's
#       underlined letter; F10 focuses the first toolbar button, then
#       Tab/Space/Enter reach the rest, including "More", without a
#       mouse).
# =======================================================================

t "60. --maxtoolbar: beyond the default of 3, the rest collect behind an icon-only \"More\" button" <<'EOF'
One :: where=toolbar
Two :: where=toolbar
Three :: where=toolbar
Four :: where=toolbar
Five :: where=toolbar
EOF

# All five names start with the same letter on purpose -- stresses the
# collision-avoidance itself, not just "does a mnemonic show up at all".
# Hold Alt: Terminal keeps T, Text Editor falls to e, Trash to r, and so
# on, each one landing on the first letter of its own name that's not
# already spoken for.
t "61. where=toolbar: Alt+letter mnemonics avoid collisions even when every name starts the same (hold Alt)" <<'EOF'
Terminal :: where=toolbar
Text Editor :: where=toolbar
Trash :: where=toolbar
EOF

t "62. where=toolbar: icons show on direct buttons and inside the More menu alike" <<'EOF'
One :: where=toolbar
Two :: where=toolbar
Three :: where=toolbar
Four :: where=toolbar icon=accessories-text-editor
Five :: where=toolbar icon=user-trash
EOF

t "63. cmd=set maxtoolbar=N: changes the overflow threshold live" <<'EOF'
One :: where=toolbar
Two :: where=toolbar
Three :: where=toolbar
Four :: where=toolbar
Five :: where=toolbar
:: cmd=set maxtoolbar=2
EOF


# =======================================================================
# XIV. --noparse: turns off :: and >> parsing entirely -- every stdin
#      line becomes a plain-text item, verbatim, no exceptions. Unlike
#      the default, where a line that's just "END" stops input right
#      there, --noparse has no such sentinel either: only actually
#      closing stdin ends input, which is why the third line below still
#      shows up.
# =======================================================================

t "64. --noparse: every line is plain text, including one with :: and one that's just END" --noparse <<'EOF'
Alpha :: icon=firefox
END
Bravo
EOF

