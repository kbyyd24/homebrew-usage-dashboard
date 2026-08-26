#!/usr/bin/env bash
# Render Casks/usage-dashboard.rb with the correct version / sha256 / url for a release.
# Usage: release.sh <zip>
# Env:
#   VERSION  (or GITHUB_REF_NAME, e.g. "v0.1.0")  - release version
#   REPO     (or GITHUB_REPOSITORY, e.g. "owner/repo") - GitHub repository
set -euo pipefail

ZIP="${1:?usage: release.sh <zip>}"
VERSION="${VERSION:-${GITHUB_REF_NAME#v}}"
REPO="${REPO:-${GITHUB_REPOSITORY}}"

if [ -z "${VERSION:-}" ]; then
  echo "error: VERSION not set (use VERSION= or GITHUB_REF_NAME)" >&2
  exit 1
fi
if [ -z "${REPO:-}" ]; then
  echo "error: REPO not set (use REPO= or GITHUB_REPOSITORY)" >&2
  exit 1
fi

VER="${VERSION#v}"
SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"

mkdir -p Casks
cat > Casks/usage-dashboard.rb <<RUBY
cask "usage-dashboard" do
  version "$VER"
  sha256 "$SHA"

  url "https://github.com/${REPO}/releases/download/v${VER}/UsageDashboard-${VER}-macos-arm64.zip"
  name "Usage Dashboard"
  desc "See multiple LLM subscription usage in a native macOS window"
  homepage "https://github.com/${REPO}"

  depends_on macos: ">= :sonoma"

  app "UsageDashboard.app"

  postflight do
    system_command "/usr/bin/xattr",
      args: ["-dr", "com.apple.quarantine", "#{appdir}/UsageDashboard.app"]
  end

  livecheck do
    url "https://github.com/${REPO}/releases/latest"
    strategy :github_latest
  end

  zap trash: "~/.config/usage-dash"
end
RUBY

echo "Rendered Casks/usage-dashboard.rb version=$VER sha256=$SHA repo=$REPO"
