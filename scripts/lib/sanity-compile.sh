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

# 1. The compiler must produce an object and an executable.
"${GCC}" -c   "${TMPDIR}/hello.c" -o "${TMPDIR}/hello.o"
"${GCC}"      "${TMPDIR}/hello.c" -o "${TMPDIR}/hello"

# 2. The executable must be for the expected architecture and endianness.
info=$(file "${TMPDIR}/hello")
echo "${info}"

case "${TARGET}" in
    aarch64-*)
        echo "${info}" | grep -q 'ELF 64-bit LSB.*ARM aarch64' \
            || { echo "::error::not an aarch64 ELF"; exit 1; }
        ;;
    armv6*|armv7*|armv8*)
        echo "${info}" | grep -q 'ELF 32-bit LSB.*ARM' \
            || { echo "::error::not a 32-bit ARM ELF"; exit 1; }
        ;;
    *)
        echo "::error::unknown target family for sanity check: ${TARGET}" >&2
        exit 1
        ;;
esac

# 3. For hard-float ABIs, the ELF note must advertise the VFP register
#    convention; for soft-float the note must NOT advertise it.
#    file(1) reports "hard-float" for glibc targets, but may omit it for
#    musl targets (which use ld-musl-armhf.so.1 as the interpreter instead).
#    Fall back to readelf -A to check the ARM ABI attributes section directly.
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
