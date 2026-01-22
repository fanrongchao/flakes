{ config, pkgs, lib, ... }:

let
  dwmPatched = pkgs.dwm.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./patches/dwm-focusdir-togglefullscreen.diff
      ./patches/dwm-gaps.diff
    ];
    postPatch = (old.postPatch or "") + ''
      cp ${./config.h} config.def.h
    '';
  });
in
{
  imports = [
    ../shared
  ];

  home-manager.users.frc.imports = [
    ./home.nix
  ];

  services.xserver.enable = true;

  services.xserver.windowManager.dwm = {
    enable = true;
    package = dwmPatched;
  };

  services.xserver.displayManager.lightdm.enable = true;
  services.displayManager.defaultSession = "none+dwm";

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "frc";

  # Ensure systemd --user services (input-leap, dwmblocks, picom, etc.) receive
  # session env (DISPLAY/XAUTHORITY) and get graphical-session.target.
  services.xserver.displayManager.sessionCommands = ''
    export XMODIFIERS='@im=fcitx'
    export GTK_IM_MODULE=fcitx
    export QT_IM_MODULE=fcitx
    export SDL_IM_MODULE=fcitx

    systemctl --user import-environment DISPLAY XAUTHORITY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XMODIFIERS GTK_IM_MODULE QT_IM_MODULE SDL_IM_MODULE
    ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd DISPLAY XAUTHORITY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XMODIFIERS GTK_IM_MODULE QT_IM_MODULE SDL_IM_MODULE
    systemctl --user start graphical-session.target >/dev/null 2>&1 || true
  '';

  security.polkit.enable = true;
}
