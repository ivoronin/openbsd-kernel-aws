#!/bin/ksh
set -eu

PATH=/usr/bin:/bin:/usr/sbin:/sbin
here=$(pwd)
kernel_dir=/usr/share/relink/kernel
sha_file=/var/db/kernel.SHA256

[ -f "$here/bsd.mp" ] || { echo "install.sh: missing bsd.mp" >&2; exit 1; }
[ -f "$here/kernel.tgz" ] || { echo "install.sh: missing kernel.tgz" >&2; exit 1; }

config=AWS.MP
install -m 600 "$here/bsd.mp" /bsd
if [ -f "$here/bsd" ]; then
	install -m 600 "$here/bsd" /bsd.sp
fi

mkdir -p /var/db "$kernel_dir"
sha256 -h "$sha_file" /bsd

rm -rf "${kernel_dir:?}/$config"
mkdir -p "$kernel_dir"
chmod 700 "$kernel_dir"
tar -C "$kernel_dir" -xzf "$here/kernel.tgz" "$config"
install -m 600 "$here/kernel.tgz" "$kernel_dir.tgz"

cd "$kernel_dir/$config"
make newbsd
make reconfig
make newinstall
sync

sha256 -C "$sha_file" /bsd
echo "install.sh: installed and relinked $config"
