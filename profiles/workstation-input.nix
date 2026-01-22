{ config, lib, pkgs, ... }:

let
  cfg = config.workstation.inputLeap;
  extraArgsFiltered = lib.filter (arg: arg != "--use-ei" && arg != "--use-x11") cfg.extraArgs;
  backendMode =
    if lib.elem "--use-ei" cfg.extraArgs then "ei"
    else if lib.elem "--use-x11" cfg.extraArgs then "x11"
    else "auto";
  inputLeapCmdBase = lib.concatStringsSep " " ([
    "${pkgs.input-leap}/bin/input-leapc"
    "--name"
    (lib.escapeShellArg cfg.clientName)
  ] ++ (map lib.escapeShellArg extraArgsFiltered));
  inputLeapStart = pkgs.writeShellScript "input-leap-start" ''
    while true; do
      for s in "$XDG_RUNTIME_DIR"/wayland-*; do
        if [ -S "$s" ]; then
          export WAYLAND_DISPLAY="$(basename "$s")"
          backend_mode="${backendMode}"
          backend_arg=""
          if [ "$backend_mode" = "auto" ]; then
            if ${pkgs.dbus}/bin/busctl --user introspect \
              org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop 2>/dev/null | \
              ${pkgs.gnugrep}/bin/grep -q "org.freedesktop.portal.RemoteDesktop"; then
              backend_arg="--use-ei"
            else
              backend_arg="--use-x11"
            fi
          elif [ "$backend_mode" = "ei" ]; then
            backend_arg="--use-ei"
          else
            backend_arg="--use-x11"
          fi

          if [ -n "$backend_arg" ]; then
            exec ${inputLeapCmdBase} "$backend_arg" ${lib.escapeShellArg cfg.server}
          else
            exec ${inputLeapCmdBase} ${lib.escapeShellArg cfg.server}
          fi
        fi
      done
      sleep 1
    done
  '';
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
      default = [ "--no-tray" "--use-ei" "--no-daemon" ];
      description = "Extra arguments passed to input-leap client.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.input-leap ];

    systemd.user.services.input-leap-client = {
      description = "Input Leap client";
      wantedBy = [ "graphical-session.target" "default.target" ];
      after = [
        "graphical-session.target"
        "xdg-desktop-portal.service"
        "xdg-desktop-portal-hyprland.service"
      ];
      wants = [
        "xdg-desktop-portal.service"
        "xdg-desktop-portal-hyprland.service"
      ];
      partOf = [ "graphical-session.target" ];

      serviceConfig = {
        ExecStart = "${inputLeapStart}";
        Restart = "always";
        RestartSec = 2;
      };
    };
  };
}
