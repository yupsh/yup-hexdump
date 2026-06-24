#!/bin/sh
# Integration checks for yup-hexdump, run inside a Debian image with util-linux
# hexdump (bsdextrautils) installed, so its output can be checked against the
# real `hexdump` reference.
#
# parity INPUT ARGS...       — yup-hexdump must produce byte-identical output to
#                              util-linux `hexdump` for the given stdin + args.
# assert WANT INPUT ARGS...  — yup-hexdump must produce WANT exactly. Used for
#                              the many documented divergences from util-linux
#                              hexdump (see cmd-hexdump COMPATIBILITY.md):
#                              yup-hexdump is line-oriented (it splits stdin on
#                              newlines, resets the canonical offset to 0 per
#                              line, drops the newline byte, never wraps a line
#                              at 16 bytes, and emits no trailing offset line).
set -eu

fails=0

parity() {
	in=$1
	shift
	ours=$(printf '%b' "$in" | yup-hexdump "$@" 2>/dev/null || true)
	ref=$(printf '%b' "$in" | hexdump "$@" 2>/dev/null || true)
	if [ "$ours" = "$ref" ]; then
		printf 'ok    parity  hexdump %s\n' "$*"
	else
		printf 'FAIL  parity  hexdump %s\n        ref:  %s\n        ours: %s\n' "$*" "$ref" "$ours"
		fails=$((fails + 1))
	fi
}

assert() {
	want=$1
	in=$2
	shift 2
	got=$(printf '%b' "$in" | yup-hexdump "$@" 2>/dev/null || true)
	if [ "$got" = "$want" ]; then
		printf 'ok    assert  hexdump %s\n' "$*"
	else
		printf 'FAIL  assert  hexdump %s\n        want: %s\n        got:  %s\n' "$*" "$want" "$got"
		fails=$((fails + 1))
	fi
}

# Empty input is the only byte-identical case: both yup-hexdump and util-linux
# hexdump emit nothing (util-linux prints no trailing offset line for an empty
# stream).
parity ''
parity '' -C

# Default mode: space-separated lowercase hex bytes, one row per input line, the
# newline byte dropped. This is xxd-like and does NOT match util-linux hexdump's
# default (byte-swapped two-byte octal-grouped words + trailing offset line).
assert '61 62 63' 'abc\n'
assert "$(printf '48 69\n6f 6b')" 'Hi\nok\n'

# Canonical mode (-C): offset, midpoint-gapped hex field, ASCII sidebar — like
# util-linux `hexdump -C` for a single short line, EXCEPT the offset resets to
# 00000000 for every input line, the newline byte is consumed by the line split,
# and there is no trailing offset/length line.
assert '00000000  48 69                                             |Hi|' 'Hi\n' -C
assert '00000000  48 65 6c 6c 6f 2c 20 57  6f 72 6c 64              |Hello, World|' 'Hello, World\n' -C

# Per-line offset reset: each line starts again at 00000000 (util-linux keeps a
# single incrementing offset across the whole stream).
assert "$(printf '00000000  61 62 63                                          |abc|\n00000000  78 79 7a                                          |xyz|')" 'abc\nxyz\n' -C

# A full 16-byte line exercises the midpoint gap after the eighth byte.
assert '00000000  30 31 32 33 34 35 36 37  38 39 61 62 63 64 65 66  |0123456789abcdef|' '0123456789abcdef\n' -C

# No 16-byte wrap: a line longer than 16 bytes is rendered as ONE oversized row
# (util-linux wraps every 16 bytes). The hex field stops at column 16, so the
# extra bytes appear only in the sidebar.
assert '00000000  54 68 65 20 71 75 69 63  6b 20 62 72 6f 77 6e 20  |The quick brown fox jumps|' 'The quick brown fox jumps\n' -C

# Canonical glyph mapping: non-printable bytes show as '.' in the sidebar while
# their true value still appears in the hex field. NUL (\0000) and DEL (\0177)
# are written as `printf %b` octal escapes.
assert '00000000  41 00 42 7f                                       |A.B.|' 'A\0000B\0177\n' -C

# Missing trailing newline: the final (unterminated) line is rendered the same
# as a terminated one (the line split yields the bytes without a newline either
# way).
assert '00000000  48 69                                             |Hi|' 'Hi' -C

if [ "$fails" -ne 0 ]; then
	printf '\n%s check(s) failed\n' "$fails"
	exit 1
fi
printf '\nall checks passed\n'
