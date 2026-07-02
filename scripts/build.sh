#!/bin/ksh
set -eu

usage() {
	echo "usage: build.sh release arch errata sp errata_url patches_path config_path signify_key drivers" >&2
	exit 1
}

apply_erratum() {
	typeset name="$1"
	typeset sig="/tmp/$name"
	typeset patch_file="/tmp/${name%.sig}"

	ftp -V -o "$sig" "$errata_url/$name"
	signify -Vep "$signify_key" -x "$sig" -m "$patch_file"

	if ! grep -Eq '^(Index: |--- )sys/' "$patch_file"; then
		rm -f "$sig" "$patch_file"
		return 1
	fi

	echo "build: applying kernel erratum $name"
	patch -p0 -d /usr/src < "$patch_file"
	rm -f "$sig" "$patch_file"
}

errata_signatures() {
	typeset index

	index=$(ftp -V -o - "$errata_url/") || {
		echo "build: failed to fetch errata index $errata_url/" >&2
		exit 1
	}

	printf '%s\n' "$index" |
		sed -n 's/.*\([0-9][0-9][0-9]_[A-Za-z0-9_][A-Za-z0-9_]*\.patch\.sig\).*/\1/p' |
		sort -u
}

apply_kernel_errata() {
	typeset name
	typeset erratum_level
	typeset applied_errata=000

	for name in $(errata_signatures); do
		erratum_level=${name%%_*}
		if [[ "$erratum_level" > "$errata" ]]; then
			continue
		fi

		if apply_erratum "$name"; then
			applied_errata="$erratum_level"
		fi
	done

	[ "$applied_errata" = "$errata" ] || {
		echo "build: errata $errata does not match applied kernel errata $applied_errata" >&2
		exit 1
	}
}

import_driver() {
	typeset entry="$1"
	typeset url gitref prefix dir

	prefix="${entry##*:}"
	url="${entry%:*}"
	gitref="${url##*@}"
	url="${url%@*}"

	dir=$(mktemp -d)
	echo "build: importing driver $url@$gitref"
	ftp -V -o "$dir/driver.tar.gz" "$url/archive/$gitref.tar.gz"
	tar -C "$dir" -xzf "$dir/driver.tar.gz"
	(cd "$dir"/*/"$prefix" && pax -rw sys /usr/src)
	rm -rf "$dir"
}

import_drivers() {
	typeset entry

	for entry in $drivers; do
		import_driver "$entry"
	done
}

apply_local_patches() {
	typeset patch_file

	[ -d "$patches_path" ] || return 0
	for patch_file in "$patches_path"/*.patch; do
		[ -e "$patch_file" ] || continue
		echo "build: applying $(basename "$patch_file")"
		patch -p0 -d /usr/src < "$patch_file"
	done
}

version_counter() {
	typeset revision=0 tail errata_dec

	case "$release" in
	*-aws[0-9]*)
		tail=${release##*-aws}
		revision=${tail%%-*}
		;;
	esac

	# errata is three digits; strip zeros so it is not read as octal
	errata_dec=${errata#0}
	errata_dec=${errata_dec#0}

	echo $(( revision * 1000 + errata_dec ))
}

build_kernels() {
	typeset kernel_config
	typeset kernel_configs="$conf.MP"

	(cd /usr/src/sys/dev/pci && make pcidevs.h pcidevs_data.h)

	cd "$arch_dir/conf"
	install -m 644 "$config_path" "$conf"
	{
		printf 'include "arch/%s/conf/%s"\n\n' "$arch" "$conf"
		printf 'option\tMULTIPROCESSOR\n'
		printf 'cpu*\tat mainbus?\n'
	} > "$conf.MP"

	hostname openbsd-kernel-aws
	ncpu=$(sysctl -n hw.ncpu)

	if [ "$sp" = y ]; then
		kernel_configs="$conf $kernel_configs"
	fi

	for kernel_config in $kernel_configs; do
		cd "$arch_dir/conf"
		config "$kernel_config"
		cd "$arch_dir/compile/$kernel_config"
		make obj >/dev/null
		version_counter > obj/version
		make -j"$ncpu"
	done
}

stage_bundle() {
	typeset bundle_dir="$work_dir/bundle"
	typeset artifact

	mkdir -p "$bundle_dir"

	install -m 755 /home/scripts/install.sh "$bundle_dir/install.sh"
	install -m 644 "$arch_dir/compile/$conf.MP/obj/bsd" "$bundle_dir/bsd.mp"
	if [ "$sp" = y ]; then
		install -m 644 "$arch_dir/compile/$conf/obj/bsd" "$bundle_dir/bsd"
	fi

	if [ "$sp" = y ]; then
		( cd "$arch_dir/compile" &&
		  tar -chzf "$bundle_dir/kernel.tgz" -s ',/obj/,/,' \
		      "$conf"/obj/*.o    "$conf"/obj/Makefile    "$conf"/obj/ld.script    "$conf"/obj/makegap.sh \
		      "$conf.MP"/obj/*.o "$conf.MP"/obj/Makefile "$conf.MP"/obj/ld.script "$conf.MP"/obj/makegap.sh )
	else
		( cd "$arch_dir/compile" &&
		  tar -chzf "$bundle_dir/kernel.tgz" -s ',/obj/,/,' \
		      "$conf.MP"/obj/*.o "$conf.MP"/obj/Makefile "$conf.MP"/obj/ld.script "$conf.MP"/obj/makegap.sh )
	fi

	artifact="/home/${release}.tgz"
	if [ "$sp" = y ]; then
		tar -C "$bundle_dir" -czf "$artifact" install.sh bsd bsd.mp kernel.tgz
	else
		tar -C "$bundle_dir" -czf "$artifact" install.sh bsd.mp kernel.tgz
	fi
	sha256 "$artifact" > "$artifact.SHA256"

	echo "build: staged $artifact"
}

main() {
	[ $# -eq 9 ] || usage

	release="$1"
	arch="$2"
	errata="$3"
	sp="$4"
	errata_url="$5"
	patches_path="$6"
	config_path="$7"
	signify_key="$8"
	drivers="$9"

	conf=AWS
	arch_dir="/usr/src/sys/arch/$arch"
	work_dir=/home/work

	case "$errata" in
	[0-9][0-9][0-9]) ;;
	*) echo "build: errata must be a three digit level like 013" >&2; exit 1 ;;
	esac
	case "$sp" in
	y|n) ;;
	*) echo "build: sp must be y or n" >&2; exit 1 ;;
	esac
	for entry in $drivers; do
		case "$entry" in
		?*://?*@?*:?*) ;;
		*) echo "build: bad driver entry: $entry" >&2; exit 1 ;;
		esac
	done
	[ -f "$config_path" ] || { echo "build: config not found: $config_path" >&2; exit 1; }
	[ -f "$signify_key" ] || { echo "build: signify key not found: $signify_key" >&2; exit 1; }

	rm -rf "$work_dir"
	mkdir -p "$work_dir"

	apply_kernel_errata
	import_drivers
	apply_local_patches
	build_kernels
	stage_bundle
}

main "$@"
