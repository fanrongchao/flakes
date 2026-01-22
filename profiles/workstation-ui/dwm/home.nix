{ config, pkgs, lib, ... }:

let
  volumeScript = pkgs.writeShellScript "dwmblock-volume" ''
    set -eu
    if ! command -v ${pkgs.pamixer}/bin/pamixer >/dev/null 2>&1; then
      echo "VOL ?"
      exit 0
    fi

    muted="$(${pkgs.pamixer}/bin/pamixer --get-mute 2>/dev/null || echo true)"
    vol="$(${pkgs.pamixer}/bin/pamixer --get-volume 2>/dev/null || echo 0)"
    if [ "''${muted}" = "true" ]; then
      echo "VOL mute"
    else
      echo "VOL ''${vol}%"
    fi
  '';

  netScript = pkgs.writeShellScript "dwmblock-net" ''
    set -eu
    # Prefer the default route device
    dev="$(${pkgs.iproute2}/bin/ip route show default 2>/dev/null | ${pkgs.gawk}/bin/awk 'NR==1 {print $5}')"
    if [ -z "''${dev:-}" ]; then
      echo "NET down"
      exit 0
    fi
    ip="$(${pkgs.iproute2}/bin/ip -4 addr show dev "$dev" 2>/dev/null | ${pkgs.gnugrep}/bin/grep -oE 'inet [0-9.]+/[0-9]+' | ${pkgs.gawk}/bin/awk '{print $2}' | ${pkgs.coreutils}/bin/head -n1)"
    if [ -n "''${ip:-}" ]; then
      echo "NET ''${dev} ''${ip}"
    else
      echo "NET ''${dev}"
    fi
  '';

  cpuScript = pkgs.writeShellScript "dwmblock-cpu" ''
    set -eu
    # 1-min load average
    load="$(${pkgs.coreutils}/bin/cat /proc/loadavg | ${pkgs.gawk}/bin/awk '{print $1}')"
    echo "CPU $load"
  '';

  dateScript = pkgs.writeShellScript "dwmblock-date" ''
    set -eu
    exec ${pkgs.coreutils}/bin/date '+%a %Y-%m-%d %H:%M'
  '';

  blocksH = pkgs.writeText "blocks.h" ''
    /* See LICENSE file for copyright and license details. */
    
    /* Icon (optional), command, interval (seconds), signal (for click updates) */
    static const Block blocks[] = {
      {"", "${volumeScript}", 2, 10},
      {"", "${netScript}", 5, 11},
      {"", "${cpuScript}", 2, 12},
      {"", "${dateScript}", 10, 13},
    };
    
    static char delim[] = "  |  ";
    static unsigned int delimLen = 5;
  '';

  dwmblocksPkg = pkgs.dwmblocks.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      cp ${blocksH} blocks.h
    '';
  });
in
{
  imports = [
    ../shared/home.nix
  ];

  # X11 session (dwm) -> use X11 frontend.
  i18n.inputMethod.fcitx5.waylandFrontend = lib.mkForce false;

  home.packages = with pkgs; [
    rofi
    dunst
    picom
    feh
    xclip
    wl-clipboard
    pamixer
    pavucontrol
    networkmanagerapplet
    polkit_gnome
    dwmblocksPkg
  ];

  home.sessionVariables = {
    XMODIFIERS = "@im=fcitx";
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    SDL_IM_MODULE = "fcitx";
  };

  xdg.configFile."rofi/config.rasi".source = ./rofi/config.rasi;
  xdg.configFile."rofi/theme.rasi".source = ./rofi/theme.rasi;
  xdg.configFile."picom/picom.conf".source = ./picom.conf;
  xdg.configFile."dunst/dunstrc".source = ./dunstrc;

  systemd.user.services.dwmblocks = {
    Unit = {
      Description = "dwmblocks status bar";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${dwmblocksPkg}/bin/dwmblocks";
      Restart = "always";
      RestartSec = 2;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # Activate fcitx5 (Rime) after login.
  systemd.user.services.fcitx5-activate = {
    Unit = {
      Description = "Activate fcitx5 on login";
      PartOf = [ "graphical-session.target" ];
      After = [ "fcitx5-daemon.service" "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -lc 'sleep 1; fcitx5-remote -o >/dev/null 2>&1 || true'";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # Fcitx5 is started by Home Manager's input-method integration.

  systemd.user.services.picom = {
    Unit = {
      Description = "Picom compositor";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.picom}/bin/picom --config %h/.config/picom/picom.conf";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  systemd.user.services.dunst = {
    Unit = {
      Description = "Dunst notification daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.dunst}/bin/dunst";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  systemd.user.services.nm-applet = {
    Unit = {
      Description = "NetworkManager applet";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.networkmanagerapplet}/bin/nm-applet";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  systemd.user.services.polkit-agent = {
    Unit = {
      Description = "Polkit GNOME authentication agent";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
