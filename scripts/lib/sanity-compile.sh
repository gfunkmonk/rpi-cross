#!/bin/bash
# Compile a tiny C program with the just-built toolchain and verify the
# resulting binary matches the expected target architecture. Cheap gate
# that catches gross CFLAGS / config regressions before we spend time
# tarring a broken toolchain.
#
# Usage: sanity-compile.sh <TARGET> <PREFIX>

set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <TARGET> <PREFIX>" >&2
    exit 1
fi

TARGET=$1
PREFIX=$2
GCC="${PREFIX}/bin/${TARGET}-gcc"

if [[ ! -x "${GCC}" ]]; then
    echo "Error: ${GCC} is not executable" >&2
    exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

cat > "${TMPDIR}/hello.c" <<'C'
#include <stdio.h>
int main(void) {
    puts("hello from rpi-cross");
    return 0;
}
C

# Bare-metal targets (e.g. the Pi Pico *-eabi / *-eabihf triples) don't have a
# Linux-style sysroot and need extra link-time options (--specs=picolibc.specs,
# a linker script, etc.) that this generic smoke test can't supply. For those
# we only verify that the compiler can produce a valid object file for the
# expected architecture.
case "${TARGET}" in
    *-linux-*) BARE_METAL=0 ;;
    *)         BARE_METAL=1 ;;
esac

"${GCC}" -c "${TMPDIR}/hello.c" -o "${TMPDIR}/hello.o"

if [[ "${BARE_METAL}" -eq 1 ]]; then
    info=$(file "${TMPDIR}/hello.o")
    echo "${info}"
    case "${TARGET}" in
        aarch64-*)
            echo "${info}" | grep -q 'ELF 64-bit LSB.*ARM aarch64' \
                || { echo "::error::not an aarch64 ELF"; exit 1; }
            ;;
        armv6-*|armv6m-*|armv7-*|armv8m-*|armv8-*)
            echo "${info}" | grep -q 'ELF 32-bit LSB.*ARM' \
                || { echo "::error::not a 32-bit ARM ELF"; exit 1; }
            ;;
        *)
            echo "::error::unknown target family for sanity check: ${TARGET}" >&2
            exit 1
            ;;
    esac
    echo "sanity check (compile-only) passed for ${TARGET}"
    exit 0
fi

# Linux targets: go further and link an executable so we can check its ABI.
"${GCC}" "${TMPDIR}/hello.c" -o "${TMPDIR}/hello"

info=$(file "${TMPDIR}/hello")
echo "${info}"

case "${TARGET}" in
    aarch64-*)
        echo "${info}" | grep -q 'ELF 64-bit LSB.*ARM aarch64' \
            || { echo "::error::not an aarch64 ELF"; exit 1; }
        ;;
    armv6-*|armv6m-*|armv7-*|armv8m-*|armv8-*)
        echo "${info}" | grep -q 'ELF 32-bit LSB.*ARM' \
            || { echo "::error::not a 32-bit ARM ELF"; exit 1; }
        ;;
    *)
        echo "::error::unknown target family for sanity check: ${TARGET}" >&2
        exit 1
        ;;
esac

# For hard-float ABIs, the ELF note must advertise the VFP register
# convention; for soft-float the note must NOT advertise it.
# file(1) reports "hard-float" for glibc targets, but may omit it for
# musl targets (which use ld-musl-armhf.so.1 as the interpreter instead).
# Fall back to readelf -A to check the ARM ABI attributes section directly.
case "${TARGET}" in
    *eabihf*)
        if ! echo "${info}" | grep -q 'hard-float'; then
            readelf -A "${TMPDIR}/hello" 2>/dev/null \
                | grep -q 'Tag_ABI_VFP_args.*VFP registers' \
                || { echo "::error::expected hard-float ABI in $(basename "${TARGET}")"; exit 1; }
        fi
        ;;
    *eabi)
        echo "${info}" | grep -q 'soft-float' \
            || { echo "::error::expected soft-float ABI in $(basename "${TARGET}")"; exit 1; }
        ;;
esac

echo "sanity check passed for ${TARGET}"
