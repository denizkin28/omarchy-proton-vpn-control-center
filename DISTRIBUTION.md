# Distribution

This repository is a locally maintained security-sensitive Omarchy plugin. The
configured `reference-upstream` remote is for reviewing Bram Vera's original
project; do not push this fork there.

## Release checklist

1. Review `git diff` and confirm no credentials, diagnostics, or machine-specific state is present.
2. Run the validation commands documented in `README.md`.
3. Run `./tools/package.sh` and verify the printed SHA-256 checksum.
4. Commit and tag the reviewed tree, for example `v0.9.0-local`.
5. Create a separate repository owned by the maintainer and add it as a new remote.
6. Push only after checking the exact remote URL with `git remote -v`.

## Install from a trusted repository

```bash
omarchy plugin add https://github.com/OWNER/REPOSITORY.git --enable
```

## Install an inspected local checkout

```bash
ln -s /absolute/path/to/checkout ~/.config/omarchy/plugins/denizkin.protonvpn
omarchy restart shell
```

The archive excludes `.git`, `dist`, Python bytecode, local agent metadata, and
environment files. Proton account data is stored outside this repository and is
never packaged.
