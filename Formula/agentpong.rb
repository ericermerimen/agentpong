# Homebrew formula for AgentPong
# Add to your tap: cp Formula/agentpong.rb $(brew --repository)/Library/Taps/YOUR_TAP/Formula/
#
# To update after a new release:
#   1. Run `make archive` to build the .tar.gz
#   2. Upload to GitHub releases
#   3. Update url + sha256 below
#   4. Push to your tap repo

class Agentpong < Formula
  desc "Pixel art room with husky pet that monitors Claude Code sessions"
  homepage "https://github.com/ericermerimen/agentpong"
  url "https://github.com/ericermerimen/agentpong/releases/download/v1.0.0/AgentPong-v1.0.0-macos.tar.gz"
  sha256 "REPLACE_WITH_SHA256"

  depends_on :macos
  depends_on macos: :sonoma

  def install
    prefix.install "AgentPong.app"
    bin.install_symlink prefix/"AgentPong.app/Contents/MacOS/AgentPong" => "agentpong"
  end

  def caveats
    <<~EOS
      To start AgentPong and auto-launch on login:

        brew services start agentpong

      After future upgrades:

        brew upgrade agentpong && brew services restart agentpong

      Next steps:
        1. Run: agentpong setup
           (Installs hook script + configures Claude Code)
        2. Restart your Claude Code sessions
        3. The husky will start reacting to your sessions!

      Optional: install jq for enhanced session tracking:
        brew install jq
    EOS
  end

  def post_install
    # Kill any running AgentPong so brew services restart picks up the new binary
    quiet_system "pkill", "-x", "AgentPong"
  end

  service do
    run [opt_prefix/"AgentPong.app/Contents/MacOS/AgentPong"]
    keep_alive true
    log_path var/"log/agentpong.log"
    error_log_path var/"log/agentpong-error.log"
  end
end
