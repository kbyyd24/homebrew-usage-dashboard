cask "usage-dashboard" do
  version "0.1.1"
  sha256 "218b1b93df2b138e1c4dd04a526f92b511756ef49e64b57869c28de38bd31685"

  url "https://github.com/kbyyd24/homebrew-usage-dashboard/releases/download/v0.1.1/UsageDashboard-0.1.1-macos-arm64.zip"
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
