#!/bin/sh
# Download, verify, and extract an rpi-cross toolchain.
#
# Usage:
#   ./install.sh <TARGET>                  # latest release
#   ./install.sh <TARGET> <RELEASE>        # specific release
#   RELEASE_PREFIX=... ./install.sh <T>    # mirror (advanced)
#
# Installs into /opt/x-tools/<TARGET> because the toolchain bakes that
# path into its specs via CT_PREFIX_DIR.

set -eu

REPO=${REPO:-gfunkmonk/rpi-cross}
INSTALL_DIR=${INSTALL_DIR:-/opt/x-tools}

usage() {
    cat >&2 <<EOF
Usage: $0 <target> [release]

Examples:
  $0 aarch64-rpi5-linux-gnu
  $0 armv6-rpi-linux-gnueabihf v2026.04

Environment:
  REPO         Default: gfunkmonk/rpi-cross
  INSTALL_DIR  Default: /opt/x-tools
EOF
    exit 2
}

[ "${1:-}" ] || usage
TARGET=$1
RELEASE=${2:-}

have() { command -v "$1" >/dev/null 2>&1; }
have curl || { echo "install.sh: curl is required" >&2; exit 1; }
have tar || { echo "install.sh: tar is required" >&2; exit 1; }
have sha256sum || { echo "install.sh: sha256sum is required" >&2; exit 1; }

if [ -z "${RELEASE}" ]; then
    RELEASE=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
        | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)
    [ -n "${RELEASE}" ] || {
        echo "install.sh: could not resolve latest release for ${REPO}" >&2
        exit 1
    }
fi

URL_BASE="https://github.com/${REPO}/releases/download/${RELEASE}"
TARBALL="${TARGET}.tar.xz"
CHECKSUM="${TARGET}.tar.xz.sha256"

WORKDIR=$(mktemp -d)
trap 'rm -rf "${WORKDIR}"' EXIT
cd "${WORKDIR}"

echo "==> Fetching ${TARBALL} from ${RELEASE}"
curl -fL --proto '=https' --tlsv1.2 -o "${TARBALL}" "${URL_BASE}/${TARBALL}"
curl -fL --proto '=https' --tlsv1.2 -o "${CHECKSUM}" "${URL_BASE}/${CHECKSUM}"

echo "==> Verifying SHA-256"
sha256sum -c "${CHECKSUM}"

echo "==> Extracting to ${INSTALL_DIR}/${TARGET}"
SUDO=
[ "$(id -u)" -eq 0 ] || SUDO=sudo
${SUDO} mkdir -p "${INSTALL_DIR}"
${SUDO} rm -rf "${INSTALL_DIR:?}/${TARGET}"
${SUDO} tar -C "${INSTALL_DIR}" -xf "${TARBALL}"

cat <<EOF

Done. Add the toolchain to your PATH:

  export PATH="${INSTALL_DIR}/${TARGET}/bin:\$PATH"

CMake:
  cmake -DCMAKE_TOOLCHAIN_FILE=${INSTALL_DIR}/${TARGET}/share/cmake/${TARGET}.toolchain.cmake ...

Meson:
  meson setup build --cross-file=${INSTALL_DIR}/${TARGET}/share/meson/${TARGET}-cross.ini
EOF
