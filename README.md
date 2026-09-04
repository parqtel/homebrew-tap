# parqtel/homebrew-tap

Homebrew tap for [**parqtel/parqtel-oss**](https://github.com/parqtel/parqtel-oss) — the ultra-lightweight SRE observability engine that ingests OpenTelemetry (OTLP) metrics, logs, and traces and stores them as compressed Apache Parquet files. ~15 MB single binary, no JVM, no service mesh.

> **TL;DR** — `brew install parqtel/parqtel/parqtel-oss`

---

## Install

```bash
brew tap parqtel/parqtel
brew install parqtel-oss
parqtel --version
```

That's it. The tap is a **binary distribution**: `brew install` downloads a prebuilt per-platform tarball from this tap's own GitHub releases (see [How it works](#how-it-works)). No Rust toolchain, no `protoc`, no 5-minute compile — just a few seconds and ~30 MB on disk.

### Upgrading

```bash
brew update
brew upgrade parqtel-oss
```

### Uninstalling

```bash
brew uninstall parqtel-oss
brew untap parqtel/parqtel  # optional
```

Parqtel stores its data in the directory pointed to by `PARQTEL_DATA_DIR` (default `./data`). Removing the formula does **not** remove this directory; delete it manually if you want a clean slate.

---

## Quick start

```bash
# 1. Start parqtel on the default ports (HTTP 8080, gRPC 4317)
parqtel serve

# 2. Open the embedded web console
open http://localhost:8080/ui

# 3. Send a test OTLP metric
curl -X POST http://localhost:8080/v1/metrics \
  -H 'Content-Type: application/json' \
  -d @<(printf '{"resourceMetrics":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"hello"}}]},"scopeMetrics":[{"metrics":[{"name":"requests_total","sum":{"dataPoints":[{"attributes":[{"key":"status","value":{"stringValue":"ok"}}],"value":1,"startTimeUnixNano":"%s","timeUnixNano":"%s"}]}}]}]}]}' "$(date +%s%N)" "$(date +%s%N)")

# 4. Query it back via PromQL
curl 'http://localhost:8080/api/v1/query?query=requests_total'
```

The full API surface (PromQL, ParqtelQL, alerts, pipelines, Grafana SimpleJSON) is documented in the upstream repo: [parqtel/parqtel-oss](https://github.com/parqtel/parqtel-oss#api-endpoints).

---

## How it works

This tap ships the **`parqtel-oss` formula** in [`Formula/parqtel-oss.rb`](Formula/parqtel-oss.rb). The formula pulls **prebuilt per-platform tarballs** from this tap's own GitHub release matching the formula's `version`:

| Platform | Tarball |
| --- | --- |
| macOS Apple Silicon | `parqtel-oss-darwin-arm64.tar.gz` |
| macOS Intel | `parqtel-oss-darwin-amd64.tar.gz` |
| Linux arm64 | `parqtel-oss-linux-arm64.tar.gz` |
| Linux x86_64 | `parqtel-oss-linux-amd64.tar.gz` |

The tarballs are **built from source** in CI on each upstream parqtel-oss release tag, then published as a release in this repo. The end-to-end pipeline is automated:

```
parqtel/parqtel-oss  →  v0.2.0 tag pushed
        │
        │  (1) build-tarballs.yml  (workflow_dispatch / repo_dispatch / schedule)
        ▼
parqtel/homebrew-tap  →  v0.2.0 release in this repo with 4 tarballs
        │
        │  (2) update-formula.yml  (workflow_dispatch / repo_dispatch / schedule)
        ▼
parqtel/homebrew-tap  →  PR "parqtel-oss 0.2.0" bumps version + sha256s
        │
        │  (3) audit.yml  (PR + main push)
        ▼
green CI  →  maintainer merges
        │
        ▼
user runs `brew update && brew upgrade parqtel-oss`
```

See [`docs/RELEASE_COORDINATION.md`](docs/RELEASE_COORDINATION.md) for the full coordination protocol (including the optional cross-repo `repository_dispatch` webhook for zero-touch releases).

### Why a tap-hosted binary and not `brew install --build-from-source`?

- **Speed**: `brew install` is ~5 s (curl + tar) vs ~10 min (cargo workspace build from scratch).
- **No toolchain on user machines**: Rust 1.87, protoc, gcc-aarch64-linux-gnu are not pulled in.
- **Reproducibility**: every install is byte-identical to the CI-built artifact; sha256 is checked on every install.
- **Independence from upstream release pipeline**: even if `parqtel/parqtel-oss` ships a release without binary assets (as v0.1.0 did initially), this tap still produces them.

---

## Bootstrapping a new version (one-time per upstream release)

Until the optional `repository_dispatch` webhook from parqtel/parqtel-oss is wired up, **publishing a new version is a two-click operation** by the maintainer:

1. **Build the tarballs** — open the [`Build & Publish Tarballs` workflow`](../../actions/workflows/build-tarballs.yml), click *Run workflow*, enter the version (e.g. `0.2.0`), and run it. This creates the matching `v0.2.0` release in this tap with the four prebuilt tarballs.
2. **Bump the formula** — open the [`Update Formula` workflow`](../../actions/workflows/update-formula.yml), click *Run workflow*, enter `0.2.0`, and run it. This opens a PR that updates `Formula/parqtel-oss.rb` with the new `version` and the four `sha256` values.

The PR is gated by [`audit.yml`](.github/workflows/audit.yml), which `brew style` / `brew audit` / `brew install --build-from-source` / `brew test`s the formula on every push. Once green, merge → users get it via `brew update && brew upgrade parqtel-oss`.

### One-shot bootstrap for v0.1.0

For the very first tap release (v0.1.0), the GitHub Actions workflow can't run until the formula is committed. The tap ships a helper script ([`scripts/publish-v0.1.0.sh`](scripts/publish-v0.1.0.sh)) that does the equivalent of step 1 from your laptop:

```bash
# 1. Stage the four prebuilt tarballs (downloaded from the parqtel-oss
#    v0.1.0 release artefacts — or built locally — see the script header).
ls /tmp/parqtel-release/v0.1.0/
#  parqtel-oss-darwin-amd64.tar.gz
#  parqtel-oss-darwin-amd64.tar.gz.sha256
#  parqtel-oss-darwin-arm64.tar.gz
#  parqtel-oss-darwin-arm64.tar.gz.sha256
#  parqtel-oss-linux-amd64.tar.gz
#  parqtel-oss-linux-amd64.tar.gz.sha256
#  parqtel-oss-linux-arm64.tar.gz
#  parqtel-oss-linux-arm64.tar.gz.sha256

# 2. Authenticate gh (one-time per machine)
gh auth login

# 3. Publish
./scripts/publish-v0.1.0.sh
```

After the release is live, the `[Update Formula]` workflow is a no-op (the formula is already at v0.1.0). From v0.2.0 onward, the `[Build & Publish Tarballs]` workflow handles step 1 and `[Update Formula]` handles step 2 — no manual intervention needed.

For continuous automation, see [`docs/RELEASE_COORDINATION.md`](docs/RELEASE_COORDINATION.md#optional-zero-touch-coordination).

---

## Repository layout

```
.
├── Formula/
│   └── parqtel-oss.rb        # The parqtel-oss formula
├── .github/
│   ├── workflows/
│   │   ├── audit.yml          # brew style / audit / install / test on every PR
│   │   ├── build-tarballs.yml # Build upstream binaries, publish tap release
│   │   └── update-formula.yml # Bump version + sha256s on new upstream tag
│   ├── ISSUE_TEMPLATE/
│   │   └── new-formula.md
│   ├── PULL_REQUEST_TEMPLATE.md
│   ├── CODEOWNERS
│   └── dependabot.yml
├── docs/
│   ├── RELEASE_COORDINATION.md   # How this tap stays in sync with parqtel/parqtel-oss
│   └── ARCHITECTURE.md           # Tap design rationale
└── README.md
```

---

## For maintainers

### Adding a new formula

1. Copy `Formula/parqtel-oss.rb` as a starting point.
2. Add an entry to `.github/CODEOWNERS` if it should be reviewed by a sub-team.
3. Open a PR — `audit.yml` will validate it automatically.

### Style and audit cheatsheet

```bash
brew tap parqtel/parqtel "$(git rev-parse --show-toplevel)"
brew style            parqtel/parqtel
brew audit --strict   parqtel/parqtel/parqtel-oss
brew install --build-from-source parqtel/parqtel/parqtel-oss
brew test             parqtel/parqtel/parqtel-oss
```

`brew style` and `brew audit --new --strict` are also run on every PR via `.github/workflows/audit.yml`.

### Bumping the upstream version manually

```bash
# 1. Build the tarballs (or let the workflow_dispatch do it).
# 2. Open a PR that updates Formula/parqtel-oss.rb:
python3 -c '
import re, pathlib
f = pathlib.Path("Formula/parqtel-oss.rb")
s = f.read_text()
s = re.sub(r"version \"[^\"]+\"", "version \"0.2.0\"", s, count=1)
# Fill the four sha256s from the build-tarballs run logs.
# s = s.replace("__SHA256_DARWIN_AMD64__", "...")
f.write_text(s)
'
git checkout -b bump/parqtel-oss-0.2.0
git commit -am "parqtel-oss 0.2.0"
git push -u origin HEAD
gh pr create --fill
```

---

## Security

- All tarballs are signed by the GitHub Actions runner (commit provenance) and the `audit.yml` workflow re-installs and re-tests every formula on every push, so a tampered formula will fail CI before reaching users.
- The `PARQTEL_DATA_DIR` is a user-controlled directory; this formula does not write outside the keg or that directory.
- The upstream parqtel-oss release workflow builds the same artifacts from the same source — these tap-hosted binaries are byte-identical to the upstream CI build (same `cargo --locked` + same Cargo.lock).

Report vulnerabilities via [parqtel/parqtel-oss/SECURITY.md](https://github.com/parqtel/parqtel-oss/blob/main/SECURITY.md).

## License

The tap repository (this one) is Apache-2.0, matching upstream. See [`LICENSE`](LICENSE).
