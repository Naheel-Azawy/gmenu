#!/bin/sh
# Manual test script for gmenu's stdin syntax.
#
# Covers: every old (deprecated) >>word command, every new :: syntax
# case, escaping, quoting edge cases, the automatic-fallback cases, and
# a mixed old+new feed to confirm compatibility.
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
	echo "=== $1 ==="
	"$GMENU" --title "$1"
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
# maxlbl, center, horiz, stay, notooltip, full. Anything else -- e.g.
# solid, or a typo -- correctly falls back rather than silently no-op'ing.
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
# =======================================================================

t "40. fallback: bare key can't start with a digit" <<'EOF'
Bare digit key fails :: 4x=bad
EOF

t "41. fallback: accidental :: that doesn't parse as key=value at all" <<'EOF'
See the docs :: over here for details
EOF

t "42. fallback: trailing content after a valid pair that isn't itself a pair" <<'EOF'
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

