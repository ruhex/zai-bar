# Homebrew Cask for ZAI Bar — a macOS menu-bar widget for the z.ai / GLM
# Coding Plan quota. Lives in your tap repo `ruhex/homebrew-tap` and is
# installed via `brew install --cask ruhex/tap/zai-bar`.
#
# Bump `version` + `sha256` on each release. Regenerate the sha256 with:
#     shasum -a 256 zai-bar-<ver>-universal-macos.zip

cask "zai-bar" do
  version "1.1.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/ruhex/zai-bar/releases/download/v#{version}/zai-bar-#{version}-universal-macos.zip"
  name "ZAI Bar"
  desc "Menu-bar widget showing z.ai / GLM Coding Plan quota and reset countdown"
  homepage "https://github.com/ruhex/zai-bar"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  app "ZAIBar.app"

  uninstall quit: "com.github.ruhex.zai-bar"

  zap trash: [
    "~/Library/Application Support/ZAI Bar",
    "~/Library/Preferences/com.github.ruhex.zai-bar.plist",
    "~/Library/Caches/com.github.ruhex.zai-bar",
    "~/Library/HTTPStorages/com.github.ruhex.zai-bar.binarycookies",
    "~/Library/Saved Application State/com.github.ruhex.zai-bar.savedState",
  ]
end
