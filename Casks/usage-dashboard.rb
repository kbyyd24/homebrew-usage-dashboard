cask "usage-dashboard" do
  version "0.1.0"
  sha256 "de2d174f702814e173dbe8444d31089e8309da3d87ae37657b3c7d1141112d20"

  url "https://github.com/kbyyd24/homebrew-usage-dashboard/releases/download/v0.1.0/UsageDashboard-0.1.0-macos-arm64.zip"
  name "Usage Dashboard"
  desc "See multiple LLM subscription usage in a native macOS window"
  homepage "https://github.com/kbyyd24/homebrew-usage-dashboard"

  depends_on macos: :sonoma

  app "UsageDashboard.app"

  postflight do
    system_command "/usr/bin/xattr",
      args: ["-dr", "com.apple.quarantine", "#{appdir}/UsageDashboard.app"]
  end

  livecheck do
    url "https://github.com/kbyyd24/homebrew-usage-dashboard/releases/latest"
    strategy :github_latest
  end

  zap trash: "~/.config/usage-dash"
end
