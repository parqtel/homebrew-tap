class ParqtelOss < Formula
  desc "Ultra-lightweight SRE observability engine: OTLP → Parquet, single binary"
  homepage "https://github.com/parqtel/parqtel-oss"
  license "Apache-2.0"

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
  # Release tag is `v#{version}` (parsed from the URL by Homebrew).
  # Asset filenames do NOT embed the version, so Homebrew can scan
  # the version from the tag without it being marked redundant.
  on_macos do
    on_arm do
      url "https://github.com/parqtel/homebrew-tap/releases/download/v#{version}/parqtel-oss-darwin-arm64.tar.gz"
      sha256 "9fe43ead9ae419d5947a70229749005ea01aa537105b6a659dcdd2b956f3cf20" # parqtel-oss-darwin-arm64.tar.gz
    end
    on_intel do
      url "https://github.com/parqtel/homebrew-tap/releases/download/v#{version}/parqtel-oss-darwin-amd64.tar.gz"
      sha256 "9c54d99c908f61cfcea571186989e271d5ae3b5d153e3d906307ad22ba1ca528" # parqtel-oss-darwin-amd64.tar.gz
    end
  end
  on_linux do
    on_arm do
      url "https://github.com/parqtel/homebrew-tap/releases/download/v#{version}/parqtel-oss-linux-arm64.tar.gz"
      sha256 "12abe2a312034f36d6d7b7dcda1e7eb4007eee195649c8d9cb0520c27f76c5d2" # parqtel-oss-linux-arm64.tar.gz
    end
    on_intel do
      url "https://github.com/parqtel/homebrew-tap/releases/download/v#{version}/parqtel-oss-linux-amd64.tar.gz"
      sha256 "4b6b5f21261d2d78596f58c87ac25d73c525fd75d087b70f83dfe95819a43d81" # parqtel-oss-linux-amd64.tar.gz
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
