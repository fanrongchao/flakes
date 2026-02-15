{ config, pkgs, inputs, ... }:

let
  quickshellPatchedSrc = pkgs.applyPatches {
    name = "quickshell-libxcb";
    src = inputs.dank-material-shell.inputs.quickshell.outPath;
    patches = [
      (pkgs.writeText "quickshell-libxcb.patch" ''
        diff --git a/default.nix b/default.nix
        --- a/default.nix
        +++ b/default.nix
        @@ -16,7 +16,7 @@
           wayland,
           wayland-protocols,
           wayland-scanner,
        -  xorg,
        +  libxcb,
           libdrm,
           libgbm ? null,
           pipewire,
        @@ -77,7 +77,7 @@
             ++ lib.optionals withWayland [ wayland wayland-protocols ]
             ++ lib.optionals (withWayland && libgbm != null) [ libdrm libgbm ]
        -    ++ lib.optional withX11 xorg.libxcb
        +    ++ lib.optional withX11 libxcb
             ++ lib.optional withPam pam
             ++ lib.optional withPipewire pipewire
             ++ lib.optionals withPolkit [ polkit glib ];
      '')
    ];
  };
  quickshellPatched = pkgs.callPackage "${quickshellPatchedSrc}/default.nix" { };
in

{
  imports = [
    ../shared/home.nix
  ];

  programs.dank-material-shell = {
    enable = true;
    systemd.enable = true;
    systemd.target = "graphical-session.target";
    enableSystemMonitoring = true;
    dgop.package = pkgs.dgop;
    quickshell.package = quickshellPatched;
  };

  # DMS spawns QuickShell via the `qs` binary. Systemd --user units don't always
  # inherit the interactive shell's PATH, so ensure the per-user profile is on PATH.
  systemd.user.services.dms.Unit = {
    After = [ "graphical-session.target" ];
    Wants = [ "graphical-session.target" ];
  };

  systemd.user.services.dms.Service.Environment = [
    "PATH=/etc/profiles/per-user/%u/bin:%h/.nix-profile/bin:/run/current-system/sw/bin:/run/wrappers/bin"
  ];
  systemd.user.services.dms.Install = {
    WantedBy = [ "graphical-session.target" ];
  };

  home.packages = with pkgs; [
    wl-clipboard
    cliphist
    brightnessctl
    fuzzel
    hyprlock
    grim
    slurp
    swappy
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
      WantedBy = [ "graphical-session.target" ];
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
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/flakes/dotfiles/hypr/hyprland.conf";

  xdg.configFile."hypr/hyprlock.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/flakes/dotfiles/hyprlock/hyprlock.conf";

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
