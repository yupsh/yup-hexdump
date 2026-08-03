// Command yup-hexdump is the CLI wrapper around github.com/gloo-foo/cmd-hexdump.
package main

import (
	clix "github.com/gloo-foo/cli"
	command "github.com/gloo-foo/cmd-hexdump"
	urf "github.com/urfave/cli/v3"
)

// version is the build version. It defaults to "dev" for local builds and is
// overridden at release time via the linker: -ldflags "-X main.version=<v>".
var version = "dev"

const (
	name          = "hexdump"
	flagCanonical = "canonical"
)

// synopsis is the multi-line --help usage block; urfave/cli indents it three
// spaces, so the lines stay flush-left.
const synopsis = `hexdump [OPTIONS] [FILE...]

The hexdump utility displays FILE contents in various formats.
With no FILE, or when FILE is -, read standard input.`

// spec declares the hexdump wrapper: a file-or-stdin filter with a canonical
// display flag.
var spec = clix.Spec{
	Name:     name,
	Summary:  "display file contents in hexadecimal, decimal, octal, or ascii",
	Synopsis: synopsis,
	Build:    build,
	Flags: []urf.Flag{
		&urf.BoolFlag{
			Name:    flagCanonical,
			Aliases: []string{"C"},
			Usage:   "canonical hex+ASCII display",
			Sources: urf.EnvVars("YUP_HEXDUMP_CANONICAL"),
		},
	},
}

// build maps the invocation to hexdump's pipeline: a file-or-stdin source into
// the hexdump command configured by the canonical flag.
func build(inv clix.Invocation) (clix.Source, clix.Command, error) {
	return clix.OperandsOrStdin(inv), command.Hexdump(options(inv.Args)...), nil
}

// options folds the parsed flags into hexdump's option values.
func options(c *urf.Command) []any {
	var opts []any
	if c.Bool(flagCanonical) {
		opts = append(opts, command.HexdumpCanonical)
	}
	return opts
}

// runMain is an indirection seam so main's wiring is testable without spawning
// the process; a test swaps it and restores it.
var runMain = clix.Main

func main() { runMain(spec, version) }
