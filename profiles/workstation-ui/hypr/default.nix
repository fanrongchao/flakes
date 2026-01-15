{ pkgs, ... }:

{
  imports = [
    ../shared
  ];

  programs.hyprland.enable = true;

  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        user = "frc";
        command = "Hyprland";
      };

      # Fallback only; autologin uses initial_session.
      default_session = {
        user = "greeter";
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --cmd Hyprland";
      };
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
  };

  security.polkit.enable = true;
}
