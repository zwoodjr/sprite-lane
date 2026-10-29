extends RefCounted

## Build stamp shown on the title screen, the pause menu, Settings and every
## tester feedback report. VERSION is bumped by hand with each tester drop;
## COMMIT / BUILT can be overwritten by a web export script (keep VERSION).
const VERSION := "0.11.0"
const COMMIT := "dev"
const BUILT := ""


## "v0.11.0 · dev" (+ " · 2026-10-29 06:10" when a build time is stamped).
static func stamp() -> String:
	var s := "v%s \u00b7 %s" % [VERSION, COMMIT]
	if BUILT != "":
		s += " \u00b7 " + BUILT
	return s
