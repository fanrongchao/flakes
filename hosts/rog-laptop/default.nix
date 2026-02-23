{ config, pkgs, lib, ... }:
{
  imports = [
    ./configuration.nix
    #profiles
    ../../profiles/workstation-ui/dwm
    ../../profiles/zero-trust-node.nix
    ../../profiles/network-egress-proxy.nix
    ../../profiles/devops-baseline.nix
  ];

  home-manager.backupFileExtension = "bak";
}
