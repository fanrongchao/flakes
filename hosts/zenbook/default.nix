{ config, pkgs, ... }:

{
  imports = [
    ./configuration.nix
    #profiles
    ../../profiles/workstation-ui/hypr
    ../../profiles/network-egress-proxy.nix
    ../../profiles/zero-trust-node.nix
  ];

  # Use Hypr ricing from ~/dotfiles on this host.
  home-manager.users.frc.imports = [
    ../../profiles/workstation-ui/hypr/home.nix
  ];
}
