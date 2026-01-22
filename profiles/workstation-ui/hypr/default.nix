{ pkgs, inputs, lib, ... }:

{
  imports = [
    ../shared
  ];

  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
  };

  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        user = "frc";
        command = "${pkgs.hyprland}/bin/Hyprland";
      };

      # Fallback only; autologin uses initial_session.
      default_session = {
        user = "greeter";
        command = "${pkgs.tuigreet}/bin/tuigreet --cmd ${pkgs.hyprland}/bin/Hyprland";
      };
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = lib.mkForce (with pkgs; [
      inputs.hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland
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
