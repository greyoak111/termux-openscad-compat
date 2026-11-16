# termux-openscad-compat

Companion libraries so that binaries built against **boost < 1.92** keep working
when the devkit base carries **boost 1.92+**.

## The problem

boost 1.92 moved `boost::program_options::arg` into
`boost::program_options::detail::arg` (symbol
`_ZN5boost15program_options3argE` → `_ZN5boost15program_options6detail3argE`).
Termux's `openscad` package (2026.07.19) was built against the old symbol, so
against a 1.92 base it dies at load time:

```
CANNOT LINK EXECUTABLE ".../openscad": cannot locate symbol "_ZN5boost15program_options3argE" ...
```

## The fix (this release)

`openscad-compat-1.92.0-aarch64.tar.xz` contains two libraries meant to be
placed in the same directory and put on `LD_LIBRARY_PATH` ahead of the base:

- `libboost_po_192.so` — the official
  `boost_1:1.92.0_aarch64.deb`'s `libboost_program_options.so`, with only its
  soname changed (`patchelf --set-soname libboost_po_192.so`) so the loader
  keeps it apart from the base's copy, and the usual
  `/data/data/com.termux/` → `/data/data/cc.codroid/` RUNPATH rewrite.
- `libboost_program_options.so` — a 24-byte shim defining the old `arg`
  symbol (zero-filled `char[24]`, the same marker object boost uses) whose
  only `DT_NEEDED` is `libboost_po_192.so`. No other code.

When the loader resolves `openscad`'s `DT_NEEDED libboost_program_options.so`
it finds the shim first, which pulls in the renamed real library; the old
symbol resolves against the shim, everything else against the real 1.92 code.

## Reproduce

```sh
./build.sh          # needs curl, ar, tar(xz), patchelf, clang, python3
```

Downloads the official deb (SHA256-pinned), extracts the library, patches the
soname, compiles `shim.c`, and prints the tarball's SHA256. The tarball is
byte-reproducible with the same clang version.

## License

The bundled library is boost, [BSL-1.0](https://www.boost.org/LICENSE_1_0.txt)
(the tarball carries a copy). `shim.c` and `build.sh` are released under the
same license.
