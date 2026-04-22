# rpi-cross

Crosstool-NG-based builder for per-model Raspberry Pi cross-toolchains. The
forked crosstool-NG lives in the `builder/` git submodule; per-target
`ct-ng` .configs live in `targets/<triple>/config`, with optional
`targets/<triple>/*.patch` applied to the submodule before build.

## Build

```sh
./scripts/make aarch64-rpi5-linux-gnu      # one target
```

The script installs apt deps, builds `ct-ng` into `/opt/ct-ng`, writes
`/opt/x-tools/<triple>`, and tarballs it as `<triple>.tar.xz` +
`<triple>.tar.xz.sha256` in the repo root. Expect **hours** per target
(GCC + glibc/musl/uClibc-ng from source). Do not run full builds in an
interactive Devin session unless explicitly asked — run a single target
or just `ct-ng olddefconfig` for smoke-testing.

## Targets / matrix

21 toolchains, kept in lockstep in three places — changes to any of
them must update the others:

1. `targets/<triple>/` directories
2. The `matrix.target` list in `.github/workflows/release.yaml`
3. The README's target table
4. Any per-target case arms in `scripts/make` (CFLAGS, sanity checks)

Triple conventions: `armv6-rpi-linux-{gnueabihf,musleabihf,uclibcgnueabihf}`,
`armv7-rpi2-linux-*hf`, `armv8-rpi{3,4}-linux-*hf` (32-bit), and
`aarch64-rpi{3,4,5}-linux-{gnu,musl,uclibc}` (64-bit). **armv6 is hard-float**
(`*eabihf`, `CT_ARCH_FLOAT_HW=y`); do not regress this to soft-float.

## Lint / local validation

No real build CI on PRs (only Sourcery + CodeRabbit review bots). Run
locally before pushing:

```sh
shellcheck -x scripts/make scripts/lib/*.sh install.sh
python3 -c "import yaml, glob; [yaml.safe_load(open(p)) for p in glob.glob('.github/workflows/*.y*ml')]"
# and if available:
actionlint
```

Install the linters with:

```sh
sudo apt-get install -y shellcheck yamllint && pip install --quiet pyyaml
```

## Pushing `.github/workflows/*`

The default Devin GitHub integration OAuth scope **cannot** push to
`.github/workflows/*`. You will see:

```
! [remote rejected] ... (refusing to allow an OAuth App to create or
update workflow `.github/workflows/...` without `workflow` scope)
```

Use the saved user-scope secret `GITHUB_PAT_WORKFLOW` (classic PAT with
`repo` + `workflow` scopes). The git config has an `insteadOf` rewrite
forcing all `https://github.com/` URLs through the devin git-manager
proxy, so you have to both bypass that and supply the PAT:

```sh
git -c "url.https://example.invalid/.insteadOf=https://github.com/" \
    push "https://x-access-token:${GITHUB_PAT_WORKFLOW}@github.com/gfunkmonk/rpi-cross.git" \
    "HEAD:refs/heads/<branch>"
```

The `url.<dummy>.insteadOf=https://github.com/` -c flag neutralizes the
rewrite for just this command. `git config` edits are disallowed, so
prefer this per-invocation `-c` form.

For non-workflow files, the normal `git push` (via the proxy) works
fine — don't use the PAT unless you have to.

## Creating a release

Releases only trigger via `workflow_dispatch` on `.github/workflows/release.yaml`
with `make_release=true` and a non-empty `release_name`. An `on: push: tags`
auto-release trigger is proposed in the "features" PR but may not be
landed yet — check `release.yaml` before assuming tag-push works.
