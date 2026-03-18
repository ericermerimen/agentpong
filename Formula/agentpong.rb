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
      Add to Applications (for Launchpad):

        ln -sf $(brew --prefix)/opt/agentpong/AgentPong.app /Applications/AgentPong.app

      Start AgentPong and auto-launch on login:

        brew services start agentpong

      Setup Claude Code hooks:

        agentpong setup

      After future upgrades:

        brew upgrade agentpong && brew services restart agentpong
    EOS
  end

  def post_install
    quiet_system "pkill", "-x", "AgentPong"
    # Try to symlink to /Applications (may fail in sandbox -- caveats has fallback)
    quiet_system "ln", "-sf", "#{opt_prefix}/AgentPong.app", "/Applications/AgentPong.app"
  end

  service do
    run [opt_prefix/"AgentPong.app/Contents/MacOS/AgentPong"]
    keep_alive true
    log_path var/"log/agentpong.log"
    error_log_path var/"log/agentpong-error.log"
  end
end
