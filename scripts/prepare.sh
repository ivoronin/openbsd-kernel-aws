#!/bin/ksh
set -eu

usage() {
	echo "usage: prepare.sh source_url signify_key" >&2
	exit 1
}

fetch_openbsd_source() {
	typeset file

	cd /usr/src
	for file in SHA256.sig src.tar.gz sys.tar.gz; do
		ftp -V -o "$file" "$source_url/$file"
	done
	signify -C -p "$signify_key" -x SHA256.sig src.tar.gz sys.tar.gz
	tar xzf src.tar.gz
	tar xzf sys.tar.gz
	rm -f src.tar.gz sys.tar.gz SHA256.sig
}

main() {
	[ $# -eq 2 ] || usage

	source_url="$1"
	signify_key="$2"

	[ -f "$signify_key" ] || { echo "prepare: signify key not found: $signify_key" >&2; exit 1; }

	fetch_openbsd_source
}

main "$@"
