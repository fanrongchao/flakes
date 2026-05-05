{ pkgs, ... }:

{
  home.username = "xfa";
  home.homeDirectory = "/home/xfa";
  home.stateVersion = "25.05";

  home.packages = [
    pkgs.htop
  ];
}
