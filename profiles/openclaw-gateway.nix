{ pkgs, ... }:
{
  home-manager.users.frc.systemd.user.services.openclaw-gateway = {
    Unit = {
      Description = "OpenClaw Gateway";
      After = [ "network.target" ];
      Wants = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.openclaw}/bin/openclaw gateway --port 18789";
      Restart = "on-failure";
      RestartSec = 3;
      Environment = [
        "XDG_CACHE_HOME=/tmp/nix-cache"
      ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
