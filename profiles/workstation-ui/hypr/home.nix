{ config, pkgs, ... }:

{
  imports = [
    ../shared/home.nix
  ];

  programs.dank-material-shell = {
    enable = true;
    systemd.enable = true;
    systemd.target = "hyprland-session.target";
    enableSystemMonitoring = true;
    dgop.package = pkgs.dgop;
  };

  home.packages = with pkgs; [
    wl-clipboard
    cliphist
    brightnessctl
  ];

  systemd.user.services.chrome-profile-cleanup = {
    Unit = {
      Description = "Clean stale Google Chrome profile locks";
      Before = [ "dms.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -lc 'rm -f \"$HOME\"/.config/google-chrome/Singleton{Lock,Socket,Cookie}'";
    };
    Install = {
      WantedBy = [ "hyprland-session.target" ];
    };
  };

  home.sessionVariables = {
    XMODIFIERS = "@im=fcitx";
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    SDL_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "ibus";
  };

  xdg.configFile."hypr/hyprland.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/hypr/hyprland.conf";

  systemd.user.targets."hyprland-session" = {
    Unit = {
      Description = "Hyprland Session Target";
      Requires = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
  };

  # Ensure fcitx5 daemon starts with the graphical session.
  systemd.user.services.fcitx5-daemon = {
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # Activate fcitx5 (Rime) after login so it's ready for Ctrl+Space.
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
}
