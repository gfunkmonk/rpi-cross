# rpi-cross

[![Release](https://github.com/gfunkmonk/rpi-cross/actions/workflows/release.yaml/badge.svg)](https://github.com/gfunkmonk/rpi-cross/actions/workflows/release.yaml)
<img align="left" width="262" height="335" alt="clipart3211372-1" src="https://github.com/user-attachments/assets/33d6a411-8462-40ef-a495-eca9487e18e7" />


| Component | Version |   
| --------- | ------- |
| GCC       | 15      |
| binutils  | 2.46    |
| Linux headers | 6.18 |
| glibc     | 2.43    |
| musl      | 1.2.6   |
| uClibc-ng | 1.0.57  |
| Linker    | mold (default) |



Per-model tuned cross-compilation toolchains for Raspberry Pi, built with a
fork of [crosstool-NG](https://github.com/crosstool-ng/crosstool-ng).

Each release contains ready-to-use GCC/binutils toolchains linked against
either glibc, musl, or uClibc-ng, with per-CPU `-mcpu`/`-mtune` flags baked
into the default specs.

## Targets

| Pi model | Bits | Triple prefix                   | Libc variants                                |
| -------- | ---- | ------------------------------- | -------------------------------------------- |
| Pi 1 / Zero / Zero W       | 32 | `armv6-rpi-linux-*`        | `gnueabi`, `musleabi`, `uclibcgnueabi`       |
| Pi 2                        | 32 | `armv7-rpi2-linux-*`       | `gnueabihf`, `musleabihf`, `uclibcgnueabihf` |
| Pi 3 (32-bit userspace)     | 32 | `armv8-rpi3-linux-*`       | `gnueabihf`, `musleabihf`, `uclibcgnueabihf` |
| Pi 4 / CM4 (32-bit)         | 32 | `armv8-rpi4-linux-*`       | `gnueabihf`, `musleabihf`, `uclibcgnueabihf` |
| Pi 3 / Zero 2W              | 64 | `aarch64-rpi3-linux-*`     | `gnu`, `musl`, `uclibc`                      |
| Pi 4 / CM4                  | 64 | `aarch64-rpi4-linux-*`     | `gnu`, `musl`, `uclibc`                      |
| Pi 5                        | 64 | `aarch64-rpi5-linux-*`     | `gnu`, `musl`, `uclibc`                      |

## Miscellaneous
| Type     | Bits | Triple                             | Notes
| ------------------| ---- | ---------------------------------- | ---------------------------------------------|
| Pi Pico			       | 32 | `armv6m-pico-eabi`	    | built with `picolib`			 |
| Pi Pico2		       | 32 | `armv8m-pico-eabi`	    | built with `picolib`			 |
| Beagle Bone Black		      | 32 | `armv7-beaglebone-linux-*` | `gnueabihf`, `musleabihf`, `uclibcgnueabihf` |
| linaro musl                         | 32 | `arm-linaro-musl`           | `Linaro GCC 7.4-2019.02`                     |
| linaro gnu                         | 32 | `arm-linaro-gnu`           | `Linaro GCC 7.4-2019.02`                     |
| linaro uclibc-ng                         | 32 | `arm-linaro-uclibc`           | `Linaro GCC 7.4-2019.02`                     |

## Install (prebuilt tarballs)

Pick a target from the [latest release](https://github.com/gfunkmonk/rpi-cross/releases/latest)
and install into `/opt/x-tools` (the path the toolchain was built for):

```sh
TARGET=aarch64-rpi5-linux-gnu
RELEASE=<release-name>

curl -LO "https://github.com/gfunkmonk/rpi-cross/releases/download/${RELEASE}/${TARGET}.tar.xz"
curl -LO "https://github.com/gfunkmonk/rpi-cross/releases/download/${RELEASE}/${TARGET}.tar.xz.sha256"
sha256sum -c "${TARGET}.tar.xz.sha256"

sudo mkdir -p /opt/x-tools
sudo tar -C /opt/x-tools -xf "${TARGET}.tar.xz"

export PATH="/opt/x-tools/${TARGET}/bin:$PATH"
echo 'int main(void){return 0;}' | "${TARGET}-gcc" -x c - -o hello
file hello
```

The toolchain embeds `/opt/x-tools/<TARGET>` paths via `CT_PREFIX_DIR`;
extracting elsewhere will break sysroot lookups.

## Build locally

Each matrix target has a `ct-ng` config under `targets/<triple>/config`:

```sh
git clone --recurse-submodules https://github.com/gfunkmonk/rpi-cross.git
cd rpi-cross
./scripts/make aarch64-rpi5-linux-gnu
```

The script installs Debian/Ubuntu build dependencies, builds the forked
`ct-ng` into `/opt/ct-ng`, and produces `<triple>.tar.xz` + `<triple>.tar.xz.sha256`
in the repo root.

## Layout

```
.
├── builder/                      # crosstool-NG submodule (fork)
├── scripts/make                  # top-level build driver
├── targets/<triple>/config       # ct-ng .config per target
├── targets/<triple>/*.patch      # optional submodule patches, applied in-order
└── .github/workflows/release.yaml
```

## License

The toolchains themselves are built from their upstream projects and
inherit their licenses (GCC: GPL/LGPL; glibc: LGPL; musl: MIT;
uClibc-ng: LGPL; binutils: GPL; Linux headers: GPL with the syscall
exception). This repository's own scripts and configs are provided
as-is.
