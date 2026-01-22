{ ... }:

{
  imports = [
    ../shared
  ];

  home-manager.users.frc.imports = [
    ./home.nix
  ];

  services.desktopManager.gnome.enable = true;
  services.displayManager.gdm.enable = true;
}
