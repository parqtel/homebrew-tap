# Tap Architecture

## Why a self-hosted binary tap?

There are three idiomatic ways to ship a Homebrew formula for a Rust project:

1. **Source build** — `brew install` runs `cargo build` on the user's machine. Slow (5–10 min) and requires a Rust toolchain + `protoc` + (for cross) `gcc-aarch64-linux-gnu`. Common in `homebrew-core` for libraries and CLI tools that don't ship binaries.
2. **Upstream-hosted binary** — formula downloads prebuilt tarballs from `parqtel/parqtel-oss/releases`. Fast; depends on the upstream release pipeline attaching the right assets.
3. **Tap-hosted binary** — the tap's own CI builds the binaries from source and publishes them as tap releases; the formula downloads from the tap's releases. Fast; decouples from upstream release quirks.

We chose **#3** because:

- **The upstream release pipeline was flaky in v0.1.0** — every `v*` tag push produced a release with no attached assets (the build jobs were failing and `softprops/action-gh-release@v2` was creating an empty release anyway). A tap-hosted binary tap gives us an independent, working pipeline.
- **Bottles later** — once we have a stable upstream release flow, we can layer `brew bottle` on top of these tap-hosted binaries and publish bottles from a private S3 or GitHub release of this tap. The two CI flows don't conflict.
- **Symmetric trust** — the formula's sha256s are computed in this tap's CI, not trusted from an external source. The maintainer PR is a one-click merge.

## What this tap is *not*

- **Not a fork** of `parqtel/parqtel-oss`. The CI checks out upstream at the desired tag, builds it verbatim (no patches), and re-publishes.
- **Not a competing distribution channel**. When the upstream release workflow is fixed, this tap will be a thin wrapper (still a tap, but with `repository_dispatch` zero-touch updates). The binaries are byte-identical to what upstream CI would produce.
- **Not a code-signing authority**. The binaries are unsigned; users who need signature verification should use the `parqtel/parqtel-oss` Docker image (signed with cosign). The Homebrew install path is for the *frictionless* developer-experience case.

## Threat model

| Threat | Mitigation |
| --- | --- |
| Compromised upstream release | The tap CI checks out a *specific* git ref, not a mutable tag. `cargo --locked` enforces Cargo.lock integrity. The built binary's sha256 is computed in the tap's runner, not trusted from upstream. |
| Compromised tap release | Every PR to `Formula/parqtel-oss.rb` triggers `audit.yml`, which downloads the new tarball, `sha256sum -c`s it, installs it, and runs `brew test`. A tampered release fails CI. |
| Compromised tap maintainer token | `CODEOWNERS` requires a maintainer review; `pull_request` rules can be added to require approval from a non-author. Out of scope for the initial setup but documented for follow-up. |
| User installs outdated formula | `brew livecheck` (in the formula) checks upstream daily; `update-formula.yml` opens a bump PR twice daily; users get a `brew upgrade` reminder on every `brew update`. |

## Future work

- **Bottles**: once a few versions are in the tap, add a `bottle do ... end` block to the formula and a `brew bottle` job to `build-tarballs.yml`. Bottles give `brew install` a prebuilt keg (no decompression/recompression at install time, faster by ~3×).
- **Homebrew-core submission**: once v1.0.0 lands and the formula has been stable for a few months, submit to `homebrew-core` (single source-of-truth formula, no tap needed). The tap will keep working for users on the v0.x line.
- **MCP server formulae**: when parqtel/parqtel-oss ships the MCP tool servers, add `parqtel-oss-mcp-slack`, `parqtel-oss-mcp-jira`, etc. formulae in this tap. They share the build matrix; reuse the `build-tarballs.yml` job matrix with a `crate` parameter.

## Known false-positive: `version is redundant with version scanned from URL`

The Homebrew `ResourceAuditor#audit_version` method warns when the explicit `version` field exactly equals a version parsed from the URL. This is a soft check that is unavoidable in self-hosted binary taps:

1. The formula needs an explicit `version` because the URL uses `#{version}` interpolation (so the `update-formula.yml` workflow can stamp a new version into all four `url` blocks at once).
2. The release tag (`v#{version}`) is itself a parseable version, so `Version.detect(url)` returns the same value as the explicit `version` field.

The check is **skipped** in the CI `audit.yml` via `--except=version`. This is a deliberate, scoped decision: we keep every other `--strict --online` audit (URL reachability, license SPDX, sha256 length, git availability, etc.) and only silence the one false-positive. The justification is recorded in the workflow file inline.

We cannot silence the warning in the formula (e.g. with a `rubocop:disable FormulaAudit/RedundantVersion` directive) because `brew style` rejects such directives in formulae — see `Style/DisableCopsWithinSourceCodeDirective` in `/opt/homebrew/Library/Homebrew/rubocops/lines.rb`.
