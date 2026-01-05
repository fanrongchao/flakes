{config, pkgs, ...}:

{
  imports = [
    ./configuration.nix
    ../../profiles/workstation-ui/gnome
    ../../profiles/workstation-ui/gnome/gsconnect.nix
  ];
}
