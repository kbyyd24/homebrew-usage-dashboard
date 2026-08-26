cask "usage-dashboard" do
  version "0.1.0"
  sha256 :no_check

  url "https://github.com/kbyyd24/homebrew-usage-dashboard/releases/download/v#{version}/UsageDashboard-#{version}-macos-arm64.zip"
  name "Usage Dashboard"
  desc "See multiple LLM subscription usage in a native macOS window"
  homepage "https://github.com/kbyyd24/homebrew-usage-dashboard"

  depends_on macos: ">= :sonoma"

  app "UsageDashboard.app"

  # The app is ad-hoc signed (not notarized); clear the quarantine so it launches.
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
