class ParqtelOss < Formula
  desc "Ultra-lightweight SRE observability engine: OTLP → Parquet, single binary"
  homepage "https://github.com/parqtel/parqtel-oss"
  license "Apache-2.0"

  # `version` must be set BEFORE the `url` lines below — the URL
  # strings use `#{version}` interpolation, and Ruby evaluates the
  # interpolation at the time the `url` line runs, not lazily. If
  # `version` is unset, the URLs would be hard-coded to
  # `.../download/v/...` and the install would 404. `Version.detect`
  # on the resulting URL would then also fail and fall back to
  # matching the trailing `64` of `arm64` as the version number.
  version "0.1.0"

  # `brew livecheck` watches the upstream parqtel-oss GitHub releases
  # for new `v*` tags. The `github_latest` strategy is auto-inferred
  # from the `homepage` (which is a GitHub repo).
  livecheck do
    url :homepage
    strategy :github_latest
  end

  # Prebuilt per-platform tarballs are published as GitHub release
  # assets in parqtel/homebrew-tap itself (see .github/workflows/
  # build-tarballs.yml). The tap CI builds the binaries from source
  # on each upstream parqtel-oss `v*` tag and uploads the four
  # platform tarballs + .sha256 sidecars to the matching tag in this
  # tap repo. This keeps `brew install parqtel-oss` fast (no Rust
  # toolchain required on the user's machine) and decouples the
  # formula from upstream release pipeline quirks.
  #
  # Asset filenames embed the version (`parqtel-oss-v#{version}-...`)
  # so that the homebrew `redundant_version` audit does not fire
  # (the audit checks if the explicit `version` exactly matches a
  # version parsed from the URL). The release tag is `v#{version}`.
  on_macos do
    on_arm do
      url "https://github.com/parqtel/homebrew-tap/releases/download/v#{version}/parqtel-oss-v#{version}-darwin-arm64.tar.gz"
      sha256 "50017248ebf7c2734b67b139e70ee17e475ac53dc3b66d62e2861c6fcd88e41d" # parqtel-oss-v#{version}-darwin-arm64.tar.gz
    end
    on_intel do
      url "https://github.com/parqtel/homebrew-tap/releases/download/v#{version}/parqtel-oss-v#{version}-darwin-amd64.tar.gz"
      sha256 "7c1e9232338b4dcb167e7c7dd911bf53c6eb16b4551fc246d3e6ff9d95d7e9b0" # parqtel-oss-v#{version}-darwin-amd64.tar.gz
    end
  end
  on_linux do
    on_arm do
      url "https://github.com/parqtel/homebrew-tap/releases/download/v#{version}/parqtel-oss-v#{version}-linux-arm64.tar.gz"
      sha256 "1cd950bdd39cf5e9fbc9a7defa677bc6f8a1250bb458c87e382d2ce3b5c9d449" # parqtel-oss-v#{version}-linux-arm64.tar.gz
    end
    on_intel do
      url "https://github.com/parqtel/homebrew-tap/releases/download/v#{version}/parqtel-oss-v#{version}-linux-amd64.tar.gz"
      sha256 "56bdf82c5478ad58e01761f307551b9559d22e4492746c953d29806d77c1e074" # parqtel-oss-v#{version}-linux-amd64.tar.gz
    end
  end

  def install
    bin.install "parqtel"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/parqtel --version")
    assert_match "Usage", shell_output("#{bin}/parqtel --help")
  end
end
