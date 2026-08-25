# Distribution

This repository is an independently maintained security-sensitive Omarchy
plugin. Review Bram Vera's
[original project](https://github.com/bramvera/omarchy-proton-vpn) when assessing
upstream changes; publish releases only from the maintainer-owned repository.

## Release checklist

1. Review `git diff` and confirm no credentials, diagnostics, or machine-specific state is present.
2. Run the validation commands documented in `README.md`.
3. Run `./tools/package.sh` twice and confirm the archives are byte-identical.
4. Verify the generated checksum with `sha256sum -c dist/*.tar.gz.sha256`.
5. Commit and push to the maintainer-owned `origin`, then confirm GitHub Actions passes.
6. Create an annotated tag matching the manifest version, push it, and publish a GitHub Release.
7. Attach both the `.tar.gz` archive and its `.sha256` file to the release.
8. Confirm the documented trusted-repository installation command works before announcing the release.

## Install from a trusted repository

```bash
omarchy plugin add https://github.com/denizkin28/omarchy-proton-vpn-control-center.git --enable
```

## Install an inspected local checkout

```bash
ln -s /absolute/path/to/checkout ~/.config/omarchy/plugins/denizkin.protonvpn
omarchy restart shell
```

The archive excludes `.git`, `dist`, Python bytecode, local agent metadata, and
environment files. Proton account data is stored outside this repository and is
never packaged.
