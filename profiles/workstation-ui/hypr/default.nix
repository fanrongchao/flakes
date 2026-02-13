{ pkgs, inputs, lib, ... }:

{
  imports = [
    ../shared
  ];

  # Keep UI-specific Home Manager bits colocated with this UI profile.
  home-manager.users.frc.imports = [
    inputs.dank-material-shell.homeModules.dank-material-shell
    ./home.nix
  ];

  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    withUWSM = true;
  };

  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        user = "frc";
        # Keep greetd and user sessions on the exact same Hyprland package/version.
        command = "${pkgs.uwsm}/bin/uwsm start hyprland-uwsm.desktop";
      };

      # Fallback only; autologin uses initial_session.
      default_session = {
        user = "greeter";
        command = "${pkgs.tuigreet}/bin/tuigreet --cmd ${pkgs.uwsm}/bin/uwsm start hyprland-uwsm.desktop";
      };
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = lib.mkForce (with pkgs; [
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ]);
    config = {
      common = {
        default = [ "hyprland" "gtk" ];
      };
    };
  };

  security.polkit.enable = true;
}
