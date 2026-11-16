#!/bin/sh
# Reproduce openscad-compat-1.92.0-aarch64.tar.xz from the official Termux boost
# package + a 24-byte shim compiled with clang.
#   ./build.sh [outdir]
# Needs: curl, ar, tar (xz), patchelf, clang, python3. Prints the tarball's SHA256.
#
# Why this exists: boost 1.92 moved boost::program_options::arg into
# boost::program_options::detail::arg, so binaries built against older boost
# (Termux's openscad 2026.07.19 is one) fail to link at load time with
#   cannot locate symbol "_ZN5boost15program_options3argE"
# This tarball carries:
#   libboost_po_192.so            — the official libboost_program_options.so from
#                                   boost 1.92.0, soname-renamed so the loader keeps
#                                   it apart from the devkit base's copy
#   libboost_program_options.so   — a shim that defines the old arg symbol and adds
#                                   DT_NEEDED libboost_po_192.so, nothing else
# Put both on LD_LIBRARY_PATH ahead of the base lib when the binary fails to link.
#
# Reproducibility: the renamed copy is byte-stable; the shim is compiled from
# shim.c, so identical clang versions produce identical bytes. The release pins
# the build from this toolchain.
set -eu
VER=1.92.0
DEB="boost_1:${VER}_aarch64.deb"
SHA=1cc81ed769453f84944095dab82228af747637e33e5eefdb8738ad2ca6964b24
URL="https://packages.termux.dev/apt/termux-main/pool/main/b/boost/${DEB}"
OUT="${1:-.}"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/scadcompat.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

echo "downloading $URL"
curl -fL --retry 3 -o "$TMP/$DEB" "$URL"
echo "$SHA  $TMP/$DEB" | sha256sum -c -

mkdir "$TMP/deb" "$TMP/stage"
(cd "$TMP/deb" && ar x "../$DEB" data.tar.xz)
tar -xJf "$TMP/deb/data.tar.xz" -C "$TMP/deb"
L="$TMP/deb/data/data/com.termux/files/usr/lib"

cp "$L/libboost_program_options.so" "$TMP/stage/libboost_po_192.so"

# Same-length prefix rewrite that devkit does for Termux packages:
# /data/data/com.termux/ -> /data/data/cc.codroid/ (both 22 bytes).
python3 - "$TMP/stage/libboost_po_192.so" <<'PY'
import sys
p = sys.argv[1]
A = b"/data/data/com.termux/"
B = b"/data/data/cc.codroid/"
assert len(A) == len(B)
data = open(p, "rb").read()
open(p, "wb").write(data.replace(A, B))
PY
patchelf --set-soname libboost_po_192.so "$TMP/stage/libboost_po_192.so"

clang -shared -fPIC -Wl,--no-undefined \
  -L "$TMP/stage" -l:libboost_po_192.so \
  "$(dirname "$0")/shim.c" -o "$TMP/stage/libboost_program_options.so"

curl -fsSL https://www.boost.org/LICENSE_1_0.txt -o "$TMP/stage/LICENSE"
chmod 644 "$TMP"/stage/*
tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner --format=gnu \
  -cJf "$OUT/openscad-compat-$VER-aarch64.tar.xz" -C "$TMP/stage" .
sha256sum "$OUT/openscad-compat-$VER-aarch64.tar.xz"
