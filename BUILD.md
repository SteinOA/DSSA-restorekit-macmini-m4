# Build the preserved Windows main program

This export belongs in the private repository `SteinOA/DSSA-restorekit-macmini-m4`.
It preserves upstream RestoreKit v0.5.13, commit
`3cf86558a2f721ff956c99eebc132a022291ddb5`, and the full working source of every
vendored submodule. Read `provenance.json` for the original URLs and pinned commits.
The vendor trees are ordinary source files in this export; do not replace them
by fresh upstream checkouts or run `git submodule update` over them.
For a byte-exact copy, extract `archives/source-snapshot.zip` and verify
`source-manifest.json`; vendor Git attributes can otherwise change line endings.

The existing `bin/windows-x64/restorekit.exe` is the single tested main build,
SHA256 `B908AC86D7ECDAA09A16512B19AAD042C8E955F6F76C1D1DE6F9F3A921EAC278`.
The main executable builds successfully; completing the Mac restore is still
unverified. Building or inspecting this repository does not authorize a restore,
driver installation, certificate import, signing, or security-setting change.

## Prerequisites

Use a short checkout path on Windows, such as `C:\src\dssa-restorekit`, because
autotools convenience archives and Windows path limits can interact badly.
Use MSYS2 UCRT64 with GNU make, GCC, pkgconf, CMake, NASM, Autoconf, Automake,
Libtool, gettext, Perl, and the UCRT64 libusb/OpenSSL development packages.
Use the GNU-host Rust toolchain `stable-x86_64-pc-windows-gnu`, not only a GNU
cross-compilation target added to an MSVC-host toolchain. The original build used
local MSYS2 and Rust tools; they are deliberately excluded from this export.

In a UCRT64 shell at the exported `source/` directory:

```sh
export OPENSSL_NO_VENDOR=1
export OPENSSL_STATIC=1
export OPENSSL_DIR="$(cygpath -w /ucrt64)"
mkdir -p .build/libzip
export RESTOREKIT_ZIP_BUILD_DIR="$(cygpath -w "$PWD/.build/libzip")"
cargo +stable-x86_64-pc-windows-gnu build --offline --release --locked -p restorekit-cli --target x86_64-pc-windows-gnu
```

`--offline` requires the locked Rust dependencies to be cached already. Populate
the dependency cache separately when necessary; the snapshot includes Cargo.lock
but excludes downloaded dependency caches and compiled objects.

### Native Apple backend and cache boundaries

The exported build script no longer defines `IRECV_USE_LIBUSB` for libirecovery.
With UCRT64 GCC (`gcc -dumpmachine` must report `x86_64-w64-mingw32`), upstream
libirecovery selects `win32 native (setupapi)`. Its Windows C code then uses
Apple's native device interface and `DeviceIoControl`. The separate embedded
PID1905 mux still uses libusb; these are intentionally different transports.

The already-built B908 executable used this native archive. During development,
old libirecovery objects were explicitly cleaned and the native archive rebuilt
after the force-libusb flag was removed. That cleanup is a cache migration, not
an extra source change missing from this export. A fresh checkout contains no
compiled archives or `.built-*` markers and builds the native backend directly.

If reusing an old development target directory from transport experiments, do
not assume another `cargo build` updates those archives: this build script skips
libraries with a `.built-<library>` marker. Prefer a fresh, short isolated target
directory (set `CARGO_TARGET_DIR` before building) rather than copying old staging
archives. Keep the checkout and target paths short and without spaces. Before
using a newly compiled program, verify the generated libirecovery Makefile has
no `IRECV_USE_LIBUSB` macro, and inspect its static archive with `nm -u`: native
libirecovery must reference `DeviceIoControl`/SetupDi functions and must not
reference libusb/WinUSB transport functions. The final program legitimately links
libusb separately for the private PID1905 mux.

This recipe preserves the intended backend; a fresh-source build has not yet
been independently completed. Exact byte-for-byte reproduction also requires
pinning the compiler and external MSYS2 package versions, beyond Cargo.lock.

## Pure data fixtures

These fixtures never link libusb or access hardware:

```sh
mkdir -p .build
gcc -std=c11 -Wall -Wextra -Werror -O2 \
  crates/restorekit-sys/vendor/usbmuxd/tests/restore_identity_fixtures.c \
  -o .build/restore-identity-fixtures.exe
./.build/restore-identity-fixtures.exe
```

The recorded fixture result and sanitized build log are in `evidence/`.

## Hardware boundaries

The Windows main route keeps Apple's native DFU/recovery/KIS drivers and uses a
separate loopback mux on `127.0.0.1:27016` only for the authorized PID1905 final
restore transport. Apple's listener on port27015 is separate. The target identity
is intentionally restricted in the source to this particular Mac. The code
accepts only the exact 24-character or hyphenated 25-character representation of
that identity, after standard USB language/serial descriptor reads.

`restorekit check-usb` checks private service startup, ListDevices protocol and
teardown. If the authorized PID1905 device and a usable driver are present,
starting USB transport may initialize its configuration/interface. This command
does not upload firmware, enter DFU, erase data or install drivers. Run it in a
separate process; the Windows mux is deliberately single-use per process.

The separately archived `driver/pid1905` INF/CAT includes only a public signing
certificate. No private signing key, local trust-store export, IPSW, toolchain or
personal PC inventory is included. Any later Mac restore and temporary
driver/trust preparation need their own explicit authorization.

## Licenses and patch provenance

The original upstream license is preserved at `source/LICENSE`; individual
vendor licenses remain in their original source directories. Raw working-tree
diffs are in `patches/`. Additional source files that were untracked in the
upstream checkout are included as ordinary files and listed in provenance.
`source-manifest.json` records every copied source file's size and SHA256.
