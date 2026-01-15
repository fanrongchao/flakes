{ config, lib, pkgs, ... }:

let
  cfg = config.workstation.inputLeap;
in
{
  options.workstation.inputLeap = {
    enable = lib.mkEnableOption "input-leap client (Windows host is server)";

    server = lib.mkOption {
      type = lib.types.str;
      example = "192.168.0.10";
      description = "input-leap server address (Windows host).";
    };

    clientName = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      description = "Client screen name shown on server.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "--no-tray" ];
      description = "Extra arguments passed to input-leap client.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.input-leap ];

    systemd.user.services.input-leap-client = {
      Unit = {
        Description = "Input Leap client";
        After = [ "default.target" ];
      };

      Service = {
        ExecStart = lib.concatStringsSep " " ([
          "${pkgs.input-leap}/bin/input-leapc"
          "--name"
          (lib.escapeShellArg cfg.clientName)
        ] ++ (map lib.escapeShellArg cfg.extraArgs) ++ [
          (lib.escapeShellArg cfg.server)
        ]);
        Restart = "on-failure";
        RestartSec = 2;
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
