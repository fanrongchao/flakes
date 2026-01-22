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
    set -eu

    while true; do
      # 1) Wayland: wait for a WAYLAND_DISPLAY socket.
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

      # 2) X11: start once DISPLAY is available.
      if [ -n "''${DISPLAY-}" ] || [ -S /tmp/.X11-unix/X0 ]; then
        export DISPLAY="''${DISPLAY-:0}"
        export XAUTHORITY="''${XAUTHORITY-$HOME/.Xauthority}"
        exec ${inputLeapCmdBase} --use-x11 ${lib.escapeShellArg cfg.server}
      fi

      sleep 1
    done
  '';

  inputLeapPreLoginStart = pkgs.writeShellScript "input-leap-prelogin-start" ''
    set -eu

    display="${cfg.preLoginDisplay}"
    xauth="/run/input-leap/.Xauthority"

    # Wait for Xorg socket and copied Xauthority.
    while true; do
      if [ -S /tmp/.X11-unix/X0 ] && [ -r "$xauth" ]; then
        export DISPLAY="$display"
        export XAUTHORITY="$xauth"
        exec ${inputLeapCmdBase} --use-x11 ${lib.escapeShellArg cfg.server}
      fi
      sleep 1
    done
  '';
in
{
  options.workstation.inputLeap = {
    enable = lib.mkEnableOption "input-leap client (Windows host is server)";

    enablePreLogin = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Start input-leap as a system service so it works on the display manager
        (pre-login) screen. This is designed for X11 + LightDM sessions.

        When enabled, the user-level service is disabled to avoid duplicate
        connections.
      '';
    };

    preLoginDisplay = lib.mkOption {
      type = lib.types.str;
      default = ":0";
      description = "X11 DISPLAY used for pre-login input-leap (usually :0).";
    };

    preLoginXauthority = lib.mkOption {
      type = lib.types.str;
      default = "/run/lightdm/root/:0";
      description = ''
        Xauthority cookie file used by the display manager X server.
        For LightDM on NixOS this is usually /run/lightdm/root/:0.
      '';
    };

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

    systemd.user.services.input-leap-client = lib.mkIf (!cfg.enablePreLogin) {
      description = "Input Leap client";
      wantedBy = [ "graphical-session.target" "default.target" ];
      after = [
        "graphical-session.target"
        "xdg-desktop-portal.service"
      ];
      wants = [
        "xdg-desktop-portal.service"
      ];
      partOf = [ "graphical-session.target" ];

      serviceConfig = {
        ExecStart = "${inputLeapStart}";
        Restart = "always";
        RestartSec = 2;
      };
    };

    systemd.services.input-leap-client = lib.mkIf cfg.enablePreLogin {
      description = "Input Leap client (pre-login X11)";
      wantedBy = [ "graphical.target" ];
      after = [ "display-manager.service" "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "simple";
        PermissionsStartOnly = true;

        RuntimeDirectory = "input-leap";
        RuntimeDirectoryMode = "0755";
        ExecStartPre = "${pkgs.coreutils}/bin/install -m 0600 -o frc -g users ${cfg.preLoginXauthority} /run/input-leap/.Xauthority";
        ExecStart = "${inputLeapPreLoginStart}";
        Restart = "always";
        RestartSec = 2;

        # Run as the real desktop user so InputLeap uses the existing
        # ~/.config/InputLeap trust store.
        User = "frc";
      };
    };
  };
}
