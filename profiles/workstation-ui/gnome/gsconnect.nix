{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    wl-clipboard
    gnomeExtensions.gsconnect
    gnome-extension-manager
  ];

  services.avahi.enable = true;
}
